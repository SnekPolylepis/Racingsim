extends SceneTree
## SixMichigan working exterior: fixture, opaque arcade corners and route clearance.
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
	var fixture = scenery.get_node("SixMichigan")
	var exterior = fixture.mesh
	check(fixture.position.distance_to(Vector3(-48.5, 8, 274.4)) < .01, "Mapped SixMichigan fixture")
	check(exterior.get_surface_count() == 8, "SixMichigan eight physical materials")
	check(absf(exterior.get_aabb().end.y - 86.0) < .02, "SixMichigan published architectural envelope")
	var closed = true
	for i in 24:
		var x = -23.5 + i * 2.0
		closed = closed and first_hit(exterior, Vector3(x, 2, -25), Vector3(x, 2, 0)) != Vector3.INF
	check(closed, "SixMichigan north arcade has no open rays at ground level")
	var corner = first_hit(
		exterior, Vector3(-23.5, 2, -25), Vector3(-23.5, 2, 0), "SixMichigan recessed opaque masonry"
	)
	check(corner != Vector3.INF, "SixMichigan opaque wall closes inset-core corner gap")
	for surface in exterior.get_surface_count():
		check(
			exterior.surface_get_material(surface).albedo_texture == null,
			"SixMichigan original physical material"
		)
	var visible_crown = first_hit(exterior, Vector3(40, 77, 0), Vector3(0, 77, 0))
	var crown_glass = first_hit(
		exterior, Vector3(40, 77, 0), Vector3(0, 77, 0), "SixMichigan separate recessed glass"
	)
	check(
		crown_glass != Vector3.INF and crown_glass.distance_to(visible_crown) < .01,
		"Crown glazing is ahead of opaque core"
	)
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w126982631"]:
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
			print("SIXMICHIGAN CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(
				is_finite(nearest) and nearest > 9.5, "Both routes clear foundation: " + id + " " + str(grid)
			)
	holder.free()
	print("SIXMICHIGAN DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
