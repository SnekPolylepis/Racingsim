extends RefCounted
## Finds and loads authored tracks (REBUILD-PLAN.md 5.3): godot/tracks3d/<id>/<id>.tscn (or .scn).
## Loading only reads, so it works from res:// in an exported build.

const ROOT = "res://tracks3d"


## [{id, path}] for every track folder that contains <id>.tscn or <id>.scn, sorted by id.
static func list(root = ROOT):
	var out = []
	var dir = DirAccess.open(root)
	if dir == null:
		return out
	for folder in dir.get_directories():
		for ext in ["tscn", "scn"]:
			var path = "%s/%s/%s.%s" % [root, folder, folder, ext]
			if ResourceLoader.exists(path):
				out.append({"id": folder, "path": path})
				break
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


## Instance and validate a track scene. Returns {asset, errors}; asset is null if it cannot be
## instanced as a TrackAsset. The caller adds the asset to the tree (needed for surface queries).
static func load_asset(path):
	var packed = ResourceLoader.load(path)
	if not (packed is PackedScene):
		return {"asset": null, "errors": ["%s is not a scene" % path]}
	var node = packed.instantiate()
	if not node.has_method("record_key"):
		node.free()
		return {"asset": null, "errors": ["%s root is not a TrackAsset" % path]}
	return {"asset": node, "errors": node.validate()}
