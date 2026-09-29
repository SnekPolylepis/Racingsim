extends SceneTree
func _initialize():
	var G = preload("res://scripts/cars/glb_car.gd").new()
	var src = load("res://assets/cars/f2004/f2004.glb").instantiate()
	for key in G.KEYS:
		var w = G._find_wheel(src, key)
		var chain = []
		var n = w
		while n != null and n != src:
			chain.append("%s s=%s" % [n.name, (n.transform.basis.get_scale() if n is Node3D else "")])
			n = n.get_parent()
		print(key, " centre_root=", G._to_root(src, w) * G._centre(w), " centre_local=", G._centre(w), " meshes=", w.find_children("*", "MeshInstance3D", true, false).size(), " chain=", chain)
	quit()
