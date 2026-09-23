@tool
class_name MarshalPost
extends Node3D
## Trackside marshal posts (REBUILD-PLAN.md P3-04 / scenery-kit): small observation cabins placed every
## N metres behind the barrier.
## Bakes to Scenery/<name> as a single MultiMeshInstance3D. No collision.

enum Side { LEFT, RIGHT }

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export_enum("Left", "Right") var side = 1
## Metres beyond verge outer edge (behind barrier).
@export var offset = 6.0
@export var from_m = 0.0
@export var to_m = -1.0
@export_range(50.0, 500.0, 10.0) var spacing = 150.0

@export_group("Cabin")
@export var cabin_size = Vector3(2.4, 2.4, 2.4)

@export_group("")
@export_tool_button("Bake MarshalPosts", "Callable") var bake_button = bake

var last_bake = {}


## Procedural marshal cabin mesh: base pedestal, waist-high lower wall, open viewing window facing track, roof and flag pole.
static func cabin_mesh(sz: Vector3) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var col_base = Color(0.82, 0.42, 0.12)  # Safety orange base
	var col_wall = Color(0.88, 0.88, 0.90)  # White/cream cabin wall
	var col_roof = Color(0.22, 0.24, 0.26)  # Dark slate roof
	var col_post = Color(0.30, 0.32, 0.35)  # Window posts
	var col_flag = Color(0.95, 0.85, 0.15)  # Yellow caution flag

	var hw = sz.x * 0.5
	var hh = sz.y * 0.5
	var hd = sz.z * 0.5
	var wall_thick = 0.15
	var waist_h = sz.y * 0.45

	# Concrete base plinth
	SceneryBuilder.add_box(
		st, Vector3(0, 0.1, 0), Vector3(sz.x + 0.4, 0.2, sz.z + 0.4), Color(0.65, 0.65, 0.68)
	)

	# Lower half walls (orange safety base)
	# Front lower wall
	SceneryBuilder.add_box(
		st, Vector3(0, waist_h * 0.5, hd - wall_thick * 0.5), Vector3(sz.x, waist_h, wall_thick), col_base
	)
	# Back wall (full height)
	SceneryBuilder.add_box(
		st, Vector3(0, hh, -hd + wall_thick * 0.5), Vector3(sz.x, sz.y, wall_thick), col_wall
	)
	# Left and right lower walls
	SceneryBuilder.add_box(
		st, Vector3(-hw + wall_thick * 0.5, waist_h * 0.5, 0), Vector3(wall_thick, waist_h, sz.z), col_base
	)
	SceneryBuilder.add_box(
		st, Vector3(hw - wall_thick * 0.5, waist_h * 0.5, 0), Vector3(wall_thick, waist_h, sz.z), col_base
	)

	# Corner pillars for open upper viewing windows
	var corner_w = 0.15
	var post_h = sz.y - waist_h
	var post_cy = waist_h + post_h * 0.5
	SceneryBuilder.add_box(
		st,
		Vector3(-hw + corner_w * 0.5, post_cy, hd - corner_w * 0.5),
		Vector3(corner_w, post_h, corner_w),
		col_post
	)
	SceneryBuilder.add_box(
		st,
		Vector3(hw - corner_w * 0.5, post_cy, hd - corner_w * 0.5),
		Vector3(corner_w, post_h, corner_w),
		col_post
	)

	# Overhanging roof
	var roof_h = 0.2
	var roof_overhang = 0.3
	SceneryBuilder.add_box(
		st,
		Vector3(0, sz.y + roof_h * 0.5, 0),
		Vector3(sz.x + roof_overhang * 2.0, roof_h, sz.z + roof_overhang * 2.0),
		col_roof
	)

	# Small yellow safety flag on roof corner
	var flag_pole_h = 1.0
	SceneryBuilder.add_box(
		st, Vector3(hw, sz.y + flag_pole_h * 0.5, hd), Vector3(0.04, flag_pole_h, 0.04), col_post
	)
	var flag_center = Vector3(hw + 0.2, sz.y + flag_pole_h - 0.15, hd)
	SceneryBuilder.add_box(st, flag_center, Vector3(0.4, 0.25, 0.02), col_flag)

	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	st.set_material(mat)
	return st.commit()


## Computes cabin transforms along the road.
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

	for i in count:
		var s = start + spacing * (i + 0.5)
		s = fposmod(s, length) if road.closed else clampf(s, 0.0, length)
		var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
		var pos = road.transform * e.point

		# Cabin faces toward track (front face +Z points along -outward)
		var track_dir = -(road.transform.basis * e.outward).normalized()
		track_dir.y = 0.0
		if track_dir.length_squared() < 1e-4:
			track_dir = Vector3.FORWARD
		else:
			track_dir = track_dir.normalized()
		var right = track_dir.cross(Vector3.UP).normalized()
		var b = Basis(right, Vector3.UP, track_dir)

		out.xforms.append(Transform3D(b, pos))
		out.stations.append(s)

	return out


func bake() -> void:
	var l = layout()
	if l.xforms.is_empty():
		push_error("MarshalPost %s: no instances to bake" % name)
		return

	var mesh = cabin_mesh(cabin_size)

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
