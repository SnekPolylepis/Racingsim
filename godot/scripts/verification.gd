extends Node
## Rendered integration runner for both editor-engine and exported executable launches.
## Invoked only by --features or --smoke, using isolated user://native-tests saves.
## Explicit checks survive release builds; do not replace them with stripped assert calls.
## See docs/TESTING.md for commands, evidence paths and untested hardware boundaries.
# Native integration checks run against isolated user://native-tests data.
var app
var failures = []
var checks = 0
var output = ""


func check(condition, description):
	checks += 1
	if not condition:
		failures.append(description)
		push_error("CHECK FAILED: " + description)


func frames(count = 3):
	for i in count:
		await get_tree().process_frame


func shot(name):
	await frames()
	await RenderingServer.frame_post_draw
	check(
		get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK,
		"capture " + name
	)


func key(code, down = true):
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func energy(capture):
	var buffer = capture.get_buffer(capture.get_frames_available())
	var sum = 0.0
	for sample in buffer:
		sum += sample.length_squared()
	return sqrt(sum / maxi(1, buffer.size()))


func run(owner_app):
	app = owner_app
	output = "res://tests" if OS.has_feature("editor") else "user://native-tests"
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.folder = "user://native-tests"
	app.settings.adaptive = false
	app.controls.configure(app.settings)
	app.apply_settings()
	app.paused = false
	app.start_drive()
	await frames(10)
	check(app.track_files.size() >= 3, "three bundled circuits")
	check(app.presets.size() == 3, "three car presets")
	check(app.preset_key == "f296gt3", "296 GT3 default car")
	check(app.active_track_file == "res://tracks/Spa-Francorchamps.json", "Spa default circuit")
	check(app.ui.car_picker.selected == app.presets.keys().find("f296gt3"), "default car selector")
	check(app.setup_fields.size() == 42, "complete garage fields")
	await check_retro_features()
	var hull = app.model.body.get_child(0).mesh.surface_get_arrays(0)
	var top_index = 0
	for i in hull[Mesh.ARRAY_VERTEX].size():
		if hull[Mesh.ARRAY_VERTEX][i].y > hull[Mesh.ARRAY_VERTEX][top_index].y:
			top_index = i
	check(hull[Mesh.ARRAY_NORMAL][top_index].y > .1, "car hull exterior normals face outward")
	check(app.model.body.find_child("Headlights", true, false) != null, "296 night headlights")
	check_car_animation()
	check(app.scenery.get_node_or_null("NightCircuit") != null, "night circuit lighting")
	var capture = AudioEffectCapture.new()
	capture.buffer_length = 2
	AudioServer.add_bus_effect(0, capture)
	app.test_input = true
	await get_tree().create_timer(1.4).timeout
	app.test_input = false
	check(app.car.speed > 1, "native driving accelerates")
	check(energy(capture) > .001, "engine produces audible PCM")
	app.settings.telemetry = true
	app.settings.debug = true
	await shot("native-drive")
	app.settings.mute = true
	await get_tree().create_timer(.8).timeout
	capture.clear_buffer()
	await get_tree().create_timer(.25).timeout
	check(energy(capture) < .0001, "mute silences audio")
	app.settings.mute = false
	app.paused = true
	await get_tree().create_timer(.8).timeout
	capture.clear_buffer()
	await get_tree().create_timer(.25).timeout
	check(energy(capture) < .0001, "pause silences audio")
	app.paused = false
	for name in app.sound.players:
		check(app.sound.players[name].stream.data.size() > 1000, "available " + name + " PCM sound")
	AudioServer.remove_bus_effect(0, 0)
	app.ui.open_garage()
	await frames()
	check(app.ui.content.get_child_count() > 2, "garage builds all tuning tabs")
	await shot("native-garage")
	var old = app.car.setup.duplicate(true)
	var field = app.setup_fields[0]
	app.car.setup[field[1]] = field[3]
	app.ui.close()
	check(app.car.setup[field[1]] == field[3], "garage applies tuning")
	var setup_path = app.storage.path("setups", "Integration.json")
	check(app.storage.write_json(setup_path, app.setup_document()), "save setup")
	app.car.setup = old
	check(app.import_setup(setup_path), "import setup")
	check(app.car.setup[field[1]] == field[3], "setup round trip")
	app.ui.close()
	app.change_car("roadster")
	app.ui.open_help()
	await frames()
	var chapter_picker = app.ui.content.find_child("HelpChapters", true, false)
	check(chapter_picker.item_count >= 7, "packaged handbook chapters")
	for i in chapter_picker.item_count:
		chapter_picker.select(i)
		chapter_picker.item_selected.emit(i)
		await frames(1)
		check(app.ui.content.get_node("HelpBody").get_child_count() > 1, "help chapter " + str(i))
	chapter_picker.select(0)
	chapter_picker.item_selected.emit(0)
	await shot("native-help")
	app.ui.close()
	app.ui.open_settings()
	await frames()
	await shot("native-settings")
	app.ui.close()
	app.controls.listening = "throttle"
	app.controls.listen_pad = false
	key(KEY_I)
	key(KEY_I, false)
	await frames()
	check(app.controls.keys.throttle == [KEY_I], "key remapping through actual input")
	key(KEY_I)
	await get_tree().create_timer(.25).timeout
	check(app.car.input.throttle > .1, "remapped accelerator drives")
	key(KEY_I, false)
	await get_tree().create_timer(.2).timeout
	check(not app.controls.held("throttle"), "key release clears")
	app.controls.listening = "steer"
	app.controls.listen_pad = true
	var axis = InputEventJoypadMotion.new()
	axis.axis = 2
	axis.axis_value = -.9
	Input.parse_input_event(axis)
	await frames()
	check(app.controls.pad.steer.axis == 2 and app.controls.pad.steer.sign == -1, "controller axis remapping")
	app.controls.configure(app.DEFAULT_SETTINGS)
	app.save_settings()
	check(app.storage.read_json(app.settings_path).has("keys"), "settings persist mappings")
	for i in 5:
		app.settings.camera = i
		app.update_camera(1, true)
		check(app.camera.position.is_finite(), "camera " + str(i))
	app.settings.camera = 0
	app.settings.debug = false
	app.settings.telemetry = false
	var track_data = app.track.to_json()
	check(app.storage.validate_track(track_data).is_empty(), "track export valid")
	check(
		app.storage.validate_track({"points": [{"x": "bad", "y": 0, "w": 12}]}) != "",
		"reject malformed track"
	)
	check(app.storage.safe_name("CON") == "CON_", "Windows reserved file name")
	app.load_track_now("res://tracks/Monza.json")
	var ghost = {"schema": 1, "time": 1.0, "samples": [[0, 0, 0, 0, 0, 0], [1, 1, 0, 0, 0, 1]]}
	var ghost_path = app.storage.path("ghosts", "Integration.ghost.json")
	app.storage.write_json(ghost_path, ghost)
	check(app.import_ghost(ghost_path), "browser ghost import")
	check(app.race.best == 1 and app.race.ghost.size() == 2, "ghost imported samples")
	var record = app.record_path()
	app.race.best = 0
	app.load_record()
	check(app.race.best == 1, "ghost reload")
	app.car.setup[app.setup_fields[0][1]] += app.setup_fields[0][5]
	check(app.record_path() != record, "setup changes record namespace")
	app.change_car("roadster")
	app.clear_ghost()
	app.ui.open_library()
	await frames()
	await shot("native-library")
	app.ui.close()
	get_window().size = Vector2i(1024, 640)
	await frames(5)
	app.ui.open_settings()
	await frames()
	check(
		(
			app.ui.modal.get_global_rect().end.x <= app.ui.root.size.x
			and app.ui.modal.get_global_rect().end.y <= app.ui.root.size.y
		),
		"settings fits smaller window"
	)
	app.ui.close()
	for name in ["Monza.json", "Spa-Francorchamps.json"]:
		check(app.load_track_now("res://tracks/" + name), "render " + name + " " + app.ui.status.text)
		await frames(2)
	for preset in app.presets:
		app.change_car(preset)
		await frames()
		check(not app.model.is_empty(), "render car " + preset)
	# Title screen and pause menu flow.
	app.load_track_now("res://tracks/Monza.json")
	app.show_main_menu()
	await frames(3)
	check(
		app.in_menu and app.blocked() and app.frontend.page == "main" and not app.instruments.visible,
		"title screen blocks driving and hides HUD"
	)
	check(
		app.track_files.size() >= 3 and app.frontend.buttons[0].has_focus(),
		"main menu retains circuits and focuses Race"
	)
	await shot("native-menu")
	app.ui.open_garage()
	await frames()
	check(app.ui.is_open() and app.in_menu, "garage opens over title screen")
	app.ui.close()
	app.start_drive()
	await frames(3)
	check(
		not app.in_menu and not app.blocked() and app.instruments.visible and app.frontend.page == "drive",
		"drive leaves title screen"
	)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames(3)
	check(
		app.paused and app.frontend.page == "pause" and app.frontend.buttons[0].has_focus(),
		"escape opens pause menu"
	)
	app.ui.open_settings()
	await frames()
	check(app.ui.is_open() and app.paused, "settings from pause menu")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	await frames(3)
	check(
		not app.ui.is_open() and app.paused and app.frontend.page == "pause",
		"closing settings returns to pause menu"
	)
	await shot("native-pause")
	app.ui.open_garage()
	await frames()
	app.ui.close()
	await frames(2)
	check(app.paused and app.frontend.page == "pause", "closing garage returns to pause menu")
	app.set_paused(false)
	await frames(2)
	check(app.frontend.page == "drive" and not app.blocked(), "resume")
	app.set_paused(true)
	await frames(2)
	app.show_main_menu()
	await frames(2)
	check(app.in_menu and not app.paused and app.frontend.page == "main", "pause menu returns to main screen")
	app.start_drive()
	await frames(2)
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.folder = "user://native-tests"
	app.controls.configure(app.settings)
	app.save_settings()
	var flow_test = preload("res://scripts/showcase_benchmark.gd").new()
	add_child(flow_test)
	await flow_test.flow(app)
	checks += flow_test.checks
	failures.append_array(flow_test.failures)
	check_record_writer()
	var result = {"checks": checks, "failures": failures}
	app.storage.write_json(output.path_join("feature-results.json"), result)
	print("FEATURE RESULTS " + JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)


