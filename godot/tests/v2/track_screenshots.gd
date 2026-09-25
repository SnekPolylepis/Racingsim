extends SceneTree
## Daylight review captures of the Proving Ground, Spa and the Nordschleife through the real
## presentation chain (the default 640x448 Authentic look), HUD hidden. Run windowed (never
## --headless), with the flow-test flag so the user's settings file is untouched:
##   tools/Godot.exe --path . --script tests/v2/track_screenshots.gd -- --v2-flow-test [--out=<dir>] [--compare]
## Writes <dir>/<shot>.png (default user://track-shots) and prints TRACK SHOTS RESULTS.
## --compare additionally writes <dir>/<shot>-compare.png for every shot with a reference frame in
## docs/art/reference/ (REFERENCE_MAP below): ours on the left, the reference on the right, both labelled.

const NightShots = preload("res://tests/v2/night_screenshots.gd")

## Chase (Look-2's default) unless a shot names CAM_BONNET explicitly.
const CAM_CHASE = 0
const CAM_BONNET = 2

## shot id -> [reference file in docs/art/reference/, one-line note on the match]. A pair is either a
## confirmed corner match or, where marked "look target", a GT4 Nordschleife frame of the same camera type
## whose corner is not identified: compare the look (road, armco, forest, sky), not the geometry. See
## docs/art/reference/README.md.
const REFERENCE_MAP = {
	"ns-flugplatz":
	["real-nordschleife-flugplatz.jpg", "Confirmed Flugplatz, both photographed crest-on from the approach."],
	"ns-hatzenbach":
	[
		"gt4-nordschleife-chase-kerbs-armco.jpg",
		"Look target: GT4 Nordschleife chase view, corner not identified."
	],
	"ns-hatzenbach-bonnet":
	[
		"gt4-nordschleife-bonnet-forest-wall.jpg",
		"Look target: GT4 Nordschleife bonnet view, corner not identified."
	],
	"ns-schwedenkreuz":
	[
		"gt4-nordschleife-chase-edge-lines.jpg",
		"Look target: GT4 Nordschleife chase view, edge lines and armco."
	],
}
const REFERENCE_DIR = "res://docs/art/reference/"

var failures = []
var folder = "user://track-shots"
var compare = false


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg == "--compare":
			compare = true
	call_deferred("run")


