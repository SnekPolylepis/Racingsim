extends SceneTree
## Visual review of a track's graphics, kept apart from the physics and drivability gates: this suite never
## judges handling, lap times or collision, only what the scenery looks like. Run windowed (never --headless),
## usually through tools/visual_review.ps1:
##   tools/Godot.exe --path . --script tests/visual/track_review.gd -- --v2-flow-test
##       [--tracks=spa,nordschleife] [--out=<run dir>] [--baseline=<previous run dir>] [--night] [--bonnet]
## For every track it poses the car and captures:
##   - each corner three times: approach (-120 m), apex, exit (+80 m);
##   - the middle of every straight (a gap of more than 300 m between corners), plus more frames every 400 m on
##     long ones;
##   - every scenic spot in SCENIC below.
## It writes <run>/<track>/<NNN-kind-name>.png, a contact sheet <run>/<track>-sheet.png, and <run>/manifest.json.
## With --baseline it also writes <shot>-diff.png (the baseline on the left, this run on the right) and scores each
## shot's change (mean absolute RGB difference, 0-255) so a graphics change can be judged shot by shot.
## Prints VISUAL REVIEW RESULTS. Failures are only load or save errors.

const NightShots = preload("res://tests/v2/night_screenshots.gd")

const DEFAULT_TRACKS = ["proving_ground", "spa", "nordschleife_s1", "nordschleife"]
const APPROACH_M = -120.0
const EXIT_M = 80.0
const STRAIGHT_MIN_M = 300.0
const STRAIGHT_STEP_M = 400.0
const CAM_CHASE = 0
const CAM_BONNET = 2
## Scenic spots per track: [name, station]. A station is metres from the start, or [corner name, offset].
const SCENIC = {
	"spa": [["eau-rouge-valley", ["Eau Rouge", 40.0]], ["kemmel-crest", ["Raidillon", 250.0]]],
	"nordschleife_s1": [["flugplatz-crest", ["Flugplatz", -20.0]]],
	"nordschleife":
	[
		["flugplatz-crest", ["Flugplatz", -20.0]],
		["karussell-bowl", ["Karussell", 20.0]],
		["pflanzgarten-jump", ["Pflanzgarten", -30.0]],
		["doettinger-hoehe-long", ["Doettinger Hoehe", 400.0]],
	],
}
## A difference score above this is flagged "changed" in the manifest and the log.
const CHANGED_SCORE = 6.0
const SHEET_THUMB = Vector2i(320, 200)
const SHEET_COLUMNS = 6
const DIFF_SIZE = Vector2i(160, 100)

var failures = []
var tracks = DEFAULT_TRACKS.duplicate()
var folder = "user://visual-review/latest"
var baseline = ""
var night = false
var bonnet = false


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tracks="):
			tracks = Array(arg.trim_prefix("--tracks=").split(",", false))
		elif arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
		elif arg.begins_with("--baseline="):
			baseline = arg.trim_prefix("--baseline=")
		elif arg == "--night":
			night = true
		elif arg == "--bonnet":
			bonnet = true
	call_deferred("run")


