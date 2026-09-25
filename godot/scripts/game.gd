extends Node3D
## Application root: owns models and coordinates UI, persistence, fixed physics and rendering.
## See docs/ARCHITECTURE.md before changing frame order.
## The game drives CarBody on TrackAssets in native Godot coordinates (the pre-rebuild planar game was
## deleted in P7-01).
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const PropSet = preload("res://scripts/props/prop_set.gd")
const RaceModel = preload("res://scripts/race.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Storage = preload("res://scripts/storage.gd")
const Controls = preload("res://scripts/controls.gd")
const Instruments = preload("res://scripts/instruments.gd")
const Sound = preload("res://scripts/audio.gd")
const Ps2Materials = preload("res://scripts/track/ps2_materials.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const RetroRenderer = preload("res://scripts/retro_renderer.gd")
## Settings > Display choices the Look-3 presentation chain reads (RetroRenderer.apply_settings).
const PRESENTATION_SETTINGS = [
	"render_resolution",
	"upscale",
	"output_mode",
	"crt_filter",
	"framebuffer_colour",
	"colour_dither",
	"speed_blur",
	"screen_aspect",
	"ui_mode",
	"native_msaa",
	"time_of_day",
]
const DEFAULT_SETTINGS = {
	"camera": 0,
	"tilt": .72,
	"units": 0,
	"debug": false,
	"telemetry": false,
	"quality": 1,
	"render_resolution": 0,
	"upscale": 1,
	"colour_dither": true,
	"speed_blur": 1,
	"time_of_day": 0,
	"native_msaa": false,
	"output_mode": 0,
	"crt_filter": false,
	"framebuffer_colour": 0,
	"screen_aspect": 1,
	"ui_mode": 0,
	"adaptive": true,
	"fullscreen": false,
	"trackpad": 0,
	"off_track": true,
	"contact": false,
	"wear": true,
	"ghost": true,
	"automatic": true,
	"handling_model": 0,
	"simcade_grip_assist": true,
	"auto_clutch": true,
	"deadzone": .08,
	"linearity": 1.6,
	"keyboard_rate": 3.5,
	"steer_assist_kb": 1.0,
	"steer_grip_kb": false,
	"steer_grip_pad": true,
	"steer_assist_pad": .35,
	"mute": false,
	"volume": .55,
	"engine_volume": .8,
	"effects_volume": .65,
	"folder": "user://"
}
var settings = DEFAULT_SETTINGS.duplicate(true)
var track = null
var car = CarBody.new()
var race = RaceModel.new()
var visuals = Visuals.new()
var storage = Storage.new()
var controls = Controls.new()
var presets = {}
var setup_fields = []
var preset_key = "f296gt3"
var track_files = []
var active_track_file = ""
## Look-2: the few real sodium lights, moved to the lamps nearest the camera at night.
var lamp_pool = []
var model = {}
var ghost_model = {}
var ghost_warming = false
var ghost_warm_serial = 0
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var retro
var applied_time = -1
var applied_horizon = ""
## Which wooded-hill silhouette each circuit's sky carries (RetroAssets.HILLS).
const HORIZON_STYLES = {"proving_ground": "generic", "spa": "ardennes", "nordschleife_s1": "eifel"}
var ui
var instruments
var sound
var frontend
var paused = false
## Title screen is up: simulation blocked, toolbar/HUD hidden, camera orbits the car.
var in_menu = false
var menu_time = 0.0
var elapsed = 0.0
## v2 path: ground height under the camera, sampled each physics tick (surface queries only work there)
## for the camera's ground clamp in _process.
var camera_ground = -INF
var zoom_user = 1.0
var quality = 2
var quality_clock = 0.0
var quality_frames = 0
var quality_time = 0.0
var test_input = false
var benchmark_driver
var model_preset = ""
var active_record_path = ""
var record_writer
var settings_path = "user://settings.json"
var skid_root: MultiMeshInstance3D
var skid_multi: MultiMesh
var skid_cursor = 0
var skid_retire_cursor = 0
var skid_timer = 0.0
var skid_last = [null, null, null, null]
var skid_times = []
## Car state before the latest physics tick; _process blends toward the current state (render interpolation).
var prev_pose = {}
var v2_smoke = false
var v2_flow_test = false
var v2_export_check = false
var v2_visual_smoke = false
var v2_surface
var v2_walls
var v2_props
var v2_track_id = "proving_ground"
var v2_tick = 0
## `-- --v2-present` (windowed, P4-04/P4-05 check): the bot drives two laps at 3x speed while the
## camera cycles; the run then checks timing, ghost, minimap, skids and audio and saves a screenshot.
var v2_present = false
## `-- --v2-look` (Look-3): --v2-present without the laps; drive 10 s, then only the presentation check.
## `--v2-track=<id>` picks the circuit for either (default proving_ground).
var v2_look_only = false
var v2_bot = null
var v2_seen = {"ghost": false, "cameras": {}, "engine_level": 0.0}


func _ready():
	v2_visual_smoke = "--v2-visual-smoke" in OS.get_cmdline_user_args()
	v2_flow_test = "--v2-flow-test" in OS.get_cmdline_user_args()
	v2_export_check = "--v2-export-check" in OS.get_cmdline_user_args()
	# `--features` (tools/run_gates.ps1 -Features) runs the same windowed v2 check since P7-01 retired the
	# legacy feature suite; it also prints a FEATURE RESULTS line.
	v2_look_only = "--v2-look" in OS.get_cmdline_user_args()
	v2_present = (
		v2_look_only
		or "--v2-present" in OS.get_cmdline_user_args()
		or "--features" in OS.get_cmdline_user_args()
	)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v2-track="):
			v2_track_id = arg.get_slice("=", 1)
	v2_smoke = v2_visual_smoke or "--v2-smoke" in OS.get_cmdline_user_args()
	setup_v2()


func message(value):
	if frontend and frontend.v2_panels:
		frontend.v2_panels.notice(str(value))


func blocked():
	return paused or in_menu or ui.is_open()


func guard_dirty(action):
	action.call()


func request_quit():
	guard_dirty(func(): get_tree().quit())


## Compatibility cannot asynchronously compile a newly visible transparent ghost.
## Draw its real meshes once in a tiny offscreen camera during menu preparation.
## Sharing the World3D preserves the actual environment/light shader variants.
func warm_ghost():
	if DisplayServer.get_name() == "headless" or ghost_model.is_empty():
		return
	ghost_warm_serial += 1
	var serial = ghost_warm_serial
	ghost_warming = true
	camera.set_cull_mask_value(2, false)
	ghost_model.root.visible = true
	ghost_model.root.transform = model.root.transform
	var view = SubViewport.new()
	view.size = Vector2i(32, 32)
	view.world_3d = get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	var preview = Camera3D.new()
	preview.cull_mask = 2
	view.add_child(preview)
	var target = ghost_model.root.global_position + Vector3.UP * .5
	preview.global_position = target + Vector3(5, 3, 5)
	preview.look_at(target)
	if skid_multi:
		var marks = MultiMeshInstance3D.new()
		marks.layers = 2
		marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.multimesh = MultiMesh.new()
		marks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		marks.multimesh.mesh = skid_multi.mesh
		marks.multimesh.instance_count = 1
		marks.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, target + Vector3.UP))
		view.add_child(marks)
	await RenderingServer.frame_post_draw
	view.queue_free()
	if serial == ghost_warm_serial:
		ghost_warming = false
		ghost_model.root.visible = false
		camera.set_cull_mask_value(2, true)


