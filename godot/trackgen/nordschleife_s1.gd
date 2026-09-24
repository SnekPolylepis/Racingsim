extends SceneTree
## Nürburgring Nordschleife Section 1 groundwork (T13 to Aremberg + return road).
## Rebuild: tools/Godot.exe --headless --path . --script trackgen/nordschleife_s1.gd
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const TerrainPatch = preload("res://scripts/track/terrain.gd")

const DATA = "res://trackgen/data/nordschleife/"
const OUTPUT = "res://tracks3d/nordschleife_s1/nordschleife_s1.scn"
const CACHE_REVISION = 2


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
		"runoff_left": 4.0 if paddock else 2.5,
		"runoff_right": 4.0 if paddock else 2.5,
		"runoff_surface": 4,
		"verge_left": 6.0,
		"verge_right": 6.0,
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
		values["runoff_" + outside] = maxf(values["runoff_" + outside], 2.5 + 8.0 * weight)
		values["runoff_" + inside] = maxf(values["runoff_" + inside], 2.5 + 3.0 * weight)
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
	var mesh_spacing = 10.0
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
	terrain.blend_m = 30.0
	terrain.under_road_drop_m = 2.0
	terrain.chunk_size = 64
	asset.add_child(terrain)
	terrain.owner = asset
	terrain.bake()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.36, 0.16)
	material.roughness = 1.0
	for chunk in asset.get_node("Terrain/Eifel").get_children():
		chunk.material_override = material
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


## Look-2 sodium lamps (scripts/track/track_lights.gd): every 72 m on alternating sides, both sides
## every 26 m through the T13 start and pit area. Poles stand 3.5 m beyond the verge, outside the
## 1.2 m armco.
static func add_lighting(asset: Node3D, road: RoadPath) -> void:
	var length = road.last_bake.length
	var zones = [{"from_m": length - 240.0, "to_m": 160.0, "spacing": 26.0, "sides": "both"}]
	TrackLights.build(asset, road, TrackLights.place(road, 72.0, zones, 3.5))


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
	add_wall(asset, "LeftArmco", WallPath.Side.LEFT, 0, 0.0, -1.0, 1.2)
	add_wall(asset, "RightArmco", WallPath.Side.RIGHT, 0, 0.0, -1.0, 1.2)
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

	add_lighting(asset, road)
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
