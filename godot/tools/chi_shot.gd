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
	print("NEON SIGNS ", app.track.get_meta("neon_signs", -1))
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
	# Fixed street-level views along Michigan Avenue (world(): x=(lon+87.6244)*82860, z=(41.8848-lat)*111320).
	app.set_process(false)
	var views = {
		"mich-north": [Vector3(0, 11, 250), Vector3(-5, 40, -380)],
		"mich-south": [Vector3(0, 11, -120), Vector3(-5, 30, 700)],
		"mich-aerial": [Vector3(250, 220, 300), Vector3(-80, 60, -100)],
	}
	for night in [0, 1]:
		app.settings.time_of_day = night
		app.apply_time_of_day()
		for key in views:
			app.camera.position = views[key][0]
			app.camera.look_at(views[key][1], Vector3.UP)
			app.camera.fov = 60
			for i in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(
				"user://chi-%s-%s-%s.png" % [tag, key, "night" if night else "day"]
			)
	quit(0)
