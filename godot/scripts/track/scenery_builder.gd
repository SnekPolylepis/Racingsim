@tool
class_name SceneryBuilder
extends RefCounted
## Procedural mesh and collision helpers for trackside scenery kit (REBUILD-PLAN.md P3-04 / scenery-kit).
## Builds low-poly geometry via SurfaceTool, MultiMesh instances for repeated items, and layer-2 StaticBody3D
## collisions for solid barriers (wall_kind armco or concrete).

const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")

const ARMCO_TEX_PATH = "res://assets/ps2/armco.png"
const TYRE_TEX_PATH = "res://assets/ps2/tyre.png"
const CONCRETE_TEX_PATH = "res://assets/ps2/concrete_floor_02_diff.png"
const CROWD_TEX_PATH = "res://assets/ps2/crowd.png"
const FENCE_SHADER_PATH = "res://shaders/fence.gdshader"

static var _mat_cache = {}


static func armco_material() -> StandardMaterial3D:
	if _mat_cache.has("armco"):
		return _mat_cache["armco"]
	var mat = StandardMaterial3D.new()
	if ResourceLoader.exists(ARMCO_TEX_PATH):
		mat.albedo_texture = load(ARMCO_TEX_PATH)
	else:
		mat.albedo_color = Color(0.72, 0.74, 0.76)
	mat.roughness = 0.5
	mat.metallic = 0.6
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache["armco"] = mat
	return mat


static func tyre_material() -> StandardMaterial3D:
	if _mat_cache.has("tyre"):
		return _mat_cache["tyre"]
	var mat = StandardMaterial3D.new()
	if ResourceLoader.exists(TYRE_TEX_PATH):
		mat.albedo_texture = load(TYRE_TEX_PATH)
	else:
		mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache["tyre"] = mat
	return mat


static func concrete_material() -> StandardMaterial3D:
	if _mat_cache.has("concrete"):
		return _mat_cache["concrete"]
	var mat = StandardMaterial3D.new()
	if ResourceLoader.exists(CONCRETE_TEX_PATH):
		mat.albedo_texture = load(CONCRETE_TEX_PATH)
	else:
		mat.albedo_color = Color(0.68, 0.68, 0.70)
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_mat_cache["concrete"] = mat
	return mat


static func crowd_material() -> StandardMaterial3D:
	if _mat_cache.has("crowd"):
		return _mat_cache["crowd"]
	var mat = StandardMaterial3D.new()
	if ResourceLoader.exists(CROWD_TEX_PATH):
		mat.albedo_texture = load(CROWD_TEX_PATH)
	else:
		mat.albedo_color = Color(0.85, 0.85, 0.85)
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat_cache["crowd"] = mat
	return mat


static func fence_material() -> ShaderMaterial:
	if _mat_cache.has("fence"):
		return _mat_cache["fence"]
	var mat = ShaderMaterial.new()
	if ResourceLoader.exists(FENCE_SHADER_PATH):
		mat.shader = load(FENCE_SHADER_PATH)
	_mat_cache["fence"] = mat
	return mat


## Resolve the host (enclosing TrackAsset or self) and container ("Scenery" or "Walls").
static func prepare_container(item: Node3D, container_name: String) -> Dictionary:
	var host = (
		item.get_parent()
		if item.get_parent() != null and item.get_parent().has_method("record_key")
		else item
	)
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and item.is_inside_tree() and item.get_tree().edited_scene_root != null:
		owner_node = item.get_tree().edited_scene_root
	var container = host.get_node_or_null(container_name)
	if container == null:
		container = Node3D.new()
		container.name = container_name
		host.add_child(container)
		container.owner = owner_node
	var old = container.get_node_or_null(NodePath(str(item.name)))
	if old != null:
		container.remove_child(old)
		old.free()
	return {"host": host, "container": container, "owner": owner_node}


