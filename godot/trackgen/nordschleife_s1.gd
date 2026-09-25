extends SceneTree
## Nürburgring Nordschleife Section 1 groundwork (T13 to Aremberg + return road).
## Rebuild: tools/Godot.exe --headless --path . --script trackgen/nordschleife_s1.gd
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const KerbMap = preload("res://trackgen/kerb_map.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const TerrainPatch = preload("res://scripts/track/terrain.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
const Grandstand = preload("res://scripts/track/grandstand.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const Billboards = preload("res://scripts/track/billboards.gd")
const PitBuilding = preload("res://scripts/track/pit_building.gd")
const MarshalPost = preload("res://scripts/track/marshal_post.gd")
const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")

const DATA = "res://trackgen/data/nordschleife/"
const OUTPUT = "res://tracks3d/nordschleife_s1/nordschleife_s1.scn"
const CACHE_REVISION = 6


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Nordschleife source missing: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Nordschleife source is not a JSON object: " + path)
		return {}
	return parsed


## Cubic Hermite tangents preserve the OSM outline while avoiding polygonal steering steps.
static func plan_curve(data: Dictionary) -> Curve3D:
	var points = PackedVector3Array()
	for p in data.points:
		points.append(Vector3(float(p[0]), 0.0, float(p[1])))
	if points[0].distance_to(points[-1]) < 0.01:
		points.remove_at(points.size() - 1)
	var curve = Curve3D.new()
	curve.bake_interval = 0.25
	var n = points.size()
	for i in n:
		var before = points[posmod(i - 1, n)]
		var after = points[(i + 1) % n]
		var tangent = (after - before).normalized()
		var incoming = points[i].distance_to(before)
		var outgoing = points[i].distance_to(after)
		var reach = minf(incoming, outgoing) / 3.0
		curve.add_point(points[i], -tangent * reach, tangent * reach)
	return curve


static func source_length(data: Dictionary) -> float:
	var original = float(data.get("measurements", {}).get("total_loop_length_m", 0.0))
	if original > 0.0:
		return original
	var points = data.points
	var total = 0.0
	for i in points.size():
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		total += Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1]))
	return total


## Measured directly from Rhineland-Palatinate DGM1 (1 m LiDAR DEM) crossfalls.
## [name, s_station, bank_deg, tarmac_width, turn_direction, kerb_type]
## turn_direction: +1 right, -1 left
## kerb_type: 0 none/ramp, 1 sausage, 2 ribbed
static func corner_specs(data: Dictionary) -> Array:
	var positions = data.get("sections", {})
	var defaults = [
		# T13 Start: gentle right banking measured from DEM crossfall (+1.1 deg, width 9.0 m)
		["T13", 50.0, 1.1, 9.0, 1, 0],
		# Sabine-Schmitz-Kurve: fast left turn into adverse camber (-4.5 deg, width 9.8 m)
		["Sabine-Schmitz-Kurve", 280.0, -4.5, 9.8, -1, 0],
		# Hatzenbogen: sweeping left curve, pronounced banking (-5.6 deg, width 9.5 m)
		["Hatzenbogen", 400.0, -5.6, 9.5, -1, 0],
		# Hatzenbach 1: right entry to chicane (+3.9 deg, width 11.8 m)
		["Hatzenbach 1", 820.0, 3.9, 11.8, 1, 2],
		# Hatzenbach 2: left transition (-1.0 deg, width 11.0 m)
		["Hatzenbach 2", 950.0, -1.0, 11.0, -1, 2],
		# Hatzenbach 3: right downhill flick (+3.0 deg, width 10.0 m)
		["Hatzenbach 3", 1120.0, 3.0, 10.0, 1, 2],
		# Hatzenbach 4: left compression (-4.1 deg, width 9.5 m)
		["Hatzenbach 4", 1250.0, -4.1, 9.5, -1, 2],
		# Hocheichen: tight right (+2.6 deg, width 11.3 m)
		["Hocheichen", 1400.0, 2.6, 11.3, 1, 2],
		# Hocheichen exit: left underpass (-2.0 deg, width 10.0 m)
		["Hocheichen exit", 1490.0, -2.0, 10.0, -1, 0],
		# Quiddelbacher Hoehe: uphill crest (+1.6 deg, width 9.0 m)
		["Quiddelbacher Hoehe", 2000.0, 1.6, 9.0, 1, 0],
		# Flugplatz: famous double-right takeoff crest (+3.3 deg, width 10.5 m)
		["Flugplatz", 2340.0, 3.3, 10.5, 1, 0],
		# Flugplatz crest exit: left compression (-3.8 deg, width 10.0 m)
		["Flugplatz exit", 2440.0, -3.8, 10.0, -1, 0],
		# Schwedenkreuz: ultra-high speed sweeping left (-1.8 deg, width 11.3 m)
		["Schwedenkreuz", 3030.0, -1.8, 11.3, -1, 0],
		# Aremberg entry: heavy downhill braking into right turn (+4.4 deg, width 8.5 m)
		["Aremberg entry", 3650.0, 4.4, 8.5, 1, 0],
		# Aremberg apex: steep right hairpin (+6.9 deg, width 8.5 m)
		["Aremberg", 3790.0, 6.9, 8.5, 1, 1],
		# Aremberg exit: bridge approach (+4.3 deg, width 8.5 m)
		["Aremberg exit", 4150.0, 4.3, 8.5, 1, 0],
		# Return road sections (gentle flow back to T13)
		["Return Bridge Straight", 4600.0, 0.0, 9.0, 0, 0],
		["Return East Valley", 5800.0, 0.0, 9.0, 0, 0],
		["Return Meadow Run", 7200.0, 0.0, 9.0, 0, 0],
		["Paddock Carousel", 8700.0, 2.5, 10.0, 1, 0]
	]
	var length = source_length(data)
	for row in defaults:
		if positions.has(row[0]):
			row[1] = float(positions[row[0]])
	defaults.sort_custom(func(a, b): return a[1] < b[1])
	return defaults


