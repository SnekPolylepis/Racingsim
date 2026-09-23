extends RefCounted
## Art direction only: stylized after-dark circuit furniture. The car is authored in ferrari_296.gd.
## No writes to the Track document or Car setup; grip, barriers and record identity remain unchanged.
## Lamps/pools share 64 m spacing with road.gdshader's authored light streaks.
const SPACING = 64.0


static func glow(color, energy = 2.0):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(color)
	mat.emission_energy_multiplier = energy
	return mat


static func box(parent, pos, size, mat):
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node


static func build(parent, track, world):
	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color("18283f")
	metal.metallic = .45
	metal.roughness = .55
	var amber = glow("ffb34f", 2.1)
	var corona_material = ShaderMaterial.new()
	corona_material.shader = preload("res://shaders/lamp_corona.gdshader")
	corona_material.set_shader_parameter("lamp_colour", Color("ffc177"))
	var corona_quad = QuadMesh.new()
	corona_quad.size = Vector2(3.2, 3.2)
	var lamps = Node3D.new()
	lamps.name = "NightCircuit"
	parent.add_child(lamps)
	for i in range(ceili(track.length / SPACING)):
		var p = track.pos_at(i * SPACING)
		var side = -1 if i % 2 == 0 else 1
		var offset = side * (p.w / 2 + 4.5)
		var x = p.x - sin(p.h) * offset
		var y = p.y + cos(p.h) * offset
		# Avoid placing decorative posts in a neighbouring section of track.
		var pr = track.project(x, y)
		if absf(pr.lat) < pr.width / 2 + 2.0:
			continue
		var root = Node3D.new()
		root.position = Vector3(x, world.ground_height(x, y), y)
		root.rotation.y = -p.h
		lamps.add_child(root)
		var mat = amber
		box(root, Vector3(0, 4.5, 0), Vector3(.18, 9, .18), metal)
		box(root, Vector3(0, 8.9, -side * 1.5), Vector3(.17, .18, 3.2), metal)
		box(root, Vector3(0, 8.74, -side * 2.7), Vector3(.7, .09, 1.0), mat)
		var corona = MeshInstance3D.new()
		corona.name = "LampHalo"
		corona.mesh = corona_quad
		corona.material_override = corona_material
		corona.position = Vector3(0, 8.70, -side * 2.7)
		corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corona.extra_cull_margin = 2
		root.add_child(corona)
		box(root, Vector3(0, 1.2, -side * .12), Vector3(.22, 1.7, .06), mat)
		var light = OmniLight3D.new()
		light.position = Vector3(0, 7.1, -side * 2.5)
		light.light_color = Color("ffc177")
		light.light_energy = 3.4
		light.omni_range = 27
		light.omni_attenuation = 1.35
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 115
		light.distance_fade_length = 35
		root.add_child(light)
		if i % 4 == 0:
			# Backlit original circuit-event signage, not copied sponsor/game logos.
			box(root, Vector3(0, 3.5, side * 2.1), Vector3(.20, 1.65, 3.5), metal)
			box(root, Vector3(-.12, 4.34, side * 2.1), Vector3(.04, .06, 3.55), amber)
			var label = Label3D.new()
			label.text = "AFTERHOURS" if i % 8 == 0 else "NIGHT RUN"
			label.font_size = 68
			label.pixel_size = .006
			label.position = Vector3(-.13, 3.55, side * 2.1)
			label.rotation.y = -PI / 2
			label.modulate = Color("ffc177")
			root.add_child(label)
	# Low amber pit accents follow the start straight rather than changing its geometry.
	var start_s = float(track.data.startS if track.data.startS != null else 0)
	for i in range(-10, 13):
		var a = track.pos_at(start_s + i * 7)
		for side in [-1, 1]:
			var pos = Vector3(
				a.x - sin(a.h) * side * (a.w / 2 + 2.4), a.z + .5, a.y + cos(a.h) * side * (a.w / 2 + 2.4)
			)
			var rail = box(lamps, pos, Vector3(5.2, .055, .07), amber)
			rail.rotation.y = -a.h
