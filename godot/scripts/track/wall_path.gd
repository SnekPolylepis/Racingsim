@tool
class_name WallPath
extends Path3D
## A barrier (REBUILD-PLAN.md P3-04): armco, tyre wall or concrete, baked to Walls/<name> of the
## enclosing TrackAsset (collision layer 2 only, metadata per §5.3) with its own visual mesh.
##
## Two ways to place it:
##   Road-following: set `follow_road` to a RoadPath, a `side`, how far beyond the road's outer verge
##     edge (`offset`), and a range along the road (`from_m`..`to_m`; wraps on a closed road). The wall
##     follows the road's plan, bank and elevation, with its inner face facing the road.
##   Freehand: leave `follow_road` empty; the wall follows this path's own curve, facing `track_side`.
## Enum-typed exports are avoided (plain @export_enum ints): a new class_name script's own enum type
## does not resolve before the editor has registered the class.
## Suspension rays see only layer 1, so a car can never drive on top of a wall; the wall line, height
## and kind are stored as metadata for car-vs-wall collision (P4-03).

enum Side { LEFT, RIGHT }

const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")

## WallBuilder.Kind: 0 armco, 1 tyre, 2 concrete.
@export_enum("Armco", "Tyre", "Concrete") var kind = 0
## Height and thickness, metres; -1 uses the kind's default (armco 0.75 x 0.15, tyre 1.0 x 0.9,
## concrete 1.0 x 0.4).
@export var height = -1.0
@export var thickness = -1.0
@export_group("Road-following")
@export var follow_road: NodePath
## Side: 0 left, 1 right of the road's direction.
@export_enum("Left", "Right") var side = 1
## Metres beyond the outer edge of the road's verge on that side.
@export var offset = 1.0
## Range along the road, metres. to_m < 0 means the road's end; from_m > to_m wraps a closed road.
@export var from_m = 0.0
@export var to_m = -1.0
## Spacing of the wall's points along the road, metres.
@export_range(.5, 10.0, .5) var step_m = 2.0
@export_group("Freehand")
## For a freehand wall: which side of this path's direction the track is on.
@export_enum("Left", "Right") var track_side = 0
@export_group("")
@export_tool_button("Bake wall", "Callable") var bake_button = bake

var last_bake = {}


func dimensions() -> Vector2:
	var d = WallBuilder.SIZE[kind]
	return Vector2(height if height > 0 else d[0], thickness if thickness > 0 else d[1])


## Base points (inner face, at ground) and horizontal outward vectors, in the host's space.
func line() -> Dictionary:
	var base = PackedVector3Array()
	var outward = PackedVector3Array()
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
		var count = maxi(1, int(ceil(span / step_m)))
		var side_sign = -1 if side == Side.LEFT else 1
		# A wall round the whole of a closed road closes on itself (no end caps at the start line).
		var full_loop = road.closed and span >= length - 1e-6
		for i in count if full_loop else count + 1:
			var s = start + span * i / count
			var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
			base.append(road.transform * e.point)
			outward.append((road.transform.basis * e.outward).normalized())
		return {"base": base, "outward": outward, "closed": full_loop}
	if curve == null or curve.point_count < 2:
		return {"base": base, "outward": outward, "closed": false}
	var pts = curve.get_baked_points()
	var sign_free = 1.0 if track_side == Side.LEFT else -1.0
	for i in pts.size():
		var a = pts[maxi(i - 1, 0)]
		var b = pts[mini(i + 1, pts.size() - 1)]
		var tangent = b - a
		tangent.y = 0.0
		# Outward = away from the track: to the right of travel when the track is on the left.
		var right = tangent.normalized().cross(Vector3.UP)
		base.append(transform * pts[i])
		outward.append((transform.basis * (right * sign_free)).normalized())
	return {"base": base, "outward": outward, "closed": false}


func bake():
	var l = line()
	if l.base.size() < 2:
		push_error("WallPath %s: nothing to follow (set follow_road or draw a curve)" % name)
		return
	var dims = dimensions()
	var face_list = WallBuilder.faces(l.base, l.outward, dims.x, dims.y, l.closed)
	last_bake = {
		"line": l.base, "outward": l.outward, "height": dims.x, "thickness": dims.y, "faces": face_list
	}
	var host = get_parent() if get_parent() != null and get_parent().has_method("record_key") else self
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		owner_node = get_tree().edited_scene_root
	var walls = host.get_node_or_null("Walls")
	if walls == null:
		walls = Node3D.new()
		walls.name = "Walls"
		host.add_child(walls)
		walls.owner = owner_node
	var old = walls.get_node_or_null(NodePath(str(name)))
	if old != null:
		walls.remove_child(old)
		old.free()
	var body = StaticBody3D.new()
	body.name = name
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(2, true)
	body.set_meta("wall_kind", WallBuilder.NAMES[kind])
	body.set_meta("wall_line", l.base)
	body.set_meta("wall_outward", l.outward)
	body.set_meta("wall_height", dims.x)
	body.set_meta("wall_thickness", dims.y)
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(face_list)
	var col = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
	var vis = MeshInstance3D.new()
	vis.name = "Mesh"
	vis.mesh = SceneryBuilder.wall_mesh(l.base, l.outward, dims.x, dims.y, l.closed, kind)
	body.add_child(vis)
	walls.add_child(body)
	for n in [body, col, vis]:
		n.owner = owner_node
