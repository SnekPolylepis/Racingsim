extends SceneTree
## Windowed studio shots of one car preset (ASSET-02): four angles, day and night, on the Proving Ground grid.
##   tools/Godot.exe --path . --script tests/visual/car_shots.gd -- --v2-flow-test --car=f296gt3 --out=<dir>
var car_id = "f296gt3"
var out = "user://car-shots"


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--car="):
			car_id = arg.trim_prefix("--car=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	app.load_v2_track("proving_ground")
	app.start_v2_drive()
	app.change_v2_car(car_id)
	for night in [false, true]:
		app.settings.time_of_day = 1 if night else 0
		app.apply_time_of_day()
		for i in 4:
			await process_frame
		app.set_process(false)
		app.set_physics_process(false)
		app.instruments.visible = false
		if app.frontend:
			app.frontend.visible = false
		app.render_v2(1.0)
		var c = app.model.root.global_position
		var views = [
			[Vector3(5.5, 1.4, 4.2), "front34"],
			[Vector3(-5.5, 1.6, 4.0), "rear34"],
			[Vector3(0.2, 1.0, 6.5), "side"],
			[Vector3(3.2, 0.8, -1.8), "wheel"]
		]
		for v in views:
			app.camera.global_position = c + v[0]
			app.camera.look_at(c + Vector3(0, 0.55, 0))
			for i in 6:
				await process_frame
			var path = "%s/%s-%s-%s.png" % [out, car_id, v[1], "night" if night else "day"]
			root.get_texture().get_image().save_png(path)
			print("CAR SHOT ", ProjectSettings.globalize_path(path))
		app.set_process(true)
	quit()
