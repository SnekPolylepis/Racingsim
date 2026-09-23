extends RefCounted
## Builds the ground for one circuit: a heightfield terrain that follows the track and rolls into
## hills away from it, textured road/verge/curb meshes, the gravel paint mask and trackside dressing
## (armco, tire walls, advertising boards, grandstands, marshal posts). Presentation only: physics
## still reads Track (surfaces, road plane) and Track.barriers (collision).
const TrackModel = preload("res://scripts/track3d.gd")
const ROAD_SHADER = preload("res://shaders/road.gdshader")
const GROUND_SHADER = preload("res://shaders/ground.gdshader")
const PAINT_SHADER = preload("res://shaders/painted.gdshader")
const TEX = "res://assets/textures/"
const VERGE = 9.0
var track
var origin = Vector2.ZERO
var cell = 8.0
var nx = 0
var ny = 0
var heights = PackedFloat32Array()
var low = 0.0
var extent = Rect2()
var margin = 360.0
var ground_material: ShaderMaterial
var road_material: ShaderMaterial
## Distance of each terrain vertex from the nearest centreline sample (after dilation), metres.
var dist = PackedFloat32Array()


static func tex(name, kind):
	var palette_path = "res://assets/ps2/" + name + "_" + kind + ".png"
	return (
		load(palette_path)
		if ResourceLoader.exists(palette_path)
		else load(TEX + name + "/" + name + "_" + kind + ".jpg")
	)


## Bilinear terrain height at world (x, y); outside the grid returns the base plane.
func height(x, y):
	var fx = (x - origin.x) / cell
	var fy = (y - origin.y) / cell
	var ix = clampi(floori(fx), 0, nx - 2)
	var iy = clampi(floori(fy), 0, ny - 2)
	var tx = clampf(fx - ix, 0, 1)
	var ty = clampf(fy - iy, 0, 1)
	var h00 = heights[iy * nx + ix]
	var h10 = heights[iy * nx + ix + 1]
	var h01 = heights[(iy + 1) * nx + ix]
	var h11 = heights[(iy + 1) * nx + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)


## Height of what is actually drawn at (x, y): road plane on the road, verge ribbon, then terrain.
func ground_height(x, y):
	var pr = track.project(x, y)
	var edge = absf(pr.lat) - pr.width / 2
	var road = track.elev_at(x, y).z
	if edge <= 0:
		return road
	if edge < VERGE:
		return lerpf(road - .05, height(x, y), smoothstep(2.5, VERGE, edge))
	return height(x, y)


func build(parent, t):
	track = t
	var S = track.samples
	var minx = INF
	var maxx = -INF
	var miny = INF
	var maxy = -INF
	low = INF
	for a in S:
		minx = minf(minx, a.x)
		maxx = maxf(maxx, a.x)
		miny = minf(miny, a.y)
		maxy = maxf(maxy, a.y)
		low = minf(low, a.z)
	extent = Rect2(minx, miny, maxx - minx, maxy - miny)
	build_heights()
	make_materials()
	build_terrain_mesh(parent)
	build_road(parent)
	build_barriers(parent)
	build_furniture(parent)
	build_landmarks(parent)


func build_heights():
	cell = maxf(8.0, maxf(extent.size.x, extent.size.y) / 240.0)
	origin = extent.position - Vector2(margin, margin)
	nx = int(ceil((extent.size.x + 2 * margin) / cell)) + 1
	ny = int(ceil((extent.size.y + 2 * margin) / cell)) + 1
	var count = nx * ny
	heights.resize(count)
	dist = PackedFloat32Array()
	dist.resize(count)
	dist.fill(1e9)
	var base = PackedFloat32Array()
	base.resize(count)
	var corridor = PackedByteArray()
	corridor.resize(count)
	var S = track.samples
	var reach = 60.0
	var r = int(ceil(reach / cell))
	for i in range(0, S.size(), 2):
		var sm = S[i]
		var cx = int((sm.x - origin.x) / cell)
		var cy = int((sm.y - origin.y) / cell)
		for gy in range(maxi(cy - r, 0), mini(cy + r + 1, ny)):
			for gx in range(maxi(cx - r, 0), mini(cx + r + 1, nx)):
				var px = origin.x + gx * cell
				var py = origin.y + gy * cell
				var dx = px - sm.x
				var dy = py - sm.y
				var d = sqrt(dx * dx + dy * dy)
				var k = gy * nx + gx
				if d < dist[k]:
					var lat = dx * sm.nx + dy * sm.ny
					dist[k] = d
					base[k] = (
						TrackModel
						. surface_point(sm, clampf(lat, -(sm.w / 2 + VERGE), sm.w / 2 + VERGE))
						. z
					)
					corridor[k] = 1 if d < sm.w / 2 + VERGE + .5 else 0
	# Dilate the track height outward so terrain far from the circuit still sits at local track level.
	# Two-pass chamfer sweep (forward then backward), O(cells).
	for gy in ny:
		for gx in nx:
			var k = gy * nx + gx
			if gx > 0 and dist[k - 1] + cell < dist[k]:
				dist[k] = dist[k - 1] + cell
				base[k] = base[k - 1]
			if gy > 0 and dist[k - nx] + cell < dist[k]:
				dist[k] = dist[k - nx] + cell
				base[k] = base[k - nx]
	for gy in range(ny - 1, -1, -1):
		for gx in range(nx - 1, -1, -1):
			var k = gy * nx + gx
			if gx < nx - 1 and dist[k + 1] + cell < dist[k]:
				dist[k] = dist[k + 1] + cell
				base[k] = base[k + 1]
			if gy < ny - 1 and dist[k + nx] + cell < dist[k]:
				dist[k] = dist[k + nx] + cell
				base[k] = base[k + nx]
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / 420
	noise.fractal_octaves = 4
	noise.seed = hash(str(track.data.get("name", "")))
	var detail = FastNoiseLite.new()
	detail.frequency = 1.0 / 60
	detail.seed = noise.seed + 7
	for k in count:
		var gx = k % nx
		var gy = k / nx
		var px = origin.x + gx * cell
		var py = origin.y + gy * cell
		var d = dist[k]
		var hills = (
			noise.get_noise_2d(px, py) * 26 * smoothstep(40, 280, d)
			+ maxf(0, noise.get_noise_2d(px * .5, py * .5)) * 30 * smoothstep(150, 420, d)
		)
		var h = base[k] + hills + detail.get_noise_2d(px, py) * .6 * smoothstep(15, 60, d)
		if corridor[k]:
			h = base[k] - .6
		# Fade to the base plane at the grid border so the terrain meets the far ground without a cliff.
		var border = minf(
			minf(px - origin.x, origin.x + (nx - 1) * cell - px),
			minf(py - origin.y, origin.y + (ny - 1) * cell - py)
		)
		heights[k] = lerpf(low - 4.2, h, smoothstep(0, 90, border))