static func circular_delta(s: float, at: float, length: float) -> float:
	return fposmod(s - at + length * 0.5, length) - length * 0.5


static func profile_at(s: float, length: float, corners: Array) -> Dictionary:
	var paddock = s < 120.0 or s > length - 200.0
	var values = {
		"width_left": 5.5 if paddock else 4.6,
		"width_right": 5.5 if paddock else 4.6,
		"bank_deg": 0.0,
		"crown": 0.02,
		"kerb_left": RoadSection.Kerb.NONE,
		"kerb_right": RoadSection.Kerb.NONE,
		"kerb_width": 0.9,
		"kerb_height": 0.045,
		"rib_height": 0.006,
		"rib_pitch": 0.75,
		# The Nordschleife is narrow and hemmed in: a grass shoulder of about half a metre, a short verge,
		# then armco (NS-section; it was 2.5 m of tarmac runoff plus a 6 m flat verge each side).
		"runoff_left": 4.0 if paddock else 0.5,
		"runoff_right": 4.0 if paddock else 0.5,
		"runoff_surface": 4 if paddock else 2,
		"verge_left": 1.5,
		"verge_right": 1.5,
		"verge_slope_deg": 0.0,
		"verge_surface": 2,
		"verge_surface_left": -1,
		"verge_surface_right": -1
	}
	var total_bank = 0.0
	var total_bank_weight = 0.0
	for corner in corners:
		var delta = circular_delta(s, corner[1], length)
		var weight = smoothstep(-110.0, -35.0, delta) * (1.0 - smoothstep(30.0, 120.0, delta))
		if weight <= 0.0:
			continue
		var w_half = float(corner[3]) * 0.5
		values.width_left = maxf(values.width_left, lerpf(4.6, w_half, weight))
		values.width_right = maxf(values.width_right, lerpf(4.6, w_half, weight))
		total_bank += float(corner[2]) * weight
		total_bank_weight += weight
		var inside = "right" if corner[4] > 0 else "left"
		var outside = "left" if corner[4] > 0 else "right"
		values["runoff_" + outside] = maxf(values["runoff_" + outside], 0.5 + 2.0 * weight)
		values["runoff_" + inside] = maxf(values["runoff_" + inside], 0.5 + 0.5 * weight)
		if delta >= -40.0 and delta < 25.0:
			if corner[5] == 1:
				values["kerb_" + inside] = RoadSection.Kerb.SAUSAGE
				values.kerb_height = 0.070
			elif corner[5] == 2:
				values["kerb_" + inside] = RoadSection.Kerb.RIBBED
			elif corner[4] != 0:
				values["kerb_" + inside] = RoadSection.Kerb.RAMP
		elif delta >= 25.0 and delta < 80.0 and corner[4] != 0:
			values["kerb_" + outside] = RoadSection.Kerb.RIBBED
	# Weighted bank blend eliminates rate-of-change warnings
	values.bank_deg = total_bank / maxf(total_bank_weight, 1.0)
	# Traced kerbs (K-02) replace the rules above once the kerbs.json is reviewed.
	KerbMap.apply(KerbMap.for_track("nordschleife_s1", DATA + "kerbs.json"), values, s, length)
	return values


