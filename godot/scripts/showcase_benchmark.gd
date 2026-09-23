extends Node
## Input-bus integration and full-lap GPU workload. Never assigns car position during a lap.
var app
var failures = []
var rows = []
var output = ""
var pad = true
var checks = 0
var timing_case = ""


func check(value, label):
	checks += 1
	if not value:
		failures.append(label)
		push_error("BENCHMARK FAILED: " + label)


func frames(count = 3):
	for i in count:
		await get_tree().process_frame


func tap(key_code, pad_code):
	var event
	if pad:
		event = InputEventJoypadButton.new()
		event.device = 31
		event.button_index = pad_code
	else:
		event = InputEventKey.new()
		event.physical_keycode = key_code
		event.keycode = key_code
	event.pressed = true
	print(
		"TAP ",
		event.as_text(),
		" accept=",
		event.is_action("ui_accept"),
		" focus=",
		app.retro.ui_view.gui_get_focus_owner(),
		" disabled=",
		app.retro.ui_view.gui_disable_input
	)
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func accept():
	await tap(KEY_ENTER, JOY_BUTTON_A)


func down(count):
	for i in count:
		await tap(KEY_DOWN, JOY_BUTTON_DPAD_DOWN)


func page(expected):
	check(app.frontend.page == expected, ("pad" if pad else "keyboard") + " reaches " + expected)
	print("FLOW " + ("pad" if pad else "keyboard") + " " + app.frontend.page + " expected=" + expected)
	if app.frontend.buttons.size() > 0 and not app.ui.is_open() and expected != "drive":
		check(app.retro.ui_view.gui_get_focus_owner() != null, expected + " has focus")
	return app.frontend.page == expected


func shot(name):
	await RenderingServer.frame_post_draw
	check(
		app.get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK,
		"capture " + name
	)


func click_button(button):
	var logical = button.get_global_rect().get_center()
	var presented = (
		app.retro.presentation.position + logical * app.retro.presentation.size / Vector2(1280, 896)
	)
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = presented * Vector2(app.get_window().size) / app.get_viewport().get_visible_rect().size
	mouse.global_position = mouse.position
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await frames()
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await frames()