## [track, shot, station (a corner name plus metres, or metres from the start), camera (optional)].
func shots() -> Array:
	return [
		["proving_ground", "pg-start", -45.0],
		["proving_ground", "pg-turn1", 200.0],
		["proving_ground", "pg-back-straight", 550.0],
		["proving_ground", "pg-turn2", 850.0],
		["proving_ground", "pg-turn3", 1300.0],
		["proving_ground", "pg-chicane-entry", 1650.0],
		["proving_ground", "pg-chicane-apex", 1750.0, CAM_BONNET],
		["proving_ground", "pg-turn4", 2150.0],
		["proving_ground", "pg-final-straight", 2400.0],
		["spa", "spa-pit-straight", -160.0],
		["spa", "spa-la-source", ["La Source", -130.0]],
		["spa", "spa-eau-rouge", ["Eau Rouge", -150.0]],
		["spa", "spa-raidillon", ["Raidillon", -40.0]],
		["spa", "spa-kemmel", ["Raidillon", 520.0]],
		["spa", "spa-les-combes", ["Les Combes", -150.0]],
		["spa", "spa-pouhon", ["Pouhon", -160.0]],
		["spa", "spa-blanchimont", ["Blanchimont", -150.0]],
		["spa", "spa-bus-stop", ["Bus Stop", -150.0]],
		["nordschleife_s1", "ns-start", -70.0],
		["nordschleife_s1", "ns-hatzenbach", ["Hatzenbach 2", -80.0]],
		["nordschleife_s1", "ns-hatzenbach-bonnet", ["Hatzenbach 2", -80.0], CAM_BONNET],
		["nordschleife_s1", "ns-hocheichen", ["Hocheichen", -120.0]],
		["nordschleife_s1", "ns-flugplatz", ["Flugplatz", -150.0]],
		["nordschleife_s1", "ns-schwedenkreuz", ["Schwedenkreuz", -150.0]],
		["nordschleife_s1", "ns-aremberg", ["Aremberg", -120.0]],
		["nordschleife", "ns-full-adenauer-forst", ["Adenauer Forst", -100.0]],
		["nordschleife", "ns-full-bergwerk", ["Bergwerk", -120.0]],
		["nordschleife", "ns-full-karussell", ["Karussell", -80.0]],
		["nordschleife", "ns-full-bruennchen", ["Bruennchen", -100.0]],
		["nordschleife", "ns-full-pflanzgarten", ["Pflanzgarten", -100.0]],
		["nordschleife", "ns-full-doettinger-hoehe", ["Doettinger Hoehe", -150.0]],
	]


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	app.settings.time_of_day = 0
	app.apply_time_of_day()
	var helper = NightShots.new()
	var loaded = ""
	for shot in shots():
		if shot[0] != loaded:
			if not app.load_v2_track(shot[0]):
				failures.append("load " + shot[0])
				continue
			loaded = shot[0]
			app.start_v2_drive()
		helper.pose(app, helper.station(app.track, shot[2]), false)
		app.settings.camera = shot[3] if shot.size() > 3 else CAM_CHASE
		app.update_camera(1.0, true)
		for i in 10:
			await process_frame
		var path = folder + "/" + shot[1] + ".png"
		var image = root.get_texture().get_image()
		if image.save_png(path) != OK:
			failures.append("save " + path)
		print("TRACK SHOT ", ProjectSettings.globalize_path(path))
		print(
			"TRACK SHOT DRAWS ",
			shot[1],
			" ",
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		)
		if compare and REFERENCE_MAP.has(shot[1]):
			await write_compare(shot[1], image)
	app.queue_free()
	await process_frame
	print("TRACK SHOTS RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


## Ours (left) vs. the reference frame (right), each captioned, side by side.
func write_compare(shot_id: String, ours: Image) -> void:
	var ref_file = REFERENCE_MAP[shot_id][0]
	var ref_path = REFERENCE_DIR + ref_file
	var ref_bytes = FileAccess.get_file_as_bytes(ref_path)
	if ref_bytes.is_empty():
		failures.append("compare reference missing " + ref_path)
		return
	var ref_image = Image.new()
	var err = ref_image.load_jpg_from_buffer(ref_bytes)
	if err != OK:
		err = ref_image.load_png_from_buffer(ref_bytes)
	if err != OK:
		failures.append("compare reference decode " + ref_path)
		return

	var pane_w = 640
	var pane_h = 480
	var label_h = 36
	var sub = SubViewport.new()
	sub.size = Vector2i(pane_w * 2, pane_h + label_h)
	sub.transparent_bg = false
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.09)
	bg.size = sub.size
	sub.add_child(bg)

	var row = HBoxContainer.new()
	row.size = sub.size
	row.add_theme_constant_override("separation", 0)
	sub.add_child(row)
	_compare_pane(row, "ours: " + shot_id, ours, pane_w, pane_h, label_h)
	_compare_pane(row, "ref: " + ref_file, ref_image, pane_w, pane_h, label_h)

	for i in 3:
		await process_frame
	var out_path = folder + "/" + shot_id + "-compare.png"
	if sub.get_texture().get_image().save_png(out_path) != OK:
		failures.append("save " + out_path)
	print("TRACK SHOT COMPARE ", ProjectSettings.globalize_path(out_path))
	sub.queue_free()


func _compare_pane(
	row: HBoxContainer, caption: String, image: Image, pane_w: int, pane_h: int, label_h: int
) -> void:
	var pane = VBoxContainer.new()
	pane.custom_minimum_size = Vector2(pane_w, pane_h + label_h)
	pane.add_theme_constant_override("separation", 0)
	row.add_child(pane)
	var label = Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(pane_w, label_h)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 18)
	pane.add_child(label)
	var tex = TextureRect.new()
	tex.texture = ImageTexture.create_from_image(image)
	tex.custom_minimum_size = Vector2(pane_w, pane_h)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	pane.add_child(tex)
