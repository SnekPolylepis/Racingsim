extends Node3D
## Application root: owns models and coordinates UI, persistence, fixed physics and rendering.
## See docs/ARCHITECTURE.md before changing frame order or editor/drive transitions.
## Resource models use simulation XY coordinates; scene nodes use Godot XZ ground coordinates.
const TrackModel = preload("res://scripts/track3d.gd")
const CarModel = preload("res://scripts/car.gd")
const RaceModel = preload("res://scripts/race.gd")
const Collisions = preload("res://scripts/collisions.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Storage = preload("res://scripts/storage.gd")
const Controls = preload("res://scripts/controls.gd")
const Interface = preload("res://scripts/interface.gd")
const CircuitEditor = preload("res://scripts/editor.gd")
const Instruments = preload("res://scripts/instruments.gd")
const Sound = preload("res://scripts/audio.gd")
const OutlineImport = preload("res://scripts/outline_import.gd")
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
var editor
var instruments
var sound
var frontend
var editing = false
var paused = false
## Title screen is up: simulation blocked, toolbar/HUD hidden, camera orbits the car.
var in_menu = false
var menu_time = 0.0
var test_from_editor = false
var elapsed = 0.0
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
	ui.car_picker.select(presets.keys().find(preset_key))
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
			editor.finish_gesture()
			if not test_mode and not in_menu and not editing:
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
	return paused or editing or in_menu or ui.is_open()


## Finish any active editor transaction before deciding whether an action may discard it.
func guard_dirty(action):
	editor.finish_gesture()
	if editor.dirty:
		ui.confirm("Unsaved circuit", "Discard the current unsaved circuit changes?", action)
	else:
		action.call()


func request_quit():
	guard_dirty(func(): get_tree().quit())


func refresh_tracks():
	track_files = []
	ui.track_picker.clear()
	var bundled = Array(DirAccess.get_files_at("res://tracks"))
	bundled.sort()
	bundled.erase("Spa-Francorchamps.json")
	bundled.push_front("Spa-Francorchamps.json")
	for name in bundled:
		if name.ends_with(".json"):
			track_files.append("res://tracks/" + name)
			ui.track_picker.add_item(name.get_basename())
	for file in storage.list_files("tracks"):
		track_files.append(file)
		ui.track_picker.add_item(file.get_file().get_basename() + " · saved")
	var index = track_files.find(active_track_file)
	if index >= 0:
		ui.track_picker.select(index)


func load_track(index):
	if index >= 0 and index < track_files.size():
		request_track_file(track_files[index])


func request_track_file(file):
	var previous = track_files.find(active_track_file)
	if previous >= 0:
		ui.track_picker.select(previous)
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
	editor.reset_document()
	rebuild_world()
	reset_car()
	load_record()
	refresh_tracks()
	instruments.rebuild_map()
	if not track.validate().errors.is_empty() and not editing:
		set_editor(true)
	if editing:
		editor.queue_redraw()
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
	scenery.visible = not editing
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
	model.root.visible = not editing
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
	ui.car_picker.select(presets.keys().find(key))
	reset_car()
	load_record()


## Central mode transition: validate before driving, restore cone state before editing.
## The editor retains its undo history across a test drive.
func set_editor(value):
	if value:
		in_menu = false
	if editing == value:
		return
	editor.finish_gesture()
	if not value:
		var report = track.validate()
		if not report.errors.is_empty():
			message("Cannot test drive: " + report.errors[0])
			return
	ui.close()
	controls.clear()
	editing = value
	if retro:
		retro.attach_ui()
	editor.visible = value
	instruments.visible = not value
	environment.fog_enabled = not value
	model.root.visible = not value
	scenery.visible = not value
	ghost_model.root.visible = false
	ui.mode_button.text = "Test drive · T" if value else "Editor · F2"
	if skid_root:
		skid_root.visible = not value
	if value:
		for o in track.data.objects:
			if o.type == "cone":
				o.x = o.ox
				o.y = o.oy
			for k in ["vx", "vy", "hit"]:
				o.erase(k)
		test_from_editor = false
		editor.validate()
		editor.refresh_props()
		editor.layout_panels()
		editor.frame_track()
	else:
		test_from_editor = true
		paused = false
		rebuild_world()
		reset_car()
		load_record()
		message("Test drive · Esc returns to your circuit")


func new_track():
	guard_dirty(
		func():
			track.load_data(
				{
					"schema": 1,
					"name": "Untitled",
					"points": [],
					"objects": [],
					"paint": {},
					"curbOverride": {},
					"curbAuto": true,
					"startS": null,
					"gridS": null
				}
			)
			active_track_file = ""
			ui.close()
			if not editing:
				set_editor(true)
			editor.reset_document()
			editor.dirty = true
			editor.set_tool("select")
			rebuild_world()
			message("New circuit: click to place points, then use Start / finish")
	)


func save_track():
	editor.finish_gesture()
	var report = track.validate()
	if not report.errors.is_empty():
		message("Cannot save: " + report.errors[0])
		return
	if track.data.name == "Untitled":
		save_track_as()
		return
	write_track_named(track.data.name)


func save_track_as():
	ui.ask_name("Save circuit as", track.data.name, write_track_named)


func write_track_named(name):
	var report = track.validate()
	if not report.errors.is_empty():
		message(report.errors[0])
		return
	var file = storage.path("tracks", storage.safe_name(name) + ".json")
	var save_action = func():
		var old_name = track.data.name
		track.data.name = name
		var ok = storage.write_json(file, track.to_json())
		if ok:
			active_track_file = file
			editor.mark_saved()
			refresh_tracks()
			message("Saved " + file.get_file())
		else:
			track.data.name = old_name
			message(storage.error)
	if FileAccess.file_exists(file) and file != active_track_file:
		ui.confirm("Replace circuit?", file.get_file() + " already exists.", save_action)
	else:
		save_action.call()


func import_track_data(d):
	var error = storage.validate_track(d)
	if not error.is_empty():
		message(error)
		return false
	guard_dirty(
		func():
			track.load_data(d)
			active_track_file = ""
			ui.close()
			if not editing:
				set_editor(true)
			editor.reset_document()
			editor.dirty = true
			editor.refresh_props()
			rebuild_world()
			message("Imported circuit · Save to keep it")
	)
	return true


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
			storage.safe_name(track.data.name if kind != "setup" else car.p.name)
			+ (".ghost.json" if kind == "ghost" else ".json")
		)
	dialog.file_selected.connect(
		func(path):
			ui.dialogs -= 1
			dialog.queue_free()
			if write:
				var data = (
					track.to_json()
					if kind == "track"
					else (setup_document() if kind == "setup" else ghost_document())
				)
				if kind == "ghost" and race.ghost.is_empty():
					message("No best lap to export")
					return
				message("Exported " + path.get_file() if storage.write_json(path, data) else storage.error)
			elif kind == "track":
				import_track_data(storage.read_json(path))
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


## Import a real circuit outline (GPX / GeoJSON / OpenStreetMap) as a new unsaved circuit.
func choose_outline():
	ui.dialogs += 1
	controls.clear()
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(
		["*.gpx ; GPS track", "*.geojson, *.json ; GeoJSON", "*.osm ; OpenStreetMap XML"]
	)
	dialog.title = "Import real circuit outline"
	add_child(dialog)
	dialog.file_selected.connect(
		func(path):
			ui.dialogs -= 1
			dialog.queue_free()
			import_outline(path)
	)
	dialog.canceled.connect(
		func():
			ui.dialogs -= 1
			dialog.queue_free()
	)
	dialog.popup_centered_ratio(.75)


func import_outline(path):
	var result = OutlineImport.load_file(path)
	if result.has("error"):
		message(result.error)
		return false
	if import_track_data(result.doc):
		message(
			(
				"Imported %s · %d points · check direction, start line and widths, then save"
				% [path.get_file(), result.doc.points.size()]
			)
		)
	return true


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
			guard_dirty(func(): connect_storage(path))
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
	guard_dirty(func(): connect_storage("user://"))


func delete_file(file):
	if file.begins_with("res://"):
		return
	if DirAccess.remove_absolute(file) != OK:
		message("Could not delete " + file.get_file())
		return
	if active_track_file == file:
		active_track_file = ""
		editor.dirty = true
	refresh_tracks()
	message("Deleted " + file.get_file())


func rename_file(file, value):
	var data = storage.read_json(file)
	if not data is Dictionary:
		message(storage.error)
		return
	var destination = storage.path("tracks", storage.safe_name(value) + ".json")
	if destination == file:
		return
	var action = func():
		data.name = value
		if storage.write_json(destination, data):
			if not file.begins_with("res://"):
				DirAccess.remove_absolute(file)
			if active_track_file == file:
				active_track_file = destination
				if editor.dirty:
					editor.rename_track(value)
				else:
					track.data.name = value
					editor.mark_saved()
			ui.open_library()
		else:
			message(storage.error)
	if FileAccess.file_exists(destination):
		ui.confirm("Replace circuit?", destination.get_file() + " already exists.", action)
	else:
		action.call()


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
		"track": track.data.duplicate(true),
		"setup": effective_setup(),
		"car": preset_key,
		"wear": settings.wear,
		"off_track": settings.off_track,
		"contact": settings.contact,
		"handling": "simcade" if settings.handling_model == 0 else "simulation"
	}
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
	if not FileAccess.file_exists(file):
		file = legacy_ghost_path()
	if FileAccess.file_exists(file):
		var saved = storage.read_json(file)
		if (
			storage.validate_ghost(saved).is_empty()
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
		"schema": 1,
		"savedAt": Time.get_datetime_string_from_system(true) + "Z",
		"track": storage.safe_name(track.data.name) + ".json",
		"car": preset_key,
		"configuration": (record_path() if destination.is_empty() else destination).get_file(),
		"time": race.best,
		"samples": race.ghost
	}


