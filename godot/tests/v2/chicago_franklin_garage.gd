extends SceneTree
## Draft geometry only: production placement still requires connector clearance.
const Night = preload("res://scripts/track/chicago_night.gd")
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


func first_hit(exterior: Mesh, start: Vector3, end: Vector3) -> Vector3:
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
	var exterior = PropMesh.mesh("res://assets/chicago/landmarks/franklin_garage.glb")
	var holder = Node3D.new()
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	holder.add_child(scenery)
	var fixture = MeshInstance3D.new()
	fixture.mesh = exterior
	scenery.add_child(fixture)
	var bounds = exterior.get_aabb()
	print("FRANKLIN DRAFT BOUNDS ", bounds)
	check(exterior.get_surface_count() == 7, "Seven authored draft materials")
	check(bounds.position.x > -24 and bounds.end.x < 24, "Mapped east west envelope")
	check(bounds.position.z > -33 and bounds.end.z < 33, "Mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Mapped foundation below street")
	check(absf(bounds.end.y - 50.1) < .02, "Provisional roof with separate guardrail")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Physical garage without photo: " + mat.resource_name)
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if mat.resource_name.begins_with("Night"):
			mat.set_meta("chicago_night", true)
			Night.set_night(holder, false)
			check(not mat.emission_enabled, "Day extinguishes garage fixtures")
			Night.set_night(holder, true)
			check(mat.emission_enabled, "Night enables recessed garage fixtures")
	var bay = first_hit(exterior, Vector3(-5, 11, -40), Vector3(-5, 11, -20))
	check(bay == Vector3.INF, "North parking bay has a true opening")
	var floor = first_hit(exterior, Vector3(-5, 12, -20), Vector3(-5, 8, -20))
	check(floor != Vector3.INF and absf(floor.y - 9.4) < .01, "Open bay has physical parking slab")
	var guard = first_hit(exterior, Vector3(-5, 9.9, -40), Vector3(-5, 9.9, -20))
	check(guard != Vector3.INF and guard.z < -30, "Concrete guardwall below open bay")
	print("FRANKLIN DRAFT RESULTS ", {"checks": checks, "failures": failures})
	holder.free()
	quit(0 if failures.is_empty() else 1)
