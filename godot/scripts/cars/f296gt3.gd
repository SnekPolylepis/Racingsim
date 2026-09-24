extends RefCounted
## Keep the separately sculpted 296 GT3 exterior and its 2023-spec reference geometry.
## This v2 entry point is intentionally thin: the Ferrari geometry is already dedicated.
const Ferrari = preload("res://scripts/ferrari_296.gd")
const Kit = preload("res://scripts/cars/car_kit.gd")


func build(visuals, preset, ghost):
	var model = Ferrari.new().build(visuals, preset, ghost)
	var kit = Kit.new()
	kit.v = visuals
	kit.p = preset
	kit.ghost = ghost
	kit.paint = Color(preset.get("color", "#bd383f"))
	kit.replace_wheels(model, "race")
	for node in model.body.find_children("*", "MeshInstance3D", true, false):
		if node.name.begins_with("LEDRunningLight") or node.name.begins_with("Projector"):
			node.visible = visuals.night and not ghost
			if not ghost:
				visuals.headlights.append(weakref(node))
		elif node.name.begins_with("TailLight") and not ghost:
			var glow = node.duplicate()
			glow.name = "TailNightGlow"
			glow.position.x -= .004
			var glow_mat = visuals.material("ff3020", .06, .2).duplicate()
			glow_mat.emission_enabled = true
			glow_mat.emission = Color("ff301a")
			glow_mat.emission_energy_multiplier = 1.3
			glow.material_override = glow_mat
			glow.visible = visuals.night
			node.get_parent().add_child(glow)
			visuals.headlights.append(weakref(glow))
	return model