## [kind, name, station in metres] for every frame on `track`, in lap order.
func plan(track, id: String) -> Array:
	var helper = NightShots.new()
	var corners = []
	var meta: Dictionary = track.get_meta("corners", {})
	for key in meta:
		corners.append([String(key), float(meta[key])])
	corners.sort_custom(func(a, b): return a[1] < b[1])
	var out = []
	for c in corners:
		var slug = c[0].to_lower().replace(" ", "-")
		# A named exit ("Bus Stop exit") is already framed by its corner's exit shot: one frame is enough.
		if slug.ends_with("-exit"):
			out.append(["corner", slug, fposmod(c[1], track.length)])
			continue
		out.append(["corner", slug + "-approach", fposmod(c[1] + APPROACH_M, track.length)])
		out.append(["corner", slug + "-apex", fposmod(c[1], track.length)])
		out.append(["corner", slug + "-exit", fposmod(c[1] + EXIT_M, track.length)])
	# Straights: the gaps between one corner's exit and the next corner's approach (wrapping on closed laps).
	var n = corners.size()
	for i in n:
		var from_s = corners[i][1] + EXIT_M
		var to_s = corners[(i + 1) % n][1] + APPROACH_M
		if i == n - 1:
			to_s += track.length
		var gap = to_s - from_s
		if gap < STRAIGHT_MIN_M:
			continue
		var steps = maxi(1, int(gap / STRAIGHT_STEP_M))
		for k in steps:
			var s = from_s + gap * (k + 0.5) / steps
			var label = "after-%s-%d" % [corners[i][0].to_lower().replace(" ", "-"), k + 1]
			out.append(["straight", label, fposmod(s, track.length)])
	if corners.is_empty():
		var s = 0.0
		while s < track.length:
			out.append(["straight", "station-%05d" % int(s), s])
			s += STRAIGHT_STEP_M
	for spot in SCENIC.get(id, []):
		out.append(["scenic", spot[0], helper.station(track, spot[1])])
	out.sort_custom(func(a, b): return a[2] < b[2])
	return out


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	app.settings.time_of_day = 1 if night else 0
	app.apply_time_of_day()
	var helper = NightShots.new()
	var manifest = {"night": night, "bonnet": bonnet, "baseline": baseline, "tracks": {}}
	for id in tracks:
		if not app.load_v2_track(id):
			failures.append("load " + id)
			continue
		app.start_v2_drive()
		var dir = folder + "/" + id
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var shots = []
		var thumbs = []
		var index = 0
		for item in plan(app.track, id):
			helper.pose(app, item[2], night)
			app.settings.camera = CAM_BONNET if bonnet else CAM_CHASE
			app.update_camera(1.0, true)
			for i in 10:
				await process_frame
			var image = root.get_texture().get_image()
			var file = "%03d-%s-%s.png" % [index, item[0], item[1]]
			index += 1
			if image.save_png(dir + "/" + file) != OK:
				failures.append("save " + dir + "/" + file)
			var entry = {"file": file, "kind": item[0], "name": item[1], "station": snappedf(item[2], 0.1)}
			var before = _baseline_image(id, file)
			if before:
				entry.score = snappedf(_score(before, image), 0.01)
				entry.changed = entry.score > CHANGED_SCORE
				_save_diff(before, image, dir + "/" + file.trim_suffix(".png") + "-diff.png")
			shots.append(entry)
			var thumb = image.duplicate()
			thumb.resize(SHEET_THUMB.x, SHEET_THUMB.y, Image.INTERPOLATE_BILINEAR)
			thumbs.append(thumb)
			print("VISUAL SHOT ", id, " ", file, " ", entry.get("score", "-"))
		_save_sheet(thumbs, folder + "/" + id + "-sheet.png")
		manifest.tracks[id] = {"length": app.track.length, "shots": shots}
	var f = FileAccess.open(folder + "/manifest.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()
	app.queue_free()
	await process_frame
	print("VISUAL REVIEW DIR ", ProjectSettings.globalize_path(folder))
	print("VISUAL REVIEW RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _baseline_image(id: String, file: String) -> Image:
	if baseline.is_empty():
		return null
	var path = baseline + "/" + id + "/" + file
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


## Mean absolute RGB difference on a small downscale (0-255): robust to single-pixel shimmer.
func _score(a: Image, b: Image) -> float:
	var x = a.duplicate()
	var y = b.duplicate()
	x.convert(Image.FORMAT_RGB8)
	y.convert(Image.FORMAT_RGB8)
	x.resize(DIFF_SIZE.x, DIFF_SIZE.y, Image.INTERPOLATE_BILINEAR)
	y.resize(DIFF_SIZE.x, DIFF_SIZE.y, Image.INTERPOLATE_BILINEAR)
	var da = x.get_data()
	var db = y.get_data()
	var total = 0
	for i in da.size():
		total += absi(da[i] - db[i])
	return float(total) / da.size()


## Baseline (left) and this run (right) at half size, side by side.
func _save_diff(before: Image, after: Image, path: String) -> void:
	var w = after.get_width() / 2
	var h = after.get_height() / 2
	var a = before.duplicate()
	var b = after.duplicate()
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	a.resize(w, h, Image.INTERPOLATE_BILINEAR)
	b.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var out = Image.create(w * 2, h, false, Image.FORMAT_RGB8)
	out.blit_rect(a, Rect2i(0, 0, w, h), Vector2i(0, 0))
	out.blit_rect(b, Rect2i(0, 0, w, h), Vector2i(w, 0))
	if out.save_png(path) != OK:
		failures.append("save " + path)


func _save_sheet(thumbs: Array, path: String) -> void:
	if thumbs.is_empty():
		return
	var rows = int(ceil(thumbs.size() / float(SHEET_COLUMNS)))
	var sheet = Image.create(SHEET_THUMB.x * SHEET_COLUMNS, SHEET_THUMB.y * rows, false, Image.FORMAT_RGB8)
	for i in thumbs.size():
		var t: Image = thumbs[i]
		t.convert(Image.FORMAT_RGB8)
		var at = Vector2i((i % SHEET_COLUMNS) * SHEET_THUMB.x, (i / SHEET_COLUMNS) * SHEET_THUMB.y)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, SHEET_THUMB), at)
	if sheet.save_png(path) != OK:
		failures.append("save " + path)
