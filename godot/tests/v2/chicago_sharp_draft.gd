extends SceneTree
## Staged Sharp mesh geometry; production placement remains to integrate.
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
	var exterior = load("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/sharp_building.glb"
	)
	var bounds = exterior.get_aabb()
	check(exterior.get_surface_count() == 6, "Sharp six original physical materials")
	check(absf(bounds.position.y + 8) < .01, "Sharp buried foundation")
	check(absf(bounds.end.y - 71.5) < .02, "Sharp retained provisional mapped height")
	check(bounds.position.x > -27 and bounds.end.x < 28, "Sharp retained east west bounds")
	check(bounds.position.z > -13 and bounds.end.z < 13, "Sharp retained north south bounds")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Sharp original geometry: " + mat.resource_name)
	var pane = first_hit(exterior, Vector3(-35, 18, 3), Vector3(-20, 18, 3), "Sharp recessed blue grey panes")
	check(pane != Vector3.INF, "Sharp west facade physical recessed pane")
	print("SHARP DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