static func sections(data: Dictionary, measured: float, corners: Array) -> Array[RoadSection]:
	var length = source_length(data)
	var marks = [0.0]
	var s = 20.0
	while s < length:
		marks.append(s)
		s += 20.0
	for corner in corners:
		for offset in [-110.0, -40.0, -35.0, 0.0, 25.0, 30.0, 80.0, 120.0]:
			marks.append(fposmod(corner[1] + offset, length))
	marks.append_array(KerbMap.marks(KerbMap.for_track("nordschleife_s1", DATA + "kerbs.json"), length))
	marks.sort()
	var keys: Array[RoadSection] = []
	var previous = -1.0
	for mark in marks:
		if mark - previous < 0.05:
			continue
		keys.append(RoadSection.make(mark * measured / length, profile_at(mark, length, corners)))
		previous = mark
	return keys


static func elevation(data: Dictionary, measured: float) -> PackedVector2Array:
	var keys = PackedVector2Array()
	var scale_s = measured / source_length(data)
	for row in data.elevation_keys:
		keys.append(Vector2(float(row.s) * scale_s, float(row.height)))
	return keys


static func add_wall(
	asset: Node3D, title: String, side: int, kind: int, from_m: float, to_m: float, extra = 1.5
) -> void:
	var wall = WallPath.new()
	wall.name = title
	wall.follow_road = NodePath("../Main")
	wall.side = side
	wall.kind = kind
	wall.offset = extra
	wall.step_m = 5.0
	wall.from_m = from_m
	wall.to_m = to_m
	asset.add_child(wall)
	wall.owner = asset
	wall.bake()


static func add_terrain(asset: Node3D) -> Dictionary:
	if not FileAccess.file_exists(DATA + "terrain.json"):
		push_warning("Nordschleife terrain unavailable; broad authored verges remain driveable")
		return {}
	var header = read_json(DATA + "terrain.json")
	var raw_path = DATA + str(header.get("file", "dem.raw"))
	if header.is_empty() or not FileAccess.file_exists(raw_path):
		return {}
	var raw = FileAccess.get_file_as_bytes(raw_path).to_float32_array()
	var width = int(header.width)
	var height = int(header.height)
	if raw.size() != width * height:
		push_warning("Nordschleife DEM dimensions do not match float32 payload; skipping terrain")
		return {}
	var pixel = float(header.metres_per_pixel)
	# 5 m, not 10: with the narrow NS-section verges a 10 m triangle reaching under the road dragged a
	# trench into the ground just behind the armco.
	var mesh_spacing = 5.0
	var w = int((width - 1) * pixel / mesh_spacing) + 1
	var h = int((height - 1) * pixel / mesh_spacing) + 1
	var reduced = PackedFloat32Array()
	reduced.resize(w * h)
	for z in h:
		for x in w:
			var sx = minf(x * mesh_spacing / pixel, width - 1.001)
			var sz = minf(z * mesh_spacing / pixel, height - 1.001)
			var ix = int(sx)
			var iz = int(sz)
			var top = lerpf(raw[iz * width + ix], raw[iz * width + ix + 1], sx - ix)
			var bottom = lerpf(raw[(iz + 1) * width + ix], raw[(iz + 1) * width + ix + 1], sx - ix)
			reduced[z * w + x] = lerpf(top, bottom, sz - iz)
	var terrain = TerrainPatch.new()
	terrain.name = "Eifel"
	terrain.heightmap = ImageTexture.create_from_image(
		Image.create_from_data(w, h, false, Image.FORMAT_RF, reduced.to_byte_array())
	)
	terrain.metres_per_pixel = mesh_spacing
	terrain.origin_offset = Vector2(header.origin_offset[0], header.origin_offset[1])
	terrain.height_offset = float(header.get("height_offset", 0.0))
	terrain.road_paths.append(NodePath("../Main"))
	# 6 m (was 30): with DGM1 at 5 m the real banks and cuttings meet the verge instead of being levelled.
	terrain.blend_m = 6.0
	terrain.under_road_drop_m = 2.0
	terrain.chunk_size = 64
	asset.add_child(terrain)
	terrain.owner = asset
	terrain.bake()
	# The chunks keep terrain.gd's PS2 grass (Look-1); a flat colour override here predated it.
	var heights = PackedFloat64Array()
	heights.resize(w * h)
	for chunk in asset.get_node("Terrain/Eifel").get_children():
		var vertices = chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			var gx = roundi((point.x - terrain.origin_offset.x) / mesh_spacing)
			var gz = roundi((point.z - terrain.origin_offset.y) / mesh_spacing)
			if gx >= 0 and gx < w and gz >= 0 and gz < h:
				heights[gz * w + gx] = point.y
	var grid = {"width": w, "height": h, "data": heights}
	asset.set_meta("terrain_mesh_spacing_m", terrain.metres_per_pixel)
	asset.set_meta("terrain_triangles", terrain.last_bake.triangles)
	return {"patch": terrain, "grid": grid}


