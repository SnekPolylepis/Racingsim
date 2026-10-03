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
	Chicago.add_loop_landmarks(asset, scenery)
	var tower = scenery.get_node("TribuneTower")
	assert(tower.mesh.get_surface_count() == 5)
	assert(tower.position.distance_to(Vector3(67.1, 8, -632.6)) < .01)
	var bounds = tower.mesh.get_aabb()
	assert(bounds.position.x >= -21 and bounds.end.x <= 21)
	assert(bounds.position.z >= -25 and bounds.end.z <= 25)
	assert(absf(bounds.position.y) < .01 and absf(bounds.end.y - 141) < .01)
	assert(not scenery.has_node("TribuneSpire"), "The old triangular cap is removed")
	var lit = 0
	for surface in tower.mesh.get_surface_count():
		var mat = tower.mesh.surface_get_material(surface)
		assert(mat.albedo_texture == null, "No facade image covers this exterior")
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			assert(mat.emission_enabled)
			Night.set_night(asset, false)
			assert(not mat.emission_enabled)
	assert(lit == 1)
	print("TRIBUNE RESULTS ", JSON.stringify({"checks": 14, "failures": []}))
	asset.queue_free()
	await process_frame
	quit()
