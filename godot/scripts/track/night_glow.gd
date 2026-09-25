extends RefCounted
## Shared facade material for trackside structures (Look-9, ART-DIRECTION.md "Nights"): pit_building.gd,
## grandstand.gd, gantry.gd and billboards.gd all use `facade_material()` instead of a plain
## StandardMaterial3D, so their baked vertex-coloured meshes gain a night glow for free. `set_night()`
## follows Ps2Materials.set_afterhours()'s pattern: each TrackAsset's scenery was baked offline into its
## own .scn, so materials aren't shared instances at runtime and have to be walked and toggled per track.

const NIGHT_GLOW_SHADER = preload("res://shaders/night_glow.gdshader")

static var cache: ShaderMaterial


## One shared material instance while building a single track (baked scenes will each embed their own
## serialized copy, same as Ps2Materials.surface()).
static func facade_material() -> ShaderMaterial:
	if cache == null:
		cache = ShaderMaterial.new()
		cache.shader = NIGHT_GLOW_SHADER
	return cache


static func set_night(root: Node, on: bool) -> void:
	if cache != null:
		cache.set_shader_parameter("afterhours", on)
	var group = root.get_node_or_null("Scenery") if root != null else null
	if group == null:
		return
	# MeshInstance3D (pit building, grandstand, gantry) and MultiMeshInstance3D (billboards) both keep
	# their material on a Mesh resource; walk both node types.
	for node in group.find_children("*", "MeshInstance3D", true, false):
		_set_mesh(node.mesh, on)
	for node in group.find_children("*", "MultiMeshInstance3D", true, false):
		_set_mesh(node.multimesh.mesh if node.multimesh else null, on)


static func _set_mesh(mesh: Mesh, on: bool) -> void:
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var mat = mesh.surface_get_material(i)
		if mat is ShaderMaterial and mat.shader == NIGHT_GLOW_SHADER:
			mat.set_shader_parameter("afterhours", on)