func effective_setup():
	var values = car.setup.duplicate(true)
	values.tcsLevel = car.tcs_level()
	values.asmLevel = car.asm_level()
	values.tcOn = 1.0 if values.tcsLevel > 0 else 0.0
	values.tcIntensity = values.tcsLevel / 10.0
	return values


## The record's identity: the TrackAsset's record_key() with the effective setup, car, wear, rules and
## handling model (serialized JSON, not canonical JSON).
func record_path():
	var identity = {
		"track": track.record_key(),
		"setup": v2_effective_setup(),
		"car": preset_key,
		"wear": settings.wear,
		"off_track": settings.off_track,
		"contact": settings.contact,
		"handling": "simcade" if settings.handling_model == 0 else "simulation"
	}
	return storage.path("records", JSON.stringify(identity).sha256_text() + ".json")


func load_record():
	if record_writer:
		record_writer.flush()
	race = RaceModel.new()
	race.off_track_invalidate = settings.off_track
	race.collision_invalidate = settings.contact
	active_record_path = record_path()
	var file = active_record_path
	if FileAccess.file_exists(file):
		var saved = storage.read_json(file)
		if (
			storage.validate_ghost(saved).is_empty()
			and saved.get("schema") == 2
			and saved.get("track") == track.record_key()
			and saved.get("car", preset_key) == preset_key
			and (saved.has("configuration") or settings.handling_model == 1)
			and saved.get("configuration", active_record_path.get_file()) == active_record_path.get_file()
		):
			race.best = saved.time
			race.ghost = saved.samples
	var sector_file = active_record_path.get_basename() + ".sectors.json"
	var sectors = storage.read_json(sector_file) if FileAccess.file_exists(sector_file) else null
	if sectors is Dictionary and sectors.get("best") is Array and sectors.best.size() == 3:
		var ok = true
		for v in sectors.best:
			ok = ok and Storage.numeric(v) and v >= 0 and v < 3600
		if ok:
			race.best_sectors = [float(sectors.best[0]), float(sectors.best[1]), float(sectors.best[2])]
	if frontend:
		frontend.reset_session_history()


