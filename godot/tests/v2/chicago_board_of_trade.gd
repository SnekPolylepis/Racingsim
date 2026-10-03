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
	var building = scenery.get_node("BoardOfTrade")
	assert(building.position.distance_to(Vector3(-653, 8, 788)) < .01)
	assert(not scenery.has_node("BoardOfTradeSetback") and not scenery.has_node("BoardOfTradePyramid"))
	var exterior = building.mesh
	assert(exterior.get_surface_count() == 10)
	var bounds = exterior.get_aabb()
	print("BOARD BOUNDS ", bounds)
	assert(bounds.position.x >= -32 and bounds.end.x <= 114)
	assert(bounds.position.z >= -38 and bounds.end.z <= 86)
	assert(absf(bounds.position.y) < .01)
	assert(bounds.end.y > 184 and bounds.end.y < 185)
	var lit = 0
	var clock_found = false
	var south_found = false
	for surface in exterior.get_surface_count():
		var material = exterior.surface_get_material(surface)
		assert(material.albedo_texture == null)
		var vertices = exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if material.resource_name == "Night clock ivory":
			clock_found = true
			for vertex in vertices:
				assert(vertex.z < -36 and vertex.z > -37, "Clock must face north towards LaSalle")
		elif material.resource_name == "Black annex cladding":
			south_found = true
			for vertex in vertices:
				assert(vertex.z > 35, "Office annex must be south of the historic tower")
		if material.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			assert(material.emission_enabled)
			Night.set_night(asset, false)
			assert(not material.emission_enabled)
	assert(lit == 5)
	assert(clock_found and south_found)
	print("BOARD OF TRADE RESULTS ", JSON.stringify({"checks": 31, "failures": []}))
	asset.queue_free()
	await process_frame
	quit()