func check_record_writer():
	app.record_writer.flush()
	check(app.record_writer.failed_jobs == 0, "lap and sector background saves complete without errors")
	var file = app.storage.path("records", "writer-integration.json")
	for value in [1, 2, 3]:
		app.record_writer.enqueue({"path": file, "data": {"value": value}})
	app.record_writer.flush()
	check(app.storage.read_json(file).value == 3, "record writes preserve submission order")
	check(not FileAccess.file_exists(file + ".tmp"), "record replacement leaves no incomplete temporary file")
	DirAccess.remove_absolute(file)
	var recorded = app.frontend.last_ghost
	var count = recorded.size()
	app.race.reset()
	app.race.recording.append([0, 0, 0, 0, 0, 0])
	check(recorded.size() == count and count > 100, "new lap cannot mutate the completed replay")
	app.race.recording = []
	# Check the immutable recording before intentionally clearing session history.
	# Garage/car/rules changes replace RaceModel through this same record service.
	app.load_record()
	app.frontend.observe_tick()
	check(
		app.frontend.laps.is_empty() and app.frontend.last_ghost.is_empty() and recorded.size() == count,
		"record change clears session results without adding a zero-time lap"
	)


## The dedicated 296 body must retain the same animated model contract as the other presets.
func check_car_animation():
	var pose = app.car.snapshot().duplicate(true)
	pose.steer = .23
	pose.roll = .04
	pose.pitch = -.03
	pose.z = .02
	pose.phase = [.3, .6, .9, 1.2]
	pose.dev = [.01, .02, -.01, -.02]
	pose.brake = 1.0
	app.visuals.pose_car(app.model, pose, app.track)
	for i in 4:
		check(
			(
				is_equal_approx(app.model.pivots[i].rotation.y, -.23 if i < 2 else 0.0)
				and is_equal_approx(app.model.spins[i].rotation.z, -pose.phase[i])
				and is_equal_approx(app.model.pivots[i].position.y, app.car.p.wheelR + pose.dev[i])
			),
			"296 wheel steering, rotation and suspension %d" % i
		)
	check(
		is_equal_approx(app.model.body.position.y, -.02) and is_equal_approx(app.model.body.rotation.x, .04),
		"296 sprung body animation"
	)
	var bright = app.model.brakes.emission.r
	pose.brake = 0.0
	pose.handbrake = 0.0
	app.visuals.pose_car(app.model, pose, app.track)
	check(app.model.brakes.emission.r < bright, "296 brake lights respond to braking")
	app.visuals.pose_car(app.model, app.car.snapshot(), app.track)
	var ghost = app.visuals.make_car(app.presets.f296gt3, true)
	check(ghost.body.find_children("*", "Light3D", true, false).is_empty(), "296 ghost emits no headlights")
	var translucent = true
	for node in ghost.root.find_children("*", "MeshInstance3D", true, false):
		translucent = (
			translucent
			and node.material_override is StandardMaterial3D
			and node.material_override.albedo_color.a < .5
		)
	for node in ghost.root.find_children("*", "Label3D", true, false):
		translucent = translucent and not node.visible
	check(translucent, "296 ghost hides livery labels and uses translucent body and wheels")
	ghost.root.free()


