extends Node3D
## Application root: owns models and coordinates UI, persistence, fixed physics and rendering.
## See docs/ARCHITECTURE.md before changing frame order.
## P4-01 drives the TrackAsset/CarBody path in native Godot coordinates. Legacy feature harnesses
## remain on the planar path until their dependent P4 ports are complete.
const TrackModel = preload("res://scripts/track3d.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const PropSet = preload("res://scripts/props/prop_set.gd")
const CarModel = preload("res://scripts/car.gd")
const RaceModel = preload("res://scripts/race.gd")
const Collisions = preload("res://scripts/collisions.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Storage = preload("res://scripts/storage.gd")
const Controls = preload("res://scripts/controls.gd")
const Interface = preload("res://scripts/interface.gd")
const Instruments = preload("res://scripts/instruments.gd")
const Sound = preload("res://scripts/audio.gd")
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
var track = TrackModel.new()
var car = CarModel.new()
var race = RaceModel.new()
var visuals = Visuals.new()
var storage = Storage.new()
var controls = Controls.new()
var presets = {}
var setup_fields = []
var preset_key = "f296gt3"
var track_files = []
var active_track_file = ""
var scenery: Node3D
var model = {}
var ghost_model = {}
var ghost_warming = false
var ghost_warm_serial = 0
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var retro
var applied_time = -1
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
var test_mode = false
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
var v2_mode = false
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
var v2_bot = null
var v2_seen = {"ghost": false, "cameras": {}, "engine_level": 0.0}


func _ready():
	test_mode = (
		"--features" in OS.get_cmdline_user_args()
		or "--smoke" in OS.get_cmdline_user_args()
		or "--art-review" in OS.get_cmdline_user_args()
		or "--title-review" in OS.get_cmdline_user_args()
		or "--compare" in OS.get_cmdline_user_args()
		or "--showcase" in OS.get_cmdline_user_args()
		or "--flow-benchmark" in OS.get_cmdline_user_args()
		or "--performance" in OS.get_cmdline_user_args()
		or "--audio-review" in OS.get_cmdline_user_args()
	)
	v2_visual_smoke = "--v2-visual-smoke" in OS.get_cmdline_user_args()
	v2_flow_test = "--v2-flow-test" in OS.get_cmdline_user_args()
	v2_export_check = "--v2-export-check" in OS.get_cmdline_user_args()
	v2_present = "--v2-present" in OS.get_cmdline_user_args()
	v2_smoke = v2_visual_smoke or "--v2-smoke" in OS.get_cmdline_user_args()
	v2_mode = v2_smoke or not test_mode
	if v2_mode:
		setup_v2()
		return
	if test_mode:
		settings_path = "user://native-tests/settings.json"
		DirAccess.make_dir_recursive_absolute("user://native-tests")
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	setup_fields = JSON.parse_string(FileAccess.get_file_as_string("res://data/setup_fields.json"))
	var saved = storage.read_json(settings_path) if FileAccess.file_exists(settings_path) else {}
	if saved is Dictionary:
		for k in DEFAULT_SETTINGS:
			if (
				saved.has(k)
				and (
					typeof(saved[k]) == typeof(DEFAULT_SETTINGS[k])
					or (Storage.numeric(saved[k]) and Storage.numeric(DEFAULT_SETTINGS[k]))
				)
			):
				settings[k] = saved[k]
		for k in ["keys", "pad"]:
			if saved.get(k) is Dictionary:
				settings[k] = saved[k]
	if "--title-review" in OS.get_cmdline_user_args():
		settings = DEFAULT_SETTINGS.duplicate(true)
	if test_mode:
		settings.folder = "user://native-tests"
		settings.fullscreen = false
	if not storage.initialize(settings.folder):
		storage.initialize()
		settings.folder = "user://"
	controls.configure(settings)
	car.simcade_enabled = settings.handling_model == 0
	car.configure(presets[preset_key])
	setup_environment()
	setup_retro_grade()
	ui = Interface.new()
	add_child(ui)
	ui.initialize(self)
	if ui and ui.menu_car:
		ui.menu_car.select(presets.keys().find(preset_key))
	sound = Sound.new()
	add_child(sound)
	record_writer = preload("res://scripts/record_writer.gd").new()
	add_child(record_writer)
	refresh_tracks()
	load_track_now(track_files[0])
	apply_settings()
	setup_skids()
	frontend = preload("res://scripts/front_end.gd").new()
	ui.root.add_child(frontend)
	ui.root.move_child(frontend, ui.blocker.get_index())
	frontend.initialize(self)
	retro.attach_ui()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_quit)
	get_window().focus_exited.connect(
		func():
			if test_mode and benchmark_driver != null:
				return
			controls.clear()
			if not test_mode and not in_menu:
				set_paused(true)
	)
	if test_mode:
		if "--title-review" in OS.get_cmdline_user_args():
			frontend.show_page("boot")
		call_deferred("run_feature_tests")
	else:
		frontend.show_page("boot")


func message(value):
	if ui and is_instance_valid(ui.status):
		ui.status.text = value


func blocked():
	return paused or in_menu or ui.is_open()


func guard_dirty(action):
	action.call()


func request_quit():
	guard_dirty(func(): get_tree().quit())


func refresh_tracks():
	track_files = []
	var bundled = Array(DirAccess.get_files_at("res://tracks"))
	bundled.sort()
	bundled.erase("Spa-Francorchamps.json")
	bundled.push_front("Spa-Francorchamps.json")
	for name in bundled:
		if name.ends_with(".json"):
			track_files.append("res://tracks/" + name)
	if ui and ui.menu_track:
		ui.menu_track.clear()
		for file in track_files:
			ui.menu_track.add_item(file.get_file().get_basename())
		var index = track_files.find(active_track_file)
		if index >= 0:
			ui.menu_track.select(index)


func load_track(index):
	if index >= 0 and index < track_files.size():
		request_track_file(track_files[index])


func request_track_file(file):
	var previous = track_files.find(active_track_file)
	if previous >= 0 and ui and ui.menu_track:
		ui.menu_track.select(previous)
	guard_dirty(
		func():
			load_track_now(file)
			ui.close()
	)


## Low-level load without a discard prompt. UI callers should use request_track_file.
func load_track_now(file):
	var d = storage.read_json(file)
	var error = storage.validate_track(d)
	if not error.is_empty():
		message(error)
		return false
	track.load_data(d)
	active_track_file = file
	rebuild_world()
	reset_car()
	load_record()
	refresh_tracks()
	instruments.rebuild_map()
	message("%s · %.3f km" % [track.data.name, track.length / 1000])
	return true


func rebuild_world():
	if is_instance_valid(scenery):
		scenery.free()
	scenery = Node3D.new()
	add_child(scenery)
	track.build_barriers()
	if not track.samples.is_empty():
		visuals.build_track(scenery, track)
	apply_time_of_day()


## Reset motion, tire state, run progress and visible car meshes; keep the selected record.
## Call load_record separately when track/car/setup/rules identity has changed.
func reset_car():
	car.reset_pose(track.grid_pose())
	race.reset()
	controls.clear()
	instruments.reset()
	skid_last = [null, null, null, null]
	if skid_multi:
		for i in skid_multi.instance_count:
			skid_multi.set_instance_transform(
				i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
			)
	for o in track.data.objects:
		if o.type == "cone":
			o.x = o.get("ox", o.x)
			o.y = o.get("oy", o.y)
			o.vx = 0
			o.vy = 0
	if model.is_empty() or model_preset != preset_key:
		if model.has("root"):
			model.root.free()
		if ghost_model.has("root"):
			ghost_model.root.free()
		model = visuals.make_car(car.p)
		ghost_model = visuals.make_car(car.p, true)
		add_child(model.root)
		add_child(ghost_model.root)
		model_preset = preset_key
		for mesh in ghost_model.root.find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 2
		warm_ghost.call_deferred()
	model.root.visible = true
	ghost_model.root.visible = false
	prev_pose = {}
	if retro:
		retro.valid_history = false
	visuals.pose_car(model, car.snapshot(), track)
	update_camera(1, true)


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


func change_car(key):
	preset_key = key
	car.configure(presets[key])
	if ui and ui.menu_car:
		ui.menu_car.select(presets.keys().find(key))
	reset_car()
	load_record()


func choose_file(kind, write):
	ui.dialogs += 1
	controls.clear()
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if write else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; Racing Sim JSON"])
	dialog.title = ("Export " if write else "Import ") + kind
	add_child(dialog)
	if write:
		dialog.current_file = (
			storage.safe_name(car.p.name if kind == "setup" else track.data.name)
			+ (".ghost.json" if kind == "ghost" else ".json")
		)
	dialog.file_selected.connect(
		func(path):
			ui.dialogs -= 1
			dialog.queue_free()
			if write:
				var data = setup_document() if kind == "setup" else ghost_document()
				if kind == "ghost" and race.ghost.is_empty():
					message("No best lap to export")
					return
				message("Exported " + path.get_file() if storage.write_json(path, data) else storage.error)
			elif kind == "setup":
				import_setup(path)
			else:
				import_ghost(path)
	)
	dialog.canceled.connect(
		func():
			ui.dialogs -= 1
			dialog.queue_free()
	)
	dialog.popup_centered_ratio(.75)


func choose_folder():
	ui.dialogs += 1
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = "Choose racing data folder"
	add_child(dialog)
	dialog.dir_selected.connect(
		func(path):
			ui.dialogs -= 1
			dialog.queue_free()
			connect_storage(path)
	)
	dialog.canceled.connect(
		func():
			ui.dialogs -= 1
			dialog.queue_free()
	)
	dialog.popup_centered_ratio(.75)


func connect_storage(folder):
	var old = storage.root
	if not storage.initialize(folder):
		message(storage.error)
		storage.initialize(old)
		return
	settings.folder = folder
	save_settings()
	refresh_tracks()
	load_record()
	ui.open_library()
	message("Connected " + ProjectSettings.globalize_path(folder))


func use_local_storage():
	connect_storage("user://")


func delete_file(file):
	if file.begins_with("res://"):
		return
	if DirAccess.remove_absolute(file) != OK:
		message("Could not delete " + file.get_file())
		return
	refresh_tracks()
	message("Deleted " + file.get_file())


func effective_setup():
	var values = car.setup.duplicate(true)
	values.tcsLevel = car.tcs_level()
	values.asmLevel = car.asm_level()
	values.tcOn = 1.0 if values.tcsLevel > 0 else 0.0
	values.tcIntensity = values.tcsLevel / 10.0
	return values


func setup_document():
	return {
		"schema": 1,
		"savedAt": Time.get_datetime_string_from_system(true) + "Z",
		"car": preset_key,
		"setup": effective_setup()
	}


func save_setup(name):
	var file = storage.path("setups", storage.safe_name(name) + ".json")
	var action = func():
		message("Setup saved" if storage.write_json(file, setup_document()) else storage.error)
		ui.open_garage()
	if FileAccess.file_exists(file):
		ui.confirm("Replace setup?", file.get_file() + " already exists.", action)
	else:
		action.call()


func import_setup(file):
	var data = storage.read_json(file)
	if not data is Dictionary:
		message("Invalid setup JSON")
		return false
	var preset = data.get("car", preset_key)
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
	for key in ["tcsLevel", "asmLevel"]:
		if values.has(key):
			if not Storage.numeric(values[key]):
				message("Invalid aid level: " + key)
				return false
			result[key] = clampf(values[key], 0, 10)
	if not result.has("tcsLevel"):
		result.tcsLevel = (result.tcIntensity * 10) if result.tcOn > .5 else 0.0
	# Old setups preserve their aids rather than silently enabling stability management.
	if not result.has("asmLevel"):
		result.asmLevel = 0.0
	change_car(preset)
	car.setup = result
	car.set_tcs(result.tcsLevel)
	reset_car()
	load_record()
	ui.open_garage()
	message("Loaded " + file.get_file())
	return true


## Build a native configuration identity from document/setup/car/rules.
## Exclude track name/timestamp and cone runtime state; this is serialized JSON, not canonical JSON.
func record_path():
	var identity = {
		"track": track.record_key() if v2_mode else track.data.duplicate(true),
		"setup": effective_setup(),
		"car": preset_key,
		"wear": settings.wear,
		"off_track": settings.off_track,
		"contact": settings.contact,
		"handling": "simcade" if settings.handling_model == 0 else "simulation"
	}
	if v2_mode:
		return storage.path("records", JSON.stringify(identity).sha256_text() + ".json")
	identity.track.erase("savedAt")
	identity.track.erase("name")
	# Default-on fields added after records existed must not change old record identities.
	if identity.track.get("autoBarriers", true):
		identity.track.erase("autoBarriers")
	for o in identity.track.objects:
		for k in ["vx", "vy", "hit"]:
			o.erase(k)
		if o.type == "cone":
			o.x = o.ox
			o.y = o.oy
	return storage.path("records", JSON.stringify(identity).sha256_text() + ".json")


func legacy_ghost_path():
	return storage.path("ghosts", storage.safe_name(track.data.name) + ".ghost.json")


func load_record():
	if record_writer:
		record_writer.flush()
	race = RaceModel.new()
	race.off_track_invalidate = settings.off_track
	race.collision_invalidate = settings.contact
	active_record_path = record_path()
	var file = active_record_path
	if not v2_mode and not FileAccess.file_exists(file):
		file = legacy_ghost_path()
	if FileAccess.file_exists(file):
		var saved = storage.read_json(file)
		if (
			storage.validate_ghost(saved).is_empty()
			and (not v2_mode or (saved.get("schema") == 2 and saved.get("track") == track.record_key()))
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


## Best individual sector times live beside the record: records/<hash>.sectors.json {"schema":1,"best":[s1,s2,s3]}.
func sectors_path():
	return record_path().get_basename() + ".sectors.json"


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
		"schema": 2 if v2_mode else 1,
		"savedAt": Time.get_datetime_string_from_system(true) + "Z",
		"track": track.record_key() if v2_mode else storage.safe_name(track.data.name) + ".json",
		"car": preset_key,
		"configuration": (record_path() if destination.is_empty() else destination).get_file(),
		"time": race.best,
		"samples": race.ghost
	}


func save_record():
	var job = {"path": active_record_path, "data": ghost_document(active_record_path)}
	if not v2_mode:
		job.legacy = legacy_ghost_path()
	record_writer.enqueue(job)


func import_ghost(file):
	record_writer.flush()
	var data = storage.read_json(file)
	var error = storage.validate_ghost(data)
	if not error.is_empty():
		message(error)
		return false
	race.best = data.time
	race.ghost = data.samples
	storage.write_json(record_path(), ghost_document())
	message("Imported best lap " + RaceModel.time_text(race.best))
	return true


func clear_ghost():
	record_writer.flush()
	for file in [record_path(), legacy_ghost_path(), sectors_path()]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	race.best = 0
	race.ghost = []
	race.delta = null
	race.best_sectors = [0.0, 0.0, 0.0]
	race.session_sectors = [0.0, 0.0, 0.0]
	message("Best lap and sectors cleared")


func save_settings():
	settings.keys = controls.keys
	settings.pad = controls.pad
	if not storage.write_json(settings_path, settings):
		message(storage.error)


func apply_settings():
	controls.dead = clampf(settings.deadzone, 0, .3)
	controls.linearity = clampf(settings.linearity, 1, 3)
	controls.keyboard_rate = clampf(settings.keyboard_rate, 1, 8)
	car.simcade_enabled = settings.handling_model == 0
	car.simcade_steering = settings.simcade_grip_assist
	car.wear_enabled = settings.wear
	car.auto_clutch = settings.auto_clutch
	race.off_track_invalidate = settings.off_track
	race.collision_invalidate = settings.contact
	set_quality(int(settings.quality))
	if retro:
		retro.apply_settings()
	apply_time_of_day()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Retro rendering deliberately omits screen-space lighting and AA. Medium and High cast
## directional shadows; measured cost on this machine is about 0.15 ms of a 16.667 ms frame.
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
	var view = retro.world_view if retro else get_viewport()
	view.msaa_3d = (
		Viewport.MSAA_2X
		if settings.render_resolution == 2 and settings.native_msaa
		else Viewport.MSAA_DISABLED
	)
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
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
	add_child(hud)
	instruments = Instruments.new()
	hud.add_child(instruments)
	instruments.initialize(self)
	if track is Node3D:
		instruments.rebuild_map()
	sound = Sound.new()
	add_child(sound)
	setup_skids()
	if not v2_smoke and not v2_present:
		frontend = preload("res://scripts/front_end.gd").new()
		hud.add_child(frontend)
		frontend.initialize(self)
		frontend.show_page("main")
	update_camera(1, true)
	prev_pose = snapshot_v2()
	if v2_present:
		settings.ghost = true
		Engine.time_scale = 3.0
		Engine.max_physics_steps_per_frame = 32
	if v2_export_check:
		call_deferred("check_exported_v2_assets")


## A packaged-build probe: both generators and Spa's raw heightmap must be inside the PCK.
func check_exported_v2_assets() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var inputs = (
		FileAccess.file_exists("res://trackgen/data/spa/centreline.json")
		and FileAccess.file_exists("res://trackgen/data/spa/terrain.json")
		and FileAccess.file_exists("res://trackgen/data/spa/dem.raw")
		and FileAccess.file_exists("res://trackgen/data/spa/road-profile.json")
	)
	var loaded = inputs and load_v2_track("spa")
	var ok = loaded and track.id == "spa" and track.length > 6000.0
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
	v2_track_id = id
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
	if v2_present:
		if v2_bot == null:
			v2_bot = BotDriver.new(track.get_node("BotLine"), car, v2_surface)
		car.input = v2_bot.command(car)
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


## --v2-present: cycle the camera every 6 s of sim, note what showed, finish after two laps.
func present_tick():
	if v2_tick % (240 * 6) == 0:
		settings.camera = (int(settings.camera) + 1) % 5
		v2_seen.cameras[settings.camera] = true
	v2_seen.ghost = v2_seen.ghost or (ghost_model.has("root") and ghost_model.root.visible)
	v2_seen.engine_level = maxf(v2_seen.engine_level, sound.engine_level if sound else 0.0)
	if race.completed < 2 and elapsed < 300.0:
		return
	v2_present = false
	var marks = 0
	for t in skid_times:
		if t > -100.0:
			marks += 1
	var checks = {
		"valid first lap": race.completed >= 1 and race.best > 0,
		"ghost shown on lap 2": v2_seen.ghost,
		"minimap points": instruments.map_points.size() > 100,
		"camera modes": v2_seen.cameras.size() >= 5,
		"engine audio": v2_seen.engine_level > .01,
	}
	var ok = not checks.values().has(false)
	var shot = "user://v2-present.png"
	settings.camera = 0
	update_camera(1, true)
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
				"screenshot": ProjectSettings.globalize_path(shot)
			}
		)
	)
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
	sound.update(car, dt, not in_menu and not paused, settings)
	instruments.queue_redraw()


