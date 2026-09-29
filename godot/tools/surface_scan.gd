extends SceneTree
## Samples TrackSurface.contact on a lateral grid along the lap line (1 m along, 1 m across, +-6 m) and
## reports holes, height steps > 5 cm between neighbours, and normals tilted > 12 deg.
## Run: tools/Godot.exe --headless --path . --script tools/surface_scan.gd -- --v2-flow-test --track=monza
func _initialize():
	call_deferred("run")
func run():
	var id = "monza"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--track="):
			id = a.trim_prefix("--track=")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track(id)
	await physics_frame
	var surf = app.track.surface()
	var c: Curve3D = app.track.get_node("TimingLine").curve
	var L = c.get_baked_length()
	var holes = 0
	var steps = 0
	var tilts = 0
	var by_sid = {}
	var worst = []
	var s = 0.0
	while s < L:
		var p = c.sample_baked(s)
		var q = c.sample_baked(fmod(s + 1.0, L))
		var side = (q - p).cross(Vector3.UP).normalized()
		var prev = null
		for k in range(-6, 7):
			var o = p + side * k + Vector3(0, 6, 0)
			var r = surf.contact(o, Vector3.DOWN, 20.0)
			if r.is_empty():
				holes += 1
				if holes % 60 == 1:
					print("SCAN HOLEAT %.1f %.1f %.1f" % [o.x, o.y - 6, o.z])
				prev = null
				continue
			by_sid[r.surface] = by_sid.get(r.surface, 0) + 1
			if r.normal.angle_to(Vector3.UP) > deg_to_rad(12):
				tilts += 1
			if prev != null and absf(r.point.y - prev) > 0.05:
				steps += 1
				if worst.size() < 12 and absf(r.point.y - prev) > 0.3:
					worst.append("s=%.0f k=%d dy=%.2f sid=%d" % [s, k, r.point.y - prev, r.surface])
			prev = r.point.y
		s += 1.0
	print("SCAN %s len=%.0f holes=%d steps>5cm=%d tilt>12deg=%d surfaces=%s" % [id, L, holes, steps, tilts, by_sid])
	for w in worst:
		print("SCAN worst ", w)
	quit()
