extends SceneTree
## Windowed Chicago comparison captures. Run with -- --v2-flow-test --v2-track=chicago.
## Writes only to --out=<dir> (default user://chicago-shots); --compare adds real- and game-frame strips.

const Generator = preload("res://trackgen/chicago.gd")
const NightShots = preload("res://tests/v2/night_screenshots.gd")
const CAM_CHASE = 0
const CAM_BONNET = 2
const REAL_DIR = "res://docs/art/reference/chicago/"
const GAME_DIR = REAL_DIR

## Spot -> [real photo, nearest game frame]. See the Chicago board README for match limitations.
const REFERENCE_MAP = {
	"michigan-bean":
	[
		"chicago-real-michigan-bean-day.jpg",
		"chicago-real-michigan-bridge-night.jpg",
		"game-nfs-underground-night-neon-street.jpg"
	],
	"lake-shore":
	[
		"chicago-real-lake-shore-day.jpg",
		"chicago-real-lakefront-night.jpg",
		"game-nfs-underground-night-wide-road-barriers.jpg"
	],
	"navy-pier":
	[
		"chicago-real-navy-pier-day.jpg",
		"chicago-real-riverfront-night.jpg",
		"game-nfs-underground-night-water-reflections.jpg"
	],
	"upper-wacker":
	[
		"chicago-real-upper-and-lower-wacker-day.jpg",
		"chicago-real-upper-wacker-night.jpg",
		"game-nfs-underground-night-wide-road-barriers.jpg"
	],
	"lower-wacker":
	[
		"chicago-real-lower-wacker-tunnel-day.jpg",
		"chicago-real-lower-wacker-tunnel-night.jpg",
		"game-nfs-underground-night-neon-street.jpg"
	],
	"michigan-bridge":
	[
		"chicago-real-michigan-bridge-day.jpg",
		"chicago-real-michigan-bridge-night.jpg",
		"game-nfs-underground-night-grid.jpg"
	],
	"state-bridge":
	[
		"chicago-real-state-bridge-day.jpg",
		"chicago-real-river-night.jpg",
		"game-nfs-underground-night-water-reflections.jpg"
	],
	"lasalle-bridge":
	[
		"chicago-real-lasalle-bridge-day.jpg",
		"chicago-real-riverfront-night.jpg",
		"game-nfs-underground-night-wide-road-barriers.jpg"
	],
	"willis-river":
	[
		"chicago-real-willis-river-day.jpg",
		"chicago-real-river-night.jpg",
		"game-nfs-underground-night-city-native.jpg"
	],
	"merchandise-mart":
	[
		"chicago-real-mart-wacker-day.jpg",
		"chicago-real-upper-wacker-night.jpg",
		"game-nfs-underground-night-neon-street.jpg"
	],
	"loop-aerial-north":
	[
		"chicago-real-loop-aerial-north-day.jpg",
		"chicago-real-lakefront-night.jpg",
		"game-nfs-underground-night-motion-blur.jpg"
	],
	"loop-aerial-river":
	[
		"chicago-real-loop-aerial-river-day.jpg",
		"chicago-real-riverfront-night.jpg",
		"game-nfs-underground-night-grid.jpg"
	],
	"bonnet-lower-wacker":
	[
		"chicago-real-lower-wacker-tunnel-day.jpg",
		"chicago-real-lower-wacker-pillar-night.jpg",
		"game-nfs-underground-pre-release-ps2.jpg"
	],
}

## Exact road coordinates, positioned at the nearest drivable camera station. Aerials use elevated views
## from the upper deck; the bonnet shot uses the lower tunnel camera.
const SPOTS = [
	["michigan-bean", [41.8830, -87.6244, 8], CAM_CHASE],
	["lake-shore", [41.8801, -87.6173, 8], CAM_CHASE],
	["navy-pier", [41.8862, -87.6139, 13], CAM_CHASE],
	["upper-wacker", [41.8869, -87.6320, 8], CAM_CHASE],
	["lower-wacker", [41.88792, -87.6207, 0], CAM_CHASE],
	["michigan-bridge", [41.8880, -87.6244, 8], CAM_CHASE],
	["state-bridge", [41.8870, -87.6289, 8], CAM_CHASE],
	["lasalle-bridge", [41.8870, -87.6327, 8], CAM_CHASE],
	["willis-river", [41.8785, -87.6369, 8], CAM_CHASE],
	["merchandise-mart", [41.8880, -87.6350, 8], CAM_CHASE],
	["loop-aerial-north", [41.8893, -87.6210, 8], CAM_CHASE],
	["loop-aerial-river", [41.8863, -87.6380, 8], CAM_CHASE],
	["bonnet-lower-wacker", [41.88792, -87.6207, 0], CAM_BONNET],
]