## Fixed 240 Hz simulation only. Preserve controls -> car -> collisions -> race ordering.
func _physics_process(dt):
	if v2_mode:
		physics_v2(dt)
		return
	if blocked() or track.samples.is_empty():
		prev_pose = {}
		return
	if frontend and frontend.page == "attract":
		frontend.demo_driver.feed(controls, car, track, settings)
	car.input = controls.update(dt, car.speed)
	# Speed-sensitive steering: strength 1 halves lock at 14 m/s (browser default), 0 = none.
	var assist = float(settings.steer_assist_pad if controls.pad_active else settings.steer_assist_kb)
	car.steer_falloff = 14.0 / assist if assist > .001 else 0.0
	var grip_assist = settings.steer_grip_pad if controls.pad_active else settings.steer_grip_kb
	car.steer_slip_limit = car.peak_slip_angle() * .85 if grip_assist else 0.0
	if test_input:
		car.input.throttle = 1.0
	for action in controls.events:
		if action == "reset":
			reset_car()
		elif action == "shiftUp":
			car.request_shift(1)
		elif action == "shiftDown":
			car.request_shift(-1)
	controls.events.clear()
	prev_pose = car.snapshot()
	car.step(dt, track, settings.automatic)
	var old_v = Vector2(car.vx, car.vy)
	Collisions.step(car, track, dt)
	if benchmark_driver != null:
		benchmark_driver.observe(car, track, car.collided)
	var impact = old_v.distance_to(Vector2(car.vx, car.vy))
	if impact > .15:
		sound.impact(impact)
	var attract = frontend != null and frontend.page == "attract"
	if not attract and race.update(car, track, dt):
		save_record()
		message("New best lap · " + RaceModel.time_text(race.best))
	if not attract and race.sectors_dirty:
		save_sectors()
	if frontend and not attract:
		frontend.observe_tick()
	instruments.sample(car, dt)
	elapsed += dt
	skid_timer += dt
	if skid_timer >= .035:
		skid_timer = 0
		add_skids()


