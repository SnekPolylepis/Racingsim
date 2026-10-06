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
		"res://assets/chicago/landmarks/equitable.glb"
	)
	check(exterior.get_surface_count() == 7, "Seven physical materials")
	check(absf(exterior.get_aabb().end.y - 50.62) < .02, "Authored roof height")
	var pane = first_hit(exterior, Vector3(.4, 30.55, 30), Vector3(.4, 30.55, 0))
	var pier = first_hit(exterior, Vector3(2.33, 30.55, 30), Vector3(2.33, 30.55, 0))
	check(
		pane != Vector3.INF and pier != Vector3.INF and pier.z - pane.z > .3,
		"Upper panes recessed behind brick"
	)
	var door = first_hit(exterior, Vector3(.2, 2.2, 30), Vector3(.2, 2.2, 0))
	check(door != Vector3.INF and door.z < 14.5, "Entrance doors physically inset")
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photograph facade")
	print("EQUITABLE RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