static func terrain_height(terrain: Dictionary, point: Vector3) -> float:
	var patch = terrain.patch
	var grid = terrain.grid
	var x = clampf((point.x - patch.origin_offset.x) / patch.metres_per_pixel, 0.0, grid.width - 1.001)
	var z = clampf((point.z - patch.origin_offset.y) / patch.metres_per_pixel, 0.0, grid.height - 1.001)
	var ix = int(x)
	var iz = int(z)
	var fx = x - ix
	var fz = z - iz
	var a = float(grid.data[iz * grid.width + ix])
	var b = float(grid.data[iz * grid.width + ix + 1])
	var c = float(grid.data[(iz + 1) * grid.width + ix])
	var d = float(grid.data[(iz + 1) * grid.width + ix + 1])
	return (
		a + fx * (b - a) + fz * (c - a) if fx + fz <= 1.0 else d + (1.0 - fx) * (c - d) + (1.0 - fz) * (b - d)
	)


static func add_forest(
	asset: Node3D,
	terrain: Dictionary,
	title: String,
	from_m: float,
	to_m: float,
	density: float,
	offset_min: float,
	offset_max: float,
	seed_value: int
) -> void:
	var trees = RoadScatter.new()
	trees.name = title
	trees.follow_road = NodePath("../Main")
	trees.sides = RoadScatter.Sides.BOTH
	trees.random_seed = seed_value
	trees.from_m = from_m
	trees.to_m = to_m
	trees.per_100m = density
	trees.offset_min = offset_min
	trees.offset_max = offset_max
	trees.scale_min = 1.0
	trees.scale_max = 2.0
	asset.add_child(trees)
	trees.owner = asset
	trees.bake()
	var multimesh = asset.get_node("Scenery/" + title).multimesh
	var clear = road_clearance(asset.get_node("Main"))
	# Ground each tree from the scatter's own layout: reading the MultiMesh back returns zeros under
	# the headless renderer, which baked every tree at the origin into the shared track cache. A tree
	# that lands near another part of the circuit (a far offset on a winding closed road) is dropped.
	for i in multimesh.instance_count:
		var xf: Transform3D = trees.last_bake.xforms[i]
		if near_road(clear, xf.origin):
			xf = Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
		elif not terrain.is_empty():
			xf.origin.y = terrain_height(terrain, xf.origin)
		multimesh.set_instance_transform(i, xf)


## Road centre points hashed into CLEAR_M cells (plan view) for near_road().
const CLEAR_M = 24.0
## No tree closer than this to any road centreline: the widest half-road plus shoulder, verge and armco.
const TREE_CLEAR_M = 9.5


static func road_clearance(road) -> Dictionary:
	var cells = {}
	for p in road.last_bake.center:
		var key = Vector2i(floori(p.x / CLEAR_M), floori(p.z / CLEAR_M))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(Vector2(p.x, p.z))
	return cells


## True when `point` is within TREE_CLEAR_M of the road's centreline anywhere on the circuit.
static func near_road(cells: Dictionary, point: Vector3) -> bool:
	var at = Vector2(point.x, point.z)
	var cx = floori(point.x / CLEAR_M)
	var cz = floori(point.z / CLEAR_M)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for p in cells.get(Vector2i(cx + dx, cz + dz), []):
				if at.distance_squared_to(p) < TREE_CLEAR_M * TREE_CLEAR_M:
					return true
	return false


