@tool
class_name RoadScatter
extends Node3D
## Scenery scattered beside a road (REBUILD-PLAN.md P3-04): trees, posts or any mesh, placed in a band
## `offset_min`..`offset_max` metres beyond the outer edge of a RoadPath's verge, on one or both sides,
## `per_100m` instances per 100 m per side, with random yaw and scale. Deterministic from `random_seed`: the
## same settings always bake the same layout. Bakes to Scenery/<name> of the enclosing TrackAsset as a
## single MultiMeshInstance3D (one draw call). Scenery has no collision.
## Ground height beyond the verge continues the verge's fall; terrain (P3-03) will replace that.

enum Sides { LEFT, RIGHT, BOTH }

const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export var follow_road: NodePath
## Sides: 0 left, 1 right, 2 both.
@export_enum("Left", "Right", "Both") var sides = 2
@export var offset_min = 4.0
@export var offset_max = 30.0
@export var per_100m = 12.0
@export var from_m = 0.0
## Range end along the road, metres; < 0 means the road's end. from_m > to_m wraps a closed road.
@export var to_m = -1.0
@export var random_seed = 1
@export var scale_min = .8
@export var scale_max = 1.3
## Mesh to scatter; empty uses a simple procedural conifer.
@export var mesh: Mesh
@export_tool_button("Bake scatter", "Callable") var bake_button = bake

var last_bake = {}


## Instance transforms, in the host's space: [Transform3D], plus each instance's distance beyond the
## verge edge and its station, for tests.
func layout() -> Dictionary:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	var out = {"xforms": [], "beyond": [], "s": []}
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
	var rng = RandomNumberGenerator.new()
	rng.seed = random_seed
	var signs = [-1, 1] if sides == Sides.BOTH else ([-1] if sides == Sides.LEFT else [1])
	for side_sign in signs:
		var count = int(round(span * per_100m / 100.0))
		for i in count:
			var s = start + rng.randf() * span
			var beyond = rng.randf_range(offset_min, offset_max)
			var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, beyond)
			var size = rng.randf_range(scale_min, scale_max)
			var yaw = rng.randf() * TAU
			var turn = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * size)
			out.xforms.append(Transform3D(turn, road.transform * e.point))
			out.beyond.append(beyond)
			out.s.append(fposmod(s, length))
	return out


func bake():
	var l = layout()
	last_bake = l
	var host = get_parent() if get_parent() != null and get_parent().has_method("record_key") else self
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		owner_node = get_tree().edited_scene_root
	var scenery = host.get_node_or_null("Scenery")
	if scenery == null:
		scenery = Node3D.new()
		scenery.name = "Scenery"
		host.add_child(scenery)
		scenery.owner = owner_node
	var old = scenery.get_node_or_null(NodePath(str(name)))
	if old != null:
		scenery.remove_child(old)
		old.free()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh if mesh != null else conifer()
	mm.instance_count = l.xforms.size()
	for i in l.xforms.size():
		mm.set_instance_transform(i, l.xforms[i])
	var inst = MultiMeshInstance3D.new()
	inst.name = name
	inst.multimesh = mm
	scenery.add_child(inst)
	inst.owner = owner_node


## A simple low-poly conifer (trunk and two cones), about 8 m tall at scale 1, base at the origin.
static func conifer() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# [base y, top y, base radius, top radius, colour]: trunk, lower and upper foliage cones.
	var parts = [
		[0.0, 1.5, .25, .2, Color(.35, .24, .15)],
		[1.2, 5.5, 2.2, 0.0, Color(.12, .3, .15)],
		[4.0, 8.0, 1.5, 0.0, Color(.14, .34, .17)]
	]
	for p in parts:
		st.set_color(p[4])
		var sides_n = 7
		for k in sides_n:
			var a0 = TAU * k / sides_n
			var a1 = TAU * (k + 1) / sides_n
			var b0 = Vector3(cos(a0) * p[2], p[0], sin(a0) * p[2])
			var b1 = Vector3(cos(a1) * p[2], p[0], sin(a1) * p[2])
			var t0 = Vector3(cos(a0) * p[3], p[1], sin(a0) * p[3])
			var t1 = Vector3(cos(a1) * p[3], p[1], sin(a1) * p[3])
			for v in [b0, t0, b1, b1, t0, t1]:
				st.add_vertex(v)
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()
