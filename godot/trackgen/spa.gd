extends SceneTree
## Spa v0: authored RoadPath over the OSM GP centreline and licensed elevation data.
## Rebuild: tools/Godot.exe --headless --path . --script trackgen/spa.gd
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const TerrainPatch = preload("res://scripts/track/terrain.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
const Grandstand = preload("res://scripts/track/grandstand.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const Billboards = preload("res://scripts/track/billboards.gd")
const PitBuilding = preload("res://scripts/track/pit_building.gd")
const MarshalPost = preload("res://scripts/track/marshal_post.gd")
const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const DATA = "res://trackgen/data/spa/"
const OUTPUT = "res://tracks3d/spa/spa.scn"
const CACHE_REVISION = 2
const REFERENCE_LENGTH = 7004.0


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Spa source is missing: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Spa source is not a JSON object: " + path)
		return {}
	return parsed


## Cubic Hermite tangents preserve the OSM outline while avoiding polygonal steering steps.
## Each tangent is limited by the shorter neighbour to keep the two slow chicanes tight.
static func plan_curve(data: Dictionary) -> Curve3D:
	var points = PackedVector3Array()
	for p in data.points:
		points.append(Vector3(float(p[0]), 0.0, float(p[1])))
	if points[0].distance_to(points[-1]) < .01:
		points.remove_at(points.size() - 1)
	var curve = Curve3D.new()
	curve.bake_interval = .25
	for i in points.size():
		var before = points[posmod(i - 1, points.size())]
		var after = points[(i + 1) % points.size()]
		var tangent = (after - before).normalized()
		var incoming = points[i].distance_to(before)
		var outgoing = points[i].distance_to(after)
		var reach = minf(incoming, outgoing) / 3.0
		curve.add_point(points[i], -tangent * reach, tangent * reach)
	return curve


static func source_length(data: Dictionary) -> float:
	# Elevation and corner keys are measured on the original OSM polyline.
	var original = float(data.get("measurements", {}).get("source_polyline_length_m", 0.0))
	if original > 0.0:
		return original
	var points = data.points
	var total = 0.0
	for i in points.size():
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		total += Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1]))
	return total


## s is authored by source station. Widths, banks, runoffs and kerbs are v0 approximations;
## the surveyed terrain profile is distinct from these hand-authored cross-sections.
static func corner_specs(data: Dictionary) -> Array:
	var positions = data.get("sections", {})
	var defaults = [
		["La Source", 350.0, 1.5, 7.5, 1, 1],
		["Eau Rouge", 950.0, -3.0, 6.5, -1, 0],
		["Raidillon", 1100.0, 4.0, 6.5, 1, 0],
		["Les Combes", 2250.0, 2.0, 6.5, 1, 0],
		["Malmedy", 2470.0, 2.0, 6.3, 1, 0],
		["Bruxelles", 2840.0, 2.0, 6.2, 1, 0],
		["No Name", 3150.0, -1.5, 6.2, -1, 0],
		["Pouhon", 3600.0, -3.5, 6.4, -1, 0],
		["Fagnes", 4100.0, 2.0, 6.2, 1, 0],
		["Stavelot", 4600.0, 2.0, 6.3, 1, 0],
		["Paul Frere", 4820.0, 2.0, 6.4, 1, 0],
		["Blanchimont", 5750.0, -2.5, 6.4, -1, 0],
		["Bus Stop", 6720.0, 1.0, 7.8, 1, 1],
	]
	var length = source_length(data)
	for row in defaults:
		row[1] = float(positions.get(row[0], row[1] * length / REFERENCE_LENGTH))
	# Second apexes of the right-left combinations and Raidillon's left-hand crest.
	for item in [["Les Combes", 90.0], ["Fagnes", 95.0], ["Bus Stop", 55.0], ["Raidillon", 115.0]]:
		for row in defaults.duplicate():
			if row[0] == item[0]:
				defaults.append([row[0] + " exit", row[1] + item[1], -row[2], row[3], -row[4], row[5]])
				break
	defaults.sort_custom(func(a, b): return a[1] < b[1])
	return defaults


## The measured road (P6-01 polish): trackgen/data/spa/road-profile.json from analyse_road.py, one row
## per ~10 m centreline station. Half-widths to the track limits (inside of the white line) and the
## kerbs beyond them come from SPW Orthophotos 2023 Été; the crossfall bank from SPW's 0.5 m LiDAR
## ground model (line fit within 3.5 m of the centreline). Loaded once; {} when the file is missing.
static var measured_rows = []


