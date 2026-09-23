extends Node
## Deterministic visual comparisons and full-lap acceptance; isolated native-tests storage.
var app
var output = ""
var failures = []
var captures = []
var spots = {
	"la-source": ["La Source", -45],
	"eau-rouge": ["Eau Rouge", -65],
	"kemmel": ["Kemmel", 0],
	"les-combes": ["Les Combes", -55],
	"pouhon": ["Pouhon", -45],
	"blanchimont": ["Blanchimont", -40],
	"bus-stop": ["Bus Stop", -50],
	"grid": ["Grid", 0]
}


func frames(count = 4):
	for i in count:
		await get_tree().process_frame


func shot(name):
	await frames()
	await RenderingServer.frame_post_draw
	var path = output.path_join(name + ".png")
	var err = app.get_viewport().get_texture().get_image().save_png(path)
	if err != OK:
		failures.append("Screenshot " + path)
	captures.append(path)


func run_compare(owner_app):
	app = owner_app
	var round_number = "1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--round="):
			round_number = arg.get_slice("=", 1)
	var backend = "gl" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "forward"
	output = (
		("res://tests/compare" if OS.has_feature("editor") else "user://native-tests/compare")
		. path_join("round-" + round_number)
		. path_join(backend)
	)
	DirAccess.make_dir_recursive_absolute(output)
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.folder = "user://native-tests"
	app.settings.adaptive = false
	app.apply_settings()
	app.set_physics_process(false)
	app.set_process(false)
	app.frontend.set_process(false)
	var lap_path = (
		"res://tests/showcase/presentation-lap.json"
		if OS.has_feature("editor")
		else "user://native-tests/showcase/presentation-lap.json"
	)
	if FileAccess.file_exists(lap_path):
		var lap_data = JSON.parse_string(FileAccess.get_file_as_string(lap_path))
		app.frontend.laps = lap_data.laps
		app.frontend.last_ghost = lap_data.ghost
		app.frontend.session_top_speed = lap_data.top_speed
	var geometry = {"car_triangles": 0, "car_meshes": 0}
	for node in app.model.root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		geometry.car_meshes += 1
		for surface in node.mesh.get_surface_count():
			var arrays = node.mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			geometry.car_triangles += (
				(
					indices.size()
					if indices != null and indices.size() > 0
					else arrays[Mesh.ARRAY_VERTEX].size()
				)
				/ 3
			)
	for tod in 2:
		app.settings.time_of_day = tod
		app.apply_settings()
		var prefix = "afternoon" if tod == 0 else "afterhours"
		app.frontend.show_page("drive")
		app.frontend.prompt.visible = false
		app.ui.sync_menus()
		for name in spots:
			var distance = float(app.track.data.startS) - 10
			for label in app.track.data.presentation.labels:
				if label.name == spots[name][0]:
					distance = app.track.project(label.x, label.y).s + spots[name][1]
			app.car.reset_pose(app.track.pos_at(distance))
			app.car.speed = 44 if name == "kemmel" else 20
			app.car.gear = 4 if name == "kemmel" else 2
			app.car.rpm = (
				app.car.speed
				/ app.car.p.wheelR
				* app.car.setup.finalDrive
				* app.car.setup["gear" + str(app.car.gear)]
				* 60
				/ TAU
			)
			app.visuals.pose_car(app.model, app.car.snapshot(), app.track)
			for camera_mode in [0, 2]:
				app.settings.camera = camera_mode
				app.update_camera(1, true)
				app.instruments.queue_redraw()
				await shot(prefix + "-" + name + ("-chase" if camera_mode == 0 else "-hood"))
		app.reset_car()
		app.instruments.visible = false
		app.frontend.visible = false
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
			await shot(prefix + "-showroom-" + item[0])
		app.frontend.visible = true
	for dimensions in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		app.get_window().size = dimensions
		await frames()
		app.retro.apply_settings()
		app.settings.time_of_day = 0
		app.apply_settings()
		for page in [
			"boot",
			"title",
			"main",
			"race",
			"car",
			"circuit",
			"circuits",
			"loading",
			"grid",
			"drive",
			"pause",
			"results",
			"attract",
			"replay"
		]:
			app.frontend.show_page(page)
			if page == "loading":
				app.frontend.loading_stage = "Circuit data validated"
				app.frontend.loading_progress = .25
			app.frontend.prompt.visible = true
			app.frontend.prompt.text = "ARROWS  Move     ENTER  Select     ESC  Back"
			app.ui.sync_menus()
			app._process(.016)
			app.frontend._process(.2)
			await shot("ui-%dx%d-%s" % [dimensions.x, dimensions.y, page])
		for panel in ["garage", "settings", "help", "library"]:
			app.frontend.show_page("main")
			app.frontend.open_panel(panel)
			await shot("ui-%dx%d-%s" % [dimensions.x, dimensions.y, panel])
			app.ui.close()
		app.start_editor()
		app.frontend._process(.016)
		await shot("ui-%dx%d-editor" % [dimensions.x, dimensions.y])
		app.set_editor(false)
		app.frontend.show_page("main")
	for settings_case in [
		[1, false, 0, "480i"],
		[1, true, 0, "480i-composite"],
		[0, false, 1, "sharp-ui"],
		[0, false, 0, "480p-4x3"]
	]:
		app.settings.output_mode = settings_case[0]
		app.settings.crt_filter = settings_case[1]
		app.settings.ui_mode = settings_case[2]
		app.settings.screen_aspect = 0 if settings_case[3] == "480p-4x3" else 1
		app.apply_settings()
		app.frontend.show_page("main")
		app.ui.sync_menus()
		app._process(.2)
		app.frontend._process(.2)
		await shot("output-" + settings_case[3])
	var report = {
		"renderer": backend,
		"geometry": geometry,
		"round": round_number,
		"captures": captures,
		"failures": failures,
		"world_raster": [app.retro.world_view.size.x, app.retro.world_view.size.y]
	}
	app.storage.write_json(output.path_join("compare-results.json"), report)
	print("COMPARE RESULTS " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