func make_materials():
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	for kind in [["grass", "grass_ground"], ["gravel", "gravel_floor"], ["runoff", "asphalt_track"]]:
		ground_material.set_shader_parameter(kind[0] + "_albedo", tex(kind[1], "diff"))
		ground_material.set_shader_parameter(kind[0] + "_normal", tex(kind[1], "nor_gl"))
		ground_material.set_shader_parameter(kind[0] + "_rough", tex(kind[1], "rough"))
	# Paint mask: one pixel per 2 m physics paint cell; red = gravel (paint 2), green = tarmac runoff (paint 3).
	var keys = track.data.paint.keys()
	if not keys.is_empty():
		var x0 = INF
		var y0 = INF
		var x1 = -INF
		var y1 = -INF
		for key in keys:
			var xy = key.split(",")
			x0 = minf(x0, int(xy[0]))
			y0 = minf(y0, int(xy[1]))
			x1 = maxf(x1, int(xy[0]))
			y1 = maxf(y1, int(xy[1]))
		var w = int(x1 - x0) + 3
		var h = int(y1 - y0) + 3
		var img = Image.create(w, h, false, Image.FORMAT_RGB8)
		for key in keys:
			var value = int(track.data.paint[key])
			if value == 2 or value == 3:
				var xy = key.split(",")
				img.set_pixel(
					int(xy[0]) - int(x0) + 1,
					int(xy[1]) - int(y0) + 1,
					Color(1, 0, 0) if value == 2 else Color(0, 1, 0)
				)
		ground_material.set_shader_parameter("paint_mask", ImageTexture.create_from_image(img))
		ground_material.set_shader_parameter("mask_origin", Vector2((x0 - 1) * 2, (y0 - 1) * 2))
		ground_material.set_shader_parameter("mask_size", Vector2(w * 2, h * 2))


func mesh_from(st, material):
	st.generate_normals()
	st.generate_tangents()
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	return node


## Forest floor: on wooded circuits (presentation.scenery.trees > 1) the ground under the woods turns
## darker and browner than the mown grass near the track.
func forest_tint(d):
	var scen = track.data.get("presentation", {}).get("scenery", {})
	var forest = clampf((float(scen.get("trees", 1.0)) - 1.0) / 3.0, 0, 1)
	var inner = float(scen.get("treeline", 36.0))
	return Color.WHITE.lerp(Color(.55, .52, .42), forest * smoothstep(inner + 5, inner + 40, d))


func build_terrain_mesh(parent):
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var colors = PackedColorArray()
	verts.resize(nx * ny)
	normals.resize(nx * ny)
	uvs.resize(nx * ny)
	colors.resize(nx * ny)
	for gy in ny:
		for gx in nx:
			var k = gy * nx + gx
			var px = origin.x + gx * cell
			var py = origin.y + gy * cell
			verts[k] = Vector3(px, heights[k], py)
			uvs[k] = Vector2(px, py) * .1
			colors[k] = forest_tint(dist[k])
			var hl = heights[gy * nx + maxi(gx - 1, 0)]
			var hr = heights[gy * nx + mini(gx + 1, nx - 1)]
			var hd = heights[maxi(gy - 1, 0) * nx + gx]
			var hu = heights[mini(gy + 1, ny - 1) * nx + gx]
			normals[k] = Vector3(hl - hr, 2 * cell, hd - hu).normalized()
	# Independent 24-cell tiles share the same heights/normals but can be
	# frustum-culled. No runtime rebuild or topology switch at tile boundaries.
	for cy in range(0, ny - 1, 24):
		for cx in range(0, nx - 1, 24):
			var width = mini(25, nx - cx)
			var depth = mini(25, ny - cy)
			var tile_vertices = PackedVector3Array()
			var tile_normals = PackedVector3Array()
			var tile_uvs = PackedVector2Array()
			var tile_colors = PackedColorArray()
			var tile_indices = PackedInt32Array()
			for gy in depth:
				for gx in width:
					var k = (cy + gy) * nx + cx + gx
					tile_vertices.append(verts[k])
					tile_normals.append(normals[k])
					tile_uvs.append(uvs[k])
					tile_colors.append(colors[k])
			for gy in depth - 1:
				for gx in width - 1:
					var a = gy * width + gx
					tile_indices.append_array([a, a + 1, a + width + 1, a, a + width + 1, a + width])
			var arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = tile_vertices
			arrays[Mesh.ARRAY_NORMAL] = tile_normals
			arrays[Mesh.ARRAY_TEX_UV] = tile_uvs
			arrays[Mesh.ARRAY_COLOR] = tile_colors
			arrays[Mesh.ARRAY_INDEX] = tile_indices
			var mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var node = MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = ground_material
			parent.add_child(node)


## A point on the road surface, `offset` metres right of the centreline. This asks the ribbon for
## the same surface the wheels are standing on, rather than rebuilding it from a linear cross-slope:
## with a cross-section profile the two disagree by more than a metre, and the car would sink into
## tarmac that looked flat. Simulation (x, y, z) maps to Godot (x, z, y).
func point(sm, offset, raise_by = 0.0):
	var q = TrackModel.surface_point(sm, offset)
	return Vector3(q.x, q.z + raise_by, q.y)


func add_vert(st, v, color, uv2 = Vector2.ZERO, uv = null):
	st.set_color(color)
	st.set_uv(Vector2(v.x, v.z) * .1 if uv == null else uv)
	st.set_uv2(uv2)
	st.add_vertex(v)


## Adds a quad a-b-c-d with upward-facing winding (Godot front faces are clockwise from above).
func quad(st, a, b, c, d, colors, uv2s = null, uvs = null):
	var order = [0, 1, 2, 0, 2, 3]
	var pts = [a, b, c, d]
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).y > 0:
		order = [0, 2, 1, 0, 3, 2]
	for o in order:
		add_vert(
			st,
			pts[o],
			colors[o] if colors is Array else colors,
			uv2s[o] if uv2s != null else Vector2.ZERO,
			uvs[o] if uvs != null else null
		)


