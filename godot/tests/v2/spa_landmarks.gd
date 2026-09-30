extends SceneTree
## Small content guard: full track bake plus landmark/paint checks, no physics changes.
const Spa = preload("res://trackgen/spa.gd")


func _initialize() -> void:
	var asset = Spa.build_asset()
	assert(asset != null)
	assert(asset.validate().is_empty())
	var scenery = asset.get_node("Scenery")
	for title in [
		"F1Terrace00",
		"F1Terrace22",
		"RaidillonCanopy",
		"EnduranceGrandstand",
		"PaddockTeam08",
		"SpaRaceControl"
	]:
		assert(scenery.has_node(title), "Missing Spa landmark " + title)
	assert(asset.get_node("RaidillonGrandstand").rows == 18)
	assert(scenery.get_node("ArdennesNear").multimesh.instance_count > 0, "Missing Ardennes canopy")
	assert(scenery.find_children("BelgianRunoff*", "MeshInstance3D", false, false).size() == 2)
	var yellow = false
	var mesh = asset.get_node("Road/Main").mesh
	for i in mesh.get_surface_count():
		var mat = mesh.surface_get_material(i)
		if mat is StandardMaterial3D and mat.albedo_texture != null:
			var colour = mat.albedo_texture.get_image().get_pixel(0, 1)
			yellow = colour.r > .8 and colour.g > .6 and colour.b < .3
	assert(yellow, "Spa kerbs must use red/yellow Wallonia colours")
	assert(absf(asset.length - 6999.732) < .1, "Visual polish changed the surveyed racing length")
	print("SPA LANDMARKS RESULTS ", JSON.stringify({"checks": 13, "failures": []}))
	asset.free()
	quit()
