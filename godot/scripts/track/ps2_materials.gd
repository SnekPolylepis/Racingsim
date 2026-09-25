extends RefCounted
## PS2-era surface materials for TrackAssets (owner's art direction: a 2003-2006 console look between
## NFS Underground and Gran Turismo 4; docs/ART-DIRECTION.md). Reuses the legacy circuit's shaders and
## the palette-reduced texture set in assets/ps2 (falling back to the source textures), so the new
## circuits read like the old game's. Materials are cached and shared; `set_afterhours()` switches
## every road to its amber night variant.
const ROAD_SHADER = preload("res://shaders/road_v2.gdshader")
const GROUND_SHADER = preload("res://shaders/ground.gdshader")
const TEX = "res://assets/textures/"
const HD = "res://assets/textures_hd/"
## SURF ids (scripts/surface/surface_table.gd): 0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff.
const TARMAC = 0
const GRASS = 2
const GRAVEL = 3
const RUNOFF = 4

static var cache = {}


static func tex(name: String, kind: String) -> Texture2D:
	var palette_path = "res://assets/ps2/" + name + "_" + kind + ".png"
	if ResourceLoader.exists(palette_path):
		return load(palette_path)
	return load(TEX + name + "/" + name + "_" + kind + ".jpg")


## The material for a road-tool surface id, or null to keep the builder's own (kerbs).
static func surface(sid: int) -> Material:
	if cache.has(sid):
		return cache[sid]
	var mat = null
	match sid:
		TARMAC:
			mat = ShaderMaterial.new()
			mat.shader = ROAD_SHADER
			# Look-8: the 2K photographic asphalt set (ART-DIRECTION.md "Road"), not the 256 px palette tile.
			mat.set_shader_parameter("albedo_tex", load(HD + "asphalt_pit_lane/asphalt_pit_lane_diff.jpg"))
			mat.set_shader_parameter("rough_tex", load(HD + "asphalt_pit_lane/asphalt_pit_lane_rough.jpg"))
			mat.set_shader_parameter("normal_tex", load(HD + "asphalt_pit_lane/asphalt_pit_lane_nor_gl.jpg"))
		GRASS, GRAVEL, RUNOFF:
			mat = ground(sid)
	cache[sid] = mat
	return mat


## The legacy ground shader with a constant paint mask: red selects gravel, green tarmac runoff, black
## grass. It projects its textures from world position, so any mesh can use it.
static func ground(sid: int) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	for kind in [["grass", "grass_ground"], ["gravel", "gravel_floor"], ["runoff", "asphalt_track"]]:
		mat.set_shader_parameter(kind[0] + "_albedo", tex(kind[1], "diff"))
		mat.set_shader_parameter(kind[0] + "_normal", tex(kind[1], "nor_gl"))
		mat.set_shader_parameter(kind[0] + "_rough", tex(kind[1], "rough"))
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.set_pixel(
		0, 0, Color(1, 0, 0) if sid == GRAVEL else (Color(0, 1, 0) if sid == RUNOFF else Color(0, 0, 0))
	)
	mat.set_shader_parameter("paint_mask", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("mask_origin", Vector2(-1e6, -1e6))
	mat.set_shader_parameter("mask_size", Vector2(2e6, 2e6))
	return mat


## Amber night variant of every road (the lamp streaks in road_v2.gdshader): the shared material, and
## each road_v2 material under `root`. A TrackAsset loaded from the user://tracks3d cache, or one with
## its own lamp streaks (track_lights.gd), carries its own copy of the material.
static func set_afterhours(on: bool, root: Node = null) -> void:
	var road = surface(TARMAC)
	if road is ShaderMaterial:
		road.set_shader_parameter("afterhours", on)
	var group = root.get_node_or_null("Road") if root != null else null
	if group == null:
		return
	for node in group.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is ShaderMaterial and mat.shader == ROAD_SHADER:
				mat.set_shader_parameter("afterhours", on)