func racing_line():
	# Out-in-out: inside at the apex (positive curvature turns right = positive lateral), outside on approach/exit.
	var step = 5.0
	var stations = int(track.length / step) + 1
	var curv = PackedFloat32Array()
	curv.resize(stations)
	for k in stations:
		curv[k] = track.curvature_at(k * step, 15.0)
	var line = PackedFloat32Array()
	line.resize(track.samples.size())
	for i in track.samples.size():
		var k = int(track.samples[i].s / step)
		var ahead = curv[(k + 9) % stations]
		var behind = curv[posmod(k - 9, stations)]
		line[i] = clampf(42 * curv[k] - 24 * (ahead + behind), -.72, .72)
	return line


func build_road(parent):
	var road = SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint = SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verge = SurfaceTool.new()
	verge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var S = track.samples
	var N = S.size()
	var line = racing_line()
	var curb_colors = track.data.get("presentation", {}).get("curbColors", ["#ca4638", "#e9e7d9"])
	for i in N:
		var a = S[i]
		var b = S[(i + 1) % N]
		var la = line[i]
		var lb = line[(i + 1) % N]
		quad(
			road,
			point(a, -a.w / 2),
			point(b, -b.w / 2),
			point(b, b.w / 2),
			point(a, a.w / 2),
			Color.WHITE,
			[Vector2(-1, la), Vector2(-1, lb), Vector2(1, lb), Vector2(1, la)],
			[Vector2(-1, a.s), Vector2(-1, b.s), Vector2(1, b.s), Vector2(1, a.s)]
		)
		for side in [-1, 1]:
			var ea = side * a.w / 2
			var eb = side * b.w / 2
			var white = Color("e9e6db")
			quad(
				paint,
				point(a, ea - side * .24, .012),
				point(b, eb - side * .24, .012),
				point(b, eb - side * .08, .012),
				point(a, ea - side * .08, .012),
				white
			)
			var curb_w = 0.0
			if a.curb:
				curb_w = 1.4
				var c = Color(curb_colors[int(a.s / 2.5) % 2])
				quad(
					paint,
					point(a, ea, .02),
					point(b, eb, .02),
					point(b, eb + side * 1.4, .07),
					point(a, ea + side * 1.4, .07),
					c
				)
			# Verge: flat strip beside the road, then blend down/up into the terrain heightfield.
			var mid_a = point(a, ea + side * maxf(2.5, curb_w), -.05)
			var mid_b = point(b, eb + side * maxf(2.5, curb_w), -.05)
			var in_a = point(a, ea + side * curb_w, -.03)
			var in_b = point(b, eb + side * curb_w, -.03)
			var oa = point(a, ea + side * VERGE)
			var ob = point(b, eb + side * VERGE)
			oa.y = height(oa.x, oa.z) + .02
			ob.y = height(ob.x, ob.z) + .02
			var green = Color(1, 1, 1)
			quad(verge, in_a, in_b, mid_b, mid_a, green)
			quad(verge, mid_a, mid_b, ob, oa, green)
	var road_mat = ShaderMaterial.new()
	road_material = road_mat
	road_mat.shader = ROAD_SHADER
	road_mat.set_shader_parameter("albedo_tex", tex("asphalt_track", "diff"))
	road_mat.set_shader_parameter("normal_tex", tex("asphalt_track", "nor_gl"))
	road_mat.set_shader_parameter("rough_tex", tex("asphalt_track", "rough"))
	var paint_mat = ShaderMaterial.new()
	paint_mat.shader = PAINT_SHADER
	paint_mat.set_shader_parameter("albedo_tex", tex("concrete_floor_02", "diff"))
	paint_mat.set_shader_parameter("normal_tex", tex("concrete_floor_02", "nor_gl"))
	paint_mat.set_shader_parameter("rough_tex", tex("concrete_floor_02", "rough"))
	parent.add_child(mesh_from(verge, ground_material))
	parent.add_child(mesh_from(road, road_mat))
	parent.add_child(mesh_from(paint, paint_mat))


func multimesh(parent, mesh, transforms, colors, material, shadows = true):
	if transforms.is_empty():
		return
	# Spatial batches let the renderer cull the back half of the circuit. One
	# lap-wide MultiMesh submitted every tyre/post/contact patch from every view.
	var groups = {}
	for i in transforms.size():
		var pos = transforms[i].origin
		var key = Vector2i(floori(pos.x / 128), floori(pos.z / 128))
		if not groups.has(key):
			groups[key] = {"poses": [], "colors": []}
		groups[key].poses.append(transforms[i])
		if not colors.is_empty():
			groups[key].colors.append(colors[i])
	for group in groups.values():
		multimesh_batch(parent, mesh, group.poses, group.colors, material, shadows)


func multimesh_batch(parent, mesh, transforms, colors, material, shadows):
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func flat_material(color, metal = 0.0, rough = .7, use_colors = false):
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.albedo_color = Color(color)
	m.metallic = metal
	m.roughness = rough
	m.vertex_color_use_as_albedo = use_colors
	m.vertex_color_is_srgb = use_colors
	return m


