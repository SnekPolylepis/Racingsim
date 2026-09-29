extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.load_v2_track("monza")
	var slot = app.track.grid_slots()[0]
	print("slot ", slot.origin)
	for b in app.track.get_node("Surfaces").get_children():
		var cs = b.get_child(0)
		var f = cs.shape.get_faces()
		var bb = AABB(f[0], Vector3.ZERO)
		for i in range(0, f.size(), 50):
			bb = bb.expand(f[i])
		print(b.name, " aabb=", bb.position, " .. ", bb.end, " layer=", b.collision_layer, " faces=", cs.shape.get_faces().size() / 3, " sid=", b.get_meta("surface", -1), " inside_tree=", b.is_inside_tree())
	await physics_frame
	var space = app.track.get_world_3d().direct_space_state
	for dy in [5.0, 50.0, 300.0]:
		var q = PhysicsRayQueryParameters3D.create(slot.origin + Vector3(0, dy, 0), slot.origin - Vector3(0, 400, 0))
		var r = space.intersect_ray(q)
		print("ray from +", dy, " -> ", r.get("position", "none"), " ", r.get("collider", null))
	quit()
