extends SceneTree
## Windowed CAR-01 visual review, through the game presentation chain.
## Run with: tools/Godot.exe --path . --script tests/v2/car_01_screenshots.gd -- --v2-flow-test

var folder = "res://docs/rebuild/screenshots/car-01"
var failures = []


func _initialize():
	call_deferred("run")


func capture(label):
	for i in 8:
		await process_frame
	var path = folder + "/" + label + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		failures.append(path)
	print("CAR-01 SHOT ", ProjectSettings.globalize_path(path))


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.load_v2_track("proving_ground"):
		failures.append("track load")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	app.change_v2_car("roadster")
	app.start_v2_drive()
	app.instruments.visible = false
	app.set_process(false)
	app.set_physics_process(false)
	for night in [false, true]:
		app.settings.time_of_day = 1 if night else 0
		app.apply_time_of_day()
		var suffix = "afterhours" if night else "day"
		var xf = app.model.root.global_transform
		app.camera.position = xf.origin - xf.basis.x * 4.9 + xf.basis.y * 1.9 + xf.basis.z * .65
		app.camera.look_at(xf.origin + xf.basis.y * .55, xf.basis.y)
		app.camera.fov = 47
		await capture("chase-" + suffix)
		app.camera.position = xf.origin + xf.basis.x * 1.17 + xf.basis.y * 1.11
		app.camera.look_at(xf.origin + xf.basis.x * 36.0 - xf.basis.y * 7.0, xf.basis.y)
		app.camera.fov = 64
		await capture("bonnet-" + suffix)
		app.camera.position = xf.origin + xf.basis.x * 4.3 + xf.basis.y * 1.55 + xf.basis.z * 3.3
		app.camera.look_at(xf.origin + xf.basis.y * .58, xf.basis.y)
		app.camera.fov = 40
		await capture("three-quarter-" + suffix)
	app.queue_free()
	await process_frame
	print("CAR_01_SHOTS RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
