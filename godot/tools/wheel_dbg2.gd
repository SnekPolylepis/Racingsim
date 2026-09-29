extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var p = app.presets["f2004"]
	var m = app.visuals.make_car(p)
	root.add_child(m.root)
	await process_frame
	for i in 4:
		var spin = m.spins[i]
		var meshes = spin.find_children("*", "MeshInstance3D", true, false)
		var g = meshes[0].global_transform * meshes[0].get_aabb() if meshes.size() else AABB()
		print("W", i, " pivot=", m.pivots[i].global_position, " spin kids=", spin.get_child_count(), " meshes=", meshes.size(), " aabb_c=", g.get_center(), " size=", g.size)
	quit()
