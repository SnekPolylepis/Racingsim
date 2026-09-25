extends SceneTree
## Headless P4-06 flow: menu selection, generator cache, drive, records, return to menu.
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
var checks = 0
var failures = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS  " if ok else "FAIL  ") + label)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	# Start from no saved records, as a fresh machine (CI) does: a record left by an earlier run must not
	# stand in for one this run failed to write. Only ever inside the isolated test storage.
	var records = app.storage.path("records")
	if records.begins_with("user://native-tests/") and DirAccess.dir_exists_absolute(records):
		for file in DirAccess.get_files_at(records):
			DirAccess.remove_absolute(records.path_join(file))
	check(
		app.frontend.page == "main" and app.in_menu and not (app.track is Node3D),
		"front end opens before the first track bake"
	)
	app.frontend.open_v2_panel("settings")
	check(app.frontend.v2_panels.is_open(), "v2 settings panel opens")
	check(
		(
			app.frontend.get_parent() == app.get_node("V2UIRoot")
			and app.frontend.v2_panels.get_parent() == app.frontend
		),
		"settings and front end share the v2 UI root"
	)
	check(
		app.frontend.v2_panels.find_children("*", "OptionButton", true, false).size() >= 10,
		"legacy presentation choices are present in v2 settings"
	)
	app.controls.listening = "throttle"
	app.controls.listen_pad = false
	var binding = InputEventKey.new()
	binding.physical_keycode = KEY_T
	binding.pressed = true
	check(
		app.frontend.handle(binding) and app.controls.keys.throttle[0] == KEY_T,
		"v2 control remapping captures key"
	)
	app.controls.keys = app.Controls.DEFAULT_KEYS.duplicate(true)
	app.save_settings()
	app.frontend.back()
	check(not app.frontend.v2_panels.is_open(), "settings close returns to menu")
	app.set_v2_setting("volume", .35)
	app.set_v2_setting("output_mode", 1)
	var saved_settings = app.storage.read_json(app.settings_path)
	check(
		(
			app.settings_path == "user://native-tests/v2/settings.json"
			and saved_settings is Dictionary
			and is_equal_approx(saved_settings.volume, .35)
			and saved_settings.output_mode == 1
		),
		"v2 settings round trip stays outside legacy settings"
	)
	app.frontend.show_page("car")
	app.frontend.cycle_v2_car()
	check(
		app.preset_key == "roadster" and app.car.p.name == app.presets.roadster.name,
		"car picker changes body"
	)
	app.frontend.show_page("circuit")
	var picked = []
	for i in app.frontend.V2_TRACKS.size():
		app.frontend.cycle_v2_track()
		picked.append(app.frontend.selected_track)
	check(
		picked == ["spa", "nordschleife_s1", "proving_ground"],
		"circuit picker cycles every circuit: " + str(picked)
	)
	app.frontend.cycle_v2_track()
	check(app.frontend.selected_track == "spa", "circuit picker lists Spa")
	app.frontend.prepare_v2_race()
	var waited = 0
	while app.frontend.loading and waited < 3600:
		await process_frame
		waited += 1
	check(
		app.v2_track_id == "spa" and app.frontend.page == "drive" and not app.in_menu, "Spa loads into drive"
	)
	check(FileAccess.file_exists(TrackDrive.cache_dir().path_join("spa.scn")), "Spa generator cache saved")
	check(
		FileAccess.file_exists(TrackDrive.cache_dir().path_join("spa.scn.revision")),
		"cache revision saved before reuse"
	)
	var spa_path = app.record_path()
	check(spa_path.find("records") >= 0, "asset configuration has a record path")
	app.frontend.open_v2_panel("garage")
	check(
		app.frontend.v2_panels.is_open() and app.setup_fields.size() == 42, "garage exposes 42 setup fields"
	)
	app.frontend.back()
	var original_grip = app.car.setup.tireMu
	app.car.setup.tireMu = original_grip + .02
	app.apply_v2_setup()
	var tuned_path = app.record_path()
	check(
		tuned_path != spa_path and is_equal_approx(app.car.setup.tireMu, original_grip + .02),
		"setup applies to CarBody and changes record"
	)
	check(app.save_v2_setup("Front end test"), "named v2 setup saved")
	var setup_file = app.storage.path("setups", "Front end test.json")
	var saved_setup = app.storage.read_json(setup_file)
	check(
		(
			saved_setup is Dictionary
			and saved_setup.car == app.preset_key
			and is_equal_approx(saved_setup.setup.tireMu, original_grip + .02)
		),
		"named setup document round trip"
	)
	app.car.setup.tireMu = original_grip
	app.apply_v2_setup()
	check(
		app.load_v2_setup(setup_file) and is_equal_approx(app.car.setup.tireMu, original_grip + .02),
		"named setup loads into CarBody"
	)
	app.set_v2_setting("handling_model", 1)
	check(
		not app.car.simcade_enabled and app.record_path() != tuned_path,
		"simulation handling selects separate record"
	)
	app.set_v2_setting("handling_model", 0)
	check(app.car.simcade_enabled and app.record_path() == tuned_path, "simcade handling and record restore")
	app.race.best = 12.5
	app.race.ghost = [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0], [12.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 100.0]
	]
	app.race.best_sectors = [4.0, 4.0, 4.5]
	app.save_record()
	app.save_sectors()
	app.record_writer.flush()
	# save_record() writes the active (tuned-setup) record, not the untuned spa_path.
	var saved = app.storage.read_json(app.active_record_path)
	check(
		(
			saved is Dictionary
			and saved.get("schema") == 2
			and saved.get("track") == app.track.record_key()
			and app.storage.validate_ghost(saved).is_empty()
		),
		"schema-2 ghost saved"
	)
	app.load_record()
	check(
		app.race.best == 12.5 and app.race.ghost.size() == 2 and app.race.best_sectors[2] == 4.5,
		"ghost and sectors reload"
	)
	app.frontend.back()
	check(app.frontend.page == "pause" and app.paused and not app.in_menu, "Esc pauses in-drive")
	app.frontend.back()
	check(app.frontend.page == "drive" and not app.paused, "Esc resumes from pause")
	app.frontend.show_page("pause")
	app.race.lap_time = 7.0
	app.restart_v2_lap()
	check(
		app.frontend.page == "drive" and app.race.lap_time == 0.0 and not app.paused,
		"restart lap resets timing and resumes"
	)
	app.return_v2_menu()
	check(app.frontend.page == "main" and app.in_menu, "return to menu")
	app.frontend.selected_track = "proving_ground"
	check(app.load_v2_track("proving_ground"), "proving ground reloads")
	check(app.record_path() != spa_path, "track record identities differ")
	print("FRONT_END RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	for player in app.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	app.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
