@tool
class_name RoadPath
extends Path3D
## An authored road (REBUILD-PLAN.md P3-02). Draw the centreline as this Path3D's curve, add
## RoadSection keys in the Inspector, and press Bake road. Baking uses scripts/track/road_builder.gd.
##
## Placed directly under a TrackAsset, baking fills in the asset's structure (5.3):
##   Road/<name>             render mesh, one surface per surface type
##   Surfaces/<name>_s<id>   StaticBody3D collision per surface type (layer 1, metadata "surface")
##   TimingLine              the road centre, if `drives_timing` (one road per asset should)
##   Grid/Slot<n>            `grid_slots` staggered slots behind the start (s = 0), on the road surface
## Anywhere else it bakes Road/ and Surfaces/ as its own children. Re-baking replaces its own output.
## Junctions and pit lanes are out of scope for v1: model them by hand.

const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const GRID_SOURCE_META = "_road_path_source"

@export var sections: Array[RoadSection] = []
## A closed road joins its end back to its start (the curve does not need to repeat its first point).
@export var closed = true
## Station spacing along the road, metres (never more than 1.5, P3-00).
@export_range(.25, 1.5, .05) var along_step = 1.5
@export var drives_timing = true
@export_range(0, 40) var grid_slots = 4
@export_tool_button("Bake road", "Callable") var bake_button = bake

var last_bake = {}


## Curve to bake: this path's curve, closed with a copy of its first point if needed.
func working_curve() -> Curve3D:
	var c = curve.duplicate() as Curve3D
	if closed and c.point_count > 2:
		var first = c.get_point_position(0)
		if first.distance_to(c.get_point_position(c.point_count - 1)) > 1e-3:
			c.add_point(first, c.get_point_in(0), c.get_point_out(0))
	c.bake_interval = .25
	return c


func bake():
	if curve == null or curve.point_count < 2:
		push_error("RoadPath %s: draw a curve with at least two points first" % name)
		return
	var result = RoadBuilder.bake(working_curve(), sections, closed, along_step)
	last_bake = result
	if result.max_twist_deg_per_m > RoadBuilder.TWIST_WARN_DEG_PER_M:
		push_warning(
			(
				"RoadPath %s: bank changes %.2f deg/m at %.0f m (over %.2f). Stiff cars will lift a wheel; spread the bank change over more distance."
				% [name, result.max_twist_deg_per_m, result.max_twist_at_m, RoadBuilder.TWIST_WARN_DEG_PER_M]
			)
		)
	var host = get_parent() if get_parent() != null and get_parent().has_method("record_key") else self
	var owner_node = host.owner if host.owner != null else host
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		owner_node = get_tree().edited_scene_root
	var road_group = group(host, "Road", owner_node)
	var surface_group = group(host, "Surfaces", owner_node)
	replace(road_group, name, owner_node, mesh_node(result))
	for child in surface_group.get_children():
		if str(child.name).begins_with(str(name) + "_s"):
			surface_group.remove_child(child)
			child.free()
	for sid in result.faces:
		var body = StaticBody3D.new()
		body.name = "%s_s%d" % [name, sid]
		body.set_meta("surface", int(sid))
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(result.faces[sid])
		var col = CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		surface_group.add_child(body)
		body.owner = owner_node
		col.owner = owner_node
	if host != self and drives_timing:
		timing(host, result, owner_node)
		slots(host, result, owner_node)


func mesh_node(result) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = RoadBuilder.mesh(result.faces, result.uvs)
	return m


static func group(host, group_name, owner_node) -> Node3D:
	var g = host.get_node_or_null(group_name)
	if g == null:
		g = Node3D.new()
		g.name = group_name
		host.add_child(g)
		g.owner = owner_node
	return g


static func replace(parent, node_name, owner_node, node):
	var old = parent.get_node_or_null(NodePath(str(node_name)))
	if old != null:
		parent.remove_child(old)
		old.free()
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node


## TimingLine from the road centre (surface height, crown included). The asset closes it implicitly,
## so the start is not repeated at the end.
func timing(host, result, owner_node):
	var path = host.get_node_or_null("TimingLine")
	if path == null:
		path = Path3D.new()
		path.name = "TimingLine"
		host.add_child(path)
		path.owner = owner_node
	var c = Curve3D.new()
	c.bake_interval = 1.0
	for p in result.center:
		c.add_point(p)
	path.curve = c
	if not path.has_meta("start_offset_m"):
		path.set_meta("start_offset_m", 0.0)


## Grid slots behind the start line, staggered 2 m either side of the centre, 9 m apart, 12 m back.
func slots(host, result, owner_node):
	var grid = group(host, "Grid", owner_node)
	# Keep authored slots and output from other roads. Only markers tagged by this path are ours.
	for child in grid.get_children():
		if str(child.get_meta(GRID_SOURCE_META, "")) == str(name):
			grid.remove_child(child)
			child.free()
	var st = result.stations
	var spacing = result.length / st.size()
	var keys = sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	for k in grid_slots:
		var back = 12.0 + 9.0 * k
		var i = (
			posmod(-int(round(back / spacing)), st.size())
			if closed
			else clampi(int(round(back / spacing)), 0, st.size() - 1)
		)
		var station = st[i]
		var sec = RoadBuilder.section_at(keys, station.s, result.length, closed)
		var fr = RoadBuilder.frame(station.tangent, sec.bank_deg)
		var lat = 2.0 if k % 2 else -2.0
		var u = lat / (sec.width_right if lat > 0 else sec.width_left)
		var ground = station.pos + fr[0] * lat + fr[1] * (sec.crown * (1 - u * u))
		var m = Marker3D.new()
		m.name = "Slot%d" % (k + 1)
		m.set_meta(GRID_SOURCE_META, str(name))
		m.transform = Transform3D(Basis(fr[0], fr[1], -station.tangent).orthonormalized(), ground)
		grid.add_child(m)
		m.owner = owner_node
