extends SceneTree
## LaSalle100 working exterior geometry, fixture and retained footprint clearance.
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
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
	var exterior = PropMesh.mesh("res://assets/chicago/landmarks/monroe_311.glb")
	check(exterior.get_surface_count() == 7, "Monroe311 seven physical materials")
	check(absf(exterior.get_aabb().end.y - 62.5) < .02, "Monroe311 published architectural height")
	var closed = true
	for i in 40:
		var x = -24.2 + i * 1.2
		closed = closed and first_hit(exterior, Vector3(x, 2, -40), Vector3(x, 2, -20)) != Vector3.INF
	check(closed, "Monroe311 north arcade has no open rays at ground level")
	var corner = first_hit(
		exterior, Vector3(-24.2, 2, -40), Vector3(-24.2, 2, -20), "Monroe311 recessed granite spandrels"
	)
	check(corner != Vector3.INF, "Monroe311 opaque wall closes inset-core corner gap")
	for surface in exterior.get_surface_count():
		check(
			exterior.surface_get_material(surface).albedo_texture == null,
			"Monroe311 original physical material"
		)
	print("MONROE311 DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