## Appends a colored 3D box (6 faces, 12 triangles) to a SurfaceTool.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h = size * 0.5
	st.set_color(col)
	var corners = [
		center + Vector3(-h.x, -h.y, -h.z),  # 0: left bottom back
		center + Vector3(h.x, -h.y, -h.z),  # 1: right bottom back
		center + Vector3(h.x, -h.y, h.z),  # 2: right bottom front
		center + Vector3(-h.x, -h.y, h.z),  # 3: left bottom front
		center + Vector3(-h.x, h.y, -h.z),  # 4: left top back
		center + Vector3(h.x, h.y, -h.z),  # 5: right top back
		center + Vector3(h.x, h.y, h.z),  # 6: right top front
		center + Vector3(-h.x, h.y, h.z)  # 7: left top front
	]
	# 6 faces: front, back, top, bottom, left, right (CCW winding when viewed from outside)
	var quads = [[3, 2, 6, 7], [1, 0, 4, 5], [4, 5, 6, 7], [0, 1, 2, 3], [0, 3, 7, 4], [2, 1, 5, 6]]
	for q in quads:
		for idx in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(corners[idx])


## Low-poly box mesh.
static func box_mesh(size: Vector3, col: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(st, Vector3.ZERO, size, col)
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(mat)
	return st.commit()


## Low-poly prism/wedge mesh (e.g. for stepped grandstands or roof peaks).
static func add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)


## Appends a quad with UV coordinates to a SurfaceTool.
static func add_uv_quad(
	st: SurfaceTool,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2,
	uv3: Vector2,
	col: Color = Color.WHITE
) -> void:
	st.set_color(col)
	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_uv(uv1)
	st.add_vertex(p1)
	st.set_uv(uv2)
	st.add_vertex(p2)

	st.set_uv(uv0)
	st.add_vertex(p0)
	st.set_uv(uv2)
	st.add_vertex(p2)
	st.set_uv(uv3)
	st.add_vertex(p3)


## Build a MultiMeshInstance3D with TRANSFORM_3D format.
static func make_multimesh(mesh: Mesh, xforms: Array) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	return inst


## StaticBody3D on layer 2 only, with wall metadata and ConcavePolygonShape3D.
static func make_wall_body(
	body_name: String,
	face_list: PackedVector3Array,
	kind_name: String,
	wall_line: PackedVector3Array,
	wall_outward: PackedVector3Array,
	wall_h: float,
	wall_t: float
) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = body_name
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(2, true)
	body.collision_mask = 0
	body.set_meta("wall_kind", kind_name)
	body.set_meta("wall_line", wall_line)
	body.set_meta("wall_outward", wall_outward)
	body.set_meta("wall_height", wall_h)
	body.set_meta("wall_thickness", wall_t)
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(face_list)
	var col = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
	return body


