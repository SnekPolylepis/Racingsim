extends SceneTree
## Nürburgring Nordschleife: The Full Lap (~20.8 km, T13 back to T13).
## Rebuild: tools/Godot.exe --headless --path . --script trackgen/nordschleife.gd
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
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
const OUTPUT = "res://tracks3d/nordschleife/nordschleife.scn"
const CACHE_REVISION = 8
## Caracciola-Karussell apex station (source metres): the concrete bowl on the inside of the right-hander.
const KARUSSELL_S = 12115.0
## The bowl's reach either side of the apex (source metres); no kerbs anywhere in it.
const KARUSSELL_REACH = 60.0


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
## turn_direction: +1 right, -1 left, 0 straight
## kerb_type: 0 none/ramp, 1 sausage, 2 ribbed
static func corner_specs(data: Dictionary) -> Array:
	var positions = data.get("sections", {})
	var defaults = [
		["T13", 50.0, 1.1, 9.0, 1, 0],
		["Sabine-Schmitz-Kurve", 280.0, -4.5, 9.8, -1, 0],
		["Hatzenbogen", 400.0, -5.6, 9.5, -1, 0],
		["Hatzenbach 1", 820.0, 3.9, 11.8, 1, 2],
		["Hatzenbach 2", 950.0, -1.0, 11.0, -1, 2],
		["Hatzenbach 3", 1120.0, 3.0, 10.0, 1, 2],
		["Hatzenbach 4", 1250.0, -4.1, 9.5, -1, 2],
		["Hocheichen", 1400.0, 2.6, 11.3, 1, 2],
		["Hocheichen exit", 1490.0, -2.0, 10.0, -1, 0],
		["Quiddelbacher Hoehe", 2150.0, 1.6, 9.0, 1, 0],
		["Flugplatz", 2340.0, 3.3, 10.5, 1, 0],
		["Flugplatz exit", 2440.0, -3.8, 10.0, -1, 0],
		["Schwedenkreuz", 3030.0, -1.8, 11.3, -1, 0],
		["Aremberg entry", 3650.0, 4.4, 8.5, 1, 0],
		["Aremberg", 3790.0, 6.9, 8.5, 1, 1],
		["Aremberg exit", 4150.0, 4.3, 8.5, 1, 0],
		["Fuchsroehre", 4600.0, 4.5, 9.5, 1, 0],
		["Adenauer Forst entry", 5200.0, -4.0, 10.0, -1, 2],
		["Adenauer Forst", 5270.0, 3.5, 10.0, 1, 2],
		["Metzgesfeld", 5870.0, -2.5, 9.5, -1, 2],
		["Kallenhard", 6480.0, 5.0, 9.0, 1, 2],
		["Wehrseifen entry", 7400.0, 3.0, 9.5, 1, 0],
		["Wehrseifen", 7470.0, 4.5, 9.0, 1, 2],
		["Breidscheid", 7915.0, -3.0, 9.5, -1, 2],
		["Ex-Muehle", 8360.0, 3.5, 9.0, 1, 2],
		["Bergwerk", 9120.0, 4.5, 9.5, 1, 2],
		["Kesselchen", 10380.0, -2.0, 10.0, -1, 0],
		["Klostertal", 11330.0, 3.0, 9.5, 1, 0],
		["Steilstrecke", 11750.0, 3.5, 9.5, 1, 0],
		# The Karussell is a left-hand hairpin (inside banked down to the left).
		["Karussell approach", 12050.0, -3.0, 9.5, -1, 0],
		["Karussell", 12115.0, -9.0, 14.0, -1, 0],
		["Karussell exit", 12180.0, -2.0, 9.5, -1, 0],
		["Hohe Acht", 12750.0, 4.0, 9.5, 1, 2],
		["Hedwigshoehe", 13150.0, -2.5, 9.5, -1, 0],
		["Wippermann", 13620.0, 3.5, 9.5, 1, 2],
		["Eschbach", 13990.0, -3.0, 9.5, -1, 2],
		["Bruennchen entry", 14400.0, 4.5, 10.0, 1, 2],
		["Bruennchen", 14450.0, 4.5, 10.0, 1, 2],
		["Eiskurve", 14850.0, -3.5, 9.5, -1, 2],
		["Pflanzgarten", 15260.0, 3.0, 9.5, 1, 0],
		["Sprunghuegel", 15770.0, 1.5, 9.5, 1, 0],
		["Stefan-Bellof-S", 16100.0, -3.0, 9.5, -1, 0],
		["Schwalbenschwanz", 16770.0, 4.0, 9.5, 1, 2],
		["Kleines Karussell", 17050.0, 4.5, 9.5, 1, 0],
		["Galgenkopf 1", 17400.0, 4.0, 10.0, 1, 0],
		["Galgenkopf", 17550.0, 4.5, 10.0, 1, 0],
		["Doettinger Hoehe", 18300.0, 0.0, 11.5, 0, 0],
		["Antoniusbuche", 19620.0, -2.0, 11.5, -1, 0],
		["Tiergarten", 20210.0, -2.5, 11.0, -1, 0],
		["Hohenrain", 20550.0, 2.5, 10.5, 1, 2]
	]
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
		# Narrow roadside enclosure: 0.5 m grass shoulder, 1.5 m verge, armco at 0.3 m beyond verge
		"runoff_left": 4.0 if paddock else 0.5,
		"runoff_right": 4.0 if paddock else 0.5,
		"runoff_surface": 4 if paddock else 2,
		"verge_left": 1.5,
		"verge_right": 1.5,
		"verge_slope_deg": 0.0,
		"verge_surface": 2,
		"verge_surface_left": -1,
		"verge_surface_right": -1,
		"ditch": 0.0,
		"ditch_offset": 2.2,
		"ditch_floor": 1.0,
		"ditch_wall": 0.5,
		"ditch_angle_deg": 20.0,
		"ditch_fillet": 0.2
	}

	# Caracciola-Karussell (references: docs/art/reference/real-nordschleife-karussell-*.jpg, nring.info,
	# Porsche Newsroom): a near-180 degree left hairpin. Inside out: a narrow asphalt strip at the lowest point,
	# a ~4.5 m band of concrete slabs banked ~20 degrees rising outward, then the outer asphalt banked more
	# gently (the whole road here, -9 degrees). One continuous slope, not a trench: the ditch profile is used
	# one-sided, with its floor as the inner strip at the tarmac edge and its outer wall as the concrete bank.
	var kar_delta = circular_delta(s, KARUSSELL_S, length)
	if absf(kar_delta) <= 55.0:
		# With the 7 m left half-width at the apex: floor -7.4..-5.8 (1.2 m strip on the tarmac), bank -5.8..-1.4.
		values.ditch_offset = -6.6
		values.ditch_floor = 0.8
		values.ditch_wall = 4.4
		values.ditch_angle_deg = 20.0
		values.ditch_fillet = 0.4
		if absf(kar_delta) <= 40.0:
			values.ditch = 1.0
		elif kar_delta < 0.0:
			values.ditch = smoothstep(-55.0, -40.0, kar_delta)
		else:
			values.ditch = 1.0 - smoothstep(40.0, 55.0, kar_delta)

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
		elif delta >= 25.0 and delta < 80.0 and corner[5] != 0:
			# LOOK-21: kerbs only where the corner spec flags them (kerb_type 1/2). Every turning corner used to
			# get an inside ramp and an outside exit kerb, so the lap was red and white nearly everywhere, where
			# many real Nordschleife corners have only edge lines. A stopgap until traced kerbs (K-03) land.
			values["kerb_" + outside] = RoadSection.Kerb.RIBBED

	values.bank_deg = total_bank / maxf(total_bank_weight, 1.0)
	# The Karussell has no kerbs: the bowl is the inside edge.
	if absf(kar_delta) <= KARUSSELL_REACH:
		values.kerb_left = RoadSection.Kerb.NONE
		values.kerb_right = RoadSection.Kerb.NONE
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
	# Karussell transition keys
	for offset in [-KARUSSELL_REACH, -55.0, -40.0, -20.0, 0.0, 20.0, 40.0, 55.0, KARUSSELL_REACH]:
		marks.append(fposmod(KARUSSELL_S + offset, length))
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
	if not FileAccess.file_exists(DATA + "terrain_full.json"):
		push_warning("Nordschleife full terrain unavailable; broad authored verges remain driveable")
		return {}
	var header = read_json(DATA + "terrain_full.json")
	var raw_path = DATA + str(header.get("file", "dem_full.raw"))
	if header.is_empty() or not FileAccess.file_exists(raw_path):
		return {}
	var raw = FileAccess.get_file_as_bytes(raw_path).to_float32_array()
	var width = int(header.width)
	var height = int(header.height)
	if raw.size() != width * height:
		push_warning("Nordschleife DEM dimensions do not match float32 payload; skipping terrain")
		return {}
	var pixel = float(header.metres_per_pixel)
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
	terrain.blend_m = 6.0
	terrain.under_road_drop_m = 2.0
	terrain.chunk_size = 64
	asset.add_child(terrain)
	terrain.owner = asset
	terrain.bake()

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
	for i in multimesh.instance_count:
		var xf: Transform3D = trees.last_bake.xforms[i]
		if near_road(clear, xf.origin):
			xf = Transform3D(Basis.from_scale(Vector3.ZERO), xf.origin)
		elif not terrain.is_empty():
			xf.origin.y = terrain_height(terrain, xf.origin)
		multimesh.set_instance_transform(i, xf)