func setup(owner_app):
	app = owner_app
	output = "res://tests/showcase" if OS.has_feature("editor") else "user://native-tests/showcase"
	DirAccess.make_dir_recursive_absolute(output)
	app.ui.close()
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.folder = "user://native-tests"
	app.settings.adaptive = false
	app.controls.configure(app.settings)
	app.controls.poll_hardware = false
	app.set_editor(false)
	if app.preset_key != "f296gt3":
		app.change_car("f296gt3")
	if app.active_track_file != "res://tracks/Spa-Francorchamps.json":
		app.load_track_now("res://tracks/Spa-Francorchamps.json")
	app.apply_settings()
	app.set_physics_process(false)
	app.frontend.set_process(true)
	app.set_process(true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await frames(12)
	check(
		not app.ghost_warming and app.camera.get_cull_mask_value(2),
		"ghost preparation restores driving camera visibility"
	)


func lap(digital = false, timing = false):
	var driver = preload("res://scripts/showcase_driver.gd").new()
	driver.digital = digital
	driver.input_bus = true
	app.benchmark_driver = driver
	app.controls.clear()
	var desktop_escape = InputEventKey.new()
	desktop_escape.physical_keycode = KEY_ESCAPE
	desktop_escape.keycode = KEY_ESCAPE
	desktop_escape.pressed = true
	Input.parse_input_event(desktop_escape)
	Input.flush_buffered_events()
	desktop_escape.pressed = false
	Input.parse_input_event(desktop_escape)
	Input.flush_buffered_events()
	check(not app.blocked() and app.frontend.page == "drive", "desktop input cannot pause automated lap")
	var samples = []
	var trace = []
	var uninterrupted = true
	var starting_completed = app.race.completed
	print(
		"LAP CONFIG ", digital, " ", JSON.stringify(app.car.setup), " settings=", JSON.stringify(app.settings)
	)
	var steps = 4 if timing else 24
	var start_usec = Time.get_ticks_usec()
	var maximum_primitives = 0
	app.set_process(false)
	for frame in 600 * 60:
		if app.blocked() or app.frontend.page != "drive":
			uninterrupted = false
			break
		var started = Time.get_ticks_usec()
		for tick in steps:
			driver.feed(app.controls, app.car, app.track, app.settings)
			app._physics_process(1.0 / 240)
			if app.race.completed > starting_completed:
				break
		var physics_finished = Time.get_ticks_usec()
		app.prev_pose = {}
		app._process(float(steps) / 240)
		var presentation_finished = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000)
		if timing:
			trace.append(
				[
					frame,
					app.race.lap_time,
					app.car.speed * 3.6,
					float(physics_finished - started) / 1000,
					float(presentation_finished - physics_finished) / 1000,
					samples[-1],
					RenderingServer.viewport_get_measured_render_time_cpu(
						app.retro.world_view.get_viewport_rid()
					),
					RenderingServer.viewport_get_measured_render_time_gpu(
						app.retro.world_view.get_viewport_rid()
					)
				]
			)
			maximum_primitives = maxi(
				maximum_primitives,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			)
		if frame % 2400 == 0:
			print("LAP PROGRESS " + str(frame) + " time=" + str(app.race.lap_time))
		if app.race.completed > starting_completed:
			break
		if app.race.lap_time > 599 or driver.contacts > 0 or driver.off_steps > 0:
			print(
				"LAP STOP ",
				JSON.stringify(app.car.snapshot()),
				" keys=",
				app.controls.held_keys,
				" input=",
				app.car.input,
				" raw=",
				app.controls.raw,
				" pad=",
				app.controls.event_pad,
				" connected=",
				Input.get_connected_joypads()
			)
			break
	app.set_process(true)
	app.benchmark_driver = null
	driver.release(app.controls)
	app.controls.clear()
	var row = {
		"valid": app.race.last_valid,
		"lap_seconds": app.race.last,
		"off_steps": driver.off_steps,
		"contacts": driver.contacts,
		"kemmel_kmh": driver.kemmel_top,
		"maximum_slip_deg": driver.maximum_slip,
		"frames": samples.size(),
		"wall_seconds": float(Time.get_ticks_usec() - start_usec) / 1000000,
		"maximum_submitted_primitives": maximum_primitives
	}
	check(uninterrupted, "lap advances without menu or pause interruptions")
	check(app.race.completed > starting_completed and app.race.last_valid, "full valid 296 Spa lap")
	check(driver.off_steps == 0 and driver.contacts == 0, "zero off-track steps and barrier contacts")
	if timing:
		if samples.is_empty():
			check(false, "timing lap produced frame samples")
			return row
		app.storage.write_json(
			output.path_join("trace-" + timing_case + ".json"),
			{
				"columns":
				[
					"frame",
					"lap_seconds",
					"speed_kmh",
					"physics_ms",
					"presentation_ms",
					"total_ms",
					"world_cpu_ms",
					"world_gpu_ms"
				],
				"frames": trace
			}
		)
		samples.sort()
		var total = 0.0
		var slow_total = 0.0
		var slow_start = int(samples.size() * .99)
		for i in samples.size():
			total += samples[i]
			if i >= slow_start:
				slow_total += samples[i]
		row.average_ms = total / samples.size()
		row.p99_ms = samples[mini(slow_start, samples.size() - 1)]
		row.slowest_one_percent_mean_ms = slow_total / (samples.size() - slow_start)
		row.one_percent_low_fps = 1000 / row.slowest_one_percent_mean_ms
		row.worst_ms = samples[-1]
		row.over_16_67_ms = samples.filter(func(v): return v > 16.667).size()
		check(row.slowest_one_percent_mean_ms <= 16.667, "full-lap 1% low >= 60 fps")
	print("LAP RESULT " + JSON.stringify(row))
	return row