## Armco rails with posts, tire walls with painted top rows and trackside advertising boards.
func build_barriers(parent):
	var ao_poses = []
	var rails = []
	var posts = []
	var fences = []
	var tires = []
	var tire_colors = []
	var boards = []
	var board_colors = []
	var ad = [
		Color("c8352d"), Color("1d5fa8"), Color("f2c230"), Color("1f8a4c"), Color("e9e6db"), Color("202a33")
	]
	var board_run = 0.0
	for o in track.barriers:
		var a = Vector3(o.x1, ground_height(o.x1, o.y1), o.y1)
		var b = Vector3(o.x2, ground_height(o.x2, o.y2), o.y2)
		var dir = b - a
		var len = dir.length()
		if len < .1:
			continue
		var yaw = -atan2(dir.z, dir.x)
		var pitch_angle = atan2(dir.y, Vector2(dir.x, dir.z).length())
		var basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch_angle)
		ao_poses.append(
			Transform3D(basis * Basis.from_scale(Vector3(len * .65, 1, 1.5)), (a + b) / 2 + Vector3.UP * .035)
		)
		if o.type == "wall":
			var outward = Vector3(-dir.z, 0, dir.x).normalized() * float(o.side)
			fences.append(
				Transform3D(
					basis * Basis.from_scale(Vector3(len, 2.7, 1)),
					(a + b) / 2 + Vector3.UP * 2.0 + outward * .5
				)
			)
			for hgt in [.42, .62]:
				rails.append(
					Transform3D(
						basis * Basis.from_scale(Vector3(len + .05, .16, .05)), (a + b) / 2 + Vector3.UP * hgt
					)
				)
			for k in int(len / 2.0) + 1:
				posts.append(
					Transform3D(
						Basis.IDENTITY.scaled(Vector3(.1, .8, .1)), a.lerp(b, k * 2.0 / len) + Vector3.UP * .4
					)
				)
			board_run += len
			if board_run > 28 and absf(track.curvature_at(track.project(o.x1, o.y1).s)) < 1.0 / 300:
				board_run = 0
				var side_offset = Vector3(-dir.z, 0, dir.x).normalized() * float(o.side) * .12
				boards.append(
					Transform3D(
						basis * Basis.from_scale(Vector3(minf(len * 1.2, 7), .8, .04)),
						(a + b) / 2 + Vector3.UP * 1.25 + side_offset
					)
				)
				board_colors.append(ad[posmod(int(o.x1 * 17 + o.y1 * 31), ad.size())])
		else:
			var n = int(len / .62)
			for k in n:
				var p = a.lerp(b, (k + .5) / n)
				for row in 3:
					tires.append(
						Transform3D(
							Basis.IDENTITY.scaled(Vector3(.62, .24, .62)), p + Vector3.UP * (.12 + row * .24)
						)
					)
					tire_colors.append(
						(
							(Color("d63a2f") if (k / 2) % 2 == 0 else Color("eeeeea"))
							if row == 2
							else Color("1b1d1f")
						)
					)
	var cube = BoxMesh.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = .5
	cyl.bottom_radius = .5
	cyl.height = 1
	cyl.radial_segments = 10
	cyl.rings = 1
	var ao = ShaderMaterial.new()
	ao.shader = preload("res://shaders/baked_ao.gdshader")
	multimesh(parent, preload("res://scripts/retro_assets.gd").ao_mesh(), ao_poses, [], ao, false)
	multimesh(parent, cube, rails, [], painted_material("armco", "a9b3b8"))
	multimesh(parent, cube, posts, [], flat_material("6b7378", .6, .5), false)
	var fence = ShaderMaterial.new()
	fence.shader = preload("res://shaders/fence.gdshader")
	var card = QuadMesh.new()
	card.size = Vector2.ONE
	multimesh(parent, card, fences, [], fence, false)
	multimesh(parent, cyl, tires, tire_colors, painted_material("tyre", "ffffff"))
	multimesh(parent, cube, boards, board_colors, flat_material("ffffff", 0, .5, true))


## Grandstands at the outside of the sharpest corners and marshal posts around the lap.
func build_furniture(parent):
	var step = 10.0
	var picks = []
	var S = track.length
	var corners = []
	for k in int(S / step):
		var c = track.curvature_at(k * step, 20.0)
		corners.append([absf(c), k * step, c])
	corners.sort_custom(func(a, b): return a[0] > b[0])
	for item in corners:
		if picks.size() >= 4 or item[0] < 1.0 / 120:
			break
		var far = true
		for p in picks:
			if absf(wrapf(p[1] - item[1], -S / 2, S / 2)) < 350:
				far = false
		if far:
			picks.append(item)
	var concrete = flat_material("b9bfc1", 0, .8)
	var seats = flat_material("ffffff", 0, .6, true)
	seats.albedo_texture = preload("res://scripts/retro_assets.gd").painted("crowd")
	seats.uv1_scale = Vector3(8, 1, 1)
	var roof = flat_material("e3e7e6", .3, .4)
	for item in picks:
		var p = track.pos_at(item[1])
		var side = -1.0 if item[2] > 0 else 1.0
		var off = side * (p.w / 2 + 40)
		var x = p.x - sin(p.h) * off
		var y = p.y + cos(p.h) * off
		var pr = track.project(x, y)
		if absf(pr.lat) < pr.width / 2 + 30:
			continue
		var root = Node3D.new()
		parent.add_child(root)
		root.position = Vector3(x, ground_height(x, y) - .3, y)
		root.rotation.y = -p.h + (PI if side < 0 else 0.0)
		var ao = ShaderMaterial.new()
		ao.shader = preload("res://shaders/baked_ao.gdshader")
		multimesh(
			root,
			preload("res://scripts/retro_assets.gd").ao_mesh(),
			[Transform3D(Basis.from_scale(Vector3(27, 1, 9)), Vector3(0, .34, 1))],
			[],
			ao,
			false
		)
		# Stand faces the track (local -Z toward the circuit).
		var mesh = BoxMesh.new()
		var tiers = []
		var colors = []
		for t in 7:
			tiers.append(
				Transform3D(
					Basis.IDENTITY.scaled(Vector3(46, .5, 1.6)), Vector3(0, .25 + t * .62, -4.8 + t * 1.6)
				)
			)
			colors.append(Color("2f6fb4").lerp(Color("d4d8da"), float(t % 2) * .25))
		multimesh(root, mesh, tiers, colors, seats)
		var back = MeshInstance3D.new()
		back.mesh = mesh
		back.scale = Vector3(46, 5, .4)
		back.position = Vector3(0, 2.6, 6.6)
		back.material_override = concrete
		root.add_child(back)
		var top = MeshInstance3D.new()
		top.mesh = mesh
		top.scale = Vector3(48, .25, 13)
		top.position = Vector3(0, 5.6, .8)
		top.rotation.x = -.08
		top.material_override = roof
		root.add_child(top)
		for px in [-22, 0, 22]:
			var col = MeshInstance3D.new()
			col.mesh = mesh
			col.scale = Vector3(.3, 5.6, .3)
			col.position = Vector3(px, 2.8, 6.4)
			col.material_override = concrete
			root.add_child(col)
	var huts = []
	var poles = []
	var flags = []
	var k = 0
	for s in range(120, int(S), 260):
		var p = track.pos_at(s)
		var side = 1.0 if k % 2 == 0 else -1.0
		k += 1
		var off = side * (p.w / 2 + 6.5)
		var x = p.x - sin(p.h) * off
		var y = p.y + cos(p.h) * off
		var pr = track.project(x, y)
		if absf(pr.lat) < pr.width / 2 + 4 or absf(wrapf(pr.s - s, -S / 2, S / 2)) > 20:
			continue
		var z = ground_height(x, y)
		var basis = Basis(Vector3.UP, -p.h)
		huts.append(Transform3D(basis * Basis.from_scale(Vector3(1.6, 2.2, 1.6)), Vector3(x, z + 1.1, y)))
		poles.append(Transform3D(Basis.IDENTITY.scaled(Vector3(.06, 3.4, .06)), Vector3(x + .9, z + 1.7, y)))
		flags.append(
			Transform3D(basis * Basis.from_scale(Vector3(.9, .6, .03)), Vector3(x + 1.35, z + 3.1, y))
		)
	var box = BoxMesh.new()
	multimesh(parent, box, huts, [], flat_material("e8e3d4", 0, .7))
	multimesh(parent, box, poles, [], flat_material("9aa1a4", .7, .4), false)
	multimesh(parent, box, flags, [], flat_material("f0c419", 0, .6), false)