static func add_bot_line(asset: Node3D, road: RoadPath) -> void:
	var stations = road.last_bake.stations
	var center = road.last_bake.center
	var cumulative = PackedFloat64Array([0.0])
	for i in range(1, stations.size()):
		cumulative.append(cumulative[-1] + center[i - 1].distance_to(center[i]))
	var path = Path3D.new()
	path.name = "BotLine"
	var curve = Curve3D.new()
	curve.bake_interval = 1.0
	var speeds = PackedFloat32Array()
	var timing = PackedFloat64Array()
	# Sample every 2nd station to capture Nordschleife's rapid corner transitions
	for i in range(0, stations.size(), 2):
		var p = center[i]
		curve.add_point(p)
		timing.append(cumulative[i])
		var before = center[posmod(i - 8, center.size())]
		var after = center[(i + 8) % center.size()]
		var a = Vector2(p.x - before.x, p.z - before.z)
		var b = Vector2(after.x - p.x, after.z - p.z)
		var chord = Vector2(after.x - before.x, after.z - before.z)
		var curvature = 2.0 * absf(a.cross(b)) / maxf(a.length() * b.length() * chord.length(), 0.001)
		# 290 km/h cap, conservative 1.4g base speed envelope
		speeds.append(minf(290.0 / 3.6, sqrt(1.4 * 9.81 / maxf(curvature, 0.00001))))
	# Backward braking envelope (7.5 m/s²), conservative 4.0 m/s² forward acceleration
	for iteration in range(3):
		for i in range(speeds.size() - 1, -1, -1):
			var next = (i + 1) % speeds.size()
			var ds = curve.get_point_position(i).distance_to(curve.get_point_position(next))
			speeds[i] = minf(speeds[i], sqrt(speeds[next] * speeds[next] + 15.0 * ds))
		for i in speeds.size():
			var previous = posmod(i - 1, speeds.size())
			var ds = curve.get_point_position(i).distance_to(curve.get_point_position(previous))
			speeds[i] = minf(speeds[i], sqrt(speeds[previous] * speeds[previous] + 8.0 * ds))
	for i in speeds.size():
		speeds[i] *= 3.6
	# Catmull-Rom handles for smooth curvature through every point
	var count = curve.point_count
	for k in count:
		var p_next = curve.get_point_position((k + 1) % count)
		var p_prev = curve.get_point_position(posmod(k - 1, count))
		var tangent = (p_next - p_prev) / 6.0
		curve.set_point_in(k, -tangent)
		curve.set_point_out(k, tangent)
	curve.add_point(curve.get_point_position(0), curve.get_point_in(0))
	timing.append(asset.length)
	speeds.append(speeds[0])
	path.curve = curve
	path.set_meta("target_speeds_kmh", speeds)
	path.set_meta("timing_stations_m", timing)
	path.set_meta("speed_model", "sqrt(1.4 g R), 290 km/h cap, 7.5 m/s² braking, 4 m/s² acceleration")
	asset.add_child(path)
	path.owner = asset


