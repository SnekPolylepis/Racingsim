extends SceneTree
## Washington309 working exterior: fixture, opaque arcade corners and route clearance.
const Chicago = preload("res://trackgen/chicago.gd")
var checks = 0
var failures = []


func check(ok: bool, label: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


func first_hit(exterior: Mesh, start: Vector3, end: Vector3, material_name: String = "") -> Vector3:
	var nearest = INF
	var result = Vector3.INF
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if material_name != "" and mat.resource_name != material_name:
			continue
		var arrays = exterior.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var hit = Geometry3D.segment_intersects_triangle(
				start, end, vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]
			)
			if hit != null and start.distance_squared_to(hit) < nearest:
				nearest = start.distance_squared_to(hit)
				result = hit
	return result


func run():
	var holder = Node3D.new()
	root.add_child(holder)
	var scenery = Node3D.new()
	holder.add_child(scenery)
	Chicago.add_loop_landmarks(holder, scenery)
	var fixture = scenery.get_node("Washington309")
	var exterior = fixture.mesh
	check(fixture.position.distance_to(Vector3(-934.55, 8, 201.05)) < .01, "Mapped Washington309 fixture")
	check(exterior.get_surface_count() == 7, "Washington309 seven physical materials")
	check(absf(exterior.get_aabb().end.y - 56.17) < .02, "Washington309 provisional draft tip")
	var closed = true
	for i in 24:
		var x = -14.2 + i * 1.2
		closed = closed and first_hit(exterior, Vector3(x, 2, -25), Vector3(x, 2, 0)) != Vector3.INF
	check(closed, "Washington309 north arcade has no open rays at ground level")
	var corner = first_hit(
		exterior, Vector3(-14.2, 2, -25), Vector3(-14.2, 2, 0), "Washington309 recessed masonry"
	)
	check(corner != Vector3.INF, "Washington309 opaque wall closes inset-core corner gap")
	for surface in exterior.get_surface_count():
		check(
			exterior.surface_get_material(surface).albedo_texture == null,
			"Washington309 original physical material"
		)
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w147013356"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 4, "Mapped footprint available: " + id)
		for grid in [false, true]:
			var curve: Curve3D = Chicago.route_curve(grid)
			var nearest = INF
			for station in range(0, ceili(curve.get_baked_length())):
				var p = curve.sample_baked(station, true)
				var pos = Vector2(p.x, p.z)
				if Geometry2D.is_point_in_polygon(pos, ring):
					nearest = 0
				for i in ring.size():
					nearest = minf(
						nearest,
						pos.distance_to(
							Geometry2D.get_closest_point_to_segment(pos, ring[i], ring[(i + 1) % ring.size()])
						)
					)
			print("WASHINGTON309 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(
				is_finite(nearest) and nearest > 9.5, "Both routes clear foundation: " + id + " " + str(grid)
			)
	holder.free()
	print("WASHINGTON309 DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