func painted_material(kind, colour):
	var mat = flat_material(colour, 0, .8, true)
	mat.albedo_texture = preload("res://scripts/retro_assets.gd").painted(kind)
	return mat


## Named landmarks around the circuit (buildings, spectator banks, bridges,
## grandstands, marshal posts, hedges).
func build_landmarks(parent):
	var landmarks = track.data.get("presentation", {}).get("landmarks", [])
	if landmarks.is_empty():
		return
	var labels = track.data.get("presentation", {}).get("labels", [])
	var label_map = {}
	for l in labels:
		if l.has("name"):
			label_map[l.name] = l

	for lm in landmarks:
		var kind = str(lm.get("kind", "")).to_lower()
		var anchor = lm.get("anchor")
		var s = -1.0
		if anchor is String:
			if label_map.has(anchor):
				var l = label_map[anchor]
				s = track.project(float(l.x), float(l.y)).s
			else:
				continue
		elif anchor is Dictionary:
			s = track.project(float(anchor.get("x", 0.0)), float(anchor.get("y", 0.0))).s
		elif anchor is int or anchor is float:
			s = float(anchor)
		else:
			continue

		if s < 0.0:
			continue

		if lm.has("s_offset"):
			s = wrapf(s + float(lm.s_offset), 0.0, track.length)

		var side_str = str(lm.get("side", "outside")).to_lower()
		var curv = track.curvature_at(s, 20.0)
		var side_sign = 1.0
		if side_str == "left":
			side_sign = -1.0
		elif side_str == "right":
			side_sign = 1.0
		elif side_str == "outside":
			side_sign = -1.0 if curv > 0.0 else 1.0
		elif side_str == "inside":
			side_sign = 1.0 if curv > 0.0 else -1.0

		var offset = float(lm.get("offset", 12.0))
		var length = float(lm.get("length", 0.0))
		var scale_val = float(lm.get("scale", 1.0))
		var variant = str(lm.get("variant", "")).to_lower()

		match kind:
			"building":
				build_landmark_building(parent, s, side_sign, offset, scale_val, variant, lm)
			"spectator_bank":
				build_landmark_spectator_bank(parent, s, side_sign, offset, length, scale_val, variant, lm)
			"bridge", "footbridge":
				build_landmark_bridge(parent, s, scale_val, variant, lm)
			"grandstand":
				build_landmark_grandstand(parent, s, side_sign, offset, length, scale_val, variant, lm)
			"marshal_post":
				build_landmark_marshal_post(parent, s, side_sign, offset, scale_val, variant, lm)
			"hedge":
				build_landmark_hedge(parent, s, side_sign, offset, length, scale_val, variant, lm)