## Car/setup/track changes already load their record. Start a fresh session from
## that selected record without rereading thousands of ghost samples at the grid.
func begin_session():
	var previous = race
	race = RaceModel.new()
	race.best = previous.best
	race.ghost = previous.ghost
	race.best_sectors = previous.best_sectors.duplicate()
	race.off_track_invalidate = settings.off_track
	race.collision_invalidate = settings.contact


func save_sectors():
	race.sectors_dirty = false
	record_writer.enqueue(
		{
			"path": active_record_path.get_basename() + ".sectors.json",
			"data":
			{
				"schema": 1,
				"savedAt": Time.get_datetime_string_from_system(true) + "Z",
				"best": race.best_sectors.duplicate()
			}
		}
	)


func ghost_document(destination = ""):
	return {
		"schema": 2,
		"savedAt": Time.get_datetime_string_from_system(true) + "Z",
		"track": track.record_key(),
		"car": preset_key,
		"configuration": (record_path() if destination.is_empty() else destination).get_file(),
		"time": race.best,
		"samples": race.ghost
	}


func save_record():
	record_writer.enqueue({"path": active_record_path, "data": ghost_document(active_record_path)})


func save_settings():
	settings.keys = controls.keys
	settings.pad = controls.pad
	if not storage.write_json(settings_path, settings):
		message(storage.error)


## Retro rendering deliberately omits screen-space lighting and AA (RetroRenderer owns the world
## viewport's MSAA: 2x only at Native with native_msaa). Medium and High cast directional shadows;
## measured cost on this machine is about 0.15 ms of a 16.667 ms frame.
func set_quality(value):
	quality = clampi(value, 0, 2)
	sun.shadow_enabled = quality >= 1
	visuals.set_cast_shadows(sun.shadow_enabled)
	sun.directional_shadow_max_distance = 160
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if quality == 2
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	)
	sun.shadow_blur = 1.4 if quality == 2 else 1.0
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	# Ambient occlusion is a High-tier extra. Low and Medium keep the flat console fill.
	environment.ssao_enabled = quality == 2
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 1.6
	environment.ssr_enabled = false
	environment.glow_enabled = false
	environment.sdfgi_enabled = false


## P4-06 entry: initialize the separate v2 save area and front end before the first drive.
## Smoke modes still build directly so their measured route stays deterministic.
func setup_v2():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	setup_fields = JSON.parse_string(FileAccess.get_file_as_string("res://data/setup_fields.json"))
	settings_path = "user://v2/settings.json"
	if v2_smoke or v2_present or v2_flow_test or v2_export_check:
		settings_path = "user://native-tests/v2/settings.json"
	DirAccess.make_dir_recursive_absolute(settings_path.get_base_dir())
	var saved = storage.read_json(settings_path) if FileAccess.file_exists(settings_path) else {}
	if saved is Dictionary:
		for key in DEFAULT_SETTINGS:
			if saved.has(key) and typeof(saved[key]) == typeof(DEFAULT_SETTINGS[key]):
				settings[key] = saved[key]
		for key in ["keys", "pad"]:
			if saved.get(key) is Dictionary:
				settings[key] = saved[key]
	if v2_smoke or v2_present or v2_flow_test or v2_export_check:
		settings.folder = "user://native-tests/v2"
	elif settings.folder == "user://":
		settings.folder = "user://v2"
	if not storage.initialize(settings.folder):
		push_error(storage.error)
		return
	controls.configure(settings)
	car = CarBody.new()
	car.simcade_enabled = settings.handling_model == 0
	car.configure(presets[preset_key])
	car.simcade_steering = settings.simcade_grip_assist
	car.wear_enabled = settings.wear
	car.auto_clutch = settings.auto_clutch
	record_writer = preload("res://scripts/record_writer.gd").new()
	add_child(record_writer)
	setup_environment()
	set_quality(int(settings.quality))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_FULLSCREEN
				if settings.fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED
			)
		)
	# Automated drive modes need an asset immediately. Normal play opens the picker first, so its
	# loading page can appear before the first generator bake.
	if v2_smoke or v2_present or v2_export_check:
		if not load_v2_track(v2_track_id):
			get_tree().quit(1)
			return
	if v2_smoke:
		car.launch(15.0)
		controls.poll_hardware = false
		if not v2_visual_smoke:
			return
	# Sky, sun, fog and ambient light for the selected time of day.
	apply_time_of_day()
	model = visuals.make_car(car.p)
	add_child(model.root)
	# P4-04/P4-05 presentation persists across menu-driven track and car changes.
	ghost_model = visuals.make_car(car.p, true)
	add_child(ghost_model.root)
	ghost_model.root.visible = false
	var hud = CanvasLayer.new()
	hud.name = "V2UIRoot"
	add_child(hud)
	instruments = Instruments.new()
	hud.add_child(instruments)
	instruments.initialize(self)
	if track is Node3D:
		instruments.rebuild_map()
	sound = Sound.new()
	add_child(sound)
	setup_skids()
	if not v2_smoke:
		frontend = preload("res://scripts/front_end.gd").new()
		hud.add_child(frontend)
		frontend.initialize(self)
		frontend.show_page("drive" if v2_present else "main")
	# Look-3: the world camera and the whole UI root render through the PS2 presentation chain.
	if DisplayServer.get_name() != "headless":
		retro = RetroRenderer.new()
		add_child(retro)
		retro.initialize(self, hud)
	update_camera(1, true)
	prev_pose = snapshot_v2()
	if v2_present:
		settings.ghost = true
		Engine.time_scale = 3.0
		Engine.max_physics_steps_per_frame = 32
	if v2_export_check:
		call_deferred("check_exported_v2_assets")


