extends SceneTree
## Wacker250 working exterior geometry, fixture and retained footprint clearance.
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
	var fixture = scenery.get_node("Wacker250")
	var exterior = fixture.mesh
	check(
		fixture.position.distance_to(Vector3(-1070.15, 8, 712.55)) < .01,
		"Wacker250 mapped production fixture"
	)
	var bounds = exterior.get_aabb()
	check(exterior.get_surface_count() == 7, "Wacker250 seven original physical materials")
	check(absf(bounds.position.y + 8) < .01, "Wacker250 buried foundation")
	check(absf(bounds.end.y - 61.3) < .02, "Wacker250 published architectural tip")
	check(bounds.position.x > -22 and bounds.end.x < 22, "Wacker250 retained east west bounds")
	check(bounds.position.z > -27 and bounds.end.z < 27, "Wacker250 retained north south bounds")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Wacker250 original geometry: " + mat.resource_name)
	var pane = first_hit(
		exterior, Vector3(-6.4, 18, -40), Vector3(-6.4, 18, -20), "Wacker250 recessed blue green glazing"
	)
	check(pane != Vector3.INF, "Wacker250 physical north glazing")
	var visible = first_hit(exterior, Vector3(-6.4, 18, -40), Vector3(-6.4, 18, -20))
	check(pane != Vector3.INF and visible.distance_to(pane) < .01, "Wacker250 north pane exposed")
	var feature = first_hit(
		exterior, Vector3(15, 80, -20), Vector3(15, 50, -20), "Wacker250 opaque white glazed feature panels"
	)
	check(feature != Vector3.INF and absf(feature.y - 61.3) < .02, "Wacker250 separate higher white corner")
	var flank = first_hit(
		exterior, Vector3(7, 70, -25), Vector3(7, 45, -25), "Wacker250 opaque white glazed feature panels"
	)
	check(flank != Vector3.INF and absf(flank.y - 57.5) < .02, "Wacker250 white flank below feature")
	var atrium = first_hit(
		exterior, Vector3(7, 4, -40), Vector3(7, 4, -20), "Wacker250 recessed blue green glazing"
	)
	check(atrium != Vector3.INF, "Wacker250 physical atrium beneath flank")
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w147350207"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 7, "Mapped footprint available: " + id)
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
			print("WACKER250 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(
				is_finite(nearest) and nearest > 9.5, "Both routes clear foundation: " + id + " " + str(grid)
			)
	holder.free()
	print("WACKER250 DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
