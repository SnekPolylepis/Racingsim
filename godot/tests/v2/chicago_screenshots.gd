extends SceneTree
## Windowed visual acceptance through the game renderer. Isolated settings via --v2-flow-test.
## Run with -- --v2-flow-test --v2-track=chicago. Captures driving views plus landmark sightlines.
const Generator = preload("res://trackgen/chicago.gd")
const NightShots = preload("res://tests/v2/night_screenshots.gd")
const FOLDER = "res://docs/rebuild/screenshots/chicago-night-refined"
var failures = []


func _initialize():
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.load_v2_track("chicago"):
		quit(1)
		return
	app.start_v2_drive()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var helper = NightShots.new()
	var views = [
		["michigan-bean", [41.8830, -87.6244, 8], "Bean"],
		["lake-shore", [41.8801, -87.6173, 8], ""],
		["navy-pier", [41.8862, -87.6139, 13], "Navy Pier"],
		["lower-wacker", [41.88792, -87.6207, 0], ""],
		["willis-tower", [41.8785, -87.6369, 8], "Willis Tower"],
		["upper-river", [41.8869, -87.6320, 8], "Chicago River"],
	]
	for night in [false, true]:
		app.settings.time_of_day = 1 if night else 0
		app.apply_time_of_day()
		for view in views:
			var p = Generator.world(view[1])
			var s = app.track.project(p, -1).s
			helper.pose(app, s, night)
			app.settings.camera = 2 if view[0] == "lower-wacker" else 0
			app.update_camera(1.0, true)
			# First save the normal driving view, no artificially repositioned landmark.
			await capture(view[0] + ("-night" if night else "-day"))
			if view[2] != "":
				# A head turn from driver's position documents side sightlines where needed.
				var target = Generator.world(Generator.data().landmarks[view[2]])
				target.y += 5 if view[2] != "Willis Tower" else 115
				if view[2] == "Navy Pier":
					target.y += 25
				app.camera.look_at(target, Vector3.UP)
				await capture(view[0] + "-sightline" + ("-night" if night else "-day"))
	helper.free()
	app.queue_free()
	await process_frame
	print("CHICAGO SHOTS RESULTS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func capture(title):
	for i in 10:
		await process_frame
	var path = FOLDER + "/" + title + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		failures.append(path)
	print(
		"CHICAGO SHOT ",
		title,
		" draws=",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	)
