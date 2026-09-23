@tool
class_name Gantry
extends Node3D
## Start/finish gantry (REBUILD-PLAN.md P3-04 / scenery-kit): spans the road at a station with two
## towers outside the verge, an overhead crossbeam, and an optional start/finish light panel.
## No collision on the road.

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export var station = 0.0
## Metres beyond the road verge outer edge on each side.
@export var extra_width = 3.0

@export_group("Dimensions")
@export var clearance_height = 6.0
@export var tower_size = Vector3(0.8, 0.0, 0.8)
@export var beam_height = 1.0
@export var beam_depth = 0.8
@export var light_panel = true

@export_group("")
@export_tool_button("Bake Gantry", "Callable") var bake_button = bake

var last_bake = {}


func bake() -> void:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	if road == null:
		push_error("Gantry %s: follow_road is not set" % name)
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

	var st_info = RoadBuilder.station_at(c, road.closed, length, spline, station)
	var e_left = RoadBuilder.beyond_edge(c, keys, road.closed, spline, station, -1, extra_width)
	var e_right = RoadBuilder.beyond_edge(c, keys, road.closed, spline, station, 1, extra_width)

	var p_left = road.transform * e_left.point
	var p_right = road.transform * e_right.point
	var p_center = road.transform * st_info.pos
	var fwd = (road.transform.basis * st_info.tangent).normalized()
	fwd.y = 0.0
	if fwd.length_squared() < 1e-4:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var right = fwd.cross(Vector3.UP).normalized()

	var base_y = minf(p_left.y, minf(p_right.y, p_center.y))
	var top_y = p_center.y + clearance_height + beam_height
	var left_tower_h = top_y - p_left.y
	var right_tower_h = top_y - p_right.y

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var col_steel = Color(0.28, 0.30, 0.33)
	var col_beam = Color(0.35, 0.37, 0.40)
	var col_housing = Color(0.12, 0.12, 0.14)
	var col_red_light = Color(0.95, 0.15, 0.15)
	var col_green_light = Color(0.15, 0.85, 0.2)

	# Left tower
	var left_center = Vector3(p_left.x, p_left.y + left_tower_h * 0.5, p_left.z)
	SceneryBuilder.add_box(st, left_center, Vector3(tower_size.x, left_tower_h, tower_size.z), col_steel)

	# Right tower
	var right_center = Vector3(p_right.x, p_right.y + right_tower_h * 0.5, p_right.z)
	SceneryBuilder.add_box(st, right_center, Vector3(tower_size.x, right_tower_h, tower_size.z), col_steel)

	# Overhead crossbeam spanning between towers
	var span_vec = p_right - p_left
	span_vec.y = 0.0
	var span_len = span_vec.length()
	var beam_center = Vector3(
		(p_left.x + p_right.x) * 0.5, top_y - beam_height * 0.5, (p_left.z + p_right.z) * 0.5
	)

	# Build rotated box for crossbeam
	var beam_h = beam_height * 0.5
	var beam_w = span_len * 0.5
	var beam_d = beam_depth * 0.5
	var b_corners = [
		beam_center - right * beam_w - Vector3.UP * beam_h - fwd * beam_d,
		beam_center + right * beam_w - Vector3.UP * beam_h - fwd * beam_d,
		beam_center + right * beam_w - Vector3.UP * beam_h + fwd * beam_d,
		beam_center - right * beam_w - Vector3.UP * beam_h + fwd * beam_d,
		beam_center - right * beam_w + Vector3.UP * beam_h - fwd * beam_d,
		beam_center + right * beam_w + Vector3.UP * beam_h - fwd * beam_d,
		beam_center + right * beam_w + Vector3.UP * beam_h + fwd * beam_d,
		beam_center - right * beam_w + Vector3.UP * beam_h + fwd * beam_d
	]
	var quads = [[3, 2, 6, 7], [1, 0, 4, 5], [4, 5, 6, 7], [0, 1, 2, 3], [0, 3, 7, 4], [2, 1, 5, 6]]
	st.set_color(col_beam)
	for q in quads:
		for idx in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(b_corners[idx])

	# Start/finish light panel
	if light_panel:
		var panel_w = 4.0
		var panel_h = 1.0
		var panel_d = 0.3
		var panel_center = beam_center - Vector3.UP * (beam_height * 0.5 + panel_h * 0.5)
		var p_hw = panel_w * 0.5
		var p_hh = panel_h * 0.5
		var p_hd = panel_d * 0.5
		var p_corners = [
			panel_center - right * p_hw - Vector3.UP * p_hh - fwd * p_hd,
			panel_center + right * p_hw - Vector3.UP * p_hh - fwd * p_hd,
			panel_center + right * p_hw - Vector3.UP * p_hh + fwd * p_hd,
			panel_center - right * p_hw - Vector3.UP * p_hh + fwd * p_hd,
			panel_center - right * p_hw + Vector3.UP * p_hh - fwd * p_hd,
			panel_center + right * p_hw + Vector3.UP * p_hh - fwd * p_hd,
			panel_center + right * p_hw + Vector3.UP * p_hh + fwd * p_hd,
			panel_center - right * p_hw + Vector3.UP * p_hh + fwd * p_hd
		]
		st.set_color(col_housing)
		for q in quads:
			for idx in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.add_vertex(p_corners[idx])

		# 5 pairs of lights across the panel on front face (-fwd, facing oncoming traffic)
		for k in 5:
			var lat_offset = (k - 2) * 0.7
			var light_base = panel_center + right * lat_offset - fwd * (p_hd + 0.02)
			# Upper red light
			SceneryBuilder.add_box(
				st, light_base + Vector3.UP * 0.22, Vector3(0.25, 0.25, 0.05), col_red_light
			)
			# Lower green light
			SceneryBuilder.add_box(
				st, light_base - Vector3.UP * 0.22, Vector3(0.25, 0.25, 0.05), col_green_light
			)

	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(mat)
	var gantry_mesh = st.commit()

	var prep = SceneryBuilder.prepare_container(self, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = gantry_mesh
	scenery.add_child(inst)
	inst.owner = owner_node

	last_bake = {
		"station": station,
		"clearance_height": clearance_height,
		"span_length": span_len,
		"light_panel": light_panel
	}
