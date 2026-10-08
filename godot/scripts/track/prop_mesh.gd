extends RefCounted
## One ArrayMesh from an imported prop scene (ASSET-02): every MeshInstance3D's surfaces, with their materials,
## in the scene's own frame. Cached per path, so MultiMeshes of the same prop share one mesh.

## Custom-channel layout bits that must accompany CUSTOMn arrays when re-adding a surface.
const CUSTOM_FORMATS = ((1 << (Mesh.ARRAY_FORMAT_CUSTOM_BITS * 4)) - 1) << Mesh.ARRAY_FORMAT_CUSTOM_BASE

static var _cache = {}


static func mesh(path: String) -> ArrayMesh:
	if _cache.has(path):
		return _cache[path]
	var root: Node = load(path).instantiate()
	# Merging through SurfaceTool drops the import's LODs, so they are regenerated on the merged surfaces.
	var merged = ImporterMesh.new()
	for part in root.find_children("*", "MeshInstance3D", true, false):
		var xf = Transform3D.IDENTITY
		var node: Node = part
		while node != root:
			xf = node.transform * xf
			node = node.get_parent()
		for s in part.mesh.get_surface_count():
			var st = SurfaceTool.new()
			st.append_from(part.mesh, s, xf)
			st.index()
			var mat = part.get_surface_override_material(s)
			merged.add_surface(
				Mesh.PRIMITIVE_TRIANGLES,
				st.commit_to_arrays(),
				[],
				{},
				mat if mat else part.mesh.surface_get_material(s),
				"",
				part.mesh.surface_get_format(s) & CUSTOM_FORMATS
			)
	root.free()
	merged.generate_lods(25.0, 60.0, [])
	var out = merged.get_mesh()
	_cache[path] = out
	return out
