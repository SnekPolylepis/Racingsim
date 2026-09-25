extends Node3D
## Standalone 6-DOF driver for any TrackAsset. Spa is baked once and cached in user://tracks3d/.
## All surface and wall queries stay in the physics callback. This dev scene writes no records.
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const Controls = preload("res://scripts/controls.gd")
const Visuals = preload("res://scripts/visuals.gd")
const VisualAdapter = preload("res://scripts/proving/visual_adapter.gd")
const PRESET_KEYS = ["roadster", "gt", "f296gt3"]
const GENERATORS = {
	"chicago": "res://trackgen/chicago.gd",
	"spa": "res://trackgen/spa.gd",
	"proving_ground": "res://trackgen/proving_ground.gd",
	"nordschleife_s1": "res://trackgen/nordschleife_s1.gd"
}

@export var track_id = "spa"
## An explicit scene overrides the generated track; its root must implement TrackAsset.
@export_file("*.tscn", "*.scn") var track_scene = ""
var asset
var surface
var walls
var car
var presets: Dictionary = {}
var preset_idx = 2
var controls = Controls.new()
var visuals = Visuals.new()
var model: Dictionary = {}
var prev_snapshot: Dictionary = {}
var curr_snapshot: Dictionary = {}
var camera: Camera3D
var hud: Label
var telemetry_visible = true
var free_fly = false
var camera_floor = -INF
var reset_pending = false
var previous_tick_rate = 240
var wall_contacts = 0
var gates: Array = []
var next_gate = 0
var clock_seconds = 0.0
var lap_started = -1.0
var sector_started = 0.0
var sector = 1
var completed_laps = 0
var last_lap = -1.0
var last_sector = -1.0
var status = "Loading track..."


## Used by the scene and the small headless drive. Cache identity changes with generator source.
static func load_asset(id: String = "spa", scene_path: String = "") -> Node3D:
	if scene_path != "":
		var supplied = load(scene_path)
		if supplied is PackedScene:
			var instance = supplied.instantiate()
			if instance is TrackAsset:
				return instance
			instance.free()
		return null
	if not GENERATORS.has(id):
		push_error("Unknown generated TrackAsset: " + id)
		return null
	var generator_path: String = GENERATORS[id]
	var generator = load(generator_path)
	if generator == null:
		return null
	var revision = _cache_revision(id, generator_path)
	var cache_path = cache_dir().path_join("%s.scn" % id)
	var revision_path = cache_path + ".revision"
	# Older packed scenes can reference resources removed from an export. Read the plain-text
	# revision first so Godot never tries to load an incompatible scene just to inspect its meta.
	if (
		FileAccess.file_exists(cache_path)
		and FileAccess.file_exists(revision_path)
		and FileAccess.get_file_as_string(revision_path) == revision
	):
		var packed = ResourceLoader.load(cache_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		if packed is PackedScene:
			var cached = packed.instantiate()
			if (
				cached is TrackAsset
				and cached.get_meta("generator_revision", "") == revision
				and cached.validate().is_empty()
			):
				print("TRACK CACHE loaded ", cache_path)
				return cached
			cached.free()
	var built = generator.build_asset()
	if built == null:
		return null
	var errors = built.validate()
	if not errors.is_empty():
		push_error("TrackAsset validation failed: %s" % [errors])
		built.free()
		return null
	built.set_meta("generator_revision", revision)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir()))
	var packed = PackedScene.new()
	var save_error = packed.pack(built)
	if save_error == OK:
		save_error = ResourceSaver.save(packed, cache_path, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_warning("Track cache could not be saved (%d); driving the generated asset" % save_error)
	else:
		var revision_file = FileAccess.open(revision_path, FileAccess.WRITE)
		if revision_file:
			revision_file.store_string(revision)
			revision_file.close()
		print("TRACK CACHE saved ", cache_path)
	return built


## The bake cache folder. A headless run (the gates) has no real renderer, so every MultiMesh it packs loses its
## instance transforms (trees, lamps, posts all saved at the origin); it keeps its own cache so the windowed game
## never loads that scene.
static func cache_dir() -> String:
	return "user://tracks3d-headless" if DisplayServer.get_name() == "headless" else "user://tracks3d"


## Include authoring tools and acquired inputs so a data/tool update cannot reuse stale geometry.
static func _cache_revision(id: String, generator_path: String) -> String:
	# This file too: a change to how the cache is written (e.g. the headless split) invalidates old bakes.
	var files: Array[String] = [generator_path, "res://scripts/proving/track_drive.gd"]
	var directories: Array[String] = ["res://scripts/track", "res://shaders", "res://trackgen/data/" + id]
	while not directories.is_empty():
		var directory = directories.pop_back()
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for child in DirAccess.get_directories_at(directory):
			directories.append(directory.path_join(child))
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".uid") and not file.ends_with(".import"):
				files.append(directory.path_join(file))
	files.sort()
	var signature = ""
	for file in files:
		signature += file + ":" + FileAccess.get_sha256(file) + "\n"
	return signature.sha256_text()


