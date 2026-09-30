extends SceneTree
func _initialize():
	var G = preload("res://scripts/cars/glb_car.gd").new()
	for path in OS.get_cmdline_user_args():
		var src = load(path).instantiate()
		var c = []
		for key in G.KEYS:
			var w = G._find_wheel(src, key)
			var box = AABB()
			for m in w.find_children("*", "MeshInstance3D", true, false):
				box = box.merge(G._to_root(src, m) * m.get_aabb()) if box.size != Vector3.ZERO else G._to_root(src, m) * m.get_aabb()
			c.append(box)
		var wb = ((c[0].get_center() + c[1].get_center()) * .5).distance_to((c[2].get_center() + c[3].get_center()) * .5)
		print(path, " wheelbase=%.3f trackF=%.3f trackR=%.3f rF=%.3f rR=%.3f" % [wb, c[0].get_center().distance_to(c[1].get_center()), c[2].get_center().distance_to(c[3].get_center()), c[0].size[c[0].size.max_axis_index()] * .5, c[2].size[c[2].size.max_axis_index()] * .5])
	quit()
