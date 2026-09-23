extends Node3D
## Standalone proving ground scene for driving the 6-DOF CarBody on analytic shapes (P2-08).
## Surfaces: flat, 8° ramp, 37° side slope, R200 crest, 20° bowl, Karussell ditch, 5 cm step, block.
## Spaced 400 m apart along +X. Evaluated analytically via TestSurface (§5.2 contact contract).

const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const Controls = preload("res://scripts/controls.gd")
const Visuals = preload("res://scripts/visuals.gd")
const VisualAdapter = preload("res://scripts/proving/visual_adapter.gd")

const ZONE_SPACING = 400.0


## Multi-zone surface implementation satisfying the §5.2 Surface contract.
class ProvingGroundSurface:
	extends RefCounted
	var zones: Array = []

	func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
		var k = clampi(roundi(origin.x / ZONE_SPACING), 0, zones.size() - 1)
		var z = zones[k]
		var local_orig = origin - z.origin
		var hit = z.surface.contact(local_orig, direction, max_dist, hint)
		if not hit.is_empty():
			hit.point += z.origin
			return hit
		return {}

	func height(x: float, z: float) -> float:
		var k = clampi(roundi(x / ZONE_SPACING), 0, zones.size() - 1)
		var zn = zones[k]
		return zn.surface.height(x - zn.origin.x, z - zn.origin.z)

	func normal(x: float, z: float) -> Vector3:
		var k = clampi(roundi(x / ZONE_SPACING), 0, zones.size() - 1)
		var zn = zones[k]
		return zn.surface.normal(x - zn.origin.x, z - zn.origin.z)


var surface: ProvingGroundSurface
var visuals: Visuals
var controls: Controls
var car: CarBody
var model: Dictionary = {}
var presets: Dictionary = {}
var preset_keys: Array = ["roadster", "gt", "f296gt3"]
var preset_idx: int = 2  # default f296gt3
var current_zone: int = 0

var prev_snapshot: Dictionary = {}
var curr_snapshot: Dictionary = {}

var camera: Camera3D
var hud_root: CanvasLayer
var hud_label: Label
var hud_visible: bool = true

# Scripted input override for tests
var scripted_input: Dictionary = {}
var scripted_active: bool = false


func _ready() -> void:
	Engine.physics_ticks_per_second = 240
	visuals = Visuals.new()
	controls = Controls.new()
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))

	_setup_environment()
	_setup_zones()
	_setup_camera()
	_setup_hud()
	_spawn_car(preset_keys[preset_idx])
	teleport_to_zone(0)


func _setup_environment() -> void:
	var sun = get_node_or_null("DirectionalLight3D")
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "DirectionalLight3D"
		sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
		sun.light_color = Color("fff5ea")
		sun.light_energy = 1.25
		sun.shadow_enabled = true
		add_child(sun)

	var env_node = get_node_or_null("WorldEnvironment")
	if env_node == null:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("769cb8")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("3a4855")
		env.ambient_light_energy = 1.0
		env_node.environment = env
		add_child(env_node)


