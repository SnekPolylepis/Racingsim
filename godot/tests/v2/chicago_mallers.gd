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
	var exterior = load("res://scripts/track/prop_mesh.gd").mesh("res://assets/chicago/landmarks/mallers.glb")
	check(exterior.get_surface_count() == 9, "Nine physical materials")
	check(absf(exterior.get_aabb().end.y - 87) < .02, "87 metre architectural height")
	var pane = first_hit(exterior, Vector3(2.2, 25.95, -35), Vector3(2.2, 25.95, 0))
	var pier = first_hit(exterior, Vector3(-.3, 25.95, -35), Vector3(-.3, 25.95, 0))
	check(
		pane != Vector3.INF and pier != Vector3.INF and pane.z - pier.z > .25,
		"North pane physically behind masonry pier"
	)
	check(exterior.get_aabb().position.x < -27, "Physical west sign projects outside mapped wall")
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("MALLERS RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