static func measured(s: float, length: float) -> Dictionary:
	if measured_rows.is_empty():
		measured_rows = read_json(DATA + "road-profile.json").get("stations", [])
	var n = measured_rows.size()
	if n == 0:
		return {}
	var f = fposmod(s, length) / length * n
	var i = int(floor(f)) % n
	var j = (i + 1) % n
	var t = f - floor(f)
	var a = measured_rows[i]
	var b = measured_rows[j]
	var near = a if t < .5 else b
	var out = {"bank": lerpf(float(a.bank_smooth_deg), float(b.bank_smooth_deg), t)}
	for side in ["left", "right"]:
		var ha = a["half_" + side + "_m"]
		var hb = b["half_" + side + "_m"]
		if ha != null and hb != null:
			out["half_" + side] = lerpf(float(ha), float(hb), t)
		out["kerb_" + side] = float(near["kerb_" + side])
	return out


static func circular_delta(s: float, at: float, length: float) -> float:
	return fposmod(s - at + length * .5, length) - length * .5


static func profile_at(s: float, length: float, corners: Array) -> Dictionary:
	var paddock = s < corners[0][1] - 70.0 or s > length - 220.0
	var values = {
		"width_left": 7.0 if paddock else 6.2,
		"width_right": 7.0 if paddock else 6.2,
		"bank_deg": 0.0,
		"crown": .025,
		"kerb_left": RoadSection.Kerb.NONE,
		"kerb_right": RoadSection.Kerb.NONE,
		"kerb_width": .9,
		"kerb_height": .045,
		"rib_height": .006,
		"rib_pitch": .75,
		"runoff_left": 4.0 if paddock else 3.0,
		"runoff_right": 4.0 if paddock else 3.0,
		"runoff_surface": 4,
		"verge_left": 7.0,
		"verge_right": 7.0,
		# A flat runoff/verge also avoids the known P3-03 slope-across-runoff stitch discrepancy.
		"verge_slope_deg": 0.0,
		"verge_surface": 2,
		"verge_surface_left": -1,
		"verge_surface_right": -1,
	}
	var total_bank = 0.0
	var total_bank_weight = 0.0
	for corner in corners:
		var delta = circular_delta(s, corner[1], length)
		var weight = smoothstep(-130.0, -45.0, delta) * (1.0 - smoothstep(35.0, 145.0, delta))
		if weight <= 0.0:
			continue
		values.width_left = maxf(values.width_left, lerpf(6.2, corner[3], weight))
		values.width_right = maxf(values.width_right, lerpf(6.2, corner[3], weight))
		total_bank += corner[2] * weight
		total_bank_weight += weight
		var inside = "right" if corner[4] > 0 else "left"
		var outside = "left" if corner[4] > 0 else "right"
		# Runoff grows on corner outsides, but half as far as v0 (4 + 20 w): the whole cross-section is built
		# in the road's banked frame, so with the measured banks (up to ~4 deg) a 24 m runoff plus a 20 m
		# verge ended 1.5 m above the real, flat ground (LiDAR) and left a ledge where the terrain began.
		values["runoff_" + outside] = maxf(values["runoff_" + outside], 4.0 + 10.0 * weight)
		values["runoff_" + inside] = maxf(values["runoff_" + inside], 3.0 + 4.0 * weight)
		if delta >= -55.0 and delta < 30.0:
			values["kerb_" + inside] = RoadSection.Kerb.SAUSAGE if corner[5] else RoadSection.Kerb.RAMP
			values.kerb_height = .075 if corner[5] else .045
		elif delta >= 30.0 and delta < 120.0:
			values["kerb_" + outside] = RoadSection.Kerb.RIBBED
		if corner[0] in ["Les Combes", "Pouhon", "Stavelot"] and weight > .1:
			values["verge_surface_" + outside] = 3
			values["verge_" + outside] = 8.0
	# Overlapping corners blend their banks by weight (the strongest alone flipped the bank 3.8 degrees
	# in 2.5 m between Les Combes and Malmedy); a lone corner still fades in by its own weight.
	values.bank_deg = total_bank / maxf(total_bank_weight, 1.0)
	# Measured widths, banking and kerb positions replace v0's authored ones where the data has them.
	# Kerb profiles keep v0's rules (sausage at La Source and the Bus Stop apexes, ramp on inside
	# apexes, ribbed on exits); a kerb the photos show where v0 had none is a ramp, and one v0 had
	# where the photos show none is removed. Runoffs and verges stay authored.
	var m = measured(s, length)
	if not m.is_empty():
		values.bank_deg = m.bank
		var kerb_w = 0.0
		for side in ["left", "right"]:
			if m.has("half_" + side):
				values["width_" + side] = m["half_" + side]
			if m["kerb_" + side] >= .5:
				if values["kerb_" + side] == RoadSection.Kerb.NONE:
					values["kerb_" + side] = RoadSection.Kerb.RAMP
				kerb_w = maxf(kerb_w, m["kerb_" + side])
			else:
				values["kerb_" + side] = RoadSection.Kerb.NONE
		if kerb_w > 0.0:
			values.kerb_width = clampf(kerb_w, .6, 1.8)
	return values