func build_landmark_building(parent, s, side_sign, offset, scale_val, variant, _lm):
	var p = track.pos_at(s)
	var off = side_sign * (p.w / 2.0 + offset)
	var x = p.x - sin(p.h) * off
	var y = p.y + cos(p.h) * off
	var pr = track.project(x, y)
	if absf(pr.lat) < pr.width / 2.0 + 3.0:
		return
	var z = ground_height(x, y)
	var root = Node3D.new()
	parent.add_child(root)
	root.position = Vector3(x, z, y)
	root.rotation.y = -p.h + (PI if side_sign < 0 else 0.0)

	var box = BoxMesh.new()
	if variant == "mill":
		# Ex-Mühle historic timbered water mill complex
		var base = MeshInstance3D.new()
		base.mesh = box
		base.scale = Vector3(14.0, 2.2, 10.0) * scale_val
		base.position = Vector3(0.0, 1.1 * scale_val, 0.0)
		base.material_override = flat_material("54514c", 0.0, 0.9)
		root.add_child(base)

		var walls = MeshInstance3D.new()
		walls.mesh = box
		walls.scale = Vector3(13.2, 4.6, 9.2) * scale_val
		walls.position = Vector3(0.0, 4.5 * scale_val, 0.0)
		walls.material_override = flat_material("ede6d6", 0.0, 0.75)
		root.add_child(walls)

		var frame = MeshInstance3D.new()
		frame.mesh = box
		frame.scale = Vector3(13.4, 0.3, 9.4) * scale_val
		frame.position = Vector3(0.0, 4.5 * scale_val, 0.0)
		frame.material_override = flat_material("382618", 0.0, 0.8)
		root.add_child(frame)

		var roof_mesh = PrismMesh.new()
		roof_mesh.size = Vector3(10.2, 3.8, 14.2) * scale_val
		var roof = MeshInstance3D.new()
		roof.mesh = roof_mesh
		roof.rotation.y = PI / 2.0
		roof.position = Vector3(0.0, 8.7 * scale_val, 0.0)
		roof.material_override = flat_material("8c3527", 0.0, 0.65)
		root.add_child(roof)

		var wing = MeshInstance3D.new()
		wing.mesh = box
		wing.scale = Vector3(6.5, 4.0, 6.0) * scale_val
		wing.position = Vector3(-9.5 * scale_val, 2.0 * scale_val, 0.5 * scale_val)
		wing.material_override = flat_material("dfd7c5", 0.0, 0.8)
		root.add_child(wing)

		var wing_roof_mesh = PrismMesh.new()
		wing_roof_mesh.size = Vector3(6.6, 2.4, 6.8) * scale_val
		var wing_roof = MeshInstance3D.new()
		wing_roof.mesh = wing_roof_mesh
		wing_roof.rotation.y = PI / 2.0
		wing_roof.position = Vector3(-9.5 * scale_val, 5.2 * scale_val, 0.5 * scale_val)
		wing_roof.material_override = flat_material("7e3023", 0.0, 0.65)
		root.add_child(wing_roof)

		var wheel_mesh = CylinderMesh.new()
		wheel_mesh.top_radius = 2.2 * scale_val
		wheel_mesh.bottom_radius = 2.2 * scale_val
		wheel_mesh.height = 0.7 * scale_val
		wheel_mesh.radial_segments = 12
		var wheel = MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(0.0, 2.0 * scale_val, -5.2 * scale_val)
		wheel.material_override = flat_material("3b2818", 0.0, 0.85)
		root.add_child(wheel)

		var race = MeshInstance3D.new()
		race.mesh = box
		race.scale = Vector3(3.0, 1.2, 7.0) * scale_val
		race.position = Vector3(0.0, 2.2 * scale_val, -7.5 * scale_val)
		race.material_override = flat_material("524e49", 0.0, 0.9)
		root.add_child(race)

	elif variant == "tower":
		# Kaiser Wilhelm Tower at Hohe Acht
		var base = MeshInstance3D.new()
		base.mesh = box
		base.scale = Vector3(7.5, 3.0, 7.5) * scale_val
		base.position = Vector3(0.0, 1.5 * scale_val, 0.0)
		base.material_override = flat_material("56514b", 0.0, 0.9)
		root.add_child(base)

		var t1 = MeshInstance3D.new()
		t1.mesh = box
		t1.scale = Vector3(6.0, 9.0, 6.0) * scale_val
		t1.position = Vector3(0.0, 7.5 * scale_val, 0.0)
		t1.material_override = flat_material("6b655d", 0.0, 0.85)
		root.add_child(t1)

		var t2 = MeshInstance3D.new()
		t2.mesh = box
		t2.scale = Vector3(5.0, 8.0, 5.0) * scale_val
		t2.position = Vector3(0.0, 16.0 * scale_val, 0.0)
		t2.material_override = flat_material("797268", 0.0, 0.85)
		root.add_child(t2)

		var platform = MeshInstance3D.new()
		platform.mesh = box
		platform.scale = Vector3(5.6, 1.2, 5.6) * scale_val
		platform.position = Vector3(0.0, 20.6 * scale_val, 0.0)
		platform.material_override = flat_material("5e5850", 0.0, 0.9)
		root.add_child(platform)

		var roof_mesh = PrismMesh.new()
		roof_mesh.size = Vector3(4.8, 2.5, 4.8) * scale_val
		var turret = MeshInstance3D.new()
		turret.mesh = roof_mesh
		turret.position = Vector3(0.0, 22.4 * scale_val, 0.0)
		turret.material_override = flat_material("3b4c42", 0.0, 0.7)
		root.add_child(turret)

	elif variant == "monument":
		# Schwedenkreuz 1638 stone cross
		var step1 = MeshInstance3D.new()
		step1.mesh = box
		step1.scale = Vector3(3.2, 0.35, 3.2) * scale_val
		step1.position = Vector3(0.0, 0.17 * scale_val, 0.0)
		step1.material_override = flat_material("66615b", 0.0, 0.9)
		root.add_child(step1)

		var step2 = MeshInstance3D.new()
		step2.mesh = box
		step2.scale = Vector3(2.2, 0.35, 2.2) * scale_val
		step2.position = Vector3(0.0, 0.52 * scale_val, 0.0)
		step2.material_override = flat_material("706a64", 0.0, 0.9)
		root.add_child(step2)

		var plinth = MeshInstance3D.new()
		plinth.mesh = box
		plinth.scale = Vector3(1.1, 1.4, 1.1) * scale_val
		plinth.position = Vector3(0.0, 1.4 * scale_val, 0.0)
		plinth.material_override = flat_material("7d776f", 0.0, 0.9)
		root.add_child(plinth)

		var shaft = MeshInstance3D.new()
		shaft.mesh = box
		shaft.scale = Vector3(0.42, 3.0, 0.42) * scale_val
		shaft.position = Vector3(0.0, 3.6 * scale_val, 0.0)
		shaft.material_override = flat_material("847e76", 0.0, 0.9)
		root.add_child(shaft)

		var bar = MeshInstance3D.new()
		bar.mesh = box
		bar.scale = Vector3(1.7, 0.42, 0.42) * scale_val
		bar.position = Vector3(0.0, 4.3 * scale_val, 0.0)
		bar.material_override = flat_material("847e76", 0.0, 0.9)
		root.add_child(bar)

	else:
		# Standard country building
		var bld = MeshInstance3D.new()
		bld.mesh = box
		bld.scale = Vector3(11.0, 5.0, 8.0) * scale_val
		bld.position = Vector3(0.0, 2.5 * scale_val, 0.0)
		bld.material_override = flat_material("eae3d5", 0.0, 0.8)
		root.add_child(bld)

		var roof_mesh = PrismMesh.new()
		roof_mesh.size = Vector3(8.5, 3.2, 11.4) * scale_val
		var roof = MeshInstance3D.new()
		roof.mesh = roof_mesh
		roof.rotation.y = PI / 2.0
		roof.position = Vector3(0.0, 6.6 * scale_val, 0.0)
		roof.material_override = flat_material("8a3627", 0.0, 0.65)
		root.add_child(roof)