## Lamp placements (Look-4) lit as sodium lamps (Look-2, scripts/track/track_lights.gd). The Marker3D
## placements under Lights/ become poles; the road-following fill adds lamps every 72 m where they leave
## the road dark, and both sides every 26 m through the T13 start. Paddock lamps stand 16 m off the
## road and light the paddock, not the tarmac.
static func add_lighting(asset: Node3D, road: RoadPath, corners: Dictionary, measured: float) -> void:
	var lights = Node3D.new()
	lights.name = "Lights"
	asset.add_child(lights)
	lights.owner = asset
	var stations = road.last_bake.stations
	var total_stations = stations.size()

	# 1. Paddock area lamps at T13 (12 sodium posts)
	for i in range(12):
		var fraction = float(i) / 12.0
		var s = fposmod(measured - 200.0 + fraction * 400.0, measured)
		var index = int(s / measured * total_stations) % total_stations
		var st = stations[index]
		var paddock = SceneryBuilder.add_light_placement(
			lights,
			asset,
			"PaddockLamp%02d" % i,
			st.pos + st.tangent.cross(Vector3.UP) * 16.0,
			st.tangent,
			"pit",
			8.0,
			Color("#F2A14A")
		)
		paddock.set_meta("road_glow", false)

	# 2. Trackside lamp markers (sodium_mast, flood, pit) spaced 40-70 m on alternating sides
	var lamp_ranges = [
		{
			"from": measured - 250.0,
			"to": corners.get("Sabine-Schmitz-Kurve", 280.0) + 60.0,
			"step": 50.0,
			"type": "t13"
		},
		{
			"from": corners.get("Hatzenbach 1", 820.0) - 60.0,
			"to": corners.get("Hocheichen exit", 1490.0),
			"step": 60.0,
			"type": "hatzenbach"
		},
		{
			"from": corners.get("Quiddelbacher Hoehe", 2000.0) - 60.0,
			"to": corners.get("Flugplatz exit", 2440.0) + 60.0,
			"step": 60.0,
			"type": "flugplatz"
		},
		{
			"from": corners.get("Schwedenkreuz", 3030.0) - 60.0,
			"to": corners.get("Aremberg exit", 4150.0),
			"step": 70.0,
			"type": "aremberg"
		}
	]

	var lamp_idx = 0
	for rng in lamp_ranges:
		var s = rng["from"]
		var s_end = rng["to"]
		var step = rng["step"]
		var side_toggle = 1
		while s <= s_end if s_end >= s else (s <= measured or s <= s_end):
			var s_cur = fposmod(s, measured)
			var idx = int(s_cur / measured * total_stations) % total_stations
			var st = stations[idx]
			var right = st.tangent.cross(Vector3.UP).normalized()
			var side_sign = side_toggle
			side_toggle = -side_toggle

			var kind = "sodium_mast"
			var h = 10.0
			var off = 9.0
			if rng["type"] == "t13":
				if s_cur > measured - 200.0 or s_cur < 20.0:
					if side_sign > 0:
						kind = "pit"
						h = 8.0
						off = 12.0
					else:
						kind = "flood"
						h = 12.0
						off = 12.0
				elif s_cur >= 20.0 and s_cur <= 120.0:
					kind = "flood"
					h = 12.0
					off = 12.0
			elif rng["type"] == "hatzenbach" or rng["type"] == "flugplatz":
				kind = "flood"
				h = 12.0

			var lamp_pos = st.pos + right * (side_sign * off)
			var fwd = st.tangent
			lamp_idx += 1
			SceneryBuilder.add_light_placement(
				lights, asset, "TrackLamp%03d" % lamp_idx, lamp_pos, fwd, kind, h, Color("#F2A14A")
			)
			s += step
			if s_end < rng["from"] and s >= measured and fposmod(s, measured) > s_end:
				break

	# 3. Poles, heads and halos for the placements, plus the fill (outside the 1.2 m armco).
	var lamps = TrackLights.from_markers(asset, road, 3.5)
	var start = {"from_m": measured - 240.0, "to_m": 160.0, "spacing": 26.0, "sides": "both"}
	lamps.append_array(TrackLights.fill(road, 72.0, [start], 3.5, lamps))
	TrackLights.build(asset, road, lamps)
	asset.lighting = {"night_lamps": lamps.size()}