static func sections(data: Dictionary, measured: float, corners: Array) -> Array[RoadSection]:
	var length = source_length(data)
	var marks = [0.0]
	var s = 20.0
	while s < length:
		marks.append(s)
		# Every 10 m: the measured road's station spacing.
		s += 10.0
	for corner in corners:
		for offset in [-130.0, -55.0, -45.0, 0.0, 30.0, 35.0, 120.0, 145.0]:
			marks.append(fposmod(corner[1] + offset, length))
	marks.sort()
	var keys: Array[RoadSection] = []
	var previous = -1.0
	for mark in marks:
		if mark - previous < .05:
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
	asset: Node3D, title: String, side: int, kind: int, from_m: float, to_m: float, extra = 2.0
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


## Licensed DEM samples supply the road profile. The broad surrounding terrain is resampled to
## approximately 10 m so baking/caching remains practical on a developer machine.
static func add_terrain(asset: Node3D) -> Dictionary:
	if not FileAccess.file_exists(DATA + "terrain.json"):
		push_warning("Spa terrain unavailable; broad authored verges remain driveable")
		return {}
	var header = read_json(DATA + "terrain.json")
	var raw_path = DATA + str(header.get("file", "dem.raw"))
	if header.is_empty() or not FileAccess.file_exists(raw_path):
		return {}
	var raw = FileAccess.get_file_as_bytes(raw_path).to_float32_array()
	var width = int(header.width)
	var height = int(header.height)
	if raw.size() != width * height:
		push_warning("Spa DEM dimensions do not match its float32 payload; skipping terrain")
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
	terrain.name = "Ardennes"
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
	# The chunks keep terrain.gd's PS2 grass (Look-1); a flat colour override here predated it.
	# Recover the exact stitched grid from the baked vertices to ground the trees, without
	# repeating the expensive road/terrain stitching pass.
	var heights = PackedFloat64Array()
	heights.resize(w * h)
	for chunk in asset.get_node("Terrain/Ardennes").get_children():
		var vertices = chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			var gx = roundi((point.x - terrain.origin_offset.x) / mesh_spacing)
			var gz = roundi((point.z - terrain.origin_offset.y) / mesh_spacing)
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
	# Match TerrainPatch's diagonal, rather than bilinear interpolation through a different surface.
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


static func road_clearance(road) -> Dictionary:
	var cells = {}
	for p in road.last_bake.center:
		var key = Vector2i(floori(p.x / CLEAR_M), floori(p.z / CLEAR_M))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(Vector2(p.x, p.z))
	return cells


