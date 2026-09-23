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
const DATA = "res://trackgen/data/spa/"
const OUTPUT = "res://tracks3d/spa/spa.scn"
const CACHE_REVISION = 1
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
	var strongest = 0.0
	for corner in corners:
		var delta = circular_delta(s, corner[1], length)
		var weight = smoothstep(-130.0, -45.0, delta) * (1.0 - smoothstep(35.0, 145.0, delta))
		if weight <= 0.0:
			continue
		values.width_left = maxf(values.width_left, lerpf(6.2, corner[3], weight))
		values.width_right = maxf(values.width_right, lerpf(6.2, corner[3], weight))
		if weight > strongest:
			values.bank_deg = corner[2] * weight
			strongest = weight
		var inside = "right" if corner[4] > 0 else "left"
		var outside = "left" if corner[4] > 0 else "right"
		values["runoff_" + outside] = maxf(values["runoff_" + outside], 4.0 + 20.0 * weight)
		values["runoff_" + inside] = maxf(values["runoff_" + inside], 3.0 + 4.0 * weight)
		if delta >= -55.0 and delta < 30.0:
			values["kerb_" + inside] = RoadSection.Kerb.SAUSAGE if corner[5] else RoadSection.Kerb.RAMP
			values.kerb_height = .075 if corner[5] else .045
		elif delta >= 30.0 and delta < 120.0:
			values["kerb_" + outside] = RoadSection.Kerb.RIBBED
		if corner[0] in ["Les Combes", "Pouhon", "Stavelot"] and weight > .1:
			values["verge_surface_" + outside] = 3
			values["verge_" + outside] = 8.0 + 12.0 * weight
	return values


static func sections(data: Dictionary, measured: float, corners: Array) -> Array[RoadSection]:
	var length = source_length(data)
	var marks = [0.0]
	var s = 20.0
	while s < length:
		marks.append(s)
		s += 20.0
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
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(.22, .34, .15)
	material.roughness = 1.0
	for chunk in asset.get_node("Terrain/Ardennes").get_children():
		chunk.material_override = material
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
	if not terrain.is_empty():
		var multimesh = asset.get_node("Scenery/" + title).multimesh
		for i in multimesh.instance_count:
			var xf = multimesh.get_instance_transform(i)
			xf.origin.y = terrain_height(terrain, xf.origin)
			multimesh.set_instance_transform(i, xf)


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
	curve.add_point(curve.get_point_position(0))
	timing.append(asset.length)
	speeds.append(speeds[0])
	path.curve = curve
	path.set_meta("target_speeds_kmh", speeds)
	path.set_meta("timing_stations_m", timing)
	path.set_meta("speed_model", "sqrt(1.6 g R), 300 km/h cap, 8 m/s² braking, 4 m/s² acceleration")
	asset.add_child(path)
	path.owner = asset


static func add_lighting(asset: Node3D, road: RoadPath) -> void:
	var lights = Node3D.new()
	lights.name = "Lights"
	asset.add_child(lights)
	lights.owner = asset
	for i in range(12):
		var fraction = float(i) / 12.0
		var s = fposmod(road.last_bake.length - 420.0 + fraction * 1050.0, road.last_bake.length)
		var index = int(s / road.last_bake.length * road.last_bake.stations.size())
		var st = road.last_bake.stations[index]
		var lamp = OmniLight3D.new()
		lamp.name = "PaddockLamp%02d" % i
		lamp.position = st.pos + st.tangent.cross(Vector3.UP) * 18.0 + Vector3.UP * 10.0
		lamp.light_energy = 1.5
		lamp.omni_range = 48.0
		lights.add_child(lamp)
		lamp.owner = asset


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
	asset.lighting = {"night_lamps": 12}
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
		32.0,
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
		42.0,
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