static func add_scenery_kit(asset: Node3D, road: RoadPath, corners: Dictionary, measured: float) -> void:
	# 1. Start/Finish Gantry at T13
	var gantry = Gantry.new()
	gantry.name = "StartGantry"
	gantry.follow_road = NodePath("../Main")
	gantry.station = 0.0
	gantry.clearance_height = 6.0
	gantry.extra_width = 3.5
	gantry.light_panel = true
	asset.add_child(gantry)
	gantry.owner = asset
	gantry.bake()

	# 2. Pit building at T13
	var pits = PitBuilding.new()
	pits.name = "PitBuilding"
	pits.follow_road = NodePath("../Main")
	pits.side = PitBuilding.Side.RIGHT
	pits.station = measured - 110.0
	pits.length_m = 90.0
	pits.offset = 12.0
	pits.has_pit_wall = false
	asset.add_child(pits)
	pits.owner = asset
	pits.bake()

	# 3. Grandstands at real Nordschleife locations: T13, Hatzenbach, Flugplatz
	var gs_t13 = Grandstand.new()
	gs_t13.name = "T13Grandstand"
	gs_t13.follow_road = NodePath("../Main")
	gs_t13.side = Grandstand.Side.LEFT
	gs_t13.station = 60.0
	gs_t13.length_m = 90.0
	gs_t13.rows = 10
	gs_t13.offset = 10.0
	gs_t13.has_roof = true
	gs_t13.solid_front = true
	asset.add_child(gs_t13)
	gs_t13.owner = asset
	gs_t13.bake()

	var gs_hatz = Grandstand.new()
	gs_hatz.name = "HatzenbachGrandstand"
	gs_hatz.follow_road = NodePath("../Main")
	gs_hatz.side = Grandstand.Side.RIGHT
	gs_hatz.station = corners.get("Hatzenbach 1", 820.0) - 30.0
	gs_hatz.length_m = 50.0
	gs_hatz.rows = 6
	gs_hatz.offset = 8.0
	gs_hatz.has_roof = false
	gs_hatz.solid_front = true
	asset.add_child(gs_hatz)
	gs_hatz.owner = asset
	gs_hatz.bake()

	var gs_flug = Grandstand.new()
	gs_flug.name = "FlugplatzGrandstand"
	gs_flug.follow_road = NodePath("../Main")
	gs_flug.side = Grandstand.Side.RIGHT
	gs_flug.station = corners.get("Flugplatz", 2340.0) - 40.0
	gs_flug.length_m = 60.0
	gs_flug.rows = 8
	gs_flug.offset = 8.0
	gs_flug.has_roof = false
	gs_flug.solid_front = true
	asset.add_child(gs_flug)
	gs_flug.owner = asset
	gs_flug.bake()

	# 4. Catch fences
	var fence_t13 = CatchFence.new()
	fence_t13.name = "T13CatchFence"
	fence_t13.follow_road = NodePath("../Main")
	fence_t13.side = CatchFence.Side.LEFT
	fence_t13.from_m = measured - 150.0
	fence_t13.to_m = 120.0
	fence_t13.offset = 5.0
	fence_t13.fence_height = 3.5
	fence_t13.solid = true
	asset.add_child(fence_t13)
	fence_t13.owner = asset
	fence_t13.bake()

	var fence_hatz = CatchFence.new()
	fence_hatz.name = "HatzenbachCatchFence"
	fence_hatz.follow_road = NodePath("../Main")
	fence_hatz.side = CatchFence.Side.RIGHT
	fence_hatz.from_m = corners.get("Hatzenbach 1", 820.0) - 30.0
	fence_hatz.to_m = corners.get("Hatzenbach 4", 1250.0) + 30.0
	fence_hatz.offset = 5.0
	fence_hatz.fence_height = 3.5
	fence_hatz.solid = true
	asset.add_child(fence_hatz)
	fence_hatz.owner = asset
	fence_hatz.bake()

	var fence_flug = CatchFence.new()
	fence_flug.name = "FlugplatzCatchFence"
	fence_flug.follow_road = NodePath("../Main")
	fence_flug.side = CatchFence.Side.RIGHT
	fence_flug.from_m = corners.get("Flugplatz", 2340.0) - 80.0
	fence_flug.to_m = corners.get("Flugplatz exit", 2440.0) + 40.0
	fence_flug.offset = 5.0
	fence_flug.fence_height = 3.5
	fence_flug.solid = true
	asset.add_child(fence_flug)
	fence_flug.owner = asset
	fence_flug.bake()

	# 5. Billboards
	var boards_t13 = Billboards.new()
	boards_t13.name = "T13Billboards"
	boards_t13.follow_road = NodePath("../Main")
	boards_t13.side = Billboards.Side.RIGHT
	boards_t13.from_m = 40.0
	boards_t13.to_m = 180.0
	boards_t13.offset = 7.0
	boards_t13.spacing = 40.0
	asset.add_child(boards_t13)
	boards_t13.owner = asset
	boards_t13.bake()

	var boards_quid = Billboards.new()
	boards_quid.name = "QuiddelbachBillboards"
	boards_quid.follow_road = NodePath("../Main")
	boards_quid.side = Billboards.Side.LEFT
	boards_quid.from_m = corners.get("Quiddelbacher Hoehe", 2000.0) - 100.0
	boards_quid.to_m = corners.get("Flugplatz", 2340.0) - 100.0
	boards_quid.offset = 7.0
	boards_quid.spacing = 50.0
	asset.add_child(boards_quid)
	boards_quid.owner = asset
	boards_quid.bake()

	# 6. Marshal posts
	var marshals = MarshalPost.new()
	marshals.name = "MarshalPosts"
	marshals.follow_road = NodePath("../Main")
	marshals.side = MarshalPost.Side.RIGHT
	marshals.offset = 6.0
	marshals.spacing = 300.0
	asset.add_child(marshals)
	marshals.owner = asset
	marshals.bake()

	# 7. Spectator crowd banks at T13, Hatzenbach, Flugplatz, Schwedenkreuz
	SceneryBuilder.build_crowd_bank(asset, road, "T13CrowdBank", measured - 50.0, 80.0, -1, 14.0)
	SceneryBuilder.build_crowd_bank(
		asset, road, "HatzenbachCrowdBank", corners.get("Hatzenbach 2", 950.0), 100.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "FlugplatzCrowdBank", corners.get("Flugplatz", 2340.0) + 40.0, 100.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "SchwedenkreuzCrowdBank", corners.get("Schwedenkreuz", 3030.0), 90.0, -1, 14.0
	)


