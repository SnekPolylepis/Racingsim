extends SceneTree
## Drives each named car for 4 s on Chicago and saves a chase-cam frame: -- --v2-flow-test rb19 f2004
func _initialize():
	call_deferred("run")
func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var track = "chicago"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--track="):
			track = a.trim_prefix("--track=")
	app.load_v2_track(track)
	app.settings.time_of_day = 0
	app.apply_time_of_day()
	for key in OS.get_cmdline_user_args():
		if key.begins_with("--"):
			continue
		app.change_v2_car(key)
		app.start_v2_drive()
		for i in 900:
			app.car.input.throttle = 1.0
			await process_frame
		print("CAR %s speed=%.1f km/h y=%.2f pos=(%.0f, %.0f)" % [key, app.car.speed * 3.6, app.car.pos_y, app.car.pos_x, app.car.pos_z])
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("user://car-%s-%s.png" % [key, track])
	quit(0)