func save_record():
	record_writer.enqueue(
		{
			"path": active_record_path,
			"legacy": legacy_ghost_path(),
			"data": ghost_document(active_record_path)
		}
	)


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


## Fixed 240 Hz simulation only. Preserve controls -> car -> collisions -> race ordering.
func _physics_process(dt):
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
	if model.is_empty():
		return
	if record_writer and not record_writer.errors.is_empty():
		message(record_writer.errors.pop_front())
	var started = Time.get_ticks_usec()
	ui.sync_menus()
	if in_menu and not editing:
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
	elif not editing:
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
		ghost_model.root.visible = settings.ghost and not gp.is_empty() and not editing
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
	if editing or model.is_empty():
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
		desired = pos + forward * 1.3 + Vector3.UP * 1.1
		target = pos + forward * 45 + Vector3.UP
	elif settings.camera >= 3:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (42 + car.speed * .45) * zoom_user
		camera.position = pos + Vector3.UP * 120
		camera.look_at(pos, Vector3(0, 0, -1) if settings.camera == 3 else forward)
		return
	camera.position = desired if snap else camera.position.lerp(desired, 1 - exp(-dt * 7))
	camera.position.y = maxf(
		camera.position.y,
		track.elev_at(camera.position.x, camera.position.z).z + (.6 if settings.camera == 2 else 1.6)
	)
	camera.look_at(target, Vector3.UP)
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
	if frontend and not editing:
		frontend.show_page("pause" if value else "drive")


