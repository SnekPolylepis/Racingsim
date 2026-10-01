extends SceneTree
## In-game Spa-Francorchamps captures from the real drive view. Windowed:
##   tools/Godot.exe --path . --script tools/spa_shot.gd -- --v2-flow-test [--tag=x]
const RoadBuilder = preload("res://scripts/track/road_builder.gd")


func _initialize():
	call_deferred("run")


func run():
	var tag = "spa"
	var selected_views = PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		if a.begins_with("--views="):
			selected_views = a.trim_prefix("--views=").split(",", false)

	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("spa")
	app.start_v2_drive()

	app.controls.poll_hardware = false
	app.controls.held_keys[int(app.controls.keys.throttle[0])] = true
	var drive_start: Vector3 = app.car.pos

	# Verify dynamic drive for 180 frames
	for i in 180:
		await process_frame

	var distance = app.car.pos.distance_to(drive_start)
	print("SPA DRIVE displacement=", distance, " speed=", app.car.speed)
	if distance < 2.0 or not app.car.pos.is_finite():
		push_error("Spa capture did not demonstrate driving")
		quit(1)
		return
	app.controls.clear()

	app.set_process(false)
	app.set_physics_process(false)
	app.instruments.visible = false

	var road = app.track.get_node("Main")
	var curve = road.working_curve()
	var length = curve.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)

	# 11 required corner and section views
	var corner_stations = {
		"la_source": 320.0,
		"eau_rouge_raidillon": 890.0,
		"kemmel": 1580.0,
		"les_combes": 2180.0,
		"malmedy": 2470.0,
		"rivage": 2840.0,
		"pouhon": 3530.0,
		"fagnes": 4100.0,
		"stavelot": 4650.0,
		"blanchimont": 5680.0,
		"bus_stop": 6660.0,
		"pit_straight": 6870.0,
	}

	var views = {}
	for cname in corner_stations:
		var s = corner_stations[cname]
		var st = RoadBuilder.station_at(curve, road.closed, length, spline, s)
		var pos = road.transform * st.pos
		var fwd = (road.transform.basis * st.tangent).normalized()
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right = fwd.cross(Vector3.UP).normalized()
		var cam_pos = pos
		var look_target = pos + fwd * 40.0

		match cname:
			"la_source":
				cam_pos = pos - fwd * 18.0 + right * 4.0 + Vector3.UP * 2.8
				look_target = pos + fwd * 35.0 + Vector3.UP * 1.0
			"eau_rouge_raidillon":
				cam_pos = pos - fwd * 14.0 + right * 2.2 + Vector3.UP * 2.2
				look_target = pos + fwd * 90.0 + Vector3.UP * 24.0
			"kemmel":
				cam_pos = pos - fwd * 20.0 - right * 2.0 + Vector3.UP * 2.0
				look_target = pos + fwd * 85.0 + Vector3.UP * 1.5
			"les_combes":
				cam_pos = pos - fwd * 22.0 + right * 3.5 + Vector3.UP * 3.0
				look_target = pos + fwd * 45.0 + Vector3.UP * 1.2
			"malmedy":
				cam_pos = pos - fwd * 18.0 - right * 3.0 + Vector3.UP * 2.5
				look_target = pos + fwd * 60.0 - Vector3.UP * 1.5
			"rivage":
				cam_pos = pos - fwd * 16.0 - right * 4.0 + Vector3.UP * 3.2
				look_target = pos + fwd * 50.0 - Vector3.UP * 2.0
			"pouhon":
				cam_pos = pos - fwd * 15.0 + right * 6.0 + Vector3.UP * 4.0
				look_target = pos + fwd * 60.0 - Vector3.UP * 0.5
			"fagnes":
				cam_pos = pos - fwd * 18.0 + right * 3.0 + Vector3.UP * 2.6
				look_target = pos + fwd * 55.0 + Vector3.UP * 0.8
			"stavelot":
				cam_pos = pos - fwd * 20.0 - right * 3.5 + Vector3.UP * 2.5
				look_target = pos + fwd * 65.0 + Vector3.UP * 1.0
			"blanchimont":
				cam_pos = pos - fwd * 20.0 - right * 2.5 + Vector3.UP * 2.2
				look_target = pos + fwd * 75.0 + Vector3.UP * 1.2
			"bus_stop":
				cam_pos = pos - fwd * 20.0 + right * 3.5 + Vector3.UP * 2.5
				look_target = pos + fwd * 55.0 + Vector3.UP * 1.4
			"pit_straight":
				cam_pos = pos - fwd * 20.0 - right * 2.0 + Vector3.UP * 2.4
				look_target = pos + fwd * 70.0 + Vector3.UP * 2.5

		views[cname] = [cam_pos, look_target]

	var output_dir = "res://docs/rebuild/screenshots/spa/"
	var global_out = ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(global_out)

	for night in [0, 1]:
		app.settings.time_of_day = night
		app.apply_time_of_day()
		for key in views:
			if not selected_views.is_empty() and key not in selected_views:
				continue
			app.camera.position = views[key][0]
			app.camera.look_at(views[key][1], Vector3.UP)
			app.TrackLights.update_pool(app.lamp_pool, app.track, app.camera.global_position, bool(night))
			app.camera.fov = 60
			for i in 20:
				await process_frame
			await RenderingServer.frame_post_draw
			var img = root.get_viewport().get_texture().get_image()
			var fn = "%s_%s.png" % [key, "night" if night else "day"]
			img.save_png(global_out + "/" + fn)
			img.save_png("user://" + fn)
			print("CAPTURED ", fn)

	print("SPA SHOT COMPLETE: 16 screenshots captured (8 day, 8 night)")
	quit(0)