## A packaged-build probe: both generators, Spa's raw heightmap and the tree atlas must be inside the PCK.
func check_exported_v2_assets() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var inputs = (
		FileAccess.file_exists("res://trackgen/data/spa/centreline.json")
		and FileAccess.file_exists("res://trackgen/data/spa/terrain.json")
		and FileAccess.file_exists("res://trackgen/data/spa/dem.raw")
		and FileAccess.file_exists("res://trackgen/data/spa/road-profile.json")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/centreline.json")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/terrain.json")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/dem.raw")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/centreline_full.json")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/terrain_full.json")
		and FileAccess.file_exists("res://trackgen/data/nordschleife/dem_full.raw")
		and ResourceLoader.exists("res://assets/trees/tree_atlas.png")
	)
	var ok = inputs and load_v2_track("spa") and track.id == "spa" and track.length > 6000.0
	ok = ok and load_v2_track("nordschleife_s1") and track.id == "nordschleife_s1" and track.length > 3000.0
	ok = ok and load_v2_track("nordschleife") and track.id == "nordschleife" and track.length > 20000.0
	print("V2 EXPORT ", "PASS" if ok else "FAIL")
	var scene_tree = get_tree()
	for player in find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	scene_tree.create_timer(.5).timeout.connect(scene_tree.quit.bind(0 if ok else 1))
	queue_free()


## Replace the active asset after a menu choice; release the old physics bodies first.
func load_v2_track(id: String) -> bool:
	var next = TrackDrive.load_asset(id)
	if next == null:
		return false
	var errors = next.validate()
	if not errors.is_empty():
		push_error("TrackAsset invalid: %s" % [errors])
		next.free()
		return false
	if track is Node3D and track.get_parent() == self:
		remove_child(track)
		track.free()
	track = next
	add_child(track)
	apply_track_night()
	v2_track_id = id
	if environment != null:
		apply_time_of_day()
	v2_surface = track.surface()
	v2_walls = WallQuery.new(track, car.hull_half)
	v2_props = PropSet.from_asset(track)
	place_v2_on_grid()
	load_record()
	if instruments:
		instruments.rebuild_map()
	return true


## Front-end car selection replaces the CarBody while preserving the chosen track and settings.
func change_v2_car(key: String) -> void:
	preset_key = key
	car = CarBody.new()
	car.simcade_enabled = settings.handling_model == 0
	car.configure(presets[key])
	car.simcade_steering = settings.simcade_grip_assist
	car.wear_enabled = settings.wear
	car.auto_clutch = settings.auto_clutch
	if track is Node3D and track.has_method("record_key"):
		v2_walls = WallQuery.new(track, car.hull_half)
		place_v2_on_grid()
		load_record()
	if not model.is_empty():
		model.root.queue_free()
		model = visuals.make_car(car.p)
		add_child(model.root)
	if not ghost_model.is_empty():
		ghost_model.root.queue_free()
		ghost_model = visuals.make_car(car.p, true)
		add_child(ghost_model.root)
		ghost_model.root.visible = false


## Start a fresh lap attempt at the first grid slot; keep the loaded best and sectors.
func start_v2_drive() -> void:
	in_menu = false
	paused = false
	place_v2_on_grid()
	if v2_props:
		v2_props.reset()
	begin_session()
	controls.clear()
	if frontend:
		frontend.show_page("drive")


## End driving and return to selection without closing the application.
func return_v2_menu() -> void:
	in_menu = true
	paused = false
	controls.clear()
	if record_writer:
		record_writer.flush()
	if frontend:
		frontend.show_page("main")


## V2 menu setting changes use their own save file and refresh only the systems they affect.
func set_v2_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		return
	var changed = settings[key] != value
	settings[key] = value
	controls.configure(settings)
	car.simcade_enabled = int(settings.handling_model) == 0
	car.simcade_steering = settings.simcade_grip_assist
	car.wear_enabled = settings.wear
	car.auto_clutch = settings.auto_clutch
	if key == "quality":
		set_quality(int(settings.quality))
	if key == "time_of_day":
		apply_time_of_day()
	if retro and key in PRESENTATION_SETTINGS:
		retro.apply_settings()
	if key == "fullscreen" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_FULLSCREEN
				if settings.fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED
			)
		)
	if key in ["camera", "tilt"] and camera:
		update_camera(1, true)
	if changed and key in ["wear", "off_track", "contact", "handling_model"] and track is Node3D:
		place_v2_on_grid()
		load_record()
	save_settings()


