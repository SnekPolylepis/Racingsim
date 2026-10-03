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
	var building = scenery.get_node("JewelersBuilding")
	check(building.position.distance_to(Vector3(-198.2, 8, -192.35)) < .01, "Mapped building origin")
	check(absf(building.rotation.y - City.JEWELERS_YAW) < .0001, "North facade follows Wacker angle")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 10, "Ten authored material surfaces")
	var bounds = exterior.get_aabb()
	print("JEWELERS BOUNDS ", bounds)
	check(bounds.position.x > -26 and bounds.end.x < 26, "Mapped east/west envelope")
	check(bounds.position.z > -24 and bounds.end.z < 24, "Mapped north/south envelope")
	check(absf(bounds.position.y) < .01, "Street base at zero")
	check(absf(bounds.end.y - 159.4) < .1, "Referenced dome top height")
	var lit = 0
	var clock_found = false
	var dome_found = false
	var triangles = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Original geometry, no facade photograph: " + mat.resource_name)
		var arrays = exterior.surface_get_arrays(surface)
		triangles += (
			arrays[Mesh.ARRAY_INDEX].size() / 3
			if not arrays[Mesh.ARRAY_INDEX].is_empty()
			else arrays[Mesh.ARRAY_VERTEX].size() / 3
		)
		if mat.resource_name == "Night clock ivory":
			clock_found = true
			var northeast = true
			for v in arrays[Mesh.ARRAY_VERTEX]:
				northeast = northeast and v.x > 22 and v.z < -23
			check(northeast, "Clock is on the northeast street corner")
		if mat.resource_name == "Carved terra cotta dome":
			dome_found = true
			var high = false
			var corner = false
			for v in arrays[Mesh.ARRAY_VERTEX]:
				high = high or v.y > 158
				corner = corner or (absf(v.x) > 18 and absf(v.z) > 15 and v.y > 102)
			check(high and corner, "Central dome and corner turret domes are physical geometry")
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission enabled: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Day emission disabled: " + mat.resource_name)
	check(lit == 4, "Occupied windows, clock and crown accents respond to time of day")
	check(clock_found and dome_found, "Required crown and clock materials present")
	check(triangles > 20000, "Exterior includes dimensional architectural detail")
	print("JEWELERS TRIANGLES ", triangles)
	asset.queue_free()
	await process_frame
	print("JEWELERS RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