## Render/audio/UI updates continue while custom simulation is blocked.
func _process(dt):
	if v2_mode:
		render_v2(dt)
		return
	if model.is_empty():
		return
	if record_writer and not record_writer.errors.is_empty():
		message(record_writer.errors.pop_front())
	var started = Time.get_ticks_usec()
	ui.sync_menus()
	if in_menu:
		menu_time += dt
		visuals.pose_car(model, car.snapshot(), track)
		visuals.animate(track, elapsed)
		var pos = model.root.position
		var ang = menu_time * .18 + 2.2
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 40
		camera.position = pos + Vector3(cos(ang) * 8.8, 1.9 + sin(menu_time * .11) * .4, sin(ang) * 8.8)
		camera.look_at(pos + Vector3.UP * .55 + model.root.basis.x * .3, Vector3.UP)
		# Frame the car in the unobscured right side of the menu.
		camera.look_at(pos + Vector3.UP * .55 + model.root.basis.x * .3 - camera.basis.x * 1.55, Vector3.UP)
	else:
		var now = car.snapshot()
		visuals.pose_car(
			model,
			(
				now
				if prev_pose.is_empty()
				else CarModel.blend(prev_pose, now, Engine.get_physics_interpolation_fraction())
			),
			track
		)
		visuals.animate(track, elapsed)
		update_camera(dt)
	var gp = race.ghost_pose()
	if not ghost_warming:
		ghost_model.root.visible = settings.ghost and not gp.is_empty()
	if ghost_model.root.visible and not ghost_warming:
		var el = track.elev_at(gp[0], gp[1])
		var forward = Vector3(cos(gp[2]), el.gx * cos(gp[2]) + el.gy * sin(gp[2]), sin(gp[2])).normalized()
		var right = Vector3(-sin(gp[2]), -el.gx * sin(gp[2]) + el.gy * cos(gp[2]), cos(gp[2])).normalized()
		var up = right.cross(forward).normalized()
		ghost_model.root.transform = Transform3D(
			Basis(forward, up, forward.cross(up).normalized()), Vector3(gp[0], el.z, gp[1])
		)
	sound.update(car, dt, not blocked(), settings)
	instruments.queue_redraw()
	quality_time += dt
	quality_frames += 1
	quality_clock += dt
	if settings.adaptive and quality_clock > 4 and not blocked():
		var fps = quality_frames / maxf(.01, quality_time)
		if fps < 45 and quality > 0:
			set_quality(quality - 1)
		elif fps > 85 and quality < int(settings.quality):
			set_quality(quality + 1)
		quality_clock = 0
		quality_time = 0
		quality_frames = 0
	instruments.frame_ms = lerpf(instruments.frame_ms, (Time.get_ticks_usec() - started) / 1000.0, .1)


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
		var body_up = model.root.basis.y if v2_mode else Vector3.UP
		desired = pos + forward * 1.3 + body_up * 1.1
		target = pos + forward * 45 + body_up
	elif settings.camera >= 3:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (42 + car.speed * .45) * zoom_user
		camera.position = pos + Vector3.UP * 120
		camera.look_at(pos, Vector3(0, 0, -1) if settings.camera == 3 else forward)
		return
	camera.position = desired if snap else camera.position.lerp(desired, 1 - exp(-dt * 7))
	var ground = camera_ground if v2_mode else track.elev_at(camera.position.x, camera.position.z).z
	camera.position.y = maxf(camera.position.y, ground + (.6 if settings.camera == 2 else 1.6))
	camera.look_at(target, model.root.basis.y if v2_mode and settings.camera == 2 else Vector3.UP)
	camera.fov = lerpf(camera.fov, 64 + minf(car.speed * .12, 8), minf(dt * 2, 1))