## V2 named setups are standalone schema-1 documents, independent of the legacy garage.
func v2_effective_setup() -> Dictionary:
	var values = car.setup.duplicate(true)
	values.tcsLevel = car.tcs_level()
	values.asmLevel = car.asm_level()
	values.tcOn = 1.0 if values.tcsLevel > 0 else 0.0
	values.tcIntensity = values.tcsLevel / 10.0
	return values


func v2_setup_document() -> Dictionary:
	return {
		"schema": 1,
		"savedAt": Time.get_datetime_string_from_system(true) + "Z",
		"car": preset_key,
		"setup": v2_effective_setup()
	}


func save_v2_setup(name: String) -> bool:
	var file = storage.path("setups", storage.safe_name(name) + ".json")
	var ok = storage.write_json(file, v2_setup_document())
	message("Setup saved" if ok else storage.error)
	return ok


func load_v2_setup(file: String) -> bool:
	var data = storage.read_json(file)
	if not data is Dictionary:
		message("Invalid setup JSON")
		return false
	var preset = str(data.get("car", preset_key))
	var values = data.get("setup", data)
	if not presets.has(preset) or not values is Dictionary:
		message("Unknown car or invalid setup")
		return false
	var result = presets[preset].setup.duplicate(true)
	for field in setup_fields:
		if values.has(field[1]):
			if not Storage.numeric(values[field[1]]):
				message("Invalid setup value: " + field[1])
				return false
			result[field[1]] = clampf(values[field[1]], field[3], field[4])
	for aid in ["tcsLevel", "asmLevel"]:
		if values.has(aid):
			if not Storage.numeric(values[aid]):
				message("Invalid aid level: " + aid)
				return false
			result[aid] = clampf(values[aid], 0, 10)
	if not result.has("tcsLevel"):
		result.tcsLevel = result.tcIntensity * 10 if result.tcOn > .5 else 0.0
	if not result.has("asmLevel"):
		result.asmLevel = 0.0
	if preset != preset_key:
		change_v2_car(preset)
	car.setup = result
	car.set_tcs(result.tcsLevel)
	apply_v2_setup()
	message("Loaded " + file.get_file())
	return true


## Re-rig and reset after setup edits, then select the record for that exact configuration.
func apply_v2_setup() -> void:
	car.rig()
	if track is Node3D:
		place_v2_on_grid()
		load_record()
	if frontend:
		frontend.reset_session_history()


func restart_v2_lap() -> void:
	if not track is Node3D:
		return
	place_v2_on_grid()
	if v2_props:
		v2_props.reset()
	begin_session()
	controls.clear()
	prev_pose = snapshot_v2()
	paused = false
	in_menu = false
	if frontend:
		frontend.show_page("drive")


func place_v2_on_grid():
	var slots = track.grid_slots()
	if slots.is_empty():
		push_error("TrackAsset has no grid slot")
		get_tree().quit(1)
		return
	var slot: Transform3D = slots[0]
	var forward = -slot.basis.z
	var up = slot.basis.y
	car.place(slot.origin, atan2(forward.z, forward.x), slot.origin.y)
	car.rot = Basis(forward, up, forward.cross(up)).orthonormalized().get_rotation_quaternion()
	car.pos = slot.origin + up * car.setup.cgHeight
	car.sync_legacy()
	# A reset teleports: the jump must not cross a gate, and the attempt in progress ends.
	race.reset()
	prev_pose = snapshot_v2()


## The Section 5.4 presentation snapshot. CarBody owns the pose; the game adds per-wheel
## presentation fields until the P4-04 visuals port consumes them directly.
func snapshot_v2() -> Dictionary:
	var pose = car.snapshot()
	var wheel_state = []
	for i in 4:
		var hit = car.contact_hits[i] if i < car.contact_hits.size() else {}
		wheel_state.append(
			{
				"steer": pose.steer if i < 2 else 0.0,
				"phase": pose.phase[i],
				"comp": car.wheels[i].comp,
				"contact_point": hit.get("point", Vector3.ZERO)
			}
		)
	return {"xform": pose.xform, "wheels": wheel_state, "steer": pose.steer}


func blend_v2(a: Dictionary, b: Dictionary, fraction: float) -> Dictionary:
	var ax: Transform3D = a.xform
	var bx: Transform3D = b.xform
	var wheels = []
	for i in 4:
		wheels.append(
			{
				"steer": lerpf(a.wheels[i].steer, b.wheels[i].steer, fraction),
				"phase": lerp_angle(a.wheels[i].phase, b.wheels[i].phase, fraction),
				"comp": lerpf(a.wheels[i].comp, b.wheels[i].comp, fraction),
				"contact_point": a.wheels[i].contact_point.lerp(b.wheels[i].contact_point, fraction)
			}
		)
	return {
		"xform":
		Transform3D(
			Basis(ax.basis.get_rotation_quaternion().slerp(bx.basis.get_rotation_quaternion(), fraction)),
			ax.origin.lerp(bx.origin, fraction)
		),
		"wheels": wheels,
		"steer": lerpf(a.steer, b.steer, fraction)
	}


