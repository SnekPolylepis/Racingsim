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
	var building = scenery.get_node("Michigan333")
	var exterior = building.mesh
	check(building.position.distance_to(Vector3(16.4, 8, -335.15)) < .01, "Mapped 333 North Michigan origin")
	check(absf(building.rotation.y - .021) < .0001, "Mapped facade alignment")
	check(exterior.get_surface_count() == 11, "Eleven authored surfaces")
	var bounds = exterior.get_aabb()
	check(
		bounds.position.y >= -8.01 and absf(bounds.end.y - 120.7) < .02,
		"Foundation and mechanical roof height"
	)
	check(bounds.size.x < 20 and bounds.size.z < 61, "Cornices remain close to mapped envelope")
	# Probe the clear door away from its centre metal stile.
	var entry = first_hit(exterior, Vector3(-30, 2.4, -13.6), Vector3(0, 2.4, -13.6))
	var jamb = first_hit(exterior, Vector3(-30, 2.4, -15.15), Vector3(0, 2.4, -15.15))
	print("ENTRY DEPTH ", entry, " JAMB ", jamb)
	check(
		entry != Vector3.INF and jamb != Vector3.INF and entry.x - jamb.x > 1,
		"Clear entrance has physical vestibule depth behind granite jambs"
	)
	var north_roof = first_hit(exterior, Vector3(0, 140, -16.75), Vector3(0, 0, -16.75))
	var south_roof = first_hit(exterior, Vector3(0, 140, 16.75), Vector3(0, 0, 16.75))
	print("SETBACK HEIGHTS ", north_roof, " ", south_roof)
	check(
		north_roof != Vector3.INF and south_roof != Vector3.INF and north_roof.y - south_roof.y > 25,
		"North tower rises above broad southern slab terrace"
	)
	var names = {}
	var lit = 0
	var transparent = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		names[mat.resource_name] = true
		check(mat.albedo_texture == null, "No facade photo: " + mat.resource_name)
		if mat.resource_name.begins_with("Night"):
			lit += 1
			check(mat.has_meta("chicago_night") and not mat.emission_enabled, "Occupied panes start unlit")
		elif mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .2,
				"Recessed entry glazing stays transparent"
			)
	check(
		names.size() == 11 and lit == 1 and transparent == 1,
		"Eleven distinct materials with day/night glazing"
	)
	for on in [true, false]:
		Night.set_night(asset, on)
		var correct = true
		for surface in exterior.get_surface_count():
			var mat = exterior.surface_get_material(surface)
			if mat.has_meta("chicago_night"):
				correct = correct and mat.emission_enabled == on
		check(correct, "333 North Michigan occupied-window toggle " + str(on))
	asset.queue_free()
	await process_frame
	print("MICHIGAN333 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
