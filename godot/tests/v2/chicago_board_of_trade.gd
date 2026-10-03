extends SceneTree
const PropMesh = preload("res://scripts/track/prop_mesh.gd")


func _initialize():
	var exterior = PropMesh.mesh("res://assets/chicago/landmarks/board_of_trade.glb")
	assert(exterior.get_surface_count() == 8)
	var bounds = exterior.get_aabb()
	print("BOARD BOUNDS ", bounds)
	assert(bounds.position.x >= -27 and bounds.end.x <= 27)
	assert(bounds.position.z >= -38 and bounds.end.z <= 38)
	assert(absf(bounds.position.y) < .01)
	assert(bounds.end.y > 184 and bounds.end.y < 185)
	for surface in exterior.get_surface_count():
		assert(exterior.surface_get_material(surface).albedo_texture == null)
	print("BOARD OF TRADE RESULTS ", JSON.stringify({"checks": 13, "failures": []}))
	quit()