## Return to the title screen from anywhere outside the editor. The car waits on the grid.
func show_main_menu():
	ui.close()
	if editing:
		set_editor(false)
	test_from_editor = false
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


func start_editor():
	ui.close()
	in_menu = false
	paused = false
	set_editor(true)
	ui.sync_menus()


func _input(event):
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if ui.is_open():
				ui.close()
			elif test_from_editor and not editing:
				set_editor(true)
			else:
				toggle_pause()
			return
		if ui.is_open() or in_menu:
			return
		if event.physical_keycode == KEY_F2:
			set_editor(not editing)
			return
		if editing:
			editor.shortcut(event)
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
	if ui.is_open() or editing or in_menu:
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
		var pos = Vector3(w.wx, track.elev_at(w.wx, w.wy, w.sIdx).z + .035, w.wy)
		if w.skidding and skid_last[i] != null:
			var previous = skid_last[i]
			var length = pos.distance_to(previous)
			if length > .02 and length < 5:
				var direction = (pos - previous).normalized()
				var side = direction.cross(Vector3.UP).normalized()
				var up = side.cross(direction).normalized()
				skid_multi.set_instance_transform(
					skid_cursor, Transform3D(Basis(direction * length, up, side), (pos + previous) * .5)
				)
				skid_times[skid_cursor] = elapsed
				skid_cursor = (skid_cursor + 1) % skid_multi.instance_count
		skid_last[i] = pos if w.skidding else null
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