func flow(owner_app):
	await setup(owner_app)
	for controller in [false] if "--keyboard" in OS.get_cmdline_user_args() else [true, false]:
		pad = controller
		app.frontend.show_page("boot")
		await frames()
		page("boot")
		await accept()
		page("title")
		await accept()
		page("main")
		await accept()
		if not page("race"):
			return
		await accept()
		page("car")
		await accept()
		page("circuit")
		await accept()
		var deadline = Time.get_ticks_msec() + 15000
		while app.frontend.page not in ["grid", "drive"] and Time.get_ticks_msec() < deadline:
			await frames()
		check("loading" in app.frontend.navigation_log, "real loading stage reached")
		while app.frontend.page == "grid" and Time.get_ticks_msec() < deadline:
			await frames()
		if not page("drive"):
			return
		var row = await lap(not pad)
		row.loading_stages_ms = app.frontend.loading_timings.duplicate()
		# The user's frame-time target is specific to this GPU-equipped machine.
		# Software-rendered CI still records preparation and checks its data,
		# without turning a portable functional suite into a hardware speed test.
		if RenderingServer.get_video_adapter_name().contains("RTX 4080"):
			check(
				row.loading_stages_ms.values().max() <= 16.667,
				"each Spa preparation stage fits one 60 Hz frame"
			)
		else:
			check(
				row.loading_stages_ms.values().all(func(ms): return is_finite(ms) and ms >= 0),
				"preparation stage measurements are finite"
			)
		row.input = "controller" if pad else "keyboard"
		rows.append(row)
		await tap(KEY_ESCAPE, JOY_BUTTON_START)
		page("pause")
		await down(5)
		await accept()
		if not page("results"):
			return
		check(app.frontend.laps.size() == 1 and app.frontend.laps[0].valid, "time sheet contains valid lap")
		check(app.frontend.last_ghost.size() > 100, "last-lap replay recording")
		if app.race.last_valid:
			app.storage.write_json(
				output.path_join("presentation-lap.json"),
				{
					"laps": app.frontend.laps,
					"ghost": app.frontend.last_ghost,
					"top_speed": app.frontend.session_top_speed
				}
			)
		await shot("flow-" + row.input + "-results")
		await down(3)
		await accept()
		page("main")
		# Secondary screens are opened and closed using the same input device.
		for item in [[1, "garage"], [3, "settings"], [4, "help"]]:
			await down(item[0])
			await accept()
			check(app.ui.screen == item[1] and app.ui.is_open(), row.input + " opens " + item[1])
			if item[1] == "settings":
				await tap(KEY_PAGEDOWN, JOY_BUTTON_RIGHT_SHOULDER)
				var tabs = app.ui.content.find_children("*", "TabContainer", true, false)[0]
				check(tabs.current_tab == 1, row.input + " switches settings tab")
				await tap(KEY_PAGEUP, JOY_BUTTON_LEFT_SHOULDER)
				check(tabs.current_tab == 0, row.input + " switches tab back")
			await tap(KEY_ESCAPE, JOY_BUTTON_B)
			check(not app.ui.is_open(), row.input + " closes " + item[1])
			page("main")
		app.storage.write_json(
			output.path_join("flow-results.json"), {"checks": checks, "results": rows, "failures": failures}
		)
	# Click the same physical pixel that presents the Race button to the player.
	app.frontend.show_page("main")
	await frames()
	await click_button(app.frontend.buttons[0])
	check(app.frontend.page == "race", "mouse selects presented Race button at SD scale")
	app.frontend.show_page("drive")
	await frames()
	await click_button(app.frontend.buttons[0])
	check(app.frontend.page == "pause", "mouse opens Pause from HUD")
	# Cancel while the preparation coroutine is suspended, then ensure its
	# continuation cannot unexpectedly return the player to the grid.
	app.frontend.prepare_race()
	await tap(KEY_ESCAPE, JOY_BUTTON_B)
	await frames(8)
	check(
		app.frontend.page == "circuit" and not app.frontend.loading,
		"cancelled loading stays on circuit selection"
	)
	app.frontend.show_page("title")
	app.frontend._process(26)
	check(
		(
			app.frontend.page == "attract"
			and app.preset_key == "f296gt3"
			and app.active_track_file.ends_with("Spa-Francorchamps.json")
		),
		"idle attract uses 296 Spa"
	)
	await frames()
	await tap(KEY_ESCAPE, JOY_BUTTON_B)
	check(
		app.frontend.page == "title" and app.frontend.demo_context.is_empty(),
		"attract Back restores selection"
	)
	app.storage.write_json(
		output.path_join("flow-results.json"), {"checks": checks, "results": rows, "failures": failures}
	)


func performance(owner_app):
	await setup(owner_app)
	app.get_window().size = Vector2i(1920, 1080)
	var backend = RenderingServer.get_current_rendering_method()
	var selected_case = -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--performance-case="):
			selected_case = int(arg.get_slice("=", 1))
	RenderingServer.viewport_set_measure_render_time(app.retro.world_view.get_viewport_rid(), true)
	for light in 2:
		for resolution in 3:
			if selected_case >= 0 and light * 3 + resolution != selected_case:
				continue
			timing_case = backend + "-" + str(light * 3 + resolution)
			app.settings.render_resolution = resolution
			app.settings.time_of_day = light
			app.apply_settings()
			app.start_drive()
			app.load_record()
			await frames(60)
			var row = await lap(false, true)
			row.backend = backend
			row.lighting = ["Afternoon", "Afterhours"][light]
			row.resolution = ["480p", "720p", "Native"][resolution]
			row.raster = [app.retro.world_view.size.x, app.retro.world_view.size.y]
			rows.append(row)
			(
				app
				. storage
				. write_json(
					output.path_join(
						"performance-" + (timing_case if selected_case >= 0 else backend) + ".json"
					),
					{
						"method":
						"Uncapped full lap, four 240 Hz simulation ticks per rendered frame, GPU present included; 1920x1080 window; 60-frame setup warmup excluded.",
						"device": RenderingServer.get_video_adapter_name(),
						"results": rows,
						"checks": checks,
						"failures": failures
					}
				)
			)


func run(owner_app, timing = false):
	if timing:
		await performance(owner_app)
	else:
		await flow(owner_app)
	var result = {"checks": checks, "results": rows, "failures": failures}
	app.storage.write_json(
		output.path_join("performance-results.json" if timing else "flow-results.json"), result
	)
	print("BENCHMARK RESULTS " + JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
