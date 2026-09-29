extends RefCounted
## Ferrari 296 GT3 (ASSET-02): Dave Bored's CC BY 4.0 Sketchfab model (Verstappen Racing livery), fitted to the
## f296gt3 preset by tools/blender/build_car.py. Body parts are named Mat_<source material>; the wheels are the
## model's own tyre, rim and disc (left wheel, mirrored for the right side).
const Kit = preload("res://scripts/cars/car_kit.gd")
const Body = preload("res://assets/cars/f296gt3/body.glb")
const PropMesh = preload("res://scripts/track/prop_mesh.gd")
const WHEELS = ["res://assets/cars/f296gt3/wheel_front.glb", "res://assets/cars/f296gt3/wheel_rear.glb"]
## Source materials that are lamp lenses: dark by day, a glowing copy after hours.
const FRONT_LAMPS = ["EXT_Emissive_Light_Front", "EXT_Glass_Emissive_Front", "Lamp"]
const REAR_LAMPS = ["EXT_Emissive_Light_Rear", "EXT_Glass_Emissive_Rear"]


func build(visuals, preset, ghost):
	var kit = Kit.new()
	var root = kit.start(visuals, preset, ghost, "Ferrari296GT3")
	var body = Body.instantiate()
	body.name = "F296Body"
	kit.body.add_child(body)
	var ghost_mat = visuals.paint_material(Color.WHITE, true) if ghost else null
	for part in body.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = Kit.shadow_mode(part)
		if ghost:
			part.material_override = ghost_mat
			continue
		var source = String(part.name).trim_prefix("Mat_")
		for lamp in FRONT_LAMPS + REAR_LAMPS:
			if source.begins_with(lamp):
				_lamp(visuals, part, Color("fff1d4") if lamp in FRONT_LAMPS else Color("ff3020"))
	var model = kit.finish(root, 1.1)
	_wheels(model, visuals, ghost_mat)
	return model


## Turn off the source emission and add a glowing twin that only shows after hours.
func _lamp(visuals, part: MeshInstance3D, color: Color) -> void:
	for i in part.mesh.get_surface_count():
		var mat = part.mesh.surface_get_material(i)
		if mat is BaseMaterial3D and mat.emission_enabled:
			mat = mat.duplicate()
			mat.emission_enabled = false
			part.set_surface_override_material(i, mat)
	var glow = MeshInstance3D.new()
	glow.name = String(part.name) + "_NightGlow"
	glow.mesh = part.mesh
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = color
	glow_mat.emission_enabled = true
	glow_mat.emission = color
	glow_mat.emission_energy_multiplier = 2.0
	glow.material_override = glow_mat
	glow.transform = part.transform
	glow.visible = visuals.night
	part.get_parent().add_child(glow)
	visuals.headlights.append(weakref(glow))


func _wheels(model, visuals, ghost_mat) -> void:
	for i in 4:
		var spin: Node3D = model.spins[i]
		var pivot: Node3D = model.pivots[i]
		for child in spin.get_children():
			spin.remove_child(child)
			child.free()
		for child in pivot.get_children():
			if child != spin:
				pivot.remove_child(child)
				child.free()
		var wheel = MeshInstance3D.new()
		wheel.name = "TyreSidewallAndRim"
		wheel.mesh = PropMesh.mesh(WHEELS[0 if i < 2 else 1])
		# The exported wheel is the left one; the right side is its mirror.
		if i % 2 == 1:
			wheel.scale = Vector3(1, 1, -1)
		wheel.material_override = ghost_mat
		spin.add_child(wheel)
