extends SceneTree
## Checks the L trains move: instance 0 position before/after 2 s.
func _initialize():
	call_deferred("run")
func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("chicago")
	var n = app.track.find_child("LTrains", true, false)
	for i in 5:
		await process_frame
	var a = n.multimesh.get_instance_transform(0).origin
	for i in 120:
		await process_frame
	var b = n.multimesh.get_instance_transform(0).origin
	print("LTRAINS trains=%d cars=%d moved=%.1f m" % [n.trains.size(), n.multimesh.instance_count, a.distance_to(b)])
	quit(0)