## True when `point` is within CLEAR_M of the road's centreline anywhere on the circuit.
static func near_road(cells: Dictionary, point: Vector3) -> bool:
	var at = Vector2(point.x, point.z)
	var cx = floori(point.x / CLEAR_M)
	var cz = floori(point.z / CLEAR_M)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for p in cells.get(Vector2i(cx + dx, cz + dz), []):
				if at.distance_squared_to(p) < CLEAR_M * CLEAR_M:
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
	for i in range(0, stations.size(), 4):
		var p = center[i]
		curve.add_point(p)
		timing.append(cumulative[i])
		var before = center[posmod(i - 10, center.size())]
		var after = center[(i + 10) % center.size()]
		var a = Vector2(p.x - before.x, p.z - before.z)
		var b = Vector2(after.x - p.x, after.z - p.z)
		var chord = Vector2(after.x - before.x, after.z - before.z)
		var curvature = 2.0 * absf(a.cross(b)) / maxf(a.length() * b.length() * chord.length(), .001)
		speeds.append(minf(300.0 / 3.6, sqrt(1.6 * 9.81 / maxf(curvature, .00001))))
	# Cyclic backwards braking envelope (8 m/s²), then a conservative 4 m/s² acceleration envelope.
	for iteration in range(3):
		for i in range(speeds.size() - 1, -1, -1):
			var next = (i + 1) % speeds.size()
			var ds = curve.get_point_position(i).distance_to(curve.get_point_position(next))
			speeds[i] = minf(speeds[i], sqrt(speeds[next] * speeds[next] + 16.0 * ds))
		for i in speeds.size():
			var previous = posmod(i - 1, speeds.size())
			var ds = curve.get_point_position(i).distance_to(curve.get_point_position(previous))
			speeds[i] = minf(speeds[i], sqrt(speeds[previous] * speeds[previous] + 8.0 * ds))
	for i in speeds.size():
		speeds[i] *= 3.6
	# Catmull-Rom handles so the line is smooth through each point rather than a polyline that turns
	# only at points ~10 m apart (Claude's P6-01 review).
	var count = curve.point_count
	for k in count:
		var tangent = (
			(curve.get_point_position((k + 1) % count) - curve.get_point_position(posmod(k - 1, count))) / 6.0
		)
		curve.set_point_in(k, -tangent)
		curve.set_point_out(k, tangent)
	curve.add_point(curve.get_point_position(0), curve.get_point_in(0))
	timing.append(asset.length)
	speeds.append(speeds[0])
	path.curve = curve
	path.set_meta("target_speeds_kmh", speeds)
	path.set_meta("timing_stations_m", timing)
	path.set_meta("speed_model", "sqrt(1.6 g R), 300 km/h cap, 8 m/s² braking, 4 m/s² acceleration")
	asset.add_child(path)
	path.owner = asset


