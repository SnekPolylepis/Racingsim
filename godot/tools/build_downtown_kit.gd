extends SceneTree
## Bakes selected pieces of the Quaternius Downtown City MegaKit (CC0) into compact meshes for Chicago
## (CHI-LOOK-02): one ArrayMesh per piece, surfaces merged per our own material, glTF materials dropped.
## Run once when the piece list changes; the outputs are committed.
##   tools/Godot.exe --headless --path . --script tools/build_downtown_kit.gd -- <kit "glTF (Godot)" dir>
const OUT = "res://assets/chicago/downtown-kit/"
const PIECES = [
	"Metal_FirstFloor_Window",
	"Metal_FirstFloor_Wall",
	"Trim_FirstFloor_Window_001",
	"Trim_FirstFloor_Wall",
	"Cornice_Brick_Center",
	"Cornice_Metal_Center",
	"Cornice_Trim_Center",
	"Door_1",
	"Prop_ACUnit",
	"Prop_Bollard",
	"Prop_Planter_Single"
]
## glTF material name -> [our key, albedo texture or "", colour, roughness, emission (night)]
const MAP = {
	"MI_Trim": ["trim", "trim", Color.WHITE, 0.85, false],
	"MI_Trim_MetalConcrete": ["metal", "metal", Color.WHITE, 0.85, false],
	"MI_RedBrick": ["brick", "brick", Color.WHITE, 0.9, false],
	"MI_RedBrick_Pale": ["brick", "brick", Color.WHITE, 0.9, false],
	"MI_Ornaments": ["ornament", "ornament", Color.WHITE, 0.8, false],
	"MI_Trim_Dark": ["dark", "", Color(0.2, 0.2, 0.21), 0.7, false],
	"MI_Trim_Green": ["green", "", Color(0.09, 0.27, 0.2), 0.7, false],
	"MI_Glass": ["glass", "", Color(0.24, 0.32, 0.42), 0.22, true],
	"MI_FakeInterior": ["interior", "", Color(0.32, 0.26, 0.2), 0.9, true],
	"MI_InteriorWall": ["interior", "", Color(0.32, 0.26, 0.2), 0.9, true],
	"MI_InteriorFloor": ["interior", "", Color(0.32, 0.26, 0.2), 0.9, true],
	"MI_Dirt": ["dirt", "", Color(0.24, 0.17, 0.12), 1.0, false],
	"MI_Concrete": ["metal", "metal", Color.WHITE, 0.85, false],
	"MI_Asphalt": ["dark", "", Color(0.2, 0.2, 0.21), 0.7, false],
}


func material_for(key: String) -> StandardMaterial3D:
	var path = OUT + "mat_%s.tres" % key
	var entry = null
	for name in MAP:
		if MAP[name][0] == key:
			entry = MAP[name]
			break
	var m = StandardMaterial3D.new()
	m.albedo_color = entry[2]
	if entry[1] != "":
		m.albedo_texture = load(OUT + "textures/%s.jpg" % entry[1])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = entry[3]
	# Some kit planes (glass, interiors) face into the building; draw both sides.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if entry[4]:
		m.emission = Color(1.0, 0.72, 0.4)
		# Glass is opaque, so it carries the shopfront glow itself after hours (dimmer than interiors).
		m.emission_energy_multiplier = 0.55 if key == "glass" else 0.9
		m.set_meta("chicago_night", true)
	ResourceSaver.save(m, path)
	return load(path)


func _initialize():
	var dir = OS.get_cmdline_user_args()[0]
	var mats = {}
	for piece in PIECES:
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		if doc.append_from_file(dir + "/" + piece + ".gltf", state) != OK:
			print("KIT FAIL ", piece)
			continue
		var root = doc.generate_scene(state)
		var tools = {}
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var xf = Transform3D.IDENTITY
			var node: Node3D = mi
			while node != null and node != root:
				xf = node.transform * xf
				node = node.get_parent() as Node3D
			for s in mi.mesh.get_surface_count():
				var src = mi.mesh.surface_get_material(s)
				var name = src.resource_name if src else "MI_Trim"
				name = name if MAP.has(name) else name.rstrip("0123456789_")
				var key = MAP[name][0] if MAP.has(name) else "trim"
				if not tools.has(key):
					var st = SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = st
				tools[key].append_from(mi.mesh, s, xf)
		var mesh = ArrayMesh.new()
		for key in tools:
			if not mats.has(key):
				mats[key] = material_for(key)
			tools[key].set_material(mats[key])
			tools[key].commit(mesh)
		ResourceSaver.save(mesh, OUT + "meshes/%s.res" % piece)
		print("KIT ", piece, " surfaces ", mesh.get_surface_count())
		root.free()
	quit()