func _setup_zones() -> void:
	surface = ProvingGroundSurface.new()

	var zone_defs = [
		{
			"name": "Flat",
			"surface": TestSurface.flat(),
			"spawn_offset": Vector3(0.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "flat"
		},
		{
			"name": "8° Ramp",
			"surface": TestSurface.ramp(8.0),
			"spawn_offset": Vector3(-50.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "ramp"
		},
		{
			"name": "37° Side Slope",
			"surface": TestSurface.side_slope(37.0),
			"spawn_offset": Vector3(-50.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "side_slope"
		},
		{
			"name": "R200 Crest",
			"surface": TestSurface.crest(0.0, 200.0, 20.0, 40.0),
			"spawn_offset": Vector3(-75.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "crest"
		},
		{
			"name": "20° Bowl",
			"surface": TestSurface.bowl(100.0, 20.0),
			"spawn_offset": Vector3(0.0, 0.0, 100.0),
			"heading": 0.0,
			"type": "bowl"
		},
		{
			"name": "Karussell Ditch",
			"surface": TestSurface.ditch(1.5, 37.0, 1.1, 0.5),
			"spawn_offset": Vector3(-60.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "ditch"
		},
		{
			"name": "5 cm Step",
			"surface": TestSurface.step(0.0, 0.05, 0.04),
			"spawn_offset": Vector3(-25.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "step"
		},
		{
			"name": "5 cm Block",
			"surface": TestSurface.block(0.0, 0.0, 1.5, 1.5, 0.05),
			"spawn_offset": Vector3(-25.0, 0.0, 0.0),
			"heading": 0.0,
			"type": "block"
		}
	]

	var surfaces_node = Node3D.new()
	surfaces_node.name = "Surfaces"
	add_child(surfaces_node)

	for i in zone_defs.size():
		var def = zone_defs[i]
		var origin = Vector3(i * ZONE_SPACING, 0.0, 0.0)
		var zone_entry = {
			"index": i,
			"name": def.name,
			"origin": origin,
			"surface": def.surface,
			"spawn": origin + def.spawn_offset,
			"heading": def.heading
		}
		surface.zones.append(zone_entry)

		var mesh_instance = _create_zone_mesh(def, origin)
		surfaces_node.add_child(mesh_instance)

		var label = Label3D.new()
		label.text = "[%d] %s" % [i + 1, def.name]
		label.position = origin + def.spawn_offset + Vector3(0.0, 3.5, -4.0)
		label.pixel_size = 0.008
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("f7f3e8")
		label.outline_modulate = Color("111b24")
		label.outline_size = 12
		surfaces_node.add_child(label)


func _create_zone_mesh(def: Dictionary, origin: Vector3) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)

	var s = def.surface
	var type = def.type

	if type == "bowl":
		_generate_bowl_mesh(st, s)
	elif type == "step":
		_generate_step_mesh(st, s)
	elif type == "block":
		_generate_block_mesh(st, s)
	else:
		_generate_grid_mesh(st, s, type)

	st.index()
	var mesh = st.commit()
	var inst = MeshInstance3D.new()
	inst.name = "Mesh_" + def.name.replace(" ", "_")
	inst.mesh = mesh
	inst.position = origin
	return inst


func _generate_grid_mesh(st: SurfaceTool, s, type: String) -> void:
	var x_span = 80.0
	var z_span = 30.0
	var step_size = 1.0

	if type == "flat":
		x_span = 75.0
		z_span = 50.0
	elif type == "crest":
		x_span = 90.0
		z_span = 25.0
	elif type == "ditch":
		x_span = 100.0
		z_span = 25.0

	var nx = int(x_span * 2.0 / step_size)
	var nz = int(z_span * 2.0 / step_size)

	for i in nx:
		var x0 = -x_span + i * step_size
		var x1 = x0 + step_size
		for j in nz:
			var z0 = -z_span + j * step_size
			var z1 = z0 + step_size

			var dark = (int(floor(x0)) + int(floor(z0))) % 2 == 0
			var c = Color(0.20, 0.22, 0.25) if dark else Color(0.25, 0.27, 0.30)
			if type == "ditch" and absf((z0 + z1) * 0.5) < 3.2:
				# Concrete plate styling for Karussell ditch
				var slab = int(floor(x0 * 0.5)) % 2 == 0
				c = Color(0.50, 0.50, 0.47) if slab else Color(0.42, 0.42, 0.39)

			_add_quad(
				st,
				Vector3(x0, s.height(x0, z0), z0),
				Vector3(x1, s.height(x1, z0), z0),
				Vector3(x1, s.height(x1, z1), z1),
				Vector3(x0, s.height(x0, z1), z1),
				s.normal(x0, z0),
				s.normal(x1, z0),
				s.normal(x1, z1),
				s.normal(x0, z1),
				c
			)


func _generate_bowl_mesh(st: SurfaceTool, s) -> void:
	var rings = 70
	var r_min = 65.0
	var r_max = 135.0
	var dr = (r_max - r_min) / rings
	var sectors = 180
	var dth = TAU / sectors

	for i in rings:
		var r0 = r_min + i * dr
		var r1 = r0 + dr
		for j in sectors:
			var th0 = j * dth
			var th1 = (j + 1) * dth

			var x00 = r0 * cos(th0)
			var z00 = r0 * sin(th0)
			var x10 = r1 * cos(th0)
			var z10 = r1 * sin(th0)
			var x11 = r1 * cos(th1)
			var z11 = r1 * sin(th1)
			var x01 = r0 * cos(th1)
			var z01 = r0 * sin(th1)

			var dark = (i + j) % 2 == 0
			var c = Color(0.21, 0.23, 0.26) if dark else Color(0.27, 0.29, 0.32)

			_add_quad(
				st,
				Vector3(x00, s.height(x00, z00), z00),
				Vector3(x10, s.height(x10, z10), z10),
				Vector3(x11, s.height(x11, z11), z11),
				Vector3(x01, s.height(x01, z01), z01),
				s.normal(x00, z00),
				s.normal(x10, z10),
				s.normal(x11, z11),
				s.normal(x01, z01),
				c
			)


func _generate_step_mesh(st: SurfaceTool, s) -> void:
	var x_coords = PackedFloat64Array()
	var x = -50.0
	while x < -1.5:
		x_coords.append(x)
		x += 1.0
	while x <= 1.5:
		x_coords.append(x)
		x += 0.05
	while x <= 50.0:
		x_coords.append(x)
		x += 1.0

	var z_span = 25.0
	var nz = int(z_span * 2.0)

	for i in range(x_coords.size() - 1):
		var x0 = x_coords[i]
		var x1 = x_coords[i + 1]
		for j in nz:
			var z0 = -z_span + j * 1.0
			var z1 = z0 + 1.0

			var near_edge = absf((x0 + x1) * 0.5) < 0.2
			var dark = (int(floor(x0)) + int(floor(z0))) % 2 == 0
			var c = (
				Color(0.85, 0.72, 0.15)
				if near_edge
				else (Color(0.20, 0.22, 0.25) if dark else Color(0.25, 0.27, 0.30))
			)

			_add_quad(
				st,
				Vector3(x0, s.height(x0, z0), z0),
				Vector3(x1, s.height(x1, z0), z0),
				Vector3(x1, s.height(x1, z1), z1),
				Vector3(x0, s.height(x0, z1), z1),
				s.normal(x0, z0),
				s.normal(x1, z0),
				s.normal(x1, z1),
				s.normal(x0, z1),
				c
			)


func _generate_block_mesh(st: SurfaceTool, s) -> void:
	var x_coords = PackedFloat64Array()
	var x = -50.0
	while x < -2.5:
		x_coords.append(x)
		x += 1.0
	while x <= 2.5:
		x_coords.append(x)
		x += 0.05
	while x <= 50.0:
		x_coords.append(x)
		x += 1.0

	var z_coords = PackedFloat64Array()
	var z = -25.0
	while z < -2.5:
		z_coords.append(z)
		z += 1.0
	while z <= 2.5:
		z_coords.append(z)
		z += 0.05
	while z <= 25.0:
		z_coords.append(z)
		z += 1.0

	for i in range(x_coords.size() - 1):
		var x0 = x_coords[i]
		var x1 = x_coords[i + 1]
		for j in range(z_coords.size() - 1):
			var z0 = z_coords[j]
			var z1 = z_coords[j + 1]

			var xm = (x0 + x1) * 0.5
			var zm = (z0 + z1) * 0.5
			var inside = absf(xm) <= 1.5 and absf(zm) <= 1.5
			var near_edge = (
				(absf(absf(xm) - 1.5) < 0.1 and absf(zm) <= 1.55)
				or (absf(absf(zm) - 1.5) < 0.1 and absf(xm) <= 1.55)
			)

			var dark = (int(floor(x0)) + int(floor(z0))) % 2 == 0
			var c = (
				Color(0.88, 0.72, 0.18)
				if near_edge
				else (
					Color(0.35, 0.38, 0.42)
					if inside
					else (Color(0.20, 0.22, 0.25) if dark else Color(0.25, 0.27, 0.30))
				)
			)

			_add_quad(
				st,
				Vector3(x0, s.height(x0, z0), z0),
				Vector3(x1, s.height(x1, z0), z0),
				Vector3(x1, s.height(x1, z1), z1),
				Vector3(x0, s.height(x0, z1), z1),
				s.normal(x0, z0),
				s.normal(x1, z0),
				s.normal(x1, z1),
				s.normal(x0, z1),
				c
			)


func _add_quad(
	st: SurfaceTool,
	v00: Vector3,
	v10: Vector3,
	v11: Vector3,
	v01: Vector3,
	n00: Vector3,
	n10: Vector3,
	n11: Vector3,
	n01: Vector3,
	color: Color
) -> void:
	# Triangle 1: [v00, v10, v01]
	st.set_color(color)
	st.set_normal(n00)
	st.add_vertex(v00)
	st.set_normal(n10)
	st.add_vertex(v10)
	st.set_normal(n01)
	st.add_vertex(v01)

	# Triangle 2: [v10, v11, v01]
	st.set_normal(n10)
	st.add_vertex(v10)
	st.set_normal(n11)
	st.add_vertex(v11)
	st.set_normal(n01)
	st.add_vertex(v01)


func _setup_camera() -> void:
	camera = get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = 55.0
		add_child(camera)
	camera.current = true


func _setup_hud() -> void:
	hud_root = CanvasLayer.new()
	hud_root.name = "HUD"
	add_child(hud_root)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = 520
	panel.offset_bottom = 360

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.11, 0.88)
	style.border_color = Color(0.35, 0.50, 0.65, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	hud_label = Label.new()
	hud_label.name = "TelemetryLabel"
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color("eef0df"))
	panel.add_child(hud_label)
	hud_root.add_child(panel)


func _spawn_car(preset_key: String) -> void:
	if not model.is_empty() and model.has("root") and is_instance_valid(model.root):
		model.root.queue_free()

	car = CarBody.new()
	car.configure(presets[preset_key])
	car.wear_enabled = false
	car.steer_falloff = 0.0

	model = VisualAdapter.make_model(visuals, presets[preset_key])
	add_child(model.root)


func teleport_to_zone(idx: int) -> void:
	if idx < 0 or idx >= surface.zones.size():
		return
	current_zone = idx
	var z = surface.zones[idx]
	car.place_on(surface, z.spawn.x, z.spawn.z, z.heading)
	car.vel = Vector3.ZERO
	car.ang = Vector3.ZERO
	car.sync_legacy()

	prev_snapshot = car.snapshot()
	curr_snapshot = prev_snapshot
	VisualAdapter.pose(model, curr_snapshot, car.setup.cgHeight)
	_update_camera(0.0, true)


func reset_car() -> void:
	teleport_to_zone(current_zone)


func cycle_preset() -> void:
	preset_idx = (preset_idx + 1) % preset_keys.size()
	_spawn_car(preset_keys[preset_idx])
	reset_car()


func set_preset(key: String) -> void:
	var idx = preset_keys.find(key)
	if idx >= 0:
		preset_idx = idx
		_spawn_car(preset_keys[preset_idx])
		reset_car()


func toggle_hud() -> void:
	hud_visible = not hud_visible
	hud_root.visible = hud_visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_8:
			teleport_to_zone(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode >= KEY_KP_1 and event.physical_keycode <= KEY_KP_8:
			teleport_to_zone(event.physical_keycode - KEY_KP_1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R:
			reset_car()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_C:
			cycle_preset()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_F1:
			toggle_hud()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if ResourceLoader.exists("res://main.tscn"):
				get_tree().change_scene_to_file("res://main.tscn")
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()
			return

	controls.handle(event, true)


func _physics_process(delta: float) -> void:
	if car == null:
		return

	var inp = scripted_input if scripted_active else controls.update(delta, car.speed)
	car.input = inp
	car.step(delta, surface, true)

	prev_snapshot = curr_snapshot
	curr_snapshot = car.snapshot()


func _process(delta: float) -> void:
	if car == null or model.is_empty():
		return

	var frac = Engine.get_physics_interpolation_fraction()
	var snap = (
		VisualAdapter.blend(prev_snapshot, curr_snapshot, frac)
		if not prev_snapshot.is_empty()
		else curr_snapshot
	)
	VisualAdapter.pose(model, snap, car.setup.cgHeight)
	_update_camera(delta)
	if hud_visible:
		_update_hud()


func _update_camera(dt: float, snap: bool = false) -> void:
	if model.is_empty() or not model.has("root"):
		return
	var forward = model.root.basis.x
	var pos = model.root.position
	var target = pos + forward * 6.5 + Vector3.UP * 0.8
	var desired = pos - forward * (6.8 + minf(car.speed * 0.035, 2.2)) + Vector3.UP * 2.7
	camera.position = desired if snap else camera.position.lerp(desired, 1.0 - exp(-dt * 8.0))
	var ground_y = surface.height(camera.position.x, camera.position.z)
	camera.position.y = maxf(camera.position.y, ground_y + 1.2)
	camera.look_at(target, Vector3.UP)


func _update_hud() -> void:
	if hud_label == null:
		return
	var b = car.basis()
	var fwd = b.x
	var up = b.y
	var right = b.z
	var pitch_deg = rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))
	var roll_deg = rad_to_deg(atan2(right.y, up.y))
	var kmh = car.speed * 3.6
	var mph = car.speed * 2.23694
	var zn = surface.zones[current_zone]

	var w_lines = []
	var names = ["FL", "FR", "RL", "RR"]
	for i in 4:
		var w = car.wheels[i]
		var hit = car.contact_hits[i] if i < car.contact_hits.size() else {}
		var s_name = "AIR" if hit.is_empty() else "SURF"
		w_lines.append(
			"  %s: load %5.0f N | comp %+4.0f mm | %s" % [names[i], w.load, w.comp * 1000.0, s_name]
		)

	hud_label.text = (
		"=== 6-DOF PROVING GROUND ===\n"
		+ "Shape:  [%d/8] %s (Origin X = %.0f m)\n" % [current_zone + 1, zn.name, zn.origin.x]
		+ "Preset: %s (%s)\n" % [car.p.name, preset_keys[preset_idx]]
		+ "Speed:  %5.1f km/h (%5.1f mph) | Gear: %d\n" % [kmh, mph, car.gear]
		+ "Body:   Roll %+.1f° | Pitch %+.1f°\n" % [roll_deg, pitch_deg]
		+ (
			"Tires:  Contacts %d/4 (Body %d) | Footprint rays %d\n"
			% [car.contacts, car.body_contacts, car.footprint_rays]
		)
		+ "\n".join(w_lines)
		+ "\n----------------------------\n"
		+ "[1-8] Shape  [R] Reset  [C] Preset  [F1] HUD  [ESC] Menu\n"
		+ "[W/A/S/D or Arrows] Drive"
	)
