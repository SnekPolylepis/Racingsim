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
		"caa": [Vector3(40, 14, 330), Vector3(-49, 30, 346)],
		"uc": [Vector3(40, 14, 410), Vector3(-46, 30, 423)],
		"rx": [Vector3(60, 20, 690), Vector3(-35, 45, 701)],
		"river": [Vector3(-470, 11, -225), Vector3(-150, 4, -262)],
		"river-air": [Vector3(-300, 90, -120), Vector3(-450, 0, -300)],
		"park-air": [Vector3(60, 70, 120), Vector3(170, 0, 280)],
		"lake-lsd": [Vector3(737, 14, 156), Vector3(1600, 6, 100)],
		"lake-lsd2": [Vector3(760, 14, -20), Vector3(1500, 6, -300)],
		"l-lake": [Vector3(-1050, 10, -150), Vector3(-900, 12, -140)],
		"lake-top": [Vector3(700, 450, 400), Vector3(1000, 0, 150)],
		"river-top": [Vector3(-560, 40, -270), Vector3(-380, 0, -330)],
		"l-wabash": [Vector3(-141, 10, 60), Vector3(-141, 15, -80)],
		"lake-oblique": [Vector3(700, 45, 170), Vector3(1100, 0, 120)],
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
