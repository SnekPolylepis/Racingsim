extends SceneTree
## Renders CC0 Poly Haven tree models (glTF, 1k textures) to alpha cut-out cards for RoadScatter.
## Not part of the game or of the export: run once, windowed, when the cards change.
##   tools/Godot.exe --path . --script tools/bake_tree_cards.gd -- <model_dir> <out_dir> [px_height]
## <model_dir> holds one folder per model (<name>/<name>.gltf). Writes <out_dir>/<name>_raw.png and
## <name>.json (world size in metres). tools/finish_tree_cards.py crops, bleeds the colour into the
## transparent border and packs the final PNGs. The downloads themselves are never committed.

const MODELS = ["fir_tree_01", "fir_sapling_medium", "tree_small_02", "shrub_02"]


func _init():
	var args = OS.get_cmdline_user_args()
	var src = args[0]
	var dst = args[1]
	var px = int(args[2]) if args.size() > 2 else 1024
	DirAccess.make_dir_recursive_absolute(dst)
	for m in MODELS:
		await _render(src, dst, m, px)
	quit()


func _render(src, dst, name, px):
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file("%s/%s/%s.gltf" % [src, name, name], state)
	if err != OK:
		push_error("load failed %s %d" % [name, err])
		return
	var model = doc.generate_scene(state)
	var vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(model)
	# bounds after the tree is built
	var box = [null]
	_walk(model, Transform3D.IDENTITY, box)
	var aabb: AABB = box[0]
	var w_m = maxf(aabb.size.x, aabb.size.z)
	var h_m = aabb.size.y
	var scale_px = float(px) / maxf(h_m, w_m * 0.5)
	var wpx = clampi(int(ceil(w_m * scale_px)), 64, 2048)
	var hpx = clampi(int(ceil(h_m * scale_px)), 64, 2048)
	vp.size = Vector2i(wpx, hpx)
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 25, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = h_m
	cam.near = 0.05
	cam.far = 400.0
	var centre = aabb.get_center()
	cam.position = Vector3(centre.x, centre.y, centre.z + maxf(w_m, h_m) * 2.0 + 10.0)
	vp.add_child(cam)
	cam.current = true
	for i in 6:
		await process_frame
	var img = vp.get_texture().get_image()
	img.save_png("%s/%s_raw.png" % [dst, name])
	var f = FileAccess.open("%s/%s.json" % [dst, name], FileAccess.WRITE)
	f.store_string(JSON.stringify({"height_m": h_m, "width_m": w_m, "px": [wpx, hpx]}))
	f.close()
	print(name, " ", aabb.size, " -> ", wpx, "x", hpx)
	vp.queue_free()
	await process_frame


func _walk(node: Node, xf: Transform3D, out: Array):
	var t = xf
	if node is Node3D:
		t = xf * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var b = t * node.mesh.get_aabb()
		out[0] = b if out[0] == null else out[0].merge(b)
	for c in node.get_children():
		_walk(c, t, out)