## Lamp placements (Look-4) lit as sodium lamps (Look-2, scripts/track/track_lights.gd). The Marker3D
## placements under Lights/ become poles; the road-following fill adds lamps every 64 m where they leave
## the road dark, and both sides every 26 m from the pit straight through La Source. Paddock lamps
## stand 18 m off the road and light the paddock, not the tarmac.
static func add_lighting(asset: Node3D, road: RoadPath, corners: Dictionary, measured: float) -> void:
	var lights = Node3D.new()
	lights.name = "Lights"
	asset.add_child(lights)
	lights.owner = asset
	var stations = road.last_bake.stations
	var total_stations = stations.size()

	# 1. Paddock area lamps (12 sodium posts)
	for i in range(12):
		var fraction = float(i) / 12.0
		var s = fposmod(measured - 420.0 + fraction * 1050.0, measured)
		var index = int(s / measured * total_stations) % total_stations
		var st = stations[index]
		var paddock = SceneryBuilder.add_light_placement(
			lights,
			asset,
			"PaddockLamp%02d" % i,
			st.pos + st.tangent.cross(Vector3.UP) * 18.0,
			st.tangent,
			"pit",
			10.0,
			Color("#F2A14A")
		)
		paddock.set_meta("road_glow", false)

	# 2. Trackside lamp markers (sodium_mast, flood, pit) spaced 40-70 m on alternating sides
	var lamp_ranges = [
		# Pit straight & La Source
		{
			"from": measured - 450.0,
			"to": corners.get("La Source", 350.0) + 120.0,
			"step": 50.0,
			"type": "pit_straight"
		},
		# Eau Rouge & Raidillon
		{
			"from": corners.get("Eau Rouge", 950.0) - 80.0,
			"to": corners.get("Raidillon", 1100.0) + 140.0,
			"step": 50.0,
			"type": "raidillon"
		},
		# Kemmel Straight
		{
			"from": corners.get("Raidillon", 1100.0) + 140.0,
			"to": corners.get("Les Combes", 2250.0),
			"step": 65.0,
			"type": "kemmel"
		},
		# Blanchimont to Bus Stop
		{
			"from": corners.get("Blanchimont", 5750.0) - 100.0,
			"to": measured - 450.0,
			"step": 60.0,
			"type": "blanchimont"
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
			var off = 10.0
			if rng["type"] == "pit_straight":
				if s_cur > measured - 300.0 or s_cur < 30.0:
					if side_sign > 0:
						kind = "pit"
						h = 8.0
						off = 14.0
					else:
						kind = "flood"
						h = 12.0
						off = 12.0
				elif (
					s_cur >= corners.get("La Source", 350.0) - 60.0
					and s_cur <= corners.get("La Source", 350.0) + 60.0
				):
					kind = "flood"
					h = 12.0
			elif rng["type"] == "raidillon":
				kind = "flood"
				h = 12.0
				off = 12.0

			var lamp_pos = st.pos + right * (side_sign * off)
			var fwd = st.tangent
			lamp_idx += 1
			SceneryBuilder.add_light_placement(
				lights, asset, "TrackLamp%03d" % lamp_idx, lamp_pos, fwd, kind, h, Color("#F2A14A")
			)
			s += step
			if s_end < rng["from"] and s >= measured and fposmod(s, measured) > s_end:
				break

	# 3. Poles, heads and halos for the placements, plus the fill (outside the 2 m armco).
	var lamps = TrackLights.from_markers(asset, road, 4.0)
	var pits = {
		"from_m": measured - 420.0,
		"to_m": corners.get("La Source", 350.0) + 70.0,
		"spacing": 26.0,
		"sides": "both"
	}
	lamps.append_array(TrackLights.fill(road, 64.0, [pits], 4.0, lamps))
	TrackLights.build(asset, road, lamps)
	asset.lighting = {"night_lamps": lamps.size()}


static func add_scenery_kit(asset: Node3D, road: RoadPath, corners: Dictionary, measured: float) -> void:
	# 1. Start/Finish Gantry
	var gantry = Gantry.new()
	gantry.name = "StartGantry"
	gantry.follow_road = NodePath("../Main")
	gantry.station = 0.0
	gantry.clearance_height = 6.0
	gantry.extra_width = 4.0
	gantry.light_panel = true
	asset.add_child(gantry)
	gantry.owner = asset
	gantry.bake()

	# 2. Pit building at F1 straight
	var pits = PitBuilding.new()
	pits.name = "PitBuilding"
	pits.follow_road = NodePath("../Main")
	pits.side = PitBuilding.Side.RIGHT
	pits.station = measured - 160.0
	pits.length_m = 130.0
	pits.offset = 12.0
	pits.has_pit_wall = false
	asset.add_child(pits)
	pits.owner = asset
	pits.bake()

	# 3. Grandstands at real Spa locations
	# Pit straight grandstand (left, opposite pits)
	var gs_pit = Grandstand.new()
	gs_pit.name = "PitGrandstand"
	gs_pit.follow_road = NodePath("../Main")
	gs_pit.side = Grandstand.Side.LEFT
	gs_pit.station = measured - 120.0
	gs_pit.length_m = 90.0
	gs_pit.rows = 8
	gs_pit.offset = 8.0
	gs_pit.has_roof = true
	gs_pit.solid_front = true
	asset.add_child(gs_pit)
	gs_pit.owner = asset
	gs_pit.bake()

	# La Source grandstand (left / outside of hairpin)
	var gs_source = Grandstand.new()
	gs_source.name = "LaSourceGrandstand"
	gs_source.follow_road = NodePath("../Main")
	gs_source.side = Grandstand.Side.LEFT
	gs_source.station = corners.get("La Source", 350.0) + 20.0
	gs_source.length_m = 60.0
	gs_source.rows = 8
	gs_source.offset = 9.0
	gs_source.has_roof = true
	gs_source.solid_front = true
	asset.add_child(gs_source)
	gs_source.owner = asset
	gs_source.bake()

	# Eau Rouge grandstand (right, foot of the hill)
	var gs_er = Grandstand.new()
	gs_er.name = "EauRougeGrandstand"
	gs_er.follow_road = NodePath("../Main")
	gs_er.side = Grandstand.Side.RIGHT
	gs_er.station = corners.get("Eau Rouge", 950.0) - 40.0
	gs_er.length_m = 50.0
	gs_er.rows = 6
	gs_er.offset = 8.0
	gs_er.has_roof = false
	gs_er.solid_front = true
	asset.add_child(gs_er)
	gs_er.owner = asset
	gs_er.bake()

	# Raidillon grandstand (left, crest of the hill)
	var gs_raid = Grandstand.new()
	gs_raid.name = "RaidillonGrandstand"
	gs_raid.follow_road = NodePath("../Main")
	gs_raid.side = Grandstand.Side.LEFT
	gs_raid.station = corners.get("Raidillon", 1100.0) + 40.0
	gs_raid.length_m = 90.0
	gs_raid.rows = 10
	gs_raid.offset = 12.0
	gs_raid.has_roof = true
	gs_raid.solid_front = true
	asset.add_child(gs_raid)
	gs_raid.owner = asset
	gs_raid.bake()

	# Bus Stop grandstand (right, chicane exit)
	var gs_bus = Grandstand.new()
	gs_bus.name = "BusStopGrandstand"
	gs_bus.follow_road = NodePath("../Main")
	gs_bus.side = Grandstand.Side.RIGHT
	gs_bus.station = corners.get("Bus Stop", 6720.0) - 30.0
	gs_bus.length_m = 70.0
	gs_bus.rows = 8
	gs_bus.offset = 8.0
	gs_bus.has_roof = true
	gs_bus.solid_front = true
	asset.add_child(gs_bus)
	gs_bus.owner = asset
	gs_bus.bake()

	# 4. Catch fences
	var fence_pit = CatchFence.new()
	fence_pit.name = "PitCatchFence"
	fence_pit.follow_road = NodePath("../Main")
	fence_pit.side = CatchFence.Side.LEFT
	fence_pit.from_m = measured - 200.0
	fence_pit.to_m = 50.0
	fence_pit.offset = 5.0
	fence_pit.fence_height = 3.5
	fence_pit.solid = true
	asset.add_child(fence_pit)
	fence_pit.owner = asset
	fence_pit.bake()

	var fence_raid = CatchFence.new()
	fence_raid.name = "RaidillonCatchFence"
	fence_raid.follow_road = NodePath("../Main")
	fence_raid.side = CatchFence.Side.LEFT
	fence_raid.from_m = corners.get("Eau Rouge", 950.0)
	fence_raid.to_m = corners.get("Raidillon", 1100.0) + 120.0
	fence_raid.offset = 6.0
	fence_raid.fence_height = 3.5
	fence_raid.solid = true
	asset.add_child(fence_raid)
	fence_raid.owner = asset
	fence_raid.bake()

	var fence_bl = CatchFence.new()
	fence_bl.name = "BlanchimontCatchFence"
	fence_bl.follow_road = NodePath("../Main")
	fence_bl.side = CatchFence.Side.RIGHT
	fence_bl.from_m = corners.get("Blanchimont", 5750.0) - 100.0
	fence_bl.to_m = corners.get("Blanchimont", 5750.0) + 100.0
	fence_bl.offset = 5.0
	fence_bl.fence_height = 3.5
	fence_bl.solid = true
	asset.add_child(fence_bl)
	fence_bl.owner = asset
	fence_bl.bake()

	# 5. Billboards on Kemmel straight
	var boards = Billboards.new()
	boards.name = "KemmelBillboards"
	boards.follow_road = NodePath("../Main")
	boards.side = Billboards.Side.LEFT
	boards.from_m = corners.get("Raidillon", 1100.0) + 250.0
	boards.to_m = corners.get("Les Combes", 2250.0) - 200.0
	boards.offset = 7.0
	boards.spacing = 60.0
	asset.add_child(boards)
	boards.owner = asset
	boards.bake()

	# 6. Marshal posts
	var marshals = MarshalPost.new()
	marshals.name = "MarshalPosts"
	marshals.follow_road = NodePath("../Main")
	marshals.side = MarshalPost.Side.RIGHT
	marshals.offset = 6.0
	marshals.spacing = 350.0
	asset.add_child(marshals)
	marshals.owner = asset
	marshals.bake()

	# 7. Spectator crowd banks at Pouhon, Kemmel, Raidillon
	SceneryBuilder.build_crowd_bank(
		asset, road, "PouhonCrowdBank", corners.get("Pouhon", 3600.0), 140.0, 1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "KemmelCrowdBank", corners.get("Raidillon", 1100.0) + 400.0, 120.0, -1, 14.0
	)
	SceneryBuilder.build_crowd_bank(
		asset, road, "RaidillonCrowdBank", corners.get("Raidillon", 1100.0) + 140.0, 80.0, -1, 16.0
	)


static func build_asset() -> Node3D:
	var data = read_json(DATA + "centreline.json")
	if data.is_empty() or data.get("points", []).size() < 8 or data.get("elevation_keys", []).size() < 3:
		return null
	var asset = TrackAsset.new()
	asset.name = "SpaFrancorchamps"
	asset.id = "spa"
	asset.display_name = "Spa-Francorchamps (v0)"
	asset.version = 1
	asset.default_time_of_day = "day"
	asset.set_meta("cache_revision", CACHE_REVISION)
	asset.set_meta(
		"attribution",
		str(
			data.get(
				"attribution",
				"© OpenStreetMap contributors (ODbL); elevation source: trackgen/data/spa/README.md"
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
	road.grid_offset_m = 2.6
	road.curve = plan_curve(data)
	var measured = road.working_curve().get_baked_length()
	var scale_s = measured / source_length(data)
	var corners = corner_specs(data)
	road.sections = sections(data, measured, corners)
	if not FileAccess.file_exists(DATA + "terrain.json"):
		for section in road.sections:
			section.verge_left = maxf(section.verge_left, 35.0)
			section.verge_right = maxf(section.verge_right, 35.0)
	road.elevation_keys = elevation(data, measured)
	asset.add_child(road)
	road.owner = asset
	road.bake()
	asset.prepare()
	var positions = {}
	for corner in corners:
		positions[corner[0]] = corner[1] * scale_s
	asset.set_meta("corners", positions)
	var timing = asset.get_node("TimingLine")
	timing.set_meta(
		"sector_offsets",
		[
			(positions["Les Combes"] + 170.0) * asset.length / measured,
			(positions["Pouhon"] + 320.0) * asset.length / measured
		]
	)
	add_bot_line(asset, road)
	var terrain = add_terrain(asset)
	add_wall(asset, "LeftArmco", WallPath.Side.LEFT, 0, 0.0, -1.0)
	add_wall(asset, "RightArmco", WallPath.Side.RIGHT, 0, 0.0, -1.0)
	add_wall(
		asset,
		"PitConcrete",
		WallPath.Side.RIGHT,
		2,
		measured - 300.0,
		maxf(20.0, positions["La Source"] - 130.0),
		.5
	)
	for corner in corners:
		if corner[0] in ["La Source", "Eau Rouge", "Blanchimont", "Bus Stop"]:
			var side = WallPath.Side.LEFT if corner[4] > 0 else WallPath.Side.RIGHT
			add_wall(
				asset,
				corner[0].replace(" ", "") + "Tyres",
				side,
				1,
				fposmod((corner[1] - 110.0) * scale_s, measured),
				fposmod((corner[1] + 125.0) * scale_s, measured),
				.25
			)
	add_forest(
		asset,
		terrain,
		"ArdennesNear",
		positions["Raidillon"] + 180.0,
		positions["Blanchimont"] + 120.0,
		18.0,
		12.0,
		65.0,
		601
	)
	add_forest(
		asset,
		terrain,
		"ArdennesDeep",
		positions["Raidillon"] + 200.0,
		positions["Blanchimont"] + 100.0,
		24.0,
		70.0,
		180.0,
		602
	)
	add_forest(
		asset,
		terrain,
		"PaddockTrees",
		positions["Blanchimont"] + 200.0,
		positions["Raidillon"] + 120.0,
		3.0,
		25.0,
		80.0,
		603
	)
	# The Ardennes close in behind the paddock, La Source and Eau Rouge too: a far belt past the
	# grandstands and paddock buildings, so the hills there are wooded, not bare.
	add_forest(
		asset,
		terrain,
		"ArdennesFar",
		positions["Blanchimont"] + 200.0,
		positions["Raidillon"] + 200.0,
		14.0,
		110.0,
		260.0,
		604
	)
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
	var deviation = absf(asset.length - REFERENCE_LENGTH) / REFERENCE_LENGTH
	print(
		(
			"LENGTH road=%.3f lap=%.3f m deviation=%.3f%%"
			% [asset.get_node("Main").last_bake.length, asset.length, deviation * 100.0]
		)
	)
	print(
		(
			"TERRAIN spacing=%.1f m triangles=%d"
			% [asset.get_meta("terrain_mesh_spacing_m", 0.0), asset.get_meta("terrain_triangles", 0)]
		)
	)
	if not errors.is_empty() or deviation > .03:
		asset.free()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tracks3d/spa"))
	var packed = PackedScene.new()
	var error = packed.pack(asset)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Spa pack/save failed: %d" % error)
	else:
		print("SCENE bytes=%d path=%s" % [FileAccess.get_file_as_bytes(OUTPUT).size(), OUTPUT])
	asset.free()
	quit(0 if error == OK else 1)
