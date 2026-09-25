extends SceneTree
## Run the editor binary with --main-pack <exported .pck> --script <absolute script> -- --v2-flow-test.
## Loads only packaged game resources; the test script itself stays outside the export.
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
	var wheel = app.track.get_node("Scenery/CentennialWheel").mesh.surface_get_material(0)
	var flood = app.track.get_node("Scenery/PlazaFlood1")
	for night in [true, false, true]:
		app.settings.time_of_day = 1 if night else 0
		app.apply_time_of_day()
		for i in 10:
			await process_frame
		if wheel.emission_enabled != night or flood.visible != night:
			failures.append("Exported Afterhours toggle %s" % night)
	var path = "user://native-tests/chicago-export-night.png"
	if root.get_texture().get_image().save_png(path) != OK:
		failures.append("Exported night capture")
	print("CHICAGO EXPORT NIGHT RESULTS ", JSON.stringify({"checks": 4, "failures": failures}))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
