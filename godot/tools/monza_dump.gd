extends SceneTree
## Dumps Monza model surface vertices (x, y, z; every 7th) per material to user://monza-verts.json.
func _initialize():
	var src: Node3D = load("res://assets/tracks/monza/monza.glb").instantiate()
	root.add_child(src)
	var out = {}
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var xf = mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(s)
			var name = mat.resource_name if mat else "none"
			var v = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if not out.has(name):
				out[name] = []
			for i in range(0, v.size(), 7):
				var p = xf * v[i]
				out[name].append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
	var f = FileAccess.open("user://monza-verts.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	for k in out:
		print(k, " ", out[k].size())
	quit()