## Generates a textured visual mesh with UV coordinates and PS2 materials for a wall.
static func wall_mesh(
	base: PackedVector3Array,
	outward: PackedVector3Array,
	height: float,
	thickness: float,
	closed: bool,
	kind: int
) -> ArrayMesh:
	var n = base.size()
	if n < 2:
		return null

	var dist = [0.0]
	for i in range(1, n):
		dist.append(dist[-1] + base[i - 1].distance_to(base[i]))

	var repeat_x = 3.0 if kind == 0 else (2.0 if kind == 1 else 4.0)
	var footing = WallBuilder.WALL_FOOTING
	var up = Vector3.UP

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var count = n if closed else n - 1
	for i in count:
		var j = (i + 1) % n
		var s0 = dist[i] / repeat_x
		var s1 = (dist[i] + base[i].distance_to(base[j])) / repeat_x

		var p_in_bot0 = base[i] - up * footing
		var p_in_bot1 = base[j] - up * footing
		var p_in_top0 = base[i] + up * height
		var p_in_top1 = base[j] + up * height

		var p_out_bot0 = p_in_bot0 + outward[i] * thickness
		var p_out_bot1 = p_in_bot1 + outward[j] * thickness
		var p_out_top0 = p_in_top0 + outward[i] * thickness
		var p_out_top1 = p_in_top1 + outward[j] * thickness

		# Inner face (facing track)
		add_uv_quad(
			st,
			p_in_bot0,
			p_in_bot1,
			p_in_top1,
			p_in_top0,
			Vector2(s0, 1.0),
			Vector2(s1, 1.0),
			Vector2(s1, 0.0),
			Vector2(s0, 0.0)
		)

		# Top face
		add_uv_quad(
			st,
			p_in_top0,
			p_in_top1,
			p_out_top1,
			p_out_top0,
			Vector2(s0, 0.0),
			Vector2(s1, 0.0),
			Vector2(s1, 0.3),
			Vector2(s0, 0.3)
		)

		# Outer face (back side)
		add_uv_quad(
			st,
			p_out_bot1,
			p_out_bot0,
			p_out_top0,
			p_out_top1,
			Vector2(s1, 1.0),
			Vector2(s0, 1.0),
			Vector2(s0, 0.0),
			Vector2(s1, 0.0)
		)

		# Bottom face
		add_uv_quad(
			st,
			p_out_bot0,
			p_out_bot1,
			p_in_bot1,
			p_in_bot0,
			Vector2(s0, 0.0),
			Vector2(s1, 0.0),
			Vector2(s1, 0.3),
			Vector2(s0, 0.3)
		)

	# End caps if open
	if not closed:
		# Front cap (at index 0)
		var p_in_b = base[0] - up * footing
		var p_in_t = base[0] + up * height
		var p_out_t = p_in_t + outward[0] * thickness
		var p_out_b = p_in_b + outward[0] * thickness
		add_uv_quad(
			st,
			p_out_b,
			p_in_b,
			p_in_t,
			p_out_t,
			Vector2(0, 1),
			Vector2(0.3, 1),
			Vector2(0.3, 0),
			Vector2(0, 0)
		)

		# End cap (at index n-1)
		var last = n - 1
		p_in_b = base[last] - up * footing
		p_in_t = base[last] + up * height
		p_out_t = p_in_t + outward[last] * thickness
		p_out_b = p_in_b + outward[last] * thickness
		add_uv_quad(
			st,
			p_in_b,
			p_out_b,
			p_out_t,
			p_in_t,
			Vector2(0, 1),
			Vector2(0.3, 1),
			Vector2(0.3, 0),
			Vector2(0, 0)
		)

	st.generate_normals()
	var mat = armco_material() if kind == 0 else (tyre_material() if kind == 1 else concrete_material())
	st.set_material(mat)
	return st.commit()


## Adds a lamp placement marker under a Lights node with kind, height, and colour metadata.
static func add_light_placement(
	lights: Node3D,
	owner_node: Node,
	lamp_name: String,
	pos: Vector3,
	fwd: Vector3,
	kind: String = "sodium_mast",
	height: float = 10.0,
	colour: Color = Color("#F2A14A")
) -> Marker3D:
	var marker = Marker3D.new()
	marker.name = lamp_name
	var up = Vector3.UP
	var right = fwd.cross(up).normalized()
	if right.length_squared() < 1e-4:
		right = Vector3.RIGHT
	var true_up = right.cross(fwd).normalized()
	marker.transform = Transform3D(Basis(right, true_up, -fwd), pos)
	marker.set_meta("kind", kind)
	marker.set_meta("height", height)
	marker.set_meta("colour", colour)
	lights.add_child(marker)
	marker.owner = owner_node
	return marker


