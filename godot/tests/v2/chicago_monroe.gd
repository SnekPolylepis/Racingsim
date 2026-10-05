extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const Night = preload("res://scripts/track/chicago_night.gd")
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
	var asset = Node3D.new()
	root.add_child(asset)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	Chicago.add_loop_landmarks(asset, scenery)
	var building = scenery.get_node("MonroeBuilding")
	var exterior = building.mesh
	print("MONROE NATIVE BOUNDS ", exterior.get_aabb())
	check(building.position.distance_to(Vector3(-46.45, 8, 466.15)) < .01, "Mapped Monroe origin")
	check(absf(building.rotation.y - .02767) < .0001, "Mapped Monroe facade alignment")
	check(exterior.get_surface_count() == 14, "Fourteen imported surfaces across twelve materials")
	var bounds = exterior.get_aabb()
	check(
		bounds.position.y >= -8.01 and bounds.end.y > 74 and bounds.end.y < 74.3,
		"Foundation and pitched roof height"
	)
	# The authored cornice projects 0.51 m beyond each 54.4 m facade edge.
	check(bounds.size.x < 55.5 and bounds.size.z < 28.5, "Overhangs remain close to mapped envelope")
	var pane = first_hit(exterior, Vector3(40, 69.85, -.63), Vector3(20, 69.85, -.63))
	var pier = first_hit(exterior, Vector3(40, 69.85, 0), Vector3(20, 69.85, 0))
	check(
		pane != Vector3.INF and pier != Vector3.INF and pier.x - pane.x > .25,
		"Physical round-head gable glazing recessed behind surround"
	)
	var vestibule = first_hit(exterior, Vector3(.65, 3, -30), Vector3(.65, 3, 0))
	var jamb = first_hit(exterior, Vector3(2.22, 3, -30), Vector3(2.22, 3, 0))
	check(
		vestibule != Vector3.INF and jamb != Vector3.INF and vestibule.z - jamb.z > 1,
		"Clear entrance leads into actual recessed vestibule"
	)
	var names = {}
	var lit = 0
	var clear = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		names[mat.resource_name] = true
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if mat.resource_name.begins_with("Night"):
			lit += 1
			check(mat.has_meta("chicago_night") and not mat.emission_enabled, "Occupied panes start unlit")
		elif mat.resource_name.begins_with("Clear"):
			clear += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .2,
				"Entrance glazing remains transparent"
			)
	check(names.size() == 12 and lit == 1 and clear == 1, "Twelve distinct authored materials")
	for on in [true, false]:
		Night.set_night(asset, on)
		var correct = true
		for surface in exterior.get_surface_count():
			var mat = exterior.surface_get_material(surface)
			if mat.has_meta("chicago_night"):
				correct = correct and mat.emission_enabled == on
		check(correct, "Monroe occupied-window night toggle " + str(on))
	asset.queue_free()
	await process_frame
	print("MONROE RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
