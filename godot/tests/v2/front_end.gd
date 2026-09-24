extends SceneTree
## Headless P4-06 flow: menu selection, generator cache, drive, records, return to menu.
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
	check(
		app.v2_mode and app.frontend.page == "main" and app.in_menu and not (app.track is Node3D),
		"front end opens before the first track bake"
	)
	app.frontend.show_page("car")
	app.frontend.cycle_v2_car()
	check(
		app.preset_key == "roadster" and app.car.p.name == app.presets.roadster.name,
		"car picker changes body"
	)
	app.frontend.show_page("circuit")
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
	check(FileAccess.file_exists("user://tracks3d/spa.scn"), "Spa generator cache saved")
	var spa_path = app.record_path()
	check(spa_path.find("records") >= 0, "asset configuration has a record path")
	app.race.best = 12.5
	app.race.ghost = [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0], [12.5, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 100.0]
	]
	app.race.best_sectors = [4.0, 4.0, 4.5]
	app.save_record()
	app.save_sectors()
	app.record_writer.flush()
	var saved = app.storage.read_json(spa_path)
	check(
		(
			saved.get("schema") == 2
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
