@tool
class_name Grandstand
extends Node3D
## Trackside grandstand (REBUILD-PLAN.md P3-04 / scenery-kit): stepped seating block with optional roof,
## placed at a station and offset along a road.
## Front barrier collision on layer 2 (wall_kind "concrete") is created if `solid_front` is true.

enum Side { LEFT, RIGHT }

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const NightGlow = preload("res://scripts/track/night_glow.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export var station = 0.0
@export_enum("Left", "Right") var side = 1
## Metres beyond verge outer edge.
@export var offset = 6.0
@export var length_m = 40.0
@export var step_m = 2.5

@export_group("Seating & Structure")
@export_range(2, 30, 1) var rows = 8
@export_range(0.4, 2.0, 0.1) var row_depth = 0.8
@export_range(0.2, 1.0, 0.05) var row_height = 0.4
@export var has_roof = true
@export_range(3.0, 12.0, 0.5) var roof_height = 5.0
@export var has_crowd = true
## If true, creates a concrete front barrier on layer 2 under Walls/<name>.
@export var solid_front = true

@export_group("")
@export_tool_button("Bake Grandstand", "Callable") var bake_button = bake

var last_bake = {}


func bake() -> void:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	if road == null:
		push_error("Grandstand %s: follow_road is not set" % name)
		return

	var c = road.working_curve()
	var length = c.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)

	var s_start = station - length_m * 0.5
	var s_end = station + length_m * 0.5
	var count = maxi(1, int(ceil(length_m / step_m)))
	var side_sign = -1 if side == Side.LEFT else 1

	var slices = []
	var front_line = PackedVector3Array()
	var front_outward = PackedVector3Array()

	for i in count + 1:
		var s = s_start + length_m * i / count
		var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
		var p0 = road.transform * e.point
		var out_vec = (road.transform.basis * e.outward).normalized()
		var up_vec = (road.transform.basis * e.up).normalized()
		slices.append({"point": p0, "outward": out_vec, "up": up_vec})
		front_line.append(p0)
		front_outward.append(out_vec)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col_concrete = Color(0.72, 0.73, 0.75)
	var col_seats = Color(0.2, 0.45, 0.78)
	var col_roof = Color(0.35, 0.38, 0.42)
	var col_pillars = Color(0.25, 0.26, 0.28)

	var st_crowd = SurfaceTool.new()
	if has_crowd:
		st_crowd.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build tiers along slices
	for i in count:
		var sl0 = slices[i]
		var sl1 = slices[i + 1]

		# Bottom slab
		var b0 = sl0.point - sl0.up * 0.2
		var b1 = sl1.point - sl1.up * 0.2
		var total_depth = rows * row_depth
		var total_rise = rows * row_height

		# Steps / seats
		for r in rows:
			var d0 = r * row_depth
			var d1 = (r + 1) * row_depth
			var h0 = r * row_height
			var h1 = (r + 1) * row_height

			# Seat tread (horizontal)
			var t0_in = sl0.point + sl0.outward * d0 + sl0.up * h0
			var t1_in = sl1.point + sl1.outward * d0 + sl1.up * h0
			var t0_out = sl0.point + sl0.outward * d1 + sl0.up * h0
			var t1_out = sl1.point + sl1.outward * d1 + sl1.up * h0
			SceneryBuilder.add_quad(st, t0_in, t1_in, t1_out, t0_out, col_seats)

			# Riser (vertical)
			var r0_top = sl0.point + sl0.outward * d1 + sl0.up * h1
			var r1_top = sl1.point + sl1.outward * d1 + sl1.up * h1
			SceneryBuilder.add_quad(st, t0_out, t1_out, r1_top, r0_top, col_concrete)

			# Crowd cards on tier
			if has_crowd:
				var c0_bot = t0_in + sl0.outward * 0.15
				var c1_bot = t1_in + sl1.outward * 0.15
				var c0_top = c0_bot + sl0.up * 0.65
				var c1_top = c1_bot + sl1.up * 0.65
				var u0 = float(i) * step_m / 4.0
				var u1 = float(i + 1) * step_m / 4.0
				SceneryBuilder.add_uv_quad(
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

		# Back wall
		var bk0_bot = sl0.point + sl0.outward * total_depth - sl0.up * 0.2
		var bk1_bot = sl1.point + sl1.outward * total_depth - sl1.up * 0.2
		var bk0_top = sl0.point + sl0.outward * total_depth + sl0.up * total_rise
		var bk1_top = sl1.point + sl1.outward * total_depth + sl1.up * total_rise
		SceneryBuilder.add_quad(st, bk0_bot, bk1_bot, bk1_top, bk0_top, col_concrete)

		# Roof if enabled
		if has_roof:
			var rf0_back = bk0_top + sl0.up * roof_height
			var rf1_back = bk1_top + sl1.up * roof_height
			# Roof overhangs forward over rows
			var rf0_front = sl0.point - sl0.outward * 0.5 + sl0.up * (total_rise + roof_height + 1.0)
			var rf1_front = sl1.point - sl1.outward * 0.5 + sl1.up * (total_rise + roof_height + 1.0)
			# Top and bottom faces of canopy
			SceneryBuilder.add_quad(st, rf0_back, rf1_back, rf1_front, rf0_front, col_roof)
			SceneryBuilder.add_quad(st, rf0_front, rf1_front, rf1_back, rf0_back, col_roof)

	# End caps (left and right sides of grandstand)
	for idx in [0, count]:
		var sl = slices[idx]
		var total_depth = rows * row_depth
		var total_rise = rows * row_height
		var p_base = sl.point - sl.up * 0.2
		var p_back_base = sl.point + sl.outward * total_depth - sl.up * 0.2
		var p_back_top = sl.point + sl.outward * total_depth + sl.up * total_rise

		if idx == 0:
			SceneryBuilder.add_quad(st, p_base, p_back_base, p_back_top, sl.point, col_concrete)
		else:
			SceneryBuilder.add_quad(st, p_back_base, p_base, sl.point, p_back_top, col_concrete)

		# Pillars for roof
		if has_roof:
			var post_top = p_back_top + sl.up * roof_height
			SceneryBuilder.add_box(
				st, (p_back_top + post_top) * 0.5, Vector3(0.3, roof_height, 0.3), col_pillars
			)

	st.generate_normals()
	st.set_material(NightGlow.facade_material())
	var grandstand_mesh = st.commit()

	if has_crowd:
		st_crowd.generate_normals()
		st_crowd.set_material(SceneryBuilder.crowd_material())
		st_crowd.commit(grandstand_mesh)

	# Container in Scenery/
	var prep = SceneryBuilder.prepare_container(self, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = grandstand_mesh
	scenery.add_child(inst)
	inst.owner = owner_node

	# Front concrete wall on layer 2 if solid_front
	var host = prep.host
	var walls = host.get_node_or_null("Walls")
	if walls != null:
		var old_wall = walls.get_node_or_null(NodePath(str(name)))
		if old_wall != null:
			walls.remove_child(old_wall)
			old_wall.free()

	if solid_front and front_line.size() >= 2:
		if walls == null:
			walls = Node3D.new()
			walls.name = "Walls"
			host.add_child(walls)
			walls.owner = owner_node
		var wall_h = 1.0
		var wall_t = 0.4
		var face_list = WallBuilder.faces(front_line, front_outward, wall_h, wall_t, false)
		var body = SceneryBuilder.make_wall_body(
			name, face_list, "concrete", front_line, front_outward, wall_h, wall_t
		)
		walls.add_child(body)
		body.owner = owner_node
		for child in body.get_children():
			child.owner = owner_node

	last_bake = {
		"station": station,
		"length_m": length_m,
		"rows": rows,
		"has_roof": has_roof,
		"solid_front": solid_front,
		"slices": slices.size()
	}