func physics_v2(dt):
	if in_menu or paused:
		controls.events.clear()
		return
	v2_tick += 1
	if v2_tick < 3:
		return
	car.input = controls.update(dt, car.speed)
	# The bot keeps driving after the laps while the presentation check times frames.
	if v2_present or v2_bot != null:
		if v2_bot == null:
			v2_bot = BotDriver.new(track.get_node("BotLine"), car, v2_surface)
		car.input = v2_bot.command(car)
		if v2_present:
			present_tick()
	for action in controls.events:
		match action:
			"reset":
				place_v2_on_grid()
				if v2_props:
					v2_props.reset()
			"shiftUp":
				car.request_shift(1)
			"shiftDown":
				car.request_shift(-1)
	controls.events.clear()
	prev_pose = snapshot_v2()
	var old_velocity = car.vel
	car.step(dt, v2_surface, settings.automatic)
	WallContact.step(car, v2_walls)
	if v2_props:
		v2_props.step(dt, [car])
	var impact = old_velocity.distance_to(car.vel)
	if impact > .15 and sound:
		sound.impact(impact)
	if race.update_asset(car, track, dt):
		save_record()
		message("New best lap · " + RaceModel.time_text(race.best))
	if race.sectors_dirty:
		save_sectors()
	elapsed += dt
	if instruments:
		instruments.sample(car, dt)
	if skid_multi:
		skid_timer += dt
		if skid_timer >= .035:
			skid_timer = 0
			add_skids()
	if camera:
		var below = v2_surface.contact(camera.position + Vector3.UP * 2.0, Vector3.DOWN, 60.0, -1)
		camera_ground = -INF if below.is_empty() else below.point.y
	if v2_smoke and v2_tick >= 123:
		var pose = snapshot_v2()
		var blended = blend_v2(prev_pose, pose, 0.5)
		var valid = (
			car.pos.is_finite()
			and car.speed > 10.0
			and car.contacts == 4
			and pose.wheels.size() == 4
			and blended.wheels.size() == 4
			and blended.xform.origin.is_finite()
			and blended.xform.basis.is_finite()
			and (
				blended.xform.origin.distance_to(prev_pose.xform.origin)
				<= pose.xform.origin.distance_to(prev_pose.xform.origin) + 1e-5
			)
		)
		print(
			"P4-01 V2 SMOKE ",
			"PASS" if valid else "FAIL",
			" speed=",
			car.speed,
			" contacts=",
			car.contacts,
			" x=",
			car.pos
		)
		get_tree().quit(0 if valid else 1)


