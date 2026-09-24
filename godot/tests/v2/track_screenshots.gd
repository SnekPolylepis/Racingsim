extends SceneTree
## Daylight review captures of Spa and the Nordschleife through the real presentation chain (the default
## 640x448 Authentic look), HUD hidden, chase camera. Run windowed (never --headless), with the
## flow-test flag so the user's settings file is untouched:
##   tools/Godot.exe --path . --script tests/v2/track_screenshots.gd -- --v2-flow-test [--out=<dir>]
## Writes <dir>/<shot>.png (default user://track-shots) and prints TRACK SHOTS RESULTS.

const NightShots = preload("res://tests/v2/night_screenshots.gd")

var failures = []
var folder = "user://track-shots"


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			folder = arg.trim_prefix("--out=")
	call_deferred("run")


## [track, shot, station (a corner name plus metres, or metres from the start)].
func shots() -> Array:
	return [
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
		["nordschleife_s1", "ns-hocheichen", ["Hocheichen", -120.0]],
		["nordschleife_s1", "ns-flugplatz", ["Flugplatz", -150.0]],
		["nordschleife_s1", "ns-schwedenkreuz", ["Schwedenkreuz", -150.0]],
		["nordschleife_s1", "ns-aremberg", ["Aremberg", -120.0]],
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
		for i in 10:
			await process_frame
		var path = folder + "/" + shot[1] + ".png"
		if root.get_texture().get_image().save_png(path) != OK:
			failures.append("save " + path)
		print("TRACK SHOT ", ProjectSettings.globalize_path(path))
	app.queue_free()
	await process_frame
	print("TRACK SHOTS RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