func build_landmark_spectator_bank(parent, s_centre, side_sign, offset, length, scale_val, _variant, _lm):
	var span = maxf(length, 40.0)
	var step = 8.0
	var count = int(span / step)
	var box = BoxMesh.new()
	var prism = PrismMesh.new()

	var earth_mat = flat_material("4b5c36", 0.0, 0.9)
	var crowd_mat = painted_material("crowd", "ffffff")
	var wood_mat = flat_material("4a3a2a", 0.0, 0.85)

	var tent_colors = [
		Color("f2f4f7"), Color("2252a8"), Color("b83228"), Color("286b3e"), Color("dca824")
	]

	var bank_root = Node3D.new()
	parent.add_child(bank_root)

	for i in count + 1:
		var st = wrapf(s_centre - span * 0.5 + i * step, 0.0, track.length)
		var p = track.pos_at(st)
		var off = side_sign * (p.w / 2.0 + offset)
		var x = p.x - sin(p.h) * off
		var y = p.y + cos(p.h) * off
		var pr = track.project(x, y)
		if absf(pr.lat) < pr.width / 2.0 + 3.0:
			continue
		var z = ground_height(x, y)

		var seg_root = Node3D.new()
		bank_root.add_child(seg_root)
		seg_root.position = Vector3(x, z, y)
		seg_root.rotation.y = -p.h + (PI if side_sign < 0 else 0.0)

		for tier in 3:
			var berm = MeshInstance3D.new()
			berm.mesh = box
			berm.scale = Vector3(step * 1.05, 0.65, 2.4) * scale_val
			berm.position = Vector3(0.0, (0.35 + tier * 0.65) * scale_val, (tier * 2.2) * scale_val)
			berm.material_override = earth_mat
			seg_root.add_child(berm)

			var crowd = MeshInstance3D.new()
			crowd.mesh = box
			crowd.scale = Vector3(step * 0.95, 0.7, 0.3) * scale_val
			crowd.position = Vector3(0.0, (0.95 + tier * 0.65) * scale_val, (tier * 2.2 - 0.5) * scale_val)
			crowd.material_override = crowd_mat
			seg_root.add_child(crowd)

		var rail = MeshInstance3D.new()
		rail.mesh = box
		rail.scale = Vector3(step * 1.02, 0.12, 0.12) * scale_val
		rail.position = Vector3(0.0, 1.1 * scale_val, -1.2 * scale_val)
		rail.material_override = wood_mat
		seg_root.add_child(rail)

		var post = MeshInstance3D.new()
		post.mesh = box
		post.scale = Vector3(0.14, 1.1, 0.14) * scale_val
		post.position = Vector3(0.0, 0.55 * scale_val, -1.2 * scale_val)
		post.material_override = wood_mat
		seg_root.add_child(post)

		if i % 3 == 1:
			var tent = MeshInstance3D.new()
			tent.mesh = prism
			tent.scale = Vector3(3.2, 1.4, 3.2) * scale_val
			tent.position = Vector3(0.0, (2.6 + 0.7) * scale_val, 6.2 * scale_val)
			var tent_col = tent_colors[(i / 3) % tent_colors.size()]
			tent.material_override = flat_material(tent_col, 0.0, 0.7)
			seg_root.add_child(tent)


func build_landmark_bridge(parent, s, scale_val, variant, _lm):
	var p = track.pos_at(s)
	var road_w = p.w
	var span_w = road_w + 6.0
	var clearance = 5.8 * scale_val
	var bridge_z = p.z + clearance
	var box = BoxMesh.new()

	var root = Node3D.new()
	parent.add_child(root)
	root.position = Vector3(p.x, bridge_z, p.y)
	root.rotation.y = -p.h

	if variant == "gantry":
		# Döttinger Höhe overhead truss gantry
		var steel_mat = flat_material("454c52", 0.6, 0.5)
		var banner_mat = flat_material("1c4899", 0.0, 0.6)
		var stripe_mat = flat_material("f2c029", 0.0, 0.6)

		var truss = MeshInstance3D.new()
		truss.mesh = box
		truss.scale = Vector3(1.3, 1.5, span_w) * scale_val
		truss.position = Vector3(0.0, 0.0, 0.0)
		truss.material_override = steel_mat
		root.add_child(truss)

		for side in [-0.7, 0.7]:
			var banner = MeshInstance3D.new()
			banner.mesh = box
			banner.scale = Vector3(0.1, 1.3, span_w - 2.0) * scale_val
			banner.position = Vector3(side * scale_val, 0.0, 0.0)
			banner.material_override = banner_mat
			root.add_child(banner)

			var stripe = MeshInstance3D.new()
			stripe.mesh = box
			stripe.scale = Vector3(0.12, 0.22, span_w - 2.0) * scale_val
			stripe.position = Vector3(side * scale_val, -0.45 * scale_val, 0.0)
			stripe.material_override = stripe_mat
			root.add_child(stripe)

		for side_sign in [-1.0, 1.0]:
			var leg_z_offset = side_sign * (span_w / 2.0 - 0.5) * scale_val
			var leg = MeshInstance3D.new()
			leg.mesh = box
			leg.scale = Vector3(1.2, clearance + 1.0, 1.2) * scale_val
			leg.position = Vector3(0.0, -clearance * 0.5, leg_z_offset)
			leg.material_override = steel_mat
			root.add_child(leg)

	elif variant == "stone":
		# Breidscheid stone viaduct
		var stone_mat = flat_material("57534c", 0.0, 0.9)
		var deck_mat = flat_material("3b3834", 0.0, 0.8)

		var deck = MeshInstance3D.new()
		deck.mesh = box
		deck.scale = Vector3(7.5, 1.4, span_w + 4.0) * scale_val
		deck.position = Vector3(0.0, 0.0, 0.0)
		deck.material_override = deck_mat
		root.add_child(deck)

		for side in [-3.5, 3.5]:
			var wall = MeshInstance3D.new()
			wall.mesh = box
			wall.scale = Vector3(0.5, 1.2, span_w + 4.0) * scale_val
			wall.position = Vector3(side * scale_val, 1.2 * scale_val, 0.0)
			wall.material_override = stone_mat
			root.add_child(wall)

		for side_sign in [-1.0, 1.0]:
			var pier_z = side_sign * (span_w / 2.0 + 1.5) * scale_val
			var pier = MeshInstance3D.new()
			pier.mesh = box
			pier.scale = Vector3(7.0, clearance + 1.5, 3.5) * scale_val
			pier.position = Vector3(0.0, -clearance * 0.5, pier_z)
			pier.material_override = stone_mat
			root.add_child(pier)

	else:
		# Footbridge / pedestrian walkway
		var steel_mat = flat_material("52595f", 0.5, 0.5)
		var roof_mat = flat_material("2d5238", 0.0, 0.7)

		var span = MeshInstance3D.new()
		span.mesh = box
		span.scale = Vector3(2.6, 0.35, span_w) * scale_val
		span.position = Vector3(0.0, 0.0, 0.0)
		span.material_override = steel_mat
		root.add_child(span)

		var canopy = MeshInstance3D.new()
		canopy.mesh = box
		canopy.scale = Vector3(3.2, 0.2, span_w) * scale_val
		canopy.position = Vector3(0.0, 2.4 * scale_val, 0.0)
		canopy.material_override = roof_mat
		root.add_child(canopy)

		for side in [-1.2, 1.2]:
			var rail = MeshInstance3D.new()
			rail.mesh = box
			rail.scale = Vector3(0.1, 1.1, span_w) * scale_val
			rail.position = Vector3(side * scale_val, 0.65 * scale_val, 0.0)
			rail.material_override = steel_mat
			root.add_child(rail)

		for side_sign in [-1.0, 1.0]:
			var tower_z = side_sign * (span_w / 2.0 + 1.0) * scale_val
			var tower = MeshInstance3D.new()
			tower.mesh = box
			tower.scale = Vector3(2.8, clearance + 2.0, 2.4) * scale_val
			tower.position = Vector3(0.0, -clearance * 0.4, tower_z)
			tower.material_override = steel_mat
			root.add_child(tower)


