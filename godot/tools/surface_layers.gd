extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("monza")
	await physics_frame
	var space = app.track.get_world_3d().direct_space_state
	var c: Curve3D = app.track.get_node("TimingLine").curve
	for s in [7.0, 20.0, 700.0]:
		var p = c.sample_baked(s)
		var q = c.sample_baked(s + 1.0)
		var side = (q - p).cross(Vector3.UP).normalized()
		var line = "s=%.0f:" % s
		for k in [-4, -3, -2, 0, 2]:
			var o = p + side * k
			var ex = []
			var hits = []
			for n in 4:
				var rq = PhysicsRayQueryParameters3D.create(o + Vector3(0, 8, 0), o - Vector3(0, 8, 0))
				rq.hit_back_faces = true
				rq.exclude = ex
				var r = space.intersect_ray(rq)
				if r.is_empty():
					break
				hits.append("%s%.2f" % [String(r.collider.name).substr(0, 9), r.position.y])
				ex.append(r.rid)
			line += " k%d[%s]" % [k, ",".join(hits)]
		print("LAYERS ", line)
	quit()
