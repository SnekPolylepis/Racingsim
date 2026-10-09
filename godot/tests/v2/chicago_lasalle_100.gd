extends SceneTree
## LaSalle100 working exterior geometry, fixture and retained footprint clearance.
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
	scenery.name = "Scenery"
	holder.add_child(scenery)
	Chicago.add_loop_landmarks(holder, scenery)
	var fixture = scenery.get_node("LaSalle100")
	var exterior = fixture.mesh
	check(
		fixture.position.distance_to(Vector3(-695, 8, 148.95)) < .01, "LaSalle100 mapped production fixture"
	)
	var bounds = exterior.get_aabb()
	check(exterior.get_surface_count() == 8, "LaSalle100 eight original physical materials")
	check(absf(bounds.position.y + 8) < .01, "LaSalle100 buried foundation")
	check(absf(bounds.end.y - 90.0) < .02, "LaSalle100 published architectural height")
	check(bounds.position.x > -14.6 and bounds.end.x < 14.6, "LaSalle100 retained east west bounds")
	check(bounds.position.z > -15.7 and bounds.end.z < 15.7, "LaSalle100 retained north south bounds")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "LaSalle100 original geometry: " + mat.resource_name)
	var pane = first_hit(
		exterior, Vector3(30, 2, 0), Vector3(10, 2, 0), "LaSalle100 recessed green grey windows"
	)
	var visible = first_hit(exterior, Vector3(30, 2, 0), Vector3(10, 2, 0))
	check(
		pane != Vector3.INF and visible.distance_to(pane) < .01, "LaSalle100 portal opening remains visible"
	)
	var top = first_hit(
		exterior, Vector3(0, 100, 0), Vector3(0, 80, 0), "LaSalle100 opaque interior and flat roof"
	)
	check(top != Vector3.INF and absf(top.y - 87.5) < .02, "LaSalle100 solid main roof")
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w147095666"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 6, "Mapped footprint available: " + id)
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
			print("LASALLE100 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(
				is_finite(nearest) and nearest > 9.5, "Both routes clear foundation: " + id + " " + str(grid)
			)
	holder.free()
	print("LASALLE100 DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