## --v2-present: cycle the camera every 6 s of sim, note what showed, finish after two laps; then the
## Look-3 presentation check (scripts/presentation_check.gd) runs every display mode.
func present_tick():
	if v2_tick % (240 * 6) == 0 and not v2_look_only:
		settings.camera = (int(settings.camera) + 1) % 5
		v2_seen.cameras[settings.camera] = true
	v2_seen.ghost = v2_seen.ghost or (ghost_model.has("root") and ghost_model.root.visible)
	v2_seen.engine_level = maxf(v2_seen.engine_level, sound.engine_level if sound else 0.0)
	if (race.completed < 2 and elapsed < 300.0) and not (v2_look_only and elapsed > 10.0):
		return
	v2_present = false
	var marks = 0
	for t in skid_times:
		if t > -100.0:
			marks += 1
	var checks = {}
	if not v2_look_only:
		checks = {
			"valid first lap": race.completed >= 1 and race.best > 0,
			"ghost shown on lap 2": v2_seen.ghost,
			"minimap points": instruments.map_points.size() > 100,
			"camera modes": v2_seen.cameras.size() >= 5,
			"engine audio": v2_seen.engine_level > .01,
		}
	settings.camera = 0
	update_camera(1, true)
	var look = {}
	if retro:
		var probe = preload("res://scripts/presentation_check.gd").new()
		add_child(probe)
		look = await probe.run(self)
		for name in look.checks:
			checks["look " + name] = look.checks[name]
		print("LOOK TIMINGS ", v2_track_id, " ", JSON.stringify(look.timings))
	var ok = not checks.values().has(false)
	var shot = "user://v2-present.png"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot)
	print(
		"V2 PRESENT ",
		"PASS" if ok else "FAIL",
		" ",
		JSON.stringify(
			{
				"checks": checks,
				"best": race.best,
				"last": race.last,
				"skid_marks": marks,
				"engine_level_max": v2_seen.engine_level,
				"screenshot": ProjectSettings.globalize_path(shot),
				"look_screenshots": look.get("screenshots", []).size()
			}
		)
	)
	var failures = []
	for name in checks:
		if not checks[name]:
			failures.append(name)
	print("FEATURE RESULTS ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	get_tree().quit(0 if ok else 1)


func render_v2(dt):
	if model.is_empty():
		return
	if record_writer and not record_writer.errors.is_empty():
		message(record_writer.errors.pop_front())
	if v2_props:
		v2_props.sync_nodes()
	var pose = blend_v2(prev_pose, snapshot_v2(), Engine.get_physics_interpolation_fraction())
	var xf: Transform3D = pose.xform
	model.root.transform = Transform3D(xf.basis, xf.origin - xf.basis.y * car.setup.cgHeight)
	for i in 4:
		model.pivots[i].rotation.y = -pose.wheels[i].steer
		model.pivots[i].position.y = model.wheel_r + pose.wheels[i].comp
		model.spins[i].rotation.z = -pose.wheels[i].phase
	var braking = car.input.get("brake", 0.0) > .05 or car.input.get("handbrake", 0.0) > .05
	model.brakes.emission = Color(1, .03, .01) * (1.7 if braking else .55)
	# The ghost is the 5.4 pose (race.gd update_asset), CG-referenced like the car.
	var gx = race.ghost_xform()
	ghost_model.root.visible = settings.ghost and gx != null
	if ghost_model.root.visible:
		ghost_model.root.transform = Transform3D(gx.basis, gx.origin - gx.basis.y * car.setup.cgHeight)
	update_camera(dt)
	TrackLights.update_pool(lamp_pool, track, camera.global_position, settings.time_of_day == 1)
	sound.update(car, dt, not in_menu and not paused, settings)
	instruments.queue_redraw()


## Fixed 240 Hz simulation only. Preserve controls -> car -> collisions -> race ordering.
func _physics_process(dt):
	physics_v2(dt)


## Render/audio/UI updates continue while custom simulation is blocked.
func _process(dt):
	render_v2(dt)
	adaptive_quality_v2(dt)


## Keep the v2 quality option effective without calling the legacy blocked/UI path.
func adaptive_quality_v2(dt: float) -> void:
	if in_menu or paused or not settings.adaptive:
		quality_clock = 0.0
		quality_time = 0.0
		quality_frames = 0
		return
	quality_time += dt
	quality_frames += 1
	quality_clock += dt
	if quality_clock <= 4.0:
		return
	var fps = quality_frames / maxf(.01, quality_time)
	if fps < 45 and quality > 0:
		set_quality(quality - 1)
	elif fps > 85 and quality < int(settings.quality):
		set_quality(quality + 1)
	quality_clock = 0.0
	quality_time = 0.0
	quality_frames = 0


func update_camera(dt, snap = false):
	if model.is_empty():
		return
	var forward = model.root.basis.x
	var pos = model.root.position
	var target = pos + forward * 7 + Vector3.UP * .75
	var desired = (
		pos
		- forward * (7.2 + minf(car.speed * .035, 2)) * zoom_user
		+ Vector3.UP * lerpf(7.0, 2.4, settings.tilt) * zoom_user
	)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if settings.camera == 1:
		desired = pos - forward * 16 * zoom_user + Vector3.UP * 14 * zoom_user
	elif settings.camera == 2:
		# Bonnet: on the 6-DOF car it rides with the body's roll and pitch.
		var body_up = model.root.basis.y
		desired = pos + forward * 1.3 + body_up * 1.1
		target = pos + forward * 45 + body_up
	elif settings.camera >= 3:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (42 + car.speed * .45) * zoom_user
		camera.position = pos + Vector3.UP * 120
		camera.look_at(pos, Vector3(0, 0, -1) if settings.camera == 3 else forward)
		return
	camera.position = desired if snap else camera.position.lerp(desired, 1 - exp(-dt * 7))
	var ground = camera_ground
	camera.position.y = maxf(camera.position.y, ground + (.6 if settings.camera == 2 else 1.6))
	camera.look_at(target, model.root.basis.y if settings.camera == 2 else Vector3.UP)
	camera.fov = lerpf(camera.fov, 64 + minf(car.speed * .12, 8), minf(dt * 2, 1))


func _input(event):
	if frontend and frontend.handle(event):
		get_viewport().set_input_as_handled()
		return
	controls.handle(event, not in_menu and not paused)
	# The UI root lives in RetroRenderer's UI viewport, which only sees what is forwarded to it.
	if retro and retro.forward_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if frontend:
					frontend.back()
			KEY_V:
				settings.camera = (int(settings.camera) + 1) % 5
				update_camera(1, true)
				save_settings()
			KEY_Y:
				settings.telemetry = not settings.telemetry
				save_settings()
			KEY_B:
				settings.debug = not settings.debug
				save_settings()


func setup_skids():
	skid_multi = MultiMesh.new()
	skid_multi.transform_format = MultiMesh.TRANSFORM_3D
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, .008, .22)
	mesh.material = visuals.material("252b2c")
	skid_multi.mesh = mesh
	skid_multi.instance_count = 1600
	for i in skid_multi.instance_count:
		skid_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		skid_times.append(-100.0)
	skid_root = MultiMeshInstance3D.new()
	skid_root.multimesh = skid_multi
	skid_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skid_root)