## Builds a tiered spectator crowd bank (grassy steps with crowd cards, wooden fence, tents) in Scenery/.
static func build_crowd_bank(
	host: Node3D,
	road: Node3D,
	bank_name: String,
	station_m: float,
	length_m: float,
	side_sign: int,
	offset_m: float = 10.0,
	tiers: int = 3,
	has_tents: bool = true,
	has_rail: bool = true
) -> Node3D:
	if road == null:
		return null

	var c = road.working_curve()
	var length = c.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)

	var s_start = station_m - length_m * 0.5
	var step_m = 4.0
	var count = maxi(1, int(ceil(length_m / step_m)))

	var slices = []
	for i in count + 1:
		var s = s_start + length_m * i / count
		var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset_m)
		var p = road.transform * e.point
		var out_vec = (road.transform.basis * e.outward).normalized()
		var up_vec = (road.transform.basis * e.up).normalized()
		slices.append({"point": p, "outward": out_vec, "up": up_vec})

	var prep = prepare_container(host, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var group = Node3D.new()
	group.name = bank_name
	scenery.add_child(group)
	group.owner = owner_node

	# 1. Earth/grass tiered berms
	var st_earth = SurfaceTool.new()
	st_earth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_grass = Color(0.24, 0.38, 0.16)
	var col_earth = Color(0.38, 0.32, 0.22)

	var tier_depth = 2.0
	var tier_rise = 0.65
	var crowd_h = 0.75

	# 2. Crowd cards surface
	var st_crowd = SurfaceTool.new()
	st_crowd.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 3. Rails and posts
	var st_wood = SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_wood = Color(0.40, 0.32, 0.22)

	for i in count:
		var sl0 = slices[i]
		var sl1 = slices[i + 1]

		for tr in tiers:
			var d0 = tr * tier_depth
			var d1 = (tr + 1) * tier_depth
			var h0 = tr * tier_rise
			var h1 = (tr + 1) * tier_rise

			# Tread (grass step surface)
			var t0_in = sl0.point + sl0.outward * d0 + sl0.up * h0
			var t1_in = sl1.point + sl1.outward * d0 + sl1.up * h0
			var t0_out = sl0.point + sl0.outward * d1 + sl0.up * h0
			var t1_out = sl1.point + sl1.outward * d1 + sl1.up * h0
			add_quad(st_earth, t0_in, t1_in, t1_out, t0_out, col_grass)

			# Riser (earth face)
			var r0_top = sl0.point + sl0.outward * d1 + sl0.up * h1
			var r1_top = sl1.point + sl1.outward * d1 + sl1.up * h1
			add_quad(st_earth, t0_out, t1_out, r1_top, r0_top, col_earth)

			# Crowd card quad standing on tread, facing track
			var c0_bot = sl0.point + sl0.outward * (d0 + 0.3) + sl0.up * h0
			var c1_bot = sl1.point + sl1.outward * (d0 + 0.3) + sl1.up * h0
			var c0_top = c0_bot + sl0.up * crowd_h
			var c1_top = c1_bot + sl1.up * crowd_h
			var u0 = float(i) * step_m / 4.0
			var u1 = float(i + 1) * step_m / 4.0
			add_uv_quad(
				st_crowd,
				c0_bot,
				c1_bot,
				c1_top,
				c0_top,
				Vector2(u0, 1.0),
				Vector2(u1, 1.0),
				Vector2(u1, 0.0),
				Vector2(u0, 0.0)
			)

		# Wooden fence rail along front of tier 0
		if has_rail:
			var rl0_bot = sl0.point + sl0.up * 0.75 - sl0.outward * 0.1
			var rl1_bot = sl1.point + sl1.up * 0.75 - sl1.outward * 0.1
			var rl0_top = rl0_bot + sl0.up * 0.12
			var rl1_top = rl1_bot + sl1.up * 0.12
			add_quad(st_wood, rl0_bot, rl1_bot, rl1_top, rl0_top, col_wood)

	# Posts for front rail
	if has_rail:
		for i in count + 1:
			var sl = slices[i]
			var post_base = sl.point - sl.outward * 0.1
			add_box(st_wood, post_base + sl.up * 0.45, Vector3(0.12, 0.9, 0.12), col_wood)

	# Colorful spectator tents along the highest tier ridge
	var st_tents = SurfaceTool.new()
	st_tents.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tent_colors = [
		Color("f2f4f7"), Color("2252a8"), Color("b83228"), Color("286b3e"), Color("dca824"), Color("df6222")
	]

	if has_tents:
		var tent_stride = maxi(2, int(count / 5))
		for i in range(1, count, tent_stride):
			var sl = slices[i]
			var top_d = tiers * tier_depth + 1.2
			var top_h = tiers * tier_rise
			var tent_pos = sl.point + sl.outward * top_d + sl.up * (top_h + 0.8)
			var tent_col = tent_colors[i % tent_colors.size()]
			# Small pitched tent (apex along road direction)
			var tw = 1.8
			var td = 1.6
			var th = 1.2
			var fwd = (slices[mini(i + 1, count)].point - sl.point).normalized()
			fwd.y = 0.0
			if fwd.length_squared() < 1e-4:
				fwd = Vector3.FORWARD
			else:
				fwd = fwd.normalized()
			var rgt = sl.outward

			var t_apex0 = tent_pos - fwd * tw + sl.up * th
			var t_apex1 = tent_pos + fwd * tw + sl.up * th
			var t_l0 = tent_pos - fwd * tw - rgt * td
			var t_l1 = tent_pos + fwd * tw - rgt * td
			var t_r0 = tent_pos - fwd * tw + rgt * td
			var t_r1 = tent_pos + fwd * tw + rgt * td

			add_quad(st_tents, t_l0, t_l1, t_apex1, t_apex0, tent_col)
			add_quad(st_tents, t_apex0, t_apex1, t_r1, t_r0, tent_col)
			# Triangular end caps
			st_tents.set_color(tent_col.darkened(0.15))
			st_tents.add_vertex(t_l0)
			st_tents.add_vertex(t_apex0)
			st_tents.add_vertex(t_r0)
			st_tents.add_vertex(t_l1)
			st_tents.add_vertex(t_r1)
			st_tents.add_vertex(t_apex1)

	# Commit earth mesh
	st_earth.generate_normals()
	var earth_mat = StandardMaterial3D.new()
	earth_mat.vertex_color_use_as_albedo = true
	earth_mat.roughness = 0.95
	st_earth.set_material(earth_mat)
	var earth_mesh = st_earth.commit()
	var inst_earth = MeshInstance3D.new()
	inst_earth.name = "Berms"
	inst_earth.mesh = earth_mesh
	group.add_child(inst_earth)
	inst_earth.owner = owner_node

	# Commit crowd mesh
	st_crowd.generate_normals()
	st_crowd.set_material(crowd_material())
	var crowd_mesh = st_crowd.commit()
	var inst_crowd = MeshInstance3D.new()
	inst_crowd.name = "CrowdCards"
	inst_crowd.mesh = crowd_mesh
	group.add_child(inst_crowd)
	inst_crowd.owner = owner_node

	# Commit wood mesh
	if has_rail:
		st_wood.generate_normals()
		var wood_mat = StandardMaterial3D.new()
		wood_mat.vertex_color_use_as_albedo = true
		wood_mat.roughness = 0.8
		st_wood.set_material(wood_mat)
		var wood_mesh = st_wood.commit()
		var inst_wood = MeshInstance3D.new()
		inst_wood.name = "Rail"
		inst_wood.mesh = wood_mesh
		group.add_child(inst_wood)
		inst_wood.owner = owner_node

	# Commit tents mesh
	if has_tents:
		st_tents.generate_normals()
		var tents_mat = StandardMaterial3D.new()
		tents_mat.vertex_color_use_as_albedo = true
		tents_mat.roughness = 0.7
		st_tents.set_material(tents_mat)
		var tents_mesh = st_tents.commit()
		var inst_tents = MeshInstance3D.new()
		inst_tents.name = "Tents"
		inst_tents.mesh = tents_mesh
		group.add_child(inst_tents)
		inst_tents.owner = owner_node

	return group
