@tool
class_name CatchFence
extends Node3D
## Trackside catch fence (REBUILD-PLAN.md P3-04 / scenery-kit): steel posts every ~3 m with mesh panels
## 3-4 m high. Follows a RoadPath (verge offset) or a WallPath (along or on top of a barrier).
## Bakes visual posts (MultiMesh) and panels to Scenery/<name>.
## Collision on layer 2 (wall_kind "armco") is created only if `solid` is true.

enum Side { LEFT, RIGHT }

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export var follow_wall: NodePath
@export_enum("Left", "Right") var side = 1
## Metres beyond verge outer edge (for follow_road) or beyond wall back/top (for follow_wall).
@export var offset = 0.5
@export var from_m = 0.0
@export var to_m = -1.0
@export_range(1.0, 10.0, 0.5) var post_spacing = 3.0

@export_group("Dimensions & Collision")
@export_range(2.0, 6.0, 0.1) var fence_height = 3.5
@export var post_thickness = 0.08
## If true, creates a StaticBody3D on layer 2 under Walls/<name> with wall_kind "armco".
@export var solid = false

@export_group("")
@export_tool_button("Bake CatchFence", "Callable") var bake_button = bake

var last_bake = {}


## Computes fence base points and outward normals in host coordinates.
func line() -> Dictionary:
	var base = PackedVector3Array()
	var outward = PackedVector3Array()
	var wall = get_node_or_null(follow_wall) if not follow_wall.is_empty() else null
	if wall != null and wall.has_method("line"):
		var wl = wall.line()
		if wl.base.size() >= 2:
			var w_dims = wall.dimensions()
			var wall_h = w_dims.x
			var wall_t = w_dims.y
			# Fence sits on top of or slightly behind the wall
			for i in wl.base.size():
				var p = wl.base[i] + wl.outward[i] * (wall_t + offset)
				p.y += wall_h
				base.append(p)
				outward.append(wl.outward[i])
			return {"base": base, "outward": outward, "closed": wl.get("closed", false)}

	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	if road != null:
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
		var count = maxi(1, int(ceil(span / post_spacing)))
		var side_sign = -1 if side == Side.LEFT else 1
		var full_loop = road.closed and span >= length - 1e-6
		for i in count if full_loop else count + 1:
			var s = start + span * i / count
			var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
			base.append(road.transform * e.point)
			outward.append((road.transform.basis * e.outward).normalized())
		return {"base": base, "outward": outward, "closed": full_loop}

	return {"base": base, "outward": outward, "closed": false}


func bake() -> void:
	var l = line()
	if l.base.size() < 2:
		push_error("CatchFence %s: nothing to follow (set follow_road or follow_wall)" % name)
		return

	var post_mesh = SceneryBuilder.box_mesh(
		Vector3(post_thickness, fence_height, post_thickness), Color(0.24, 0.25, 0.28)
	)

	var xforms = []
	for i in l.base.size():
		var p = l.base[i] + Vector3(0, fence_height * 0.5, 0)
		var fwd = Vector3.FORWARD
		if i + 1 < l.base.size():
			fwd = (l.base[i + 1] - l.base[i]).normalized()
		elif i > 0:
			fwd = (l.base[i] - l.base[i - 1]).normalized()
		fwd.y = 0.0
		if fwd.length_squared() < 1e-4:
			fwd = Vector3.FORWARD
		else:
			fwd = fwd.normalized()
		var right = fwd.cross(Vector3.UP).normalized()
		var b = Basis(right, Vector3.UP, fwd)
		xforms.append(Transform3D(b, p))

	# SurfaceTool for mesh panels between posts
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var panel_col = Color(0.5, 0.53, 0.56)
	var n_panels = l.base.size() if l.closed else l.base.size() - 1
	var collision_faces = PackedVector3Array()

	var dist = [0.0]
	for k in range(1, l.base.size()):
		dist.append(dist[-1] + l.base[k - 1].distance_to(l.base[k]))

	for i in n_panels:
		var j = (i + 1) % l.base.size()
		var b0 = l.base[i]
		var b1 = l.base[j]
		var t0 = b0 + Vector3(0, fence_height, 0)
		var t1 = b1 + Vector3(0, fence_height, 0)

		var s0 = dist[i]
		var s1 = s0 + b0.distance_to(b1)

		# Visual panel quads with true metre UV coordinates for fence.gdshader
		SceneryBuilder.add_uv_quad(
			st,
			b0,
			b1,
			t1,
			t0,
			Vector2(s0, 0.0),
			Vector2(s1, 0.0),
			Vector2(s1, fence_height),
			Vector2(s0, fence_height),
			panel_col
		)
		SceneryBuilder.add_uv_quad(
			st,
			b1,
			b0,
			t0,
			t1,
			Vector2(s1, 0.0),
			Vector2(s0, 0.0),
			Vector2(s0, fence_height),
			Vector2(s1, fence_height),
			panel_col
		)

		if solid:
			collision_faces.append_array(PackedVector3Array([b0, b1, t1, b0, t1, t0]))
			collision_faces.append_array(PackedVector3Array([b1, b0, t0, b1, t0, t1]))

	st.generate_normals()
	var panel_mat = SceneryBuilder.fence_material()
	st.set_material(panel_mat)
	var panels_mesh = st.commit()

	# Destination in Scenery/
	var prep = SceneryBuilder.prepare_container(self, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var group = Node3D.new()
	group.name = name
	scenery.add_child(group)
	group.owner = owner_node

	var mm_inst = SceneryBuilder.make_multimesh(post_mesh, xforms)
	mm_inst.name = "Posts"
	group.add_child(mm_inst)
	mm_inst.owner = owner_node

	var panel_inst = MeshInstance3D.new()
	panel_inst.name = "Panels"
	panel_inst.mesh = panels_mesh
	group.add_child(panel_inst)
	panel_inst.owner = owner_node

	# Destination in Walls/ if solid
	var host = prep.host
	var walls = host.get_node_or_null("Walls")
	if walls != null:
		var old_wall = walls.get_node_or_null(NodePath(str(name)))
		if old_wall != null:
			walls.remove_child(old_wall)
			old_wall.free()

	if solid and not collision_faces.is_empty():
		if walls == null:
			walls = Node3D.new()
			walls.name = "Walls"
			host.add_child(walls)
			walls.owner = owner_node
		var body = SceneryBuilder.make_wall_body(
			name, collision_faces, "armco", l.base, l.outward, fence_height, post_thickness
		)
		walls.add_child(body)
		body.owner = owner_node
		for c in body.get_children():
			c.owner = owner_node

	last_bake = {
		"line": l.base,
		"outward": l.outward,
		"posts_count": xforms.size(),
		"panels_count": n_panels,
		"solid": solid
	}