func cycle_camera():
	settings.camera = (int(settings.camera) + 1) % 5
	update_camera(1, true)
	save_settings()
	message(["Chase", "High chase", "Bonnet", "Overhead north", "Overhead car"][settings.camera] + " camera")


func toggle_pause():
	if ui.is_open():
		ui.close()
		return
	if in_menu:
		return
	set_paused(not paused)


func set_paused(value):
	paused = value
	controls.clear()
	prev_pose = {}
	if frontend:
		frontend.show_page("pause" if value else "drive")


## Return to the title screen. The car waits on the grid.
func show_main_menu():
	ui.close()
	paused = false
	in_menu = true
	menu_time = 0.0
	reset_car()
	if frontend:
		frontend.show_page("main")
	ui.sync_menus()


func start_drive():
	ui.close()
	in_menu = false
	paused = false
	reset_car()
	if frontend:
		frontend.show_page("drive")
	ui.sync_menus()


func _input(event):
	if v2_mode:
		if frontend and frontend.handle(event):
			get_viewport().set_input_as_handled()
			return
		controls.handle(event, not in_menu and not paused)
		return
	# Automated laps own their input stream. Desktop events must not pause a
	# timing sample or change its driving controls; ordinary play is unaffected.
	if test_mode and benchmark_driver != null and not event.has_meta("showcase_input"):
		get_viewport().set_input_as_handled()
		return
	if frontend and frontend.handle(event):
		get_viewport().set_input_as_handled()
		return
	var listening = not controls.listening.is_empty()
	if controls.handle(event, not blocked()):
		if listening and controls.listening.is_empty():
			save_settings()
			ui.update_mapping_labels()
		get_viewport().set_input_as_handled()
		return
	if retro and retro.forward_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if v2_mode:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE:
					return_v2_menu()
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
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if ui.is_open():
				ui.close()
			else:
				toggle_pause()
			return
		if ui.is_open() or in_menu:
			return
		match event.physical_keycode:
			KEY_G:
				ui.open_garage()
			KEY_V:
				cycle_camera()
			KEY_M:
				settings.automatic = not settings.automatic
				save_settings()
			KEY_B:
				settings.debug = not settings.debug
				save_settings()
			KEY_Y:
				settings.telemetry = not settings.telemetry
				save_settings()
			KEY_F11:
				settings.fullscreen = not settings.fullscreen
				apply_settings()
				save_settings()
	if ui.is_open() or in_menu:
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	):
		zoom_user = clampf(
			zoom_user * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / .9), .5, 2.5
		)
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		toggle_pause()


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
		var ground = w.roadZ if v2_mode else track.elev_at(w.wx, w.wy, w.sIdx).z
		var normal = Vector3.UP
		if v2_mode and i < car.contact_hits.size() and not car.contact_hits[i].is_empty():
			normal = car.contact_hits[i].normal
		var pos = Vector3(w.wx, ground, w.wy) + normal * .035
		# v2: mark only a tyre past its slip peak (sliding), not one merely near its grip limit: on the
		# 6-DOF car at a fast pace `skidding` (friction ellipse > 0.92) held through every braking zone
		# and corner and filled all 1600 marks in two laps.
		var marking = w.skidding
		if v2_mode:
			marking = (
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


## Deferred after startup so the UI/models exist; the runner owns test completion and exit.
func run_feature_tests():
	if "--audio-review" in OS.get_cmdline_user_args():
		var review = preload("res://scripts/audio_review.gd").new()
		add_child(review)
		await review.run(self)
		return
	if "--flow-benchmark" in OS.get_cmdline_user_args() or "--performance" in OS.get_cmdline_user_args():
		var benchmark = preload("res://scripts/showcase_benchmark.gd").new()
		add_child(benchmark)
		await benchmark.run(self, "--performance" in OS.get_cmdline_user_args())
		return
	if "--compare" in OS.get_cmdline_user_args():
		var review = preload("res://scripts/showcase_review.gd").new()
		add_child(review)
		await review.run_compare(self)
		return
	var test = load("res://scripts/verification.gd").new()
	add_child(test)
	if "--title-review" in OS.get_cmdline_user_args():
		await test.run_title(self)
	elif "--art-review" in OS.get_cmdline_user_args():
		await test.run_art(self)
	else:
		await test.run(self)


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
	camera.far = 1100
	add_child(camera)
	camera.make_current()


func apply_time_of_day():
	var night = settings.time_of_day == 1
	if applied_time != int(settings.time_of_day):
		applied_time = int(settings.time_of_day)
		var sky = Sky.new()
		var paint = PanoramaSkyMaterial.new()
		paint.panorama = preload("res://scripts/retro_assets.gd").panorama(night)
		sky.sky_material = paint
		environment.sky = sky
		# Daylight fill is deliberately weak and cool against a warm key. The old 0.62 ambient
		# was close enough to the sun energy that afternoon read as overcast: everything sat in
		# one mid value and nothing had a shaded side.
		environment.ambient_light_color = Color("8499c0") if night else Color("9db7d6")
		environment.ambient_light_energy = .65 if night else .42
		environment.tonemap_exposure = 1.0
		environment.fog_light_color = Color("44465e") if night else Color("bed3e2")
		environment.fog_depth_begin = 60 if night else 130
		environment.fog_depth_end = 520 if night else 950
		environment.fog_density = 1.0
		environment.fog_sky_affect = .15
		sun.light_color = Color("8ca6df") if night else Color("ffd79a")
		sun.light_energy = .7 if night else 1.5
		camera.far = 650 if night else 1100
		visuals.set_time(night)
		if not ghost_model.is_empty():
			warm_ghost.call_deferred()
	if is_instance_valid(scenery):
		var lamps = scenery.get_node_or_null("NightCircuit")
		if lamps:
			lamps.visible = night
		visuals.world.road_material.set_shader_parameter("afterhours", night)


func setup_retro_grade():
	retro = preload("res://scripts/retro_renderer.gd").new()
	add_child(retro)
	retro.initialize(self)
