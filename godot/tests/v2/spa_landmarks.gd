extends SceneTree
## Small content guard: full track bake plus landmark/paint checks, no physics changes.
const Spa = preload("res://trackgen/spa.gd")
const Landmarks = preload("res://trackgen/spa_landmarks.gd")


func _initialize() -> void:
	var asset = Spa.build_asset()
	assert(asset != null)
	assert(asset.validate().is_empty())
	var scenery = asset.get_node("Scenery")
	for title in [
		"F1Terrace00",
		"F1Terrace22",
		"PitFootbridge",
		"HotelDeLaSource",
		"OldFrancorchampsGantry",
		"EauRougeBridge",
		"RaidillonCanopy",
		"EnduranceGrandstand",
		"StavelotFarms",
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
	var wheel_surface = SurfaceTool.new()
	wheel_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	Landmarks.wheel(wheel_surface, Vector3.ZERO, .55, .34, Color.WHITE)
	var wheel = wheel_surface.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var round_rim = false
	var bounded = not wheel.is_empty()
	var axle_min = INF
	var axle_max = -INF
	for point in wheel:
		var radial = Vector2(point.x, point.y).length()
		bounded = bounded and radial <= .5501
		round_rim = round_rim or (absf(point.x) > .01 and absf(point.y) > .01 and absf(radial - .55) < .0001)
		axle_min = minf(axle_min, point.z)
		axle_max = maxf(axle_max, point.z)
	assert(
		bounded and round_rim and absf(axle_max - axle_min - .34) < .0001,
		"Transporter wheel must have a circular XY rim and a 0.34 m Z axle"
	)
	print("SPA LANDMARKS RESULTS ", JSON.stringify({"checks": 16, "failures": []}))
	asset.free()
	quit()
