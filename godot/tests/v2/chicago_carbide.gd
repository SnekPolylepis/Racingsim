extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const City = preload("res://trackgen/chicago_city.gd")
const Night = preload("res://scripts/track/chicago_night.gd")
var checks = 0
var failures = []


func check(ok: bool, label: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


func run():
	var asset = Node3D.new()
	root.add_child(asset)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	Chicago.add_loop_landmarks(asset, scenery)
	var building = scenery.get_node("CarbideCarbon")
	check(building.position.distance_to(Vector3(-50.4, 8, -192.2)) < .01, "Mapped origin")
	check(absf(building.rotation.y - City.CARBIDE_YAW) < .0001, "Mapped footprint orientation")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 8, "Eight original architectural materials")
	var bounds = exterior.get_aabb()
	print("CARBIDE BOUNDS ", bounds)
	check(bounds.position.x > -21 and bounds.end.x < 21, "Footprint east/west envelope")
	check(bounds.position.z > -23 and bounds.end.z < 23, "Footprint north/south envelope")
	check(absf(bounds.position.y) < .01, "Base rests at street level")
	check(absf(bounds.end.y - 153.3) < .05, "Referenced architectural cap height")
	var lit = 0
	var gold_found = false
	var granite_found = false
	var triangles = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		var arrays = exterior.surface_get_arrays(surface)
		triangles += (
			arrays[Mesh.ARRAY_INDEX].size() / 3
			if not arrays[Mesh.ARRAY_INDEX].is_empty()
			else arrays[Mesh.ARRAY_VERTEX].size() / 3
		)
		if mat.resource_name == "Polished black granite base":
			granite_found = true
			var low = true
			for v in arrays[Mesh.ARRAY_VERTEX]:
				low = low and v.y < 13.2
			check(low, "Polished granite stays on the podium")
		if mat.resource_name == "Night gilded crown and relief":
			gold_found = true
			var cap = false
			var east = true
			var frieze = false
			for v in arrays[Mesh.ARRAY_VERTEX]:
				if v.y > 142:
					cap = true
					east = east and v.x > 4 and v.x < 14
				frieze = frieze or (v.y > 127 and v.y < 131)
			check(cap and east, "Narrow gilded cap occupies east-end tower")
			check(frieze, "Physical gilded shoulder ornament")
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Day emission: " + mat.resource_name)
	check(lit == 2, "Selective windows and gilded cap toggle at night")
	check(gold_found and granite_found, "Distinctive base and crown materials")
	check(triangles > 20000, "Dimensional window and ornament detail")
	print("CARBIDE TRIANGLES ", triangles)
	asset.queue_free()
	await process_frame
	print("CARBIDE RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