static func build_asset() -> Node3D:
	var data = read_json(DATA + "centreline.json")
	if data.is_empty() or data.get("points", []).size() < 8:
		return null
	var asset = TrackAsset.new()
	asset.name = "NordschleifeSection1"
	asset.id = "nordschleife_s1"
	asset.display_name = "Nürburgring Nordschleife (Section 1 v0)"
	asset.version = 1
	asset.default_time_of_day = "day"
	asset.set_meta("cache_revision", CACHE_REVISION)
	asset.set_meta(
		"attribution",
		str(
			data.get(
				"attribution",
				"© OpenStreetMap contributors (ODbL); elevation: LVermGeo RLP DGM1 (dl-de/by-2.0)"
			)
		)
	)
	var road = RoadPath.new()
	road.name = "Main"
	road.closed = true
	road.along_step = 1.5
	road.road_stations = 9
	road.grid_slots = 20
	road.grid_first_m = 12.0
	road.grid_spacing_m = 8.0
	road.grid_offset_m = 2.2
	road.curve = plan_curve(data)
	var measured = road.working_curve().get_baked_length()
	var scale_s = measured / source_length(data)
	var corners = corner_specs(data)
	road.sections = sections(data, measured, corners)
	road.elevation_keys = elevation(data, measured)
	asset.add_child(road)
	road.owner = asset
	road.bake()
	asset.prepare()

	var positions = {}
	for corner in corners:
		positions[corner[0]] = corner[1] * scale_s
	asset.set_meta("corners", positions)

	# Timing sectors: S1 = T13 to Hatzenbach exit (~1400m), S2 = Flugplatz to Schwedenkreuz (~3000m)
	var timing = asset.get_node("TimingLine")
	var s1_m = positions.get("Hocheichen", 1400.0 * scale_s)
	var s2_m = positions.get("Schwedenkreuz", 3030.0 * scale_s)
	timing.set_meta("sector_offsets", [s1_m * asset.length / measured, s2_m * asset.length / measured])

	add_bot_line(asset, road)
	var terrain = add_terrain(asset)

	# Barriers: Armco along track, pit concrete at T13
	add_wall(asset, "LeftArmco", WallPath.Side.LEFT, 0, 0.0, -1.0, 0.3)
	add_wall(asset, "RightArmco", WallPath.Side.RIGHT, 0, 0.0, -1.0, 0.3)
	add_wall(asset, "PitConcrete", WallPath.Side.RIGHT, 2, measured - 200.0, 120.0, 0.5)

	# Tyre walls at key heavy-impact outside runoffs
	for corner in corners:
		if corner[0] in ["Sabine-Schmitz-Kurve", "Hatzenbach 1", "Hocheichen", "Flugplatz", "Aremberg"]:
			var side = WallPath.Side.LEFT if corner[4] > 0 else WallPath.Side.RIGHT
			add_wall(
				asset,
				corner[0].replace(" ", "") + "Tyres",
				side,
				1,
				fposmod((corner[1] - 60.0) * scale_s, measured),
				fposmod((corner[1] + 70.0) * scale_s, measured),
				0.3
			)

	# The Nordschleife runs through Eifel forest: a near row and a deep band behind it.
	# The Eifel forest stands right behind the armco: a dense near wall, then a deep band.
	add_forest(asset, terrain, "EifelNear", 0.0, -1.0, 56.0, 1.5, 18.0, 713)
	add_forest(asset, terrain, "EifelDeep", 0.0, -1.0, 34.0, 18.0, 120.0, 714)
	add_scenery_kit(asset, road, positions, measured)
	add_lighting(asset, road, positions, measured)
	return asset


func _initialize() -> void:
	var asset = build_asset()
	if asset == null:
		quit(1)
		return
	var warnings = asset.get_node("Main").last_bake.warnings
	print("BAKE warnings=%d %s" % [warnings.size(), warnings])
	var errors = asset.validate()
	print("VALIDATE errors=%d %s" % [errors.size(), errors])
	var len_road = asset.get_node("Main").last_bake.length
	print("LENGTH road=%.3f lap=%.3f m" % [len_road, asset.length])
	print(
		(
			"TERRAIN spacing=%.1f m triangles=%d"
			% [asset.get_meta("terrain_mesh_spacing_m", 0.0), asset.get_meta("terrain_triangles", 0)]
		)
	)
	if not errors.is_empty():
		asset.free()
		quit(1)
	var out_dir = ProjectSettings.globalize_path("res://tracks3d/nordschleife_s1")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var packed = PackedScene.new()
	var error = packed.pack(asset)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Nordschleife S1 pack/save failed: %d" % error)
	else:
		print("SCENE bytes=%d path=%s" % [FileAccess.get_file_as_bytes(OUTPUT).size(), OUTPUT])
	asset.free()
	quit(0 if error == OK else 1)
