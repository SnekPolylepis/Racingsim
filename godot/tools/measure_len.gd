extends SceneTree
func _initialize():
	var G = preload("res://scripts/cars/glb_car.gd").new()
	for path in OS.get_cmdline_user_args():
		var src = load(path).instantiate()
		var box = AABB()
		var first = true
		for m in src.find_children("*", "MeshInstance3D", true, false):
			var a = G._to_root(src, m) * m.get_aabb()
			box = a if first else box.merge(a)
			first = false
		print(path, " size=", box.size)
	quit()
