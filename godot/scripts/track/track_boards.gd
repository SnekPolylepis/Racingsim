extends RefCounted
## Trackside braking boards (Look-11): 300/200/100 m countdown boards before corners where cars really
## brake, as on GT4's circuits (Spa only, owner's call). Placed behind the barrier on the
## corner's outside (the approach side), facing the track. No collision: they sit beyond the verge.
##
## Braking is read from the TrackAsset's BotLine target speeds (metadata target_speeds_kmh and
## timing_stations_m): boards go up only where the speed falls by more than BRAKE_DROP_KMH from the
## approach to the apex, so flat-out kinks (Eau Rouge, Blanchimont) stay clean.
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const SceneryBuilder = preload("res://scripts/track/scenery_builder.gd")
const FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const BRAKE_DROP_KMH = 40.0
## Countdown distances before the turn-in point, which sits TURN_IN_M before the apex.
const COUNTDOWN = [300.0, 200.0, 100.0]
const TURN_IN_M = 40.0
## Metres beyond the verge's outer edge (behind the armco).
const OFFSET = 1.2
## Boards fade out past this distance (they are small; this keeps the draw calls local).
const VISIBLE_M = 420.0


## `corners`: rows [name, source station, bank, width, direction (+1 right, -1 left), ...]; `scale_s` maps a
## source station to the road's measured station. Returns the number of boards placed.
static func build(asset: Node3D, road, corners: Array, scale_s: float) -> int:
	var bot = asset.get_node_or_null("BotLine")
	var speeds = bot.get_meta("target_speeds_kmh", PackedFloat32Array()) if bot else PackedFloat32Array()
	var stations = bot.get_meta("timing_stations_m", PackedFloat64Array()) if bot else PackedFloat64Array()
	var c = road.working_curve()
	var length = c.get_baked_length()
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var spline = (
		RoadBuilder.elevation_spline(road.elevation_keys, length, road.closed)
		if not road.elevation_keys.is_empty()
		else []
	)
	var holder = Node3D.new()
	holder.name = "Boards"
	var scenery = asset.get_node_or_null("Scenery")
	if scenery == null:
		scenery = Node3D.new()
		scenery.name = "Scenery"
		asset.add_child(scenery)
		scenery.owner = asset
	scenery.add_child(holder)
	holder.owner = asset
	var apexes = []
	for row in corners:
		apexes.append(fposmod(float(row[1]) * scale_s, length))
	apexes.sort()
	var count = 0
	for row in corners:
		var dir = int(row[4]) if row.size() > 4 else 0
		if dir == 0:
			continue
		var apex = fposmod(float(row[1]) * scale_s, length)
		var side = -1 if dir > 0 else 1  # outside of the corner: left for a right-hander
		if speeds.is_empty() or not _brakes(speeds, stations, apex, length):
			continue
		var previous = _previous_apex(apexes, apex, length)
		for d in COUNTDOWN:
			var s = apex - TURN_IN_M - d
			# Skip boards that would stand inside the previous corner.
			if (
				fposmod(s - previous, length) > fposmod(apex - previous, length)
				or fposmod(s - previous, length) < 40.0
			):
				continue
			count += _board(
				holder, asset, c, keys, road, spline, fposmod(s, length), side, str(int(d)), false
			)
	return count


static func _brakes(
	speeds: PackedFloat32Array, stations: PackedFloat64Array, apex: float, length: float
) -> bool:
	var slow = INF
	var fast = 0.0
	for i in speeds.size():
		var d = fposmod(stations[i] - apex + length * 0.5, length) - length * 0.5
		if d > -80.0 and d < 40.0:
			slow = minf(slow, speeds[i])
		elif d > -450.0 and d < -150.0:
			fast = maxf(fast, speeds[i])
	return fast - slow > BRAKE_DROP_KMH


static func _previous_apex(apexes: Array, apex: float, length: float) -> float:
	var best = apex - length
	for a in apexes:
		if a < apex - 1.0 and a > best:
			best = a
	if best == apex - length and apexes.size() > 1:
		best = apexes[-1] - length
	return best


static func _board(
	holder: Node3D, asset: Node3D, c, keys, road, spline, s: float, side: int, text: String, is_name: bool
) -> int:
	var e = RoadBuilder.beyond_edge(c, keys, road.closed, spline, s, side, OFFSET)
	var pos = road.transform * e.point
	var facing = -(road.transform.basis * e.outward)
	facing.y = 0.0
	if facing.length_squared() < 1e-4:
		return 0
	facing = facing.normalized()
	# Turn the face a little toward oncoming cars, as real boards are angled.
	var tangent = (
		road.transform.basis * RoadBuilder.station_at(c, road.closed, c.get_baked_length(), spline, s).tangent
	)
	tangent.y = 0.0
	if tangent.length_squared() > 1e-4:
		facing = (facing - tangent.normalized() * 0.45).normalized()
	var right = Vector3.UP.cross(facing).normalized()
	var basis = Basis(right, Vector3.UP, facing)
	var size = Vector2(3.2, 0.8) if is_name else Vector2(1.1, 0.8)
	var height = 2.6 if is_name else 1.6
	var mesh = _mesh(size, height, Color(0.08, 0.18, 0.42) if is_name else Color(0.95, 0.95, 0.93))
	var board = MeshInstance3D.new()
	board.name = ("Name_" if is_name else "Brake_") + text.replace(" ", "_")
	board.mesh = mesh
	board.transform = Transform3D(basis, pos)
	board.visibility_range_end = VISIBLE_M
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(board)
	board.owner = asset
	var label = Label3D.new()
	label.name = "Text"
	label.text = text.to_upper()
	label.font = FONT
	label.font_size = 96 if not is_name else 64
	label.pixel_size = 0.0055 if not is_name else 0.0048
	label.modulate = Color(0.97, 0.97, 0.97) if is_name else Color(0.05, 0.05, 0.05)
	label.outline_size = 0
	label.double_sided = false
	label.no_depth_test = false
	label.position = Vector3(0.0, height, 0.035)
	label.visibility_range_end = VISIBLE_M
	board.add_child(label)
	label.owner = asset
	return 1


## Board panel (facing +Z) on two dark posts; the panel's centre is `height` above the ground.
static func _mesh(size: Vector2, height: float, face: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post = Color(0.16, 0.17, 0.18)
	SceneryBuilder.add_box(st, Vector3(0.0, height, 0.0), Vector3(size.x, size.y, 0.05), face)
	SceneryBuilder.add_box(st, Vector3(0.0, height, -0.03), Vector3(size.x + 0.06, size.y + 0.06, 0.02), post)
	for x in [-size.x * 0.35, size.x * 0.35]:
		SceneryBuilder.add_box(
			st,
			Vector3(x, (height - size.y * 0.5) * 0.5, -0.05),
			Vector3(0.08, height - size.y * 0.5, 0.08),
			post
		)
	st.generate_normals()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	st.set_material(mat)
	return st.commit()
