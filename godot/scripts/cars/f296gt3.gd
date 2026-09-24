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
		if node.name == "LEDRunningLight" or node.name == "Projector":
			node.visible = visuals.night and not ghost
			if not ghost:
				visuals.headlights.append(weakref(node))
	return model