## Grid -Z is forward; the car is +X forward. Preserve grid slope and banking, not just heading.
static func place_on_grid(body, slot: Transform3D) -> void:
	var marker = slot.basis.orthonormalized()
	var forward = -marker.z
	body.place(slot.origin, atan2(forward.z, forward.x), slot.origin.y)
	body.rot = Basis(forward, marker.y, marker.x).get_rotation_quaternion()
	body.pos = slot.origin + marker.y * body.setup.cgHeight
	body.vel = Vector3.ZERO
	body.ang = Vector3.ZERO
	body.mark_pose()
	body.sync_legacy()


func _ready() -> void:
	previous_tick_rate = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 240
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	if get_tree().has_meta("dev_track_id"):
		track_id = str(get_tree().get_meta("dev_track_id"))
		get_tree().remove_meta("dev_track_id")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_id = arg.trim_prefix("--track=")
		if arg.begins_with("--track-scene="):
			track_scene = arg.trim_prefix("--track-scene=")
	_setup_presentation()
	_load_track.call_deferred()


func _load_track() -> void:
	# Let the loading label render before the first synchronous road/terrain bake.
	await get_tree().process_frame
	asset = load_asset(track_id, track_scene)
	if asset == null or not (asset is TrackAsset):
		status = "Could not load TrackAsset. Esc returns to the menu."
		return
	add_child(asset)
	var errors = asset.validate()
	if not errors.is_empty():
		status = "Invalid TrackAsset: %s" % [errors]
		return
	surface = asset.surface()
	gates = asset.gates()
	_spawn_car()
	status = ""


func _setup_presentation() -> void:
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sun.light_color = Color("fff5ea")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("769cb8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8794a0")
	env.ambient_light_energy = .65
	world.environment = env
	add_child(world)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 6500.0
	add_child(camera)
	camera.current = true
	var canvas = CanvasLayer.new()
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(20, 20)
	hud.add_theme_font_size_override("font_size", 19)
	hud.add_theme_color_override("font_color", Color("eef0df"))
	var box = StyleBoxFlat.new()
	box.bg_color = Color(.025, .04, .065, .86)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	hud.add_theme_stylebox_override("normal", box)
	hud.text = status
	canvas.add_child(hud)


func _spawn_car() -> void:
	var simcade = car.simcade_enabled if car != null else false
	if not model.is_empty():
		model.root.queue_free()
	car = CarBody.new()
	car.simcade_enabled = simcade
	car.configure(presets[PRESET_KEYS[preset_idx]])
	car.wear_enabled = false
	model = VisualAdapter.make_model(visuals, presets[PRESET_KEYS[preset_idx]])
	add_child(model.root)
	walls = WallQuery.new(asset, car.hull_half)
	reset_pending = true


func reset_car() -> void:
	place_on_grid(car, asset.grid_slots()[0])
	controls.clear()
	reset_pending = false
	wall_contacts = 0
	next_gate = 0
	clock_seconds = 0.0
	lap_started = -1.0
	sector_started = 0.0
	sector = 1
	completed_laps = 0
	last_lap = -1.0
	last_sector = -1.0
	prev_snapshot = car.snapshot()
	curr_snapshot = prev_snapshot
	VisualAdapter.pose(model, curr_snapshot, car.setup.cgHeight)
	camera_floor = -INF
	_update_chase(0.0, true)


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if reset_pending:
		reset_car()
	if free_fly:
		return
	var previous_position = car.pos
	car.input = controls.update(delta, car.speed)
	for action in controls.events:
		if action == "reset":
			reset_pending = true
	controls.events.clear()
	car.step(delta, surface, true)
	wall_contacts = WallContact.step(car, walls)
	clock_seconds += delta
	_update_timing(previous_position, car.pos, delta)
	prev_snapshot = curr_snapshot
	curr_snapshot = car.snapshot()
	# Camera collision uses TrackSurface too, so query here rather than in _process.
	var ground = surface.contact(camera.position + Vector3.UP * 5.0, Vector3.DOWN, 30.0, -1)
	camera_floor = ground.point.y + 1.1 if not ground.is_empty() else -INF


