extends SceneTree
## In-game Chicago captures from the real drive view. Windowed:
##   tools/Godot.exe --path . --script tools/chi_shot.gd -- --v2-flow-test [--tag=x]


func _initialize():
	call_deferred("run")


func run():
	var tag = "x"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("chicago")
	app.start_v2_drive()
	app.car.input.throttle = 1.0
	for night in [1, 0]:
		app.settings.time_of_day = night
		app.apply_time_of_day()
		for i in 240:
			app.car.input.throttle = 1.0
			await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_viewport().get_texture().get_image()
		img.save_png("user://chi-%s-%s.png" % [tag, "night" if night else "day"])
	quit(0)
