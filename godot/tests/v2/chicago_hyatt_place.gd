extends SceneTree
var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


func first_hit(exterior, start, end):
	var nearest = INF
	var result = Vector3.INF
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
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
	var exterior = load("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/hyatt_place.glb"
	)
	check(exterior.get_surface_count() == 6, "Six physical materials")
	check(absf(exterior.get_aabb().end.y - 64.4) < .02, "64.4 metre architectural height")
	var pane = first_hit(exterior, Vector3(40, 25.5, -.5406), Vector3(0, 25.5, -.5406))
	var frame = first_hit(exterior, Vector3(40, 25.5, .0812), Vector3(0, 25.5, .0812))
	print("HYATT CURTAIN HITS ", pane, " ", frame)
	check(
		pane != Vector3.INF and frame != Vector3.INF and frame.x - pane.x > .12,
		"Curtain pane physically behind metal frame"
	)
	var wing_pane = first_hit(exterior, Vector3(40, 26.95, 8.15), Vector3(0, 26.95, 8.15))
	var wing_pier = first_hit(exterior, Vector3(40, 26.95, 9.90), Vector3(0, 26.95, 9.90))
	print("HYATT WING HITS ", wing_pane, " ", wing_pier)
	check(
		wing_pane != Vector3.INF and wing_pier != Vector3.INF and wing_pier.x - wing_pane.x > .15,
		"Punched wing pane recessed in real aperture"
	)
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("HYATT RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