func _update_timing(p0: Vector3, p1: Vector3, dt: float) -> void:
	for _i in gates.size():
		var gate = gates[next_gate]
		if not TrackAsset.crossed(gate, p0, p1):
			break
		var d0 = (p0 - gate.origin).dot(gate.normal)
		var d1 = (p1 - gate.origin).dot(gate.normal)
		var crossed_at = clock_seconds - dt + dt * d0 / (d0 - d1)
		if gate.kind == "start":
			if lap_started >= 0.0:
				last_lap = crossed_at - lap_started
				last_sector = crossed_at - sector_started
				completed_laps += 1
			lap_started = crossed_at
			sector_started = crossed_at
			sector = 1
		elif gate.kind == "sector":
			last_sector = crossed_at - sector_started
			sector_started = crossed_at
			sector += 1
		next_gate = (next_gate + 1) % gates.size()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://main.tscn")
			KEY_R:
				reset_pending = true
			KEY_C:
				if car != null:
					preset_idx = (preset_idx + 1) % PRESET_KEYS.size()
					_spawn_car()
			KEY_M:
				if car != null:
					car.simcade_enabled = not car.simcade_enabled
					reset_pending = true
			KEY_F1:
				telemetry_visible = not telemetry_visible
			KEY_F2:
				free_fly = not free_fly
				controls.clear()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_:
				controls.handle(event, not free_fly)
				return
		get_viewport().set_input_as_handled()
		return
	if free_fly and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if free_fly and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * .003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * .003, -1.5, 1.5)
		camera.rotation.z = 0.0
	controls.handle(event, not free_fly)


func _process(delta: float) -> void:
	hud.visible = telemetry_visible or car == null
	if car == null or curr_snapshot.is_empty():
		hud.text = status
		return
	var snap = VisualAdapter.blend(prev_snapshot, curr_snapshot, Engine.get_physics_interpolation_fraction())
	VisualAdapter.pose(model, snap, car.setup.cgHeight)
	if free_fly:
		var direction = Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
		camera.position += (
			camera.basis
			* direction.normalized()
			* delta
			* (140.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 35.0)
		)
	else:
		_update_chase(delta)
	_update_hud()


func _update_chase(dt: float, snap = false) -> void:
	var forward: Vector3 = model.root.basis.x
	var pos: Vector3 = model.root.position
	var target = pos + forward * 6.5 + Vector3.UP * .8
	var desired = pos - forward * (6.8 + minf(car.speed * .035, 2.2)) + Vector3.UP * 2.7
	camera.position = desired if snap else camera.position.lerp(desired, 1.0 - exp(-dt * 8.0))
	camera.position.y = maxf(camera.position.y, camera_floor)
	camera.look_at(target, Vector3.UP)


func _update_hud() -> void:
	var elapsed = clock_seconds - lap_started if lap_started >= 0.0 else -1.0
	var b = car.basis()
	var wheel_lines: Array[String] = []
	for i in 4:
		var wheel = car.wheels[i]
		wheel_lines.append(
			"%s %4.0f N / %+3.0f mm" % [["FL", "FR", "RL", "RR"][i], wheel.load, wheel.comp * 1000.0]
		)
	hud.text = (
		(
			"%s  |  %s  |  %s\n"
			% [asset.display_name, car.p.name, "Simcade" if car.simcade_enabled else "Simulation"]
		)
		+ "%.1f km/h  |  Gear %d  |  %.0f RPM\n" % [car.speed * 3.6, car.gear, car.rpm]
		+ (
			"Lap %d: %s  |  Sector %d  |  Last lap %s\n"
			% [completed_laps + 1, _time_text(elapsed), sector, _time_text(last_lap)]
		)
		+ "Last sector %s  |  Gate %d/%d\n" % [_time_text(last_sector), next_gate + 1, gates.size()]
		+ (
			"Roll %+.1f deg  |  Pitch %+.1f deg  |  Contacts %d/4  |  Walls %d\n"
			% [
				rad_to_deg(atan2(b.z.y, b.y.y)),
				rad_to_deg(asin(clampf(b.x.y, -1, 1))),
				car.contacts,
				wall_contacts
			]
		)
		+ "  ".join(wheel_lines)
		+ "\n"
		+ str(asset.get_meta("attribution", ""))
		+ "\nWASD / Arrows / Gamepad: drive  |  Space: handbrake\n"
		+ "R: grid  C: car  M: handling (resets lap)  F1: HUD  F2: camera  Esc: menu"
		+ ("\nFREE FLY (car paused): WASD / Q E / Shift fast / hold RMB to look" if free_fly else "")
	)


static func _time_text(seconds: float) -> String:
	return "%d:%06.3f" % [int(seconds) / 60, fmod(seconds, 60.0)] if seconds >= 0.0 else "--:--.---"


func _exit_tree() -> void:
	Engine.physics_ticks_per_second = previous_tick_rate
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
