extends RefCounted
## One ArrayMesh from an imported prop scene (ASSET-02): every MeshInstance3D's surfaces, with their materials,
## in the scene's own frame. Cached per path, so MultiMeshes of the same prop share one mesh.

static var _cache = {}


static func mesh(path: String) -> ArrayMesh:
	if _cache.has(path):
		return _cache[path]
	var root: Node = load(path).instantiate()
	var out = ArrayMesh.new()
	for part in root.find_children("*", "MeshInstance3D", true, false):
		var xf = Transform3D.IDENTITY
		var node: Node = part
		while node != root:
			xf = node.transform * xf
			node = node.get_parent()
		for s in part.mesh.get_surface_count():
			var st = SurfaceTool.new()
			st.append_from(part.mesh, s, xf)
			st.commit(out)
			var mat = part.get_surface_override_material(s)
			out.surface_set_material(
				out.get_surface_count() - 1, mat if mat else part.mesh.surface_get_material(s)
			)
	root.free()
	_cache[path] = out
	return out