func build_landmark_grandstand(parent, s, side_sign, offset, length, scale_val, _variant, _lm):
	var p = track.pos_at(s)
	var off = side_sign * (p.w / 2.0 + offset)
	var x = p.x - sin(p.h) * off
	var y = p.y + cos(p.h) * off
	var pr = track.project(x, y)
	if absf(pr.lat) < pr.width / 2.0 + 3.0:
		return
	var z = ground_height(x, y)
	var width = maxf(length, 45.0)

	var root = Node3D.new()
	parent.add_child(root)
	root.position = Vector3(x, z - 0.2, y)
	root.rotation.y = -p.h + (PI if side_sign < 0 else 0.0)

	var concrete = flat_material("b5bbbd", 0.0, 0.8)
	var seats = flat_material("ffffff", 0.0, 0.6, true)
	seats.albedo_texture = preload("res://scripts/retro_assets.gd").painted("crowd")
	seats.uv1_scale = Vector3(8, 1, 1)
	var roof_mat = flat_material("dfe3e2", 0.3, 0.4)
	var box = BoxMesh.new()

	var tiers = []
	var colors = []
	for t in 7:
		tiers.append(
			Transform3D(
				Basis.IDENTITY.scaled(Vector3(width, 0.5, 1.6) * scale_val),
				Vector3(0.0, (0.25 + t * 0.62) * scale_val, (-4.8 + t * 1.6) * scale_val)
			)
		)
		colors.append(Color("2f6fb4").lerp(Color("d4d8da"), float(t % 2) * 0.25))
	multimesh(root, box, tiers, colors, seats)

	var back = MeshInstance3D.new()
	back.mesh = box
	back.scale = Vector3(width, 5.0, 0.4) * scale_val
	back.position = Vector3(0.0, 2.6 * scale_val, 6.6 * scale_val)
	back.material_override = concrete
	root.add_child(back)

	var top = MeshInstance3D.new()
	top.mesh = box
	top.scale = Vector3(width + 2.0, 0.25, 13.0) * scale_val
	top.position = Vector3(0.0, 5.6 * scale_val, 0.8 * scale_val)
	top.rotation.x = -0.08
	top.material_override = roof_mat
	root.add_child(top)

	for px in [-width * 0.45, 0.0, width * 0.45]:
		var col = MeshInstance3D.new()
		col.mesh = box
		col.scale = Vector3(0.35, 5.6, 0.35) * scale_val
		col.position = Vector3(px * scale_val, 2.8 * scale_val, 6.4 * scale_val)
		col.material_override = concrete
		root.add_child(col)


func build_landmark_marshal_post(parent, s, side_sign, offset, scale_val, _variant, _lm):
	var p = track.pos_at(s)
	var off = side_sign * (p.w / 2.0 + offset)
	var x = p.x - sin(p.h) * off
	var y = p.y + cos(p.h) * off
	var pr = track.project(x, y)
	if absf(pr.lat) < pr.width / 2.0 + 3.0:
		return
	var z = ground_height(x, y)

	var root = Node3D.new()
	parent.add_child(root)
	root.position = Vector3(x, z, y)
	root.rotation.y = -p.h + (PI if side_sign < 0 else 0.0)

	var box = BoxMesh.new()
	var wood_mat = flat_material("524334", 0.0, 0.8)
	var roof_mat = flat_material("3a423e", 0.0, 0.7)
	var pole_mat = flat_material("9aa1a4", 0.7, 0.4)
	var flag_mat = flat_material("f0c419", 0.0, 0.6)

	var hut = MeshInstance3D.new()
	hut.mesh = box
	hut.scale = Vector3(2.2, 2.2, 2.2) * scale_val
	hut.position = Vector3(0.0, 1.4 * scale_val, 0.0)
	hut.material_override = wood_mat
	root.add_child(hut)

	var roof = MeshInstance3D.new()
	roof.mesh = box
	roof.scale = Vector3(2.6, 0.25, 2.6) * scale_val
	roof.position = Vector3(0.0, 2.6 * scale_val, 0.0)
	roof.material_override = roof_mat
	root.add_child(roof)

	var pole = MeshInstance3D.new()
	pole.mesh = box
	pole.scale = Vector3(0.08, 4.2, 0.08) * scale_val
	pole.position = Vector3(1.3 * scale_val, 2.1 * scale_val, 0.0)
	pole.material_override = pole_mat
	root.add_child(pole)

	var flag = MeshInstance3D.new()
	flag.mesh = box
	flag.scale = Vector3(0.02, 0.7, 1.1) * scale_val
	flag.position = Vector3(1.3 * scale_val, 3.8 * scale_val, 0.6 * scale_val)
	flag.material_override = flag_mat
	root.add_child(flag)


func build_landmark_hedge(parent, s_centre, side_sign, offset, length, scale_val, _variant, _lm):
	var span = maxf(length, 30.0)
	var step = 4.0
	var count = int(span / step)
	var box = BoxMesh.new()
	var hedge_mat = flat_material("375226", 0.0, 0.95)

	var hedge_root = Node3D.new()
	parent.add_child(hedge_root)

	for i in count + 1:
		var st = wrapf(s_centre - span * 0.5 + i * step, 0.0, track.length)
		var p = track.pos_at(st)
		var off = side_sign * (p.w / 2.0 + offset)
		var x = p.x - sin(p.h) * off
		var y = p.y + cos(p.h) * off
		var pr = track.project(x, y)
		if absf(pr.lat) < pr.width / 2.0 + 2.5:
			continue
		var z = ground_height(x, y)

		var seg = MeshInstance3D.new()
		seg.mesh = box
		seg.scale = Vector3(step * 1.05, 1.6 + ((i * 7) % 5) * 0.1, 1.4) * scale_val
		seg.position = Vector3(x, z + 0.8 * scale_val, y)
		seg.rotation.y = -p.h
		seg.material_override = hedge_mat
		hedge_root.add_child(seg)