func add_skids():
	if not skid_multi:
		return
	for i in 4:
		var w = car.wheels[i]
		# v2: the wheel's contact point and ground normal (w.roadZ is its height; CarBody sets it).
		var ground = w.roadZ
		var normal = Vector3.UP
		if i < car.contact_hits.size() and not car.contact_hits[i].is_empty():
			normal = car.contact_hits[i].normal
		var pos = Vector3(w.wx, ground, w.wy) + normal * .035
		# v2: mark only a tyre past its slip peak (sliding), not one merely near its grip limit: on the
		# 6-DOF car at a fast pace `skidding` (friction ellipse > 0.92) held through every braking zone
		# and corner and filled all 1600 marks in two laps.
		var marking = (
			w.skidding
			and (absf(w.slipAngle) > car.peak_slip_angle() or absf(w.slipRatio) > car.peak_slip_ratio())
		)
		if marking and skid_last[i] != null:
			var previous = skid_last[i]
			var length = pos.distance_to(previous)
			if length > .02 and length < 5:
				var direction = (pos - previous).normalized()
				var side = direction.cross(normal).normalized()
				var up = side.cross(direction).normalized()
				skid_multi.set_instance_transform(
					skid_cursor, Transform3D(Basis(direction * length, up, side), (pos + previous) * .5)
				)
				skid_times[skid_cursor] = elapsed
				skid_cursor = (skid_cursor + 1) % skid_multi.instance_count
		skid_last[i] = pos if marking else null
	# Retire a bounded number of old marks each update.
	for j in 24:
		var index = skid_retire_cursor
		skid_retire_cursor = (skid_retire_cursor + 1) % skid_multi.instance_count
		if elapsed - skid_times[index] > 25:
			skid_multi.set_instance_transform(
				index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
			)


func setup_environment():
	var world = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_curve = 1.0
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -32, 0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = .035
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 64
	camera.near = .15
	camera.far = 3000
	add_child(camera)
	camera.make_current()
	lamp_pool = TrackLights.make_pool(self)


func apply_time_of_day():
	var night = settings.time_of_day == 1
	var horizon = HORIZON_STYLES.get(v2_track_id, "generic")
	if applied_time != int(settings.time_of_day) or applied_horizon != horizon:
		applied_time = int(settings.time_of_day)
		applied_horizon = horizon
		var sky = Sky.new()
		var paint = PanoramaSkyMaterial.new()
		paint.panorama = preload("res://scripts/retro_assets.gd").hills_panorama(night, horizon)
		sky.sky_material = paint
		environment.sky = sky
		# Daylight fill is deliberately weak and cool against a warm key. The old 0.62 ambient
		# was close enough to the sun energy that afternoon read as overcast: everything sat in
		# one mid value and nothing had a shaded side. Afterhours (Look-2) keeps the moon and fill low so
		# the amber sodium lamps carry the scene, NFS Underground style.
		environment.ambient_light_color = Color("56628c") if night else Color("9db7d6")
		environment.ambient_light_energy = .34 if night else .42
		environment.tonemap_exposure = 1.0
		# Daylight aerial perspective (GT4): a haze toward the sky's horizon blue that clears the middle
		# distance (curve > 1) and closes at 1.15 km, where the painted hill silhouette in the sky takes over
		# (RetroAssets.hills_panorama), so the world fades into wooded hills like GT4's Nordschleife overview
		# instead of ending in a bare horizon. At 2.4 km the sky met flat ground; the old 950 m wall turned
		# every hill into one pale mint band.
		environment.fog_light_color = Color("2a2433") if night else Color("a9bfd3")
		environment.fog_depth_begin = 60 if night else 150
		environment.fog_depth_end = 520 if night else 1150
		environment.fog_depth_curve = 1.0 if night else 1.8
		environment.fog_density = 1.0
		environment.fog_sky_affect = .15
		sun.light_color = Color("8ca6df") if night else Color("ffd79a")
		sun.light_energy = .32 if night else 1.5
		camera.far = 650 if night else 1250
		visuals.set_time(night)
		if not ghost_model.is_empty():
			warm_ghost.call_deferred()
	apply_track_night()


## Look-2: the loaded TrackAsset's sodium lamps and the road_v2 amber streaks follow Afterhours.
func apply_track_night() -> void:
	var night = settings.time_of_day == 1
	Ps2Materials.set_afterhours(night, track if track is Node3D else null)
	if track is Node3D:
		TrackLights.set_night(track, night)
