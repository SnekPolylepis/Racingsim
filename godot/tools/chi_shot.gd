extends SceneTree
## In-game Chicago captures from the real drive view. Windowed:
##   tools/Godot.exe --path . --script tools/chi_shot.gd -- --v2-flow-test [--tag=x] [--views=wrigley,river]


func _initialize():
	call_deferred("run")


func run():
	var tag = "x"
	var selected_views = PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		if a.begins_with("--views="):
			selected_views = a.trim_prefix("--views=").split(",", false)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("chicago")
	app.start_v2_drive()
	if "--drive-lower" in OS.get_cmdline_user_args():
		var point = Vector3(-1035.75, float(app.track.get_meta("wacker_floor_y")), 0)
		var forward = Vector3.BACK
		app.car.place(point, PI / 2, point.y)
		app.car.rot = Basis(forward, Vector3.UP, forward.cross(Vector3.UP)).get_rotation_quaternion()
		app.car.pos = point + Vector3.UP * app.car.setup.cgHeight
		app.car.sync_legacy()
		app.race.reset()
		app.prev_pose = app.snapshot_v2()
		app.settings.camera = 2
	print("NEON SIGNS ", app.track.get_meta("neon_signs", -1))
	app.controls.poll_hardware = false
	app.controls.held_keys[int(app.controls.keys.throttle[0])] = true
	var drive_start: Vector3 = app.car.pos
	for night in [1, 0]:
		app.settings.time_of_day = night
		app.apply_time_of_day()
		for i in 240:
			await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_viewport().get_texture().get_image()
		img.save_png("user://chi-%s-%s.png" % [tag, "night" if night else "day"])
	var distance = app.car.pos.distance_to(drive_start)
	print("CHICAGO DRIVE displacement=", distance, " speed=", app.car.speed)
	if distance < 5.0 or not app.car.pos.is_finite():
		push_error("Chicago capture did not demonstrate driving")
		quit(1)
		return
	app.controls.clear()
	# Fixed street-level views along Michigan Avenue (world(): x=(lon+87.6244)*82860, z=(41.8848-lat)*111320).
	app.set_process(false)
	app.set_physics_process(false)
	app.instruments.visible = false
	var lower_eye = float(app.track.get_meta("wacker_floor_y", 0.0)) + 1.4
	var views = {
		"400-lake-shore": [Vector3(1040, 30, -330), Vector3(760, 145, -566)],
		"mich-north": [Vector3(0, 11, 250), Vector3(-5, 40, -380)],
		"mich-south": [Vector3(0, 11, -120), Vector3(-5, 30, 700)],
		"caa": [Vector3(40, 14, 330), Vector3(-49, 30, 346)],
		"uc": [Vector3(40, 14, 410), Vector3(-46, 30, 423)],
		"rx": [Vector3(60, 20, 690), Vector3(-35, 45, 701)],
		"river": [Vector3(-470, 11, -225), Vector3(-150, 4, -262)],
		"lower-west": [Vector3(-600, lower_eye, -234), Vector3(-950, lower_eye, -234)],
		"lower-south": [Vector3(-1035, lower_eye, 0), Vector3(-1035, lower_eye, 500)],
		"lower-portal": [Vector3(530, lower_eye, -317), Vector3(200, lower_eye, -340)],
		"river-air": [Vector3(-300, 90, -120), Vector3(-450, 0, -300)],
		"park-air": [Vector3(60, 70, 120), Vector3(170, 0, 280)],
		"lake-lsd": [Vector3(737, 14, 156), Vector3(1600, 6, 100)],
		"lake-lsd2": [Vector3(760, 14, -20), Vector3(1500, 6, -300)],
		"l-lake": [Vector3(-1050, 10, -150), Vector3(-900, 12, -140)],
		"lake-top": [Vector3(700, 450, 400), Vector3(1000, 0, 150)],
		"river-top": [Vector3(-560, 40, -270), Vector3(-380, 0, -330)],
		"l-wabash": [Vector3(-141, 10, 60), Vector3(-141, 15, -80)],
		"lake-oblique": [Vector3(700, 45, 170), Vector3(1100, 0, 120)],
		"pritzker": [Vector3(210, 20, 360), Vector3(210, 20, 150)],
		"pritzker-pylons": [Vector3(145, 10, 300), Vector3(166, 10, 276)],
		"harbor": [Vector3(760, 30, 250), Vector3(1100, 5, 60)],
		"sym": [Vector3(40, 12, 680), Vector3(-50, 18, 668)],
		"wrigley": [Vector3(10, 12, -350), Vector3(23, 100, -409)],
		"wrigley-clock": [Vector3(23, 112, -365), Vector3(23, 120, -394)],
		"wrigley-clock-west": [Vector3(-25, 120, -409), Vector3(10, 120, -409)],
		"wrigley-clock-east": [Vector3(70, 120, -409), Vector3(35, 120, -409)],
		"wrigley-clock-north": [Vector3(23, 120, -465), Vector3(23, 120, -424)],
		"mich-aerial": [Vector3(250, 220, 300), Vector3(-80, 60, -100)],
	}
	for night in [0, 1]:
		app.settings.time_of_day = night
		app.apply_time_of_day()
		for key in views:
			if not selected_views.is_empty() and key not in selected_views:
				continue
			app.camera.position = views[key][0]
			var rain = app.camera.get_node_or_null("Rain")
			if rain:
				rain.visible = rain.emitting and not key.begins_with("lower-")
			app.camera.look_at(views[key][1], Vector3.UP)
			app.TrackLights.update_pool(app.lamp_pool, app.track, app.camera.global_position, bool(night))
			app.camera.fov = 60
			for i in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(
				"user://chi-%s-%s-%s.png" % [tag, key, "night" if night else "day"]
			)
	quit(0)
