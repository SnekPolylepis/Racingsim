@tool
class_name PitBuilding
extends Node3D
## Pit building and pit-lane wall (REBUILD-PLAN.md P3-04 / scenery-kit): long garage block with segmented
## bays and roof, placed at a station and offset.
## Front pit-wall collision on layer 2 (wall_kind "concrete") is created if `has_pit_wall` is true.

enum Side { LEFT, RIGHT }

const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const NightGlow = preload("res://scripts/track/night_glow.gd")

@export_group("Placement")
@export var follow_road: NodePath
@export var station = 0.0
@export_enum("Left", "Right") var side = 0
## Metres beyond verge outer edge for the main garage building.
@export var offset = 12.0
@export var length_m = 60.0
@export var depth_m = 10.0
@export var height_m = 4.5
@export_range(1, 30, 1) var garages = 8

@export_group("Pit Wall")
@export var has_pit_wall = true
## Metres beyond verge outer edge for the concrete pit wall.
@export var pit_wall_offset = 3.5
@export var pit_wall_height = 1.0
@export var pit_wall_thickness = 0.4

@export_group("")
@export_tool_button("Bake PitBuilding", "Callable") var bake_button = bake

var last_bake = {}


func bake() -> void:
	var road = get_node_or_null(follow_road) if not follow_road.is_empty() else null
	if road == null:
		push_error("PitBuilding %s: follow_road is not set" % name)
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
	var step_m = 4.0
	var count = maxi(1, int(ceil(length_m / step_m)))
	var side_sign = -1 if side == Side.LEFT else 1

	var slices = []
	var pit_wall_line = PackedVector3Array()
	var pit_wall_outward = PackedVector3Array()

	for i in count + 1:
		var s = s_start + length_m * i / count
		# Building slice at `offset`
		var e_bld = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, offset)
		var p_bld = road.transform * e_bld.point
		var out_vec = (road.transform.basis * e_bld.outward).normalized()
		var up_vec = (road.transform.basis * e_bld.up).normalized()
		slices.append({"point": p_bld, "outward": out_vec, "up": up_vec})

		# Pit wall at `pit_wall_offset`
		if has_pit_wall:
			var e_wall = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side_sign, pit_wall_offset)
			pit_wall_line.append(road.transform * e_wall.point)
			pit_wall_outward.append((road.transform.basis * e_wall.outward).normalized())

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var col_concrete = Color(0.70, 0.72, 0.74)
	var col_doors = Color(0.22, 0.24, 0.26)
	var col_fascia = Color(0.85, 0.15, 0.12)
	var col_roof = Color(0.32, 0.34, 0.36)

	var bay_width = length_m / garages
	var bay_door_h = height_m * 0.75
	var bay_fascia_h = height_m - bay_door_h

	# Building extrusion along slices
	for i in count:
		var sl0 = slices[i]
		var sl1 = slices[i + 1]

		# Floor slab
		var f0_front = sl0.point
		var f1_front = sl1.point
		var f0_back = sl0.point + sl0.outward * depth_m
		var f1_back = sl1.point + sl1.outward * depth_m

		# Roof points
		var r0_front = f0_front + sl0.up * height_m
		var r1_front = f1_front + sl1.up * height_m
		var r0_back = f0_back + sl0.up * height_m
		var r1_back = f1_back + sl1.up * height_m

		# Roof top face
		SceneryBuilder.add_quad(st, r0_front, r1_front, r1_back, r0_back, col_roof)

		# Back wall
		SceneryBuilder.add_quad(st, f0_back, f1_back, r1_back, r0_back, col_concrete)

		# Front face: upper fascia board (team colors)
		var d0_top = f0_front + sl0.up * bay_door_h
		var d1_top = f1_front + sl1.up * bay_door_h
		SceneryBuilder.add_quad(st, d0_top, d1_top, r1_front, r0_front, col_fascia)

		# Front face: garage door opening (recessed slightly)
		var recess0 = sl0.outward * 0.3
		var recess1 = sl1.outward * 0.3
		SceneryBuilder.add_quad(
			st, f0_front + recess0, f1_front + recess1, d1_top + recess1, d0_top + recess0, col_doors
		)

	# End caps (left and right outer walls)
	for idx in [0, count]:
		var sl = slices[idx]
		var p_front = sl.point
		var p_back = sl.point + sl.outward * depth_m
		var p_roof_f = p_front + sl.up * height_m
		var p_roof_b = p_back + sl.up * height_m
		if idx == 0:
			SceneryBuilder.add_quad(st, p_front, p_back, p_roof_b, p_roof_f, col_concrete)
		else:
			SceneryBuilder.add_quad(st, p_back, p_front, p_roof_f, p_roof_b, col_concrete)

	st.generate_normals()
	st.set_material(NightGlow.facade_material())
	var building_mesh = st.commit()

	var prep = SceneryBuilder.prepare_container(self, "Scenery")
	var scenery = prep.container
	var owner_node = prep.owner

	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = building_mesh
	scenery.add_child(inst)
	inst.owner = owner_node

	# Concrete pit wall on layer 2 if has_pit_wall
	var host = prep.host
	var walls = host.get_node_or_null("Walls")
	if walls != null:
		var old_wall = walls.get_node_or_null(NodePath(str(name)))
		if old_wall != null:
			walls.remove_child(old_wall)
			old_wall.free()

	if has_pit_wall and pit_wall_line.size() >= 2:
		if walls == null:
			walls = Node3D.new()
			walls.name = "Walls"
			host.add_child(walls)
			walls.owner = owner_node
		var face_list = WallBuilder.faces(
			pit_wall_line, pit_wall_outward, pit_wall_height, pit_wall_thickness, false
		)
		var body = SceneryBuilder.make_wall_body(
			name, face_list, "concrete", pit_wall_line, pit_wall_outward, pit_wall_height, pit_wall_thickness
		)
		walls.add_child(body)
		body.owner = owner_node
		for child in body.get_children():
			child.owner = owner_node

	last_bake = {"station": station, "length_m": length_m, "has_pit_wall": has_pit_wall, "garages": garages}