## Deterministic native art review: isolated saves, real renderer, multiple car angles and driving views.
func run_art(owner_app):
	app = owner_app
	output = "res://tests" if OS.has_feature("editor") else "user://native-tests"
	var renderer = "gl" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "forward"
	output = output.path_join("ps2-" + renderer)
	DirAccess.make_dir_recursive_absolute(output)
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.adaptive = false
	app.settings.folder = "user://native-tests"
	app.set_physics_process(false)
	app.set_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var timings = []
	for tod in 2:
		for resolution in [0, 2]:
			app.settings.time_of_day = tod
			app.settings.render_resolution = resolution
			app.settings.quality = 1
			app.apply_settings()
			app.in_menu = false
			app.paused = true
			app.ui.root.visible = false
			app.reset_car()
			await frames(20)
			var prefix = (
				("afternoon" if tod == 0 else "afterhours") + ("-480p" if resolution == 0 else "-native")
			)
			var pos = app.model.root.position
			var basis = app.model.root.basis
			app.camera.fov = 42
			for item in [
				["front", Vector3(5.6, 2.3, 4.7)],
				["rear", Vector3(-5.8, 2.1, -4.5)],
				["profile", Vector3(.1, 1.6, 7.3)]
			]:
				app.camera.position = pos + basis * item[1]
				app.camera.look_at(pos + Vector3.UP * .65)
				await shot(prefix + "-" + item[0])
			var eau = app.track.project(96.2, -879.5)
			app.car.reset_pose(app.track.pos_at(eau.s - 60))
			app.visuals.pose_car(app.model, app.car.snapshot(), app.track)
			app.update_camera(1, true)
			app.camera.fov = 64
			await shot(prefix + "-eau-rouge")
			app.ui.root.visible = true
			app.show_main_menu()
			app._process(.016)
			await shot(prefix + "-menu")
			app.in_menu = false
			app.paused = false
			app.ui.sync_menus()
			app.car.vx = cos(app.car.h) * 40
			app.car.vy = sin(app.car.h) * 40
			for w in app.car.wheels:
				w.omega = 40 / app.car.p.wheelR
			for tick in 100:
				app.car.input = {"throttle": .3, "brake": 0., "steer": 0., "clutch": 0., "handbrake": 0.}
				app.car.step(1. / 240, app.track)
				app._process(1. / 240)
				await frames(1)
			await shot(prefix + "-hud-motion")
			for q in 3:
				app.set_quality(q)
				await frames(30)
				timings.append(await measure_frames(prefix + "-q" + str(q)))
	for tod in 2:
		app.settings.time_of_day = tod
		app.settings.speed_blur = 2
		app.settings.native_msaa = true
		app.settings.quality = 2
		for resolution in [1, 2]:
			app.settings.render_resolution = resolution
			app.apply_settings()
			app.reset_car()
			app.car.vx = cos(app.car.h) * 40
			app.car.vy = sin(app.car.h) * 40
			app.car.speed = 40
			app.car.gear = 4
			app.car.engine_w = 40 / app.car.p.wheelR * app.car.setup.gear4 * app.car.setup.finalDrive
			for wheel in app.car.wheels:
				wheel.omega = 40 / app.car.p.wheelR
			app.paused = false
			await frames(30)
			timings.append(
				await measure_frames(
					(
						("afternoon" if tod == 0 else "afterhours")
						+ ("-720p" if resolution == 1 else "-native-msaa2")
						+ "-q2-blur-high"
					)
				)
			)
	var report = {
		"checks": checks,
		"failures": failures,
		"renderer": renderer,
		"timings": timings,
		"gpu": RenderingServer.get_video_adapter_name()
	}
	app.storage.write_json(output.path_join("art-results.json"), report)
	print("ART RESULTS " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func measure_frames(label):
	app.set_process(true)
	app.set_physics_process(true)
	var samples = []
	var views = [app.retro.world_view, app.retro.glow_view] + app.retro.history
	for view in views:
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	var gpu = 0.0
	var last = Time.get_ticks_usec()
	for i in 180:
		await frames(1)
		var now = Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
		for view in [app.retro.world_view, app.retro.glow_view, app.retro.history[app.retro.cursor]]:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())
	app.set_process(false)
	app.set_physics_process(false)
	samples.sort()
	return {
		"case": label,
		"median_ms": samples[90],
		"p95_ms": samples[171],
		"mean_gpu_view_sum_ms": gpu / 180,
		"frames": 180
	}


