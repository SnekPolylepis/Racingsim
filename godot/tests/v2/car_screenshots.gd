extends SceneTree
## Windowed review captures of the three v2 cars on the proving ground.


func _initialize():
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.load_v2_track("proving_ground"):
		quit(1)
		return
	var folder = "res://docs/rebuild/screenshots/P4-cars"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for key in ["roadster", "gt", "f296gt3"]:
		app.change_v2_car(key)
		app.start_v2_drive()
		app.set_v2_setting("camera", 0)
		for i in 4:
			await process_frame
		app.set_process(false)
		app.set_physics_process(false)
		app.instruments.visible = false
		var xf = app.model.root.global_transform
		app.camera.position = xf.origin - xf.basis.x * 4.9 + Vector3.UP * 1.9 + xf.basis.z * .65
		app.camera.look_at(xf.origin + Vector3.UP * .55, Vector3.UP)
		app.camera.fov = 47
		for i in 4:
			await process_frame
		var path = folder + "/" + key + ".png"
		var code = root.get_texture().get_image().save_png(path)
		print("CAR SCREENSHOT ", key, " ", path, " ", code)
		app.return_v2_menu()
		app.set_process(true)
		app.set_physics_process(true)
		app.instruments.visible = true
	app.queue_free()
	await process_frame
	quit(0)