const CLEAR_M = 24.0
const TREE_CLEAR_M = 9.5


static func road_clearance(road) -> Dictionary:
	var cells = {}
	for p in road.last_bake.center:
		var key = Vector2i(floori(p.x / CLEAR_M), floori(p.z / CLEAR_M))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(Vector2(p.x, p.z))
	return cells


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


static func add_lighting(asset: Node3D, road: RoadPath, corners: Dictionary, measured: float) -> void:
	var lights = Node3D.new()
	lights.name = "Lights"
	asset.add_child(lights)
	lights.owner = asset
	var stations = road.last_bake.stations
	var total_stations = stations.size()

	# Paddock area lamps at T13
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

	# Key lighted corner sectors along full lap
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
			"from": corners.get("Quiddelbacher Hoehe", 2150.0) - 60.0,
			"to": corners.get("Flugplatz exit", 2440.0) + 60.0,
			"step": 60.0,
			"type": "flugplatz"
		},
		{
			"from": corners.get("Schwedenkreuz", 3030.0) - 60.0,
			"to": corners.get("Aremberg exit", 4150.0),
			"step": 70.0,
			"type": "aremberg"
		},
		{
			"from": corners.get("Breidscheid", 7915.0) - 80.0,
			"to": corners.get("Ex-Muehle", 8360.0) + 60.0,
			"step": 50.0,
			"type": "breidscheid"
		},
		{
			"from": corners.get("Karussell", 12115.0) - 60.0,
			"to": corners.get("Karussell", 12115.0) + 60.0,
			"step": 40.0,
			"type": "karussell"
		},
		{
			"from": corners.get("Bruennchen", 14450.0) - 60.0,
			"to": corners.get("Bruennchen", 14450.0) + 60.0,
			"step": 50.0,
			"type": "bruennchen"
		},
		{
			"from": corners.get("Doettinger Hoehe", 18300.0) - 50.0,
			"to": corners.get("Doettinger Hoehe", 18300.0) + 500.0,
			"step": 80.0,
			"type": "dottinger"
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
			elif rng["type"] in ["hatzenbach", "flugplatz", "breidscheid", "karussell"]:
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

	# 3. Grandstands
	var grandstands = [
		{
			"name": "T13Grandstand",
			"station": 60.0,
			"side": Grandstand.Side.LEFT,
			"len": 90.0,
			"rows": 10,
			"roof": true
		},
		{
			"name": "HatzenbachGrandstand",
			"station": corners.get("Hatzenbach 1", 820.0) - 30.0,
			"side": Grandstand.Side.RIGHT,
			"len": 50.0,
			"rows": 6,
			"roof": false
		},
		{
			"name": "FlugplatzGrandstand",
			"station": corners.get("Flugplatz", 2340.0) - 40.0,
			"side": Grandstand.Side.RIGHT,
			"len": 60.0,
			"rows": 8,
			"roof": false
		},
		{
			"name": "BreidscheidGrandstand",
			"station": corners.get("Breidscheid", 7915.0) - 20.0,
			"side": Grandstand.Side.LEFT,
			"len": 45.0,
			"rows": 6,
			"roof": false
		},
		{
			"name": "BruennchenGrandstand",
			"station": corners.get("Bruennchen", 14450.0) - 30.0,
			"side": Grandstand.Side.RIGHT,
			"len": 60.0,
			"rows": 8,
			"roof": false
		}
	]
	for gs_data in grandstands:
		var gs = Grandstand.new()
		gs.name = gs_data["name"]
		gs.follow_road = NodePath("../Main")
		gs.side = gs_data["side"]
		gs.station = gs_data["station"]
		gs.length_m = gs_data["len"]
		gs.rows = gs_data["rows"]
		gs.offset = 8.0
		gs.has_roof = gs_data["roof"]
		gs.solid_front = true
		asset.add_child(gs)
		gs.owner = asset
		gs.bake()

	# 4. Catch fences
	var fences = [
		{"name": "T13CatchFence", "side": CatchFence.Side.LEFT, "from": measured - 150.0, "to": 120.0},
		{
			"name": "HatzenbachCatchFence",
			"side": CatchFence.Side.RIGHT,
			"from": corners.get("Hatzenbach 1", 820.0) - 30.0,
			"to": corners.get("Hatzenbach 4", 1250.0) + 30.0
		},
		{
			"name": "FlugplatzCatchFence",
			"side": CatchFence.Side.RIGHT,
			"from": corners.get("Flugplatz", 2340.0) - 80.0,
			"to": corners.get("Flugplatz exit", 2440.0) + 40.0
		},
		{
			"name": "BreidscheidCatchFence",
			"side": CatchFence.Side.LEFT,
			"from": corners.get("Breidscheid", 7915.0) - 50.0,
			"to": corners.get("Breidscheid", 7915.0) + 50.0
		},
		{
			"name": "BruennchenCatchFence",
			"side": CatchFence.Side.RIGHT,
			"from": corners.get("Bruennchen", 14450.0) - 60.0,
			"to": corners.get("Bruennchen", 14450.0) + 60.0
		}
	]
	for fc in fences:
		var fence = CatchFence.new()
		fence.name = fc["name"]
		fence.follow_road = NodePath("../Main")
		fence.side = fc["side"]
		fence.from_m = fc["from"]
		fence.to_m = fc["to"]
		fence.offset = 5.0
		fence.fence_height = 3.5
		fence.solid = true
		asset.add_child(fence)
		fence.owner = asset
		fence.bake()

	# 5. Billboards
	var billboards = [
		{"name": "T13Billboards", "side": Billboards.Side.RIGHT, "from": 40.0, "to": 180.0, "spacing": 40.0},
		{
			"name": "QuiddelbachBillboards",
			"side": Billboards.Side.LEFT,
			"from": corners.get("Quiddelbacher Hoehe", 2150.0) - 100.0,
			"to": corners.get("Flugplatz", 2340.0) - 100.0,
			"spacing": 50.0
		},
		{
			"name": "DottingerBillboards",
			"side": Billboards.Side.RIGHT,
			"from": corners.get("Doettinger Hoehe", 18300.0) + 100.0,
			"to": corners.get("Doettinger Hoehe", 18300.0) + 800.0,
			"spacing": 70.0
		}
	]
	for bb in billboards:
		var boards = Billboards.new()
		boards.name = bb["name"]
		boards.follow_road = NodePath("../Main")
		boards.side = bb["side"]
		boards.from_m = bb["from"]
		boards.to_m = bb["to"]
		boards.offset = 7.0
		boards.spacing = bb["spacing"]
		asset.add_child(boards)
		boards.owner = asset
		boards.bake()

	# 6. Marshal posts spaced every 300 m along full lap
	var marshals = MarshalPost.new()
	marshals.name = "MarshalPosts"
	marshals.follow_road = NodePath("../Main")
	marshals.side = MarshalPost.Side.RIGHT
	marshals.offset = 6.0
	marshals.spacing = 300.0
	asset.add_child(marshals)
	marshals.owner = asset
	marshals.bake()

	# 7. Spectator crowd banks at key scenic spectator spots
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
	SceneryBuilder.build_crowd_bank(
		asset, road, "AdenauerForstCrowdBank", corners.get("Adenauer Forst", 5270.0), 90.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "WehrseifenCrowdBank", corners.get("Wehrseifen", 7470.0), 80.0, -1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "KarussellCrowdBank", corners.get("Karussell", 12115.0), 80.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "BruennchenCrowdBank", corners.get("Bruennchen", 14450.0) + 20.0, 100.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "PflanzgartenCrowdBank", corners.get("Pflanzgarten", 15260.0), 90.0, 1, 14.0
	)


static func build_asset() -> Node3D:
	var data = read_json(DATA + "centreline_full.json")
	if data.is_empty() or data.get("points", []).size() < 8:
		return null
	var asset = TrackAsset.new()
	asset.name = "Nordschleife"
	asset.id = "nordschleife"
	asset.display_name = "Nürburgring Nordschleife"
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
	# Dense station range for Karussell's concrete bowl
	road.dense_ranges = [{"from_m": 12050.0, "to_m": 12180.0, "road_stations": 57}]
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
	# Concrete slabs in the Karussell bowl: road_v2's per-instance band, in the road's UV metres
	# (UV.y along the working curve, UV.x across it, + right).
	var kar_s = KARUSSELL_S * scale_s
	var band = Vector4(kar_s - 55.0 * scale_s, kar_s + 55.0 * scale_s, -5.9, -1.3)
	# The render mesh is the asset's Road/Main (built by prepare()), not a child of the RoadPath.
	var road_mesh = asset.get_node_or_null("Road/Main") as GeometryInstance3D
	if road_mesh:
		road_mesh.set_instance_shader_parameter("concrete_band", band)
	else:
		push_warning("Nordschleife: Road/Main render mesh not found; Karussell concrete skipped")

	var positions = {}
	for corner in corners:
		positions[corner[0]] = corner[1] * scale_s
	asset.set_meta("corners", positions)

	# Timing sectors: 3 sectors across 20.8 km lap (splits at Adenauer Forst ~5270m and Doettinger Hoehe ~18300m)
	var timing = asset.get_node("TimingLine")
	var s1_m = positions.get("Adenauer Forst", 5270.0 * scale_s)
	var s2_m = positions.get("Doettinger Hoehe", 18300.0 * scale_s)
	timing.set_meta("sector_offsets", [s1_m * asset.length / measured, s2_m * asset.length / measured])

	add_bot_line(asset, road)
	var terrain = add_terrain(asset)

	# Barriers: Armco along track, pit concrete at T13
	add_wall(asset, "LeftArmco", WallPath.Side.LEFT, 0, 0.0, -1.0, 0.3)
	add_wall(asset, "RightArmco", WallPath.Side.RIGHT, 0, 0.0, -1.0, 0.3)
	add_wall(asset, "PitConcrete", WallPath.Side.RIGHT, 2, measured - 200.0, 120.0, 0.5)

	# Tyre walls at heavy-impact outside runoffs
	var tyre_corners = [
		"Sabine-Schmitz-Kurve",
		"Hatzenbach 1",
		"Hocheichen",
		"Flugplatz",
		"Aremberg",
		"Adenauer Forst",
		"Metzgesfeld",
		"Kallenhard",
		"Wehrseifen",
		"Ex-Muehle",
		"Bergwerk",
		"Hohe Acht",
		"Wippermann",
		"Bruennchen",
		"Pflanzgarten",
		"Schwalbenschwanz",
		"Galgenkopf"
	]
	for corner in corners:
		if corner[0] in tyre_corners:
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

	# Eifel forest
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
	var out_dir = ProjectSettings.globalize_path("res://tracks3d/nordschleife")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var packed = PackedScene.new()
	var error = packed.pack(asset)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Nordschleife pack/save failed: %d" % error)
	else:
		print("SCENE bytes=%d path=%s" % [FileAccess.get_file_as_bytes(OUTPUT).size(), OUTPUT])
	asset.free()
	quit(0 if error == OK else 1)