func check_retro_features():
	app.paused = true
	check(app.settings.handling_model == 0 and app.car.simcade_enabled, "Simcade default and model flag")
	check(
		app.car.tcs_level() == 3 and app.car.asm_level() == 3 and app.car.setup.absOn == 1,
		"TCS 3 ASM 3 ABS on defaults"
	)
	var simcade_record = app.record_path()
	app.settings.handling_model = 1
	app.apply_settings()
	check(not app.car.simcade_enabled and app.car.asm_level() == 0, "Simulation preserves native defaults")
	check(app.record_path() != simcade_record, "handling model separates records and ghosts")
	app.car.setup.asmLevel = 10
	app.car.set_tcs(10)
	check(app.car.tcs_level() == 10 and app.car.asm_level() == 10, "numbered aids work in Simulation")
	app.car.set_tcs(0)
	app.car.setup.asmLevel = 0
	app.car.setup.absOn = 0
	check(
		app.car.setup.tcOn == 0 and app.car.setup.tcIntensity == 0 and app.car.setup.absOn == 0,
		"TCS zero and ABS off"
	)
	app.settings.handling_model = 0
	app.apply_settings()
	app.change_car("f296gt3")
	var default_record = app.record_path()
	var default_file = app.storage.path("setups", "DefaultAids.json")
	app.storage.write_json(default_file, app.setup_document())
	check(app.import_setup(default_file), "effective aid defaults export and reimport")
	check(
		app.car.tcs_level() == 3 and app.car.asm_level() == 3 and app.record_path() == default_record,
		"setup round trip preserves model aid identity"
	)
	app.ui.close()
	var legacy = {"schema": 1, "car": "f296gt3", "setup": app.presets.f296gt3.setup.duplicate(true)}
	legacy.setup.tcOn = 0
	legacy.setup.absOn = 0
	var file = app.storage.path("setups", "LegacyAids.json")
	app.storage.write_json(file, legacy)
	check(app.import_setup(file), "old 42-field setup imports")
	check(
		app.car.tcs_level() == 0 and app.car.asm_level() == 0 and app.car.setup.absOn == 0,
		"legacy aids retain off state"
	)
	app.ui.close()
	app.change_car("f296gt3")
	var identity = app.record_path()
	for tod in 2:
		app.settings.time_of_day = tod
		app.apply_settings()
		check(
			app.scenery.get_node("NightCircuit").visible == (tod == 1),
			"time of day switches lamps " + str(tod)
		)
		check(app.record_path() == identity, "time of day excluded from records " + str(tod))
	for resolution in 3:
		app.settings.render_resolution = resolution
		app.apply_settings()
		await frames(4)
		var expected_height = [448, 720, get_window().size.y][resolution]
		check(app.retro.world_view.size.y == expected_height, "internal resolution " + str(resolution))
		var logical = get_viewport().get_visible_rect().size
		var pixel = app.retro.world_pixel(logical * .5)
		check(
			pixel.distance_to(Vector2(app.retro.world_view.size) * .5) < .01,
			"SubViewport camera picking mapping " + str(resolution)
		)
		check(
			app.camera.project_ray_normal(pixel).dot(-app.camera.global_basis.z) > .999,
			"camera centre ray " + str(resolution)
		)
	app.settings.time_of_day = 0
	app.settings.render_resolution = 0
	app.apply_settings()
	app.reset_car()
	app.load_record()
	# Medium is the default tier and now casts directional shadows; the contact patch stays on
	# underneath it for close grounding. Screen-space lighting remains off at every tier.
	check(
		app.sun.shadow_enabled and not app.environment.ssao_enabled, "default directional shadows and no SSAO"
	)
	check(app.visuals.cast_shadows, "contact patch backs off when shadows cast")
	check(app.model.root.get_node_or_null("CarDropShadow") != null, "road-aligned car drop shadow")
	check(app.ui.get_parent() == app.retro.ui_view, "authentic UI joins the SD output chain")
	var texture = app.visuals.world.tex("asphalt_track", "diff")
	check(
		texture.get_width() <= 256 and texture.get_height() <= 256,
		"3D CC0 texture import downsamples originals"
	)
	app.paused = false


func run_title(owner_app):
	app = owner_app
	output = "res://tests" if OS.has_feature("editor") else "user://native-tests"
	await frames(60)
	check(app.in_menu and app.frontend.page in ["boot", "title"] and app.blocked(), "fresh launch boot/title")
	app.frontend.show_page("title")
	await frames(3)
	check(
		app.preset_key == "f296gt3" and app.active_track_file.ends_with("Spa-Francorchamps.json"),
		"fresh launch Spa and 296"
	)
	check(app.car.simcade_enabled and app.settings.time_of_day == 0, "fresh launch Simcade and Afternoon")
	check(app.retro.world_view.size.y == 448 and app.settings.upscale == 1, "fresh launch 480p Soft")
	check(app.settings.colour_dither and app.settings.speed_blur == 1, "fresh launch dither on and blur Low")
	check(
		app.car.tcs_level() == 3 and app.car.asm_level() == 3 and app.car.setup.absOn == 1,
		"fresh launch aid defaults"
	)
	await shot("native-title-defaults")
	var result = {"checks": checks, "failures": failures}
	app.storage.write_json(output.path_join("title-results.json"), result)
	print("TITLE RESULTS " + JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
