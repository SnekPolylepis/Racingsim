@tool
class_name Billboards
extends Node3D
## Trackside advertising billboards (REBUILD-PLAN.md P3-04 / scenery-kit): boards mounted on posts
## beside the road, spaced along the road with flat retro colors and deterministic placement.
## Bakes to Scenery/<name> as a single MultiMeshInstance3D. No collision.

enum Side { LEFT, RIGHT }

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export_enum("Left", "Right") var side = 1
## Metres beyond verge outer edge.
@export var offset = 6.0
@export var from_m = 0.0
@export var to_m = -1.0
@export_range(10.0, 100.0, 5.0) var spacing = 35.0
@export var random_seed = 12345

@export_group("Dimensions")
@export var board_width = 6.0
@export var board_height = 2.2
@export var board_elevation = 1.6
@export var post_radius = 0.1

@export_group("")
@export_tool_button("Bake Billboards", "Callable") var bake_button = bake

var last_bake = {}


## Generates the procedural billboard mesh (posts, frame, and retro-striped board).
static func billboard_mesh(w: float, h: float, elev: float, r_post: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var col_post = Color(0.25, 0.26, 0.28)
	var col_frame = Color(0.18, 0.18, 0.20)
	var col_bg = Color(0.92, 0.92, 0.94)
	var col_stripe1 = Color(0.85, 0.15, 0.12)
	var col_stripe2 = Color(0.15, 0.35, 0.75)

	var total_h = elev + h
	var post_spacing = w * 0.65

	# Left and right support posts
	var left_post = Vector3(-post_spacing * 0.5, total_h * 0.5, 0)
	var right_post = Vector3(post_spacing * 0.5, total_h * 0.5, 0)
	SceneryBuilder.add_box(st, left_post, Vector3(r_post * 2.0, total_h, r_post * 2.0), col_post)
	SceneryBuilder.add_box(st, right_post, Vector3(r_post * 2.0, total_h, r_post * 2.0), col_post)

	# Diagonal rear support struts
	var strut_base_z = -1.5
	var strut_h = elev + h * 0.5
	var strut_mid_l = Vector3(-post_spacing * 0.5, strut_h * 0.5, strut_base_z * 0.5)
	var strut_mid_r = Vector3(post_spacing * 0.5, strut_h * 0.5, strut_base_z * 0.5)
	SceneryBuilder.add_box(st, strut_mid_l, Vector3(r_post * 1.5, strut_h, 0.08), col_post)
	SceneryBuilder.add_box(st, strut_mid_r, Vector3(r_post * 1.5, strut_h, 0.08), col_post)

	# Outer border/frame
	var frame_center = Vector3(0, elev + h * 0.5, 0.05)
	var frame_size = Vector3(w, h, 0.12)
	SceneryBuilder.add_box(st, frame_center, frame_size, col_frame)

	# Board face with retro racing stripes (facing +Z, toward oncoming traffic)
	var z_face = 0.12
	var hw = (w - 0.2) * 0.5
	var y_bot = elev + 0.1
	var y_top = elev + h - 0.1
	var y_s1 = y_bot + (y_top - y_bot) * 0.33
	var y_s2 = y_bot + (y_top - y_bot) * 0.66

	# Lower band (retro blue)
	var p00 = Vector3(-hw, y_bot, z_face)
	var p10 = Vector3(hw, y_bot, z_face)
	var p11 = Vector3(hw, y_s1, z_face)
	var p01 = Vector3(-hw, y_s1, z_face)
	SceneryBuilder.add_quad(st, p00, p10, p11, p01, col_stripe2)

	# Middle band (white / cream)
	var p20 = Vector3(-hw, y_s1, z_face)
	var p30 = Vector3(hw, y_s1, z_face)
	var p31 = Vector3(hw, y_s2, z_face)
	var p21 = Vector3(-hw, y_s2, z_face)
	SceneryBuilder.add_quad(st, p20, p30, p31, p21, col_bg)

	# Upper band (retro red)
	var p40 = Vector3(-hw, y_s2, z_face)
	var p50 = Vector3(hw, y_s2, z_face)
	var p51 = Vector3(hw, y_top, z_face)
	var p41 = Vector3(-hw, y_top, z_face)
	SceneryBuilder.add_quad(st, p40, p50, p51, p41, col_stripe1)

	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(mat)
	return st.commit()


## Computes instance transforms for each billboard.
func layout() -> Dictionary:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	var out = {"xforms": [], "stations": []}
	if road == null:
		return out

	var c = road.working_curve()
	var length = c.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)

	var start = clampf(from_m, 0.0, length)
	var stop = length if to_m < 0 else clampf(to_m, 0.0, length)
	var span = stop - start
	if road.closed and stop <= start:
		span += length

	var count = maxi(1, int(floor(span / spacing)))
	var side_sign = -1 if side == Side.LEFT else 1
	var rng = RandomNumberGenerator.new()
	rng.seed = random_seed

	for i in count:
		# Deterministic station spacing with slight jitter
		var s = start + spacing * (i + 0.5) + rng.randf_range(-spacing * 0.1, spacing * 0.1)
		s = fposmod(s, length) if road.closed else clampf(s, 0.0, length)
		var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
		var st_info = RoadBuilder.station_at(c, road.closed, length, spline, s)

		var pos = road.transform * e.point
		var fwd = (road.transform.basis * st_info.tangent).normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 1e-4:
			fwd = Vector3.FORWARD
		else:
			fwd = fwd.normalized()
		var right = fwd.cross(Vector3.UP).normalized()

		# Angle board slightly toward oncoming traffic (yaw toward track)
		var angle_offset = deg_to_rad(-15.0 if side == Side.RIGHT else 15.0)
		var board_fwd = -fwd.rotated(Vector3.UP, angle_offset)
		var board_right = board_fwd.cross(Vector3.UP).normalized()
		var b = Basis(board_right, Vector3.UP, board_fwd)

		out.xforms.append(Transform3D(b, pos))
		out.stations.append(s)

	return out


func bake() -> void:
	var l = layout()
	if l.xforms.is_empty():
		push_error("Billboards %s: no instances to bake" % name)
		return

	var mesh = billboard_mesh(board_width, board_height, board_elevation, post_radius)

	var prep = SceneryBuilder.prepare_container(self, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = l.xforms.size()
	for i in l.xforms.size():
		mm.set_instance_transform(i, l.xforms[i])

	var inst = MultiMeshInstance3D.new()
	inst.name = name
	inst.multimesh = mm
	scenery.add_child(inst)
	inst.owner = owner_node

	last_bake = {"count": l.xforms.size(), "stations": l.stations}
