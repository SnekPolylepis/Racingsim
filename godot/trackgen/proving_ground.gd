extends SceneTree
## Reproducible P5-03 proving-ground authoring. Run from godot/ with:
## tools/Godot.exe --headless --path . --script trackgen/proving_ground.gd
## The generated binary scene is committed only when it stays near the 5 MB content budget.
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
const Grandstand = preload("res://scripts/track/grandstand.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const Billboards = preload("res://scripts/track/billboards.gd")
const PitBuilding = preload("res://scripts/track/pit_building.gd")
const MarshalPost = preload("res://scripts/track/marshal_post.gd")
const PropBody = preload("res://scripts/props/prop_body.gd")
const OUTPUT = "res://tracks3d/proving_ground/proving_ground.scn"
const ARC = PI / 2.0
const QUARTER = PI / 4.0


static func segments() -> Array:
	return [
		[150.0, 0.0],
		[130.0 * ARC, -1.0 / 130.0],
		[400.0, 0.0],
		[160.0 * ARC, -1.0 / 160.0],
		[410.0, 0.0],
		[90.0 * ARC, -1.0 / 90.0],
		[70.0, 0.0],
		[80.0 * QUARTER, 1.0 / 80.0],
		[80.0 * ARC, -1.0 / 80.0],
		[80.0 * QUARTER, 1.0 / 80.0],
		[174.0, 0.0],
		[130.0 * ARC, -1.0 / 130.0],
		[250.0, 0.0]
	]


static func plan_length() -> float:
	var length = 0.0
	for segment in segments():
		length += segment[0]
	return length


## Horizontal point and tangent at a nominal scaffold station. Negative curvature turns left.
static func plan_at(s: float) -> Dictionary:
	var p = Vector3.ZERO
	var heading = 0.0
	var remaining = clampf(s, 0.0, plan_length())
	for segment in segments():
		var d = minf(remaining, segment[0])
		var k = segment[1]
		if absf(k) < 1e-9:
			p += Vector3(cos(heading) * d, 0.0, sin(heading) * d)
		else:
			p += Vector3(
				(sin(heading + k * d) - sin(heading)) / k, 0.0, (cos(heading) - cos(heading + k * d)) / k
			)
			heading += k * d
		remaining -= d
		if remaining <= 1e-7:
			break
	return {"pos": p, "tangent": Vector3(cos(heading), 0.0, sin(heading))}


static func plan_curve() -> Curve3D:
	var stations = [0.0]
	var s = 10.0
	var length = plan_length()
	while s < length - 1.0:
		stations.append(s)
		s += 10.0
	var edge = 0.0
	for seg in segments():
		edge += seg[0]
		if edge < length - 1e-5:
			stations.append(edge)
	stations.sort()
	var unique = []
	for station in stations:
		if unique.is_empty() or station - unique[-1] > 1e-4:
			unique.append(station)
	var c = Curve3D.new()
	c.bake_interval = .25
	for i in unique.size():
		var at = plan_at(unique[i])
		var prev_s = unique[i - 1] if i > 0 else unique[-1] - length
		var next_s = unique[i + 1] if i < unique.size() - 1 else length
		var incoming = -at.tangent * (unique[i] - prev_s) / 3.0
		var outgoing = at.tangent * (next_s - unique[i]) / 3.0
		c.add_point(at.pos, incoming, outgoing)
	return c


## Map paper-design stations to the curve's measured horizontal distance after cubic easing.
static func actual_station(curve: Curve3D, nominal: float, length: float) -> float:
	if nominal >= plan_length() - 1e-5:
		return length
	return curve.get_closest_offset(plan_at(nominal).pos)


static func bank_at(s: float) -> float:
	var bowl = 16.0 * smoothstep(60.0, 240.0, s) * (1.0 - smoothstep(285.0, 465.0, s))
	var adverse = 4.0 * smoothstep(690.0, 790.0, s) * (1.0 - smoothstep(960.0, 1060.0, s))
	return -bowl + adverse


static func profile_at(s: float) -> Dictionary:
	var width = 7.0 - smoothstep(100.0, 140.0, s)
	var runoff = (
		10.0 * smoothstep(990.0, 1040.0, s) * (1.0 - smoothstep(1400.0, 1450.0, s))
		+ 10.0 * smoothstep(1840.0, 1880.0, s) * (1.0 - smoothstep(2030.0, 2070.0, s))
	)
	var ditch = smoothstep(1380.0, 1410.0, s) * (1.0 - smoothstep(1560.0, 1590.0, s))
	var out = {
		"width_left": width,
		"width_right": width,
		"bank_deg": bank_at(s),
		"crown": .02,
		"kerb_left": RoadSection.Kerb.NONE,
		"kerb_right": RoadSection.Kerb.NONE,
		"kerb_width": .6,
		"kerb_height": .04,
		"rib_height": .008,
		"rib_pitch": .5,
		"runoff_left": runoff,
		"runoff_right": runoff,
		"runoff_surface": 4,
		"verge_left": 6.0,
		"verge_right": 6.0,
		"verge_slope_deg": 3.0,
		"road_surface": 0,
		"verge_surface": 2,
		"verge_surface_left": -1,
		"verge_surface_right": -1,
		"ditch": ditch,
		"ditch_offset": -2.0,
		"ditch_floor": 1.5,
		"ditch_wall": 1.1,
		"ditch_angle_deg": 37.0,
		"ditch_fillet": .5
	}
	if s < 70.0:
		out.kerb_right = RoadSection.Kerb.RAMP
		out.kerb_width = .4
		out.kerb_height = 0.0  # zero-height painted control
	elif s >= 950.0 and s < 1030.0:
		out.kerb_left = RoadSection.Kerb.RAMP
	elif s >= 1600.0 and s < 1900.0:
		out.kerb_left = RoadSection.Kerb.RIBBED
		out.kerb_right = RoadSection.Kerb.RIBBED
		out.kerb_width = .8
		out.kerb_height = .045
	elif s >= 2050.0 and s < 2250.0:
		out.kerb_left = RoadSection.Kerb.SAUSAGE
		out.kerb_height = .09
	if absf(s - 70.0) < .01:
		out.kerb_height = 0.0
	if absf(s - 2250.0) < .01:
		out.kerb_height = .09
	if s >= 700.0 and s < 1006.0:
		out.verge_surface_right = 3
	if s >= 1400.0 and s < 1600.0:
		out.verge_surface_right = 3
	return out


static func sections(curve: Curve3D, length: float) -> Array[RoadSection]:
	var keys: Array[RoadSection] = []
	var marks = [
		0.0,
		70.0,
		80.0,
		100.0,
		110.0,
		140.0,
		150.0,
		190.0,
		220.0,
		250.0,
		285.0,
		325.0,
		354.0,
		385.0,
		425.0,
		690.0,
		700.0,
		754.0,
		790.0,
		900.0,
		950.0,
		960.0,
		1006.0,
		1030.0,
		1040.0,
		1060.0,
		1200.0,
		1380.0,
		1400.0,
		1410.0,
		1450.0,
		1557.0,
		1560.0,
		1590.0,
		1600.0,
		1690.0,
		1815.0,
		1840.0,
		1878.0,
		1880.0,
		1900.0,
		1970.0,
		2030.0,
		2050.0,
		2052.0,
		2070.0,
		2250.0,
		2256.0,
		2400.0
	]
	for s in marks:
		keys.append(RoadSection.make(actual_station(curve, s, length), profile_at(s)))
	return keys


## Eased curvature profile: zero at +/-60 m, 1/130 m near the apex. Integrating it gives
## smooth height and grade without the entry/exit lips of a constant-radius arc.
static func crest_height(distance: float) -> float:
	var n = maxi(1, int(ceil(distance / .25)))
	var step = distance / n
	var drop = 0.0
	for i in n + 1:
		var u = i * step
		var curvature = (1.0 - smoothstep(15.0, 60.0, u)) / 130.0
		var weight = .5 if i == 0 or i == n else 1.0
		drop += weight * (distance - u) * curvature * step
	return 27.0 - drop


static func elevation(curve: Curve3D, length: float) -> PackedVector2Array:
	# P5-02's eight-key approach gave an 86 m apex. Dense central keys hold ~130 m
	# without making the approach or landing edge tighter than the apex.
	var raw = [
		[0.0, 0.0],
		[150.0, 0.0],
		[250.0, -5.0],
		[354.0, -2.0],
		[500.0, 4.0],
		[754.0, 15.0],
		[900.0, 15.0],
		[1006.0, 9.0],
		[1025.0, 10.0],
		[1040.0, 11.5],
		[1200.0, 10.5],
		[1250.0, 8.0],
		[1416.0, 8.0],
		[1557.0, 6.0],
		[1878.0, 4.0],
		[1945.0, .6],
		[1970.0, -2.0],
		[1995.0, .6],
		[2052.0, 5.0],
		[2256.0, 0.0],
		[2400.0, 0.0]
	]
	for i in range(-12, 13):
		var offset = i * 5.0
		raw.append([1115.0 + offset, crest_height(absf(offset))])
	raw.sort_custom(func(a, b): return a[0] < b[0])
	var out = PackedVector2Array()
	for row in raw:
		out.append(Vector2(actual_station(curve, row[0], length), row[1]))
	return out


static func add_wall(asset: Node3D, title: String, road: RoadPath, side: int, kind: int) -> void:
	var wall = WallPath.new()
	wall.name = title
	wall.follow_road = NodePath("../Main")
	wall.side = side
	wall.kind = kind
	wall.offset = 4.0
	wall.step_m = 5.0
	asset.add_child(wall)
	wall.owner = asset
	wall.bake()


static func add_bot_line(asset: Node3D, road: RoadPath) -> void:
	var stations = road.last_bake.stations
	var measured = road.last_bake.length
	var sorted = road.sections.duplicate()
	sorted.sort_custom(func(a, b): return a.at < b.at)
	var path = Path3D.new()
	path.name = "BotLine"
	var curve = Curve3D.new()
	curve.bake_interval = 1.0
	var speeds = PackedFloat32Array()
	var timing_stations = PackedFloat64Array()
	var challenge = Path3D.new()
	challenge.name = "DitchChallengeLine"
	var cc = Curve3D.new()
	cc.bake_interval = 1.0
	for i in range(0, stations.size(), 4):
		var st = stations[i]
		var sec = RoadBuilder.section_at(sorted, st.s, measured, true)
		var fr = RoadBuilder.frame(st.tangent, sec.bank_deg)
		var avoid = 3.5 * smoothstep(1360.0, 1420.0, st.s)
		avoid *= 1.0 - smoothstep(1550.0, 1610.0, st.s)
		curve.add_point(st.pos + fr[0] * avoid + fr[1] * RoadBuilder.road_height(sec, avoid))
		var lat = -2.0 * smoothstep(1360.0, 1420.0, st.s)
		lat *= 1.0 - smoothstep(1550.0, 1610.0, st.s)
		cc.add_point(st.pos + fr[0] * lat + fr[1] * RoadBuilder.road_height(sec, lat))
		timing_stations.append(st.s)
		speeds.append(75.0 if st.s > 1000.0 and st.s < 1400.0 else 60.0)
	curve.add_point(curve.get_point_position(0))
	cc.add_point(cc.get_point_position(0))
	timing_stations.append(measured)
	speeds.append(speeds[0])
	path.curve = curve
	path.set_meta("target_speeds_kmh", speeds)
	path.set_meta("timing_stations_m", timing_stations)
	asset.add_child(path)
	path.owner = asset
	challenge.curve = cc
	challenge.set_meta("timing_stations_m", timing_stations)
	asset.add_child(challenge)
	challenge.owner = asset


## Look-2 sodium lamps (scripts/track/track_lights.gd): every 50 m on alternating sides, both sides
## every 25 m along the start/finish and the pits (left, 40-110 m), and on the right every 22 m past
## the bowl grandstand (225-275 m). Poles stand 5.5 m beyond the verge, outside the 4 m armco.
static func add_lighting(asset: Node3D, road: RoadPath) -> void:
	var length = road.last_bake.length
	var zones = [
		{"from_m": length - 75.0, "to_m": 120.0, "spacing": 25.0, "sides": "both"},
		{"from_m": 205.0, "to_m": 295.0, "spacing": 22.0, "sides": "both"},
	]
	TrackLights.build(asset, road, TrackLights.place(road, 50.0, zones, 5.5))


static func build_asset() -> Node3D:
	var asset = TrackAsset.new()
	asset.name = "ProvingGround"
	asset.id = "proving_ground"
	asset.display_name = "Proving Ground"
	asset.version = 1
	asset.default_time_of_day = "day"
	var road = RoadPath.new()
	road.name = "Main"
	road.closed = true
	road.along_step = 1.5
	road.road_stations = 9
	road.dense_ranges = [{"from_m": 1350.0, "to_m": 1620.0, "road_stations": 57}]
	road.grid_slots = 4
	road.grid_first_m = 35.0
	road.grid_spacing_m = 40.0
	road.grid_offset_m = 3.0
	road.curve = plan_curve()
	var work = road.working_curve()
	var measured = work.get_baked_length()
	road.sections = sections(work, measured)
	road.elevation_keys = elevation(work, measured)
	asset.add_child(road)
	road.owner = asset
	road.bake()
	var timing = asset.get_node("TimingLine")
	timing.set_meta("sector_offsets", [700.0, 1600.0])
	# No gate in the jump/ditch approaches; steady straight or corner sections only.
	timing.set_meta(
		"checkpoint_offsets",
		[120.0, 350.0, 550.0, 720.0, 900.0, 1260.0, 1360.0, 1640.0, 1840.0, 2130.0, 2350.0]
	)
	add_bot_line(asset, road)
	add_wall(asset, "OuterArmco", road, WallPath.Side.RIGHT, 0)
	add_wall(asset, "InnerArmco", road, WallPath.Side.LEFT, 0)
	var trees = RoadScatter.new()
	trees.name = "Trees"
	trees.follow_road = NodePath("../Main")
	trees.sides = RoadScatter.Sides.BOTH
	trees.random_seed = 503
	trees.per_100m = 4.0
	trees.offset_min = 8.0
	trees.offset_max = 30.0
	asset.add_child(trees)
	trees.owner = asset
	trees.bake()
	add_lighting(asset, road)
	add_scenery_kit(asset, road)
	add_props(asset, road)
	return asset


## Knock-over cones (P4-03 props) lining the inside of the T3 ditch approach, 4.5 m left of centre on
## flat tarmac before the trough opens (1380 m), on the ditch's side of the road. The BotLine moves to
## the bypass lane (3.5 m right) between 1360 and 1420 m, so a row between the two lanes would be on
## its path; here every car's hull stays at least 3.4 m clear on the bot's laps, and laps stay at zero
## prop contacts.
static func add_props(asset: Node3D, road: RoadPath) -> void:
	var props = Node3D.new()
	props.name = "Props"
	asset.add_child(props)
	props.owner = asset
	var measured = road.last_bake.length
	var sorted = road.sections.duplicate()
	sorted.sort_custom(func(a, b): return a.at < b.at)
	var curve = road.working_curve()
	var elev = RoadBuilder.elevation_spline(road.elevation_keys, measured, true)
	var k = 0
	for nominal in [1340.0, 1350.0, 1360.0, 1370.0, 1380.0, 1390.0]:
		var s = actual_station(curve, nominal, measured)
		var st = RoadBuilder.station_at(curve, true, measured, elev, s)
		var sec = RoadBuilder.section_at(sorted, s, measured, true)
		var fr = RoadBuilder.frame(st.tangent, sec.bank_deg)
		var lat = -4.5
		var at = st.pos + fr[0] * lat + fr[1] * RoadBuilder.road_height(sec, lat)
		var fwd = (st.tangent - fr[1] * st.tangent.dot(fr[1])).normalized()
		var marker = Marker3D.new()
		k += 1
		marker.name = "DitchCone%d" % k
		marker.transform = Transform3D(Basis(fwd, fr[1], fwd.cross(fr[1])), at)
		marker.set_meta("prop", "cone")
		props.add_child(marker)
		marker.owner = asset
		var mesh = PropBody.visual("cone")
		marker.add_child(mesh)
		mesh.owner = asset


static func add_scenery_kit(asset: Node3D, _road: RoadPath) -> void:
	# 1. Gantry at start line
	var gantry = Gantry.new()
	gantry.name = "StartGantry"
	gantry.follow_road = NodePath("../Main")
	gantry.station = 0.0
	gantry.clearance_height = 6.0
	gantry.extra_width = 3.0
	gantry.light_panel = true
	asset.add_child(gantry)
	gantry.owner = asset
	gantry.bake()

	# 2. Grandstand at bowl
	var grandstand = Grandstand.new()
	grandstand.name = "BowlGrandstand"
	grandstand.follow_road = NodePath("../Main")
	grandstand.station = 250.0
	grandstand.side = Grandstand.Side.RIGHT
	grandstand.offset = 7.0
	grandstand.length_m = 50.0
	grandstand.rows = 8
	grandstand.has_roof = true
	grandstand.solid_front = true
	asset.add_child(grandstand)
	grandstand.owner = asset
	grandstand.bake()

	# 3. Catch fences on crest landing
	var fence = CatchFence.new()
	fence.name = "CrestCatchFence"
	fence.follow_road = NodePath("../Main")
	fence.side = CatchFence.Side.RIGHT
	fence.from_m = 1130.0
	fence.to_m = 1250.0
	fence.offset = 5.0
	fence.fence_height = 3.5
	fence.solid = true
	asset.add_child(fence)
	fence.owner = asset
	fence.bake()

	# 4. Billboards on main straight
	var boards = Billboards.new()
	boards.name = "MainBillboards"
	boards.follow_road = NodePath("../Main")
	boards.side = Billboards.Side.RIGHT
	boards.from_m = 40.0
	boards.to_m = 130.0
	boards.offset = 7.0
	boards.spacing = 30.0
	asset.add_child(boards)
	boards.owner = asset
	boards.bake()

	# 5. Pit building by grid
	var pits = PitBuilding.new()
	pits.name = "Pits"
	pits.follow_road = NodePath("../Main")
	pits.side = PitBuilding.Side.LEFT
	pits.station = 75.0
	pits.length_m = 70.0
	pits.offset = 12.0
	pits.has_pit_wall = true
	pits.pit_wall_offset = 4.5
	asset.add_child(pits)
	pits.owner = asset
	pits.bake()

	# 6. Marshal posts around circuit
	var marshals = MarshalPost.new()
	marshals.name = "MarshalPosts"
	marshals.follow_road = NodePath("../Main")
	marshals.side = MarshalPost.Side.RIGHT
	marshals.offset = 6.0
	marshals.spacing = 300.0
	asset.add_child(marshals)
	marshals.owner = asset
	marshals.bake()


func _initialize() -> void:
	var asset = build_asset()
	var warnings = asset.get_node("Main").last_bake.warnings
	print("BAKE warnings=%d %s" % [warnings.size(), warnings])
	var errors = asset.validate()
	print("VALIDATE errors=%d %s" % [errors.size(), errors])
	print(
		(
			"LENGTH plan=%.3f road=%.3f lap=%.3f m"
			% [plan_length(), asset.get_node("Main").last_bake.length, asset.length]
		)
	)
	if not warnings.is_empty() or not errors.is_empty():
		asset.free()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tracks3d/proving_ground"))
	var packed = PackedScene.new()
	var pack_error = packed.pack(asset)
	if pack_error != OK:
		print("PACK ERROR %d" % pack_error)
		asset.free()
		quit(1)
		return
	var save_error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		print("SAVE ERROR %d" % save_error)
		asset.free()
		quit(1)
		return
	print("SCENE bytes=%d path=%s" % [FileAccess.get_file_as_bytes(OUTPUT).size(), OUTPUT])
	asset.free()
	quit()
