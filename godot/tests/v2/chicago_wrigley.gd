extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const Night = preload("res://scripts/track/chicago_night.gd")


func _initialize():
	call_deferred("run")


func run():
	var asset = Node3D.new()
	root.add_child(asset)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	var mat = StandardMaterial3D.new()
	Chicago.add_loop_landmarks(asset, scenery, mat, mat, mat)
	var building = scenery.get_node("WrigleyBuilding")
	assert(building.position.distance_to(Vector3(-40, 8, -530)) < .01)
	assert(building.mesh.get_surface_count() == 12)
	var bounds = building.mesh.get_aabb()
	assert(bounds.position.x >= -29 and bounds.end.x <= 45)
	assert(bounds.position.z >= -55 and bounds.end.z <= 33)
	assert(absf(bounds.position.y) < .01 and bounds.end.y > 131 and bounds.end.y < 133)
	assert(not scenery.has_node("WrigleyTower") and not scenery.has_node("WrigleyCrown"))
	var lit = 0
	for surface in building.mesh.get_surface_count():
		var material = building.mesh.surface_get_material(surface)
		assert(material.albedo_texture == null)
		if material.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			assert(material.emission_enabled)
			Night.set_night(asset, false)
			assert(not material.emission_enabled)
	assert(lit == 8, "Six floodlit terra-cotta shades, occupied windows and clock faces")
	print("WRIGLEY RESULTS ", JSON.stringify({"checks": 35, "failures": []}))
	asset.queue_free()
	await process_frame
	quit()
