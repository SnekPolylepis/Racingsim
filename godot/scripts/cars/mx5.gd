extends RefCounted
## Lexyc16's NA MX-5 exterior, fitted to the roadster physics preset.
const Kit = preload("res://scripts/cars/car_kit.gd")
const Exterior = preload("res://assets/cars/mx5na/mx5na.gltf")
const PaintShader = preload("res://shaders/mx5na_paint.gdshader")


func build(visuals, preset, ghost):
	var kit = Kit.new()
	var root = kit.start(visuals, preset, ghost, "MazdaMX5NA")
	var exterior = Exterior.instantiate()
	exterior.name = "MX5NAExterior"
	kit.body.add_child(exterior)
	var paint = ShaderMaterial.new()
	paint.shader = PaintShader
	paint.set_shader_parameter("paint_color", Color(preset.get("color", "#c1272d")))
	paint.set_shader_parameter("environment_map", visuals.RetroAssets.panorama(visuals.night, true))
	visuals.paint_materials.append(weakref(paint))
	for part in exterior.find_children("*", "MeshInstance3D", true, false):
		if part.name.begins_with("PaintedBody") or part.name.begins_with("PaintedLampPods"):
			part.material_override = paint
		if part.name.begins_with("PodGlass") or part.name.begins_with("PodTrim"):
			part.visible = visuals.night and not ghost
			if not ghost:
				visuals.headlights.append(weakref(part))
	# The source pop-up housings remain raised; fitted lens overlays glow at night.
	for side in [-1.0, 1.0]:
		var lens = kit.box(
			"NAHeadlampLens", Vector3(1.755, .69, side * .52), Vector3(.018, .10, .17), "d7d0bc"
		)
		lens.visible = visuals.night and not ghost
		if not ghost:
			visuals.headlights.append(weakref(lens))
		var head_glow = kit.box(
			"NAHeadlampNightGlow", Vector3(1.771, .69, side * .52), Vector3(.008, .085, .15), "fff0d0"
		)
		var head_mat = visuals.material("fff0d0", .04, .15).duplicate()
		head_mat.emission_enabled = true
		head_mat.emission = Color("fff1d4")
		head_mat.emission_energy_multiplier = 2.0
		head_glow.material_override = head_mat
		head_glow.visible = visuals.night and not ghost
		if not ghost:
			visuals.headlights.append(weakref(head_glow))
		var tail_glow = kit.box(
			"NATailNightGlow", Vector3(-2.027, .62, side * .47), Vector3(.008, .065, .13), "fc3028"
		)
		var tail_mat = visuals.material("fc3028", .04, .2).duplicate()
		tail_mat.emission_enabled = true
		tail_mat.emission = Color("ff3028")
		tail_mat.emission_energy_multiplier = 1.5
		tail_glow.material_override = tail_mat
		tail_glow.visible = visuals.night and not ghost
		if not ghost:
			visuals.headlights.append(weakref(tail_glow))
	var model = kit.finish(root, .83)
	visuals.merge_static(kit.body)
	return model