var failures = []
var folder = "user://chicago-shots"
var compare = false


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg == "--compare":
			compare = true
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.load_v2_track("chicago"):
		quit(1)
		return
	app.start_v2_drive()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var helper = NightShots.new()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for night in [false, true]:
		app.settings.time_of_day = 1 if night else 0
		app.apply_time_of_day()
		for spot in SPOTS:
			var point = Generator.world(spot[1])
			var station = app.track.project(point, -1).s
			helper.pose(app, station, night)
			app.settings.camera = 2 if spot[0] == "lower-wacker" else spot[2]
			app.update_camera(1.0, true)
			if spot[0].begins_with("loop-aerial"):
				app.camera.global_position = point + Vector3(0.0, 95.0, -45.0)
				app.camera.look_at(point, Vector3(0.0, 0.0, -1.0))
			var shot_id: String = spot[0] + ("-night" if night else "-day")
			var image = await capture(shot_id)
			if compare and REFERENCE_MAP.has(spot[0]):
				var real_ref: String = REFERENCE_MAP[spot[0]][0]
				if night:
					real_ref = REFERENCE_MAP[spot[0]][1]
				await write_compare(shot_id, image, real_ref, REAL_DIR)
				await write_compare(shot_id + "-game", image, REFERENCE_MAP[spot[0]][2], GAME_DIR)
	helper.free()
	app.queue_free()
	await process_frame
	print("CHICAGO SHOTS RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func capture(shot_id: String) -> Image:
	for i in 10:
		await process_frame
	var path = folder.path_join(shot_id + ".png")
	var image = root.get_texture().get_image()
	if image.save_png(path) != OK:
		failures.append("save " + path)
	print(
		"CHICAGO SHOT ",
		shot_id,
		" ",
		ProjectSettings.globalize_path(path),
		" draws=",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		" gpu_ms=",
		RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	)
	return image


func write_compare(shot_id: String, ours: Image, reference: String, base: String) -> void:
	var path = base + reference
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		failures.append("compare reference missing " + path)
		return
	var image = Image.new()
	var err = image.load_jpg_from_buffer(bytes)
	if err != OK:
		err = image.load_png_from_buffer(bytes)
	if err != OK:
		failures.append("compare reference decode " + path)
		return
	var pane_w = 640
	var pane_h = 480
	var label_h = 36
	var sub = SubViewport.new()
	sub.size = Vector2i(pane_w * 2, pane_h + label_h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var row = HBoxContainer.new()
	row.size = sub.size
	row.add_theme_constant_override("separation", 0)
	sub.add_child(row)
	_compare_pane(row, "ours: " + shot_id, ours, pane_w, pane_h, label_h)
	_compare_pane(row, "ref: " + reference, image, pane_w, pane_h, label_h)
	for i in 3:
		await process_frame
	var out = folder.path_join(shot_id + "-compare.png")
	if sub.get_texture().get_image().save_png(out) != OK:
		failures.append("save " + out)
	print("CHICAGO COMPARE ", ProjectSettings.globalize_path(out))
	sub.queue_free()


func _compare_pane(row: HBoxContainer, caption: String, image: Image, w: int, h: int, label_h: int) -> void:
	var pane = VBoxContainer.new()
	pane.custom_minimum_size = Vector2(w, h + label_h)
	pane.add_theme_constant_override("separation", 0)
	row.add_child(pane)
	var label = Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(w, label_h)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 18)
	pane.add_child(label)
	var tex = TextureRect.new()
	tex.texture = ImageTexture.create_from_image(image)
	tex.custom_minimum_size = Vector2(w, h)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	pane.add_child(tex)
