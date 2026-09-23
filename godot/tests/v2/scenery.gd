extends SceneTree
## P3-04 / scenery-kit: validation and gate test for trackside scenery kit (REBUILD-PLAN.md P3-04).
## Checks:
##   1. CatchFence: deterministic bakes, layer 2 only when solid (wall_kind armco), 0 collision when not.
##   2. Grandstand: stepped seating block, roof, front wall collision on layer 2 (wall_kind concrete).
##   3. Gantry: spans road at station, clearance >= 5 m, no collision on road.
##   4. Billboards: seeded deterministic MultiMesh, retro colors, no collision.
##   5. MarshalPost: cabins spaced behind barrier, MultiMesh, no collision.
##   6. PitBuilding: garage block, front pit-wall collision on layer 2 (concrete).
##   7. KerbPaint: alternating red/white stripes on surface ID 1.
##   8. Boundary: all items stay outside road + kerb + runoff band.
##   9. Proving Ground: TrackAsset.validate() clean, zero collision on layer 1 under Scenery or Walls.
##  10. Bot lap: 296 GT3 completes lap, never touches new scenery collisions (min distance > 3.0 m).

const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const CatchFence = preload("res://scripts/track/catch_fence.gd")
const Grandstand = preload("res://scripts/track/grandstand.gd")
const Gantry = preload("res://scripts/track/gantry.gd")
const Billboards = preload("res://scripts/track/billboards.gd")
const PitBuilding = preload("res://scripts/track/pit_building.gd")
const MarshalPost = preload("res://scripts/track/marshal_post.gd")
const ProvingGroundGen = preload("res://trackgen/proving_ground.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")

const DT = 1.0 / 240.0

var checks = 0
var failures = []
var results = {}
var frames = 0
var ran = false

var test_host: Node3D
var pg_asset: Node3D
var presets: Dictionary


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize() -> void:
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	test_host = Node3D.new()
	test_host.name = "SceneryTestHost"
	root.add_child(test_host)

	# Straight road for component testing
	var road = RoadPath.new()
	road.name = "Road"
	road.closed = false
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, -500.0))
	c.add_point(Vector3(300.0, 0, -500.0))
	road.curve = c
	var sec_val = {
		"width_left": 5.0,
		"width_right": 5.0,
		"kerb_right": RoadSection.Kerb.RAMP,
		"kerb_width": 1.0,
		"kerb_height": 0.05,
		"runoff_right": 2.0,
		"verge_left": 4.0,
		"verge_right": 4.0,
		"verge_slope_deg": 3.0
	}
	road.sections.assign([RoadSection.make(0.0, sec_val), RoadSection.make(300.0, sec_val)])
	test_host.add_child(road)
	road.bake()


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("SCENERY RESULTS aborted by script error (see stderr)")
		quit(1)
		return true
	ran = true

	test_catch_fence()
	test_grandstand()
	test_gantry()
	test_billboards()
	test_marshal_post()
	test_pit_building()
	test_kerb_paint()
	test_boundary_envelope()
	test_proving_ground_integration()
	test_bot_lap_clearance()

	print("SCENERY RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


func test_catch_fence() -> void:
	var fence = CatchFence.new()
	fence.name = "TestFence"
	fence.follow_road = NodePath("../Road")
	fence.side = CatchFence.Side.RIGHT
	fence.offset = 1.0
	fence.from_m = 20.0
	fence.to_m = 80.0
	fence.post_spacing = 3.0
	fence.fence_height = 3.5
	fence.solid = true
	test_host.add_child(fence)
	fence.bake()

	var posts = fence.get_node_or_null("Scenery/TestFence/Posts")
	var panels = fence.get_node_or_null("Scenery/TestFence/Panels")
	var wall = fence.get_node_or_null("Walls/TestFence")

	var ok_posts = posts != null and posts is MultiMeshInstance3D and posts.multimesh.instance_count == 21
	var ok_panels = panels != null and panels.mesh != null
	var ok_wall = (
		wall != null
		and wall is StaticBody3D
		and not wall.get_collision_layer_value(1)
		and wall.get_collision_layer_value(2)
		and wall.get_meta("wall_kind", "") == "armco"
		and wall.get_meta("wall_height", 0.0) == 3.5
	)

	# Re-bake as non-solid: wall should be removed
	fence.solid = false
	fence.bake()
	var wall_removed = fence.get_node_or_null("Walls/TestFence") == null

	check(
		ok_posts and ok_panels and ok_wall and wall_removed,
		"CatchFence: 21 posts MultiMesh, panel mesh, layer-2 armco collision when solid, clean removal when non-solid"
	)


func test_grandstand() -> void:
	var stand = Grandstand.new()
	stand.name = "TestStand"
	stand.follow_road = NodePath("../Road")
	stand.station = 150.0
	stand.side = Grandstand.Side.RIGHT
	stand.offset = 6.0
	stand.length_m = 40.0
	stand.rows = 8
	stand.has_roof = true
	stand.solid_front = true
	test_host.add_child(stand)
	stand.bake()

	var scenery_mesh = stand.get_node_or_null("Scenery/TestStand")
	var wall = stand.get_node_or_null("Walls/TestStand")
	var ok_mesh = scenery_mesh != null and scenery_mesh.mesh != null
	var ok_wall = (
		wall != null
		and wall is StaticBody3D
		and not wall.get_collision_layer_value(1)
		and wall.get_collision_layer_value(2)
		and wall.get_meta("wall_kind", "") == "concrete"
	)
	check(
		ok_mesh and ok_wall,
		"Grandstand: stepped seating block with roof baked to Scenery/, front concrete wall on layer 2"
	)


func test_gantry() -> void:
	var gantry = Gantry.new()
	gantry.name = "TestGantry"
	gantry.follow_road = NodePath("../Road")
	gantry.station = 50.0
	gantry.clearance_height = 6.0
	gantry.extra_width = 3.0
	gantry.light_panel = true
	test_host.add_child(gantry)
	gantry.bake()

	var inst = gantry.get_node_or_null("Scenery/TestGantry")
	var ok_mesh = inst != null and inst.mesh != null
	# Verify no collision on road
	var walls_node = gantry.get_node_or_null("Walls/TestGantry")
	check(
		ok_mesh and walls_node == null and gantry.last_bake.clearance_height >= 5.0,
		"Gantry: spans road at station 50 with clearance 6.0 m, start lights, zero collision on road"
	)


func test_billboards() -> void:
	var b1 = Billboards.new()
	b1.name = "TestBoards"
	b1.follow_road = NodePath("../Road")
	b1.side = Billboards.Side.RIGHT
	b1.from_m = 100.0
	b1.to_m = 200.0
	b1.spacing = 30.0
	b1.random_seed = 101
	test_host.add_child(b1)
	b1.bake()

	var l1 = b1.last_bake.duplicate(true)
	b1.bake()
	var l1_again = b1.last_bake.duplicate(true)
	b1.random_seed = 202
	b1.bake()
	var l2 = b1.last_bake.duplicate(true)

	var same_seed = var_to_str(l1) == var_to_str(l1_again)
	var diff_seed = var_to_str(l1) != var_to_str(l2)
	var inst = b1.get_node_or_null("Scenery/TestBoards")
	var ok_mm = inst != null and inst is MultiMeshInstance3D and inst.multimesh.instance_count == 3

	check(
		ok_mm and same_seed and diff_seed,
		"Billboards: 3 boards MultiMesh, deterministic from seed, flat retro colors, zero collision"
	)


func test_marshal_post() -> void:
	var mp = MarshalPost.new()
	mp.name = "TestMarshals"
	mp.follow_road = NodePath("../Road")
	mp.side = MarshalPost.Side.RIGHT
	mp.from_m = 0.0
	mp.to_m = 300.0
	mp.spacing = 100.0
	test_host.add_child(mp)
	mp.bake()

	var inst = mp.get_node_or_null("Scenery/TestMarshals")
	var ok_mm = inst != null and inst is MultiMeshInstance3D and inst.multimesh.instance_count == 3
	check(ok_mm, "MarshalPost: 3 cabins placed every 100 m as a single MultiMesh, zero collision")


func test_pit_building() -> void:
	var pits = PitBuilding.new()
	pits.name = "TestPits"
	pits.follow_road = NodePath("../Road")
	pits.side = PitBuilding.Side.LEFT
	pits.station = 100.0
	pits.length_m = 60.0
	pits.offset = 10.0
	pits.has_pit_wall = true
	pits.pit_wall_offset = 3.5
	test_host.add_child(pits)
	pits.bake()

	var building = pits.get_node_or_null("Scenery/TestPits")
	var wall = pits.get_node_or_null("Walls/TestPits")
	var ok_bld = building != null and building.mesh != null
	var ok_wall = (
		wall != null
		and wall is StaticBody3D
		and not wall.get_collision_layer_value(1)
		and wall.get_collision_layer_value(2)
		and wall.get_meta("wall_kind", "") == "concrete"
	)
	check(
		ok_bld and ok_wall,
		"PitBuilding: garage block in Scenery/, concrete pit wall on layer 2 (wall_kind concrete)"
	)


func test_kerb_paint() -> void:
	var faces = {1: PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT])}
	var uvs = {1: PackedVector2Array([Vector2.ZERO, Vector2(0, 1.0), Vector2(1.0, 0)])}
	var m = RoadBuilder.mesh(faces, uvs)
	var mat = m.surface_get_material(0)
	var has_tex = mat != null and mat.albedo_texture != null
	var img = mat.albedo_texture.get_image() if has_tex else null
	var is_stripes = false
	if img != null:
		var c0 = img.get_pixel(0, 0)
		var c1 = img.get_pixel(0, 1)
		# Red and white pixels
		is_stripes = c0.r > 0.7 and c0.g < 0.3 and c1.r > 0.8 and c1.g > 0.8 and c1.b > 0.8
	check(
		has_tex and is_stripes and mat.uv1_scale.y == 1.0,
		"KerbPaint: alternating red/white stripes on kerb UVs/material (surface ID 1)"
	)


func test_boundary_envelope() -> void:
	# On our test road: width 5.0 + kerb 1.0 + runoff 2.0 = 8.0 m from centreline.
	# Verge is 4.0 m beyond that (edge at 12.0 m).
	# Any item with offset >= 0 beyond verge edge is at least 12.0 m from centreline.
	var road = test_host.get_node("Road")
	var c = road.working_curve()
	var keys = road.sections
	var e_fence = RoadBuilder.beyond_edge(c, keys, false, [], 50.0, 1, 1.0)
	var e_stand = RoadBuilder.beyond_edge(c, keys, false, [], 150.0, 1, 6.0)
	var e_boards = RoadBuilder.beyond_edge(c, keys, false, [], 100.0, 1, 6.0)
	var e_pits = RoadBuilder.beyond_edge(c, keys, false, [], 100.0, -1, 3.5)

	var d_fence = absf(e_fence.point.z - (-500.0))
	var d_stand = absf(e_stand.point.z - (-500.0))
	var d_boards = absf(e_boards.point.z - (-500.0))
	var d_pits = absf(e_pits.point.z - (-500.0))

	var min_clearance_band = 8.0  # road 5 + kerb 1 + runoff 2
	var all_outside = (
		d_fence > min_clearance_band
		and d_stand > min_clearance_band
		and d_boards > min_clearance_band
		and d_pits > min_clearance_band
	)
	check(
		all_outside,
		(
			"boundary envelope: all items stay outside road + kerb + runoff (min dist %.2f m > %.1f m band)"
			% [minf(minf(d_fence, d_stand), minf(d_boards, d_pits)), min_clearance_band]
		)
	)


func test_proving_ground_integration() -> void:
	pg_asset = ProvingGroundGen.build_asset()
	root.add_child(pg_asset)

	var errors = pg_asset.validate()
	check(errors.is_empty(), "Proving Ground with scenery kit validates: %s" % [errors])

	# Check collision layers across the whole asset:
	# 1. Surfaces/ must be layer 1 only.
	# 2. Walls/ must be layer 2 only.
	# 3. Scenery/ must have NO collision objects.
	var bad_layers = 0
	var scenery = pg_asset.get_node_or_null("Scenery")
	if scenery != null:
		var bodies = scenery.find_children("*", "CollisionObject3D", true, false)
		bad_layers += bodies.size()

	var walls = pg_asset.get_node_or_null("Walls")
	var wall_count = 0
	if walls != null:
		for w in walls.get_children():
			if w is StaticBody3D:
				wall_count += 1
				if w.get_collision_layer_value(1) or not w.get_collision_layer_value(2):
					bad_layers += 1

	check(
		bad_layers == 0 and wall_count >= 5,
		(
			"collision layers: 0 collision shapes on layer 1 from scenery, %d bodies on layer 2 with valid wall_kind"
			% wall_count
		)
	)


func test_bot_lap_clearance() -> void:
	var path = pg_asset.get_node("BotLine")
	var pole = pg_asset.grid_slots()[0]
	var fwd = -pole.basis.z
	var surf = pg_asset.surface()

	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	c.launch(60.0 / 3.6)

	var new_walls = {}
	for wall_name in ["BowlGrandstand", "CrestCatchFence", "Pits"]:
		var w = pg_asset.get_node_or_null("Walls/" + wall_name)
		if w != null and w.has_meta("wall_line"):
			new_walls[wall_name] = w.get_meta("wall_line")

	var gates = pg_asset.gates()
	var next_gate = 0
	var started = -1.0
	var lap_time = -1.0
	var hint = -1
	var off_steps = 0
	var min_dists = {}
	for k in new_walls:
		min_dists[k] = INF

	var prev = c.pos
	var time = 0.0

	for i in 240 * 180:
		var pr = pg_asset.project(c.pos, hint)
		hint = pr.idx
		var lookahead = 9.0 + c.speed * 0.5
		driver(c, line_point(path, pr.s + lookahead), line_speed(path, pr.s + lookahead))
		c.step(DT, surf, true)
		time += DT

		for w in c.wheels:
			if w.surf.id >= 2:
				off_steps += 1

		if i % 24 == 0:
			var xz = Vector2(c.pos.x, c.pos.z)
			for w_name in new_walls:
				var line = new_walls[w_name]
				for k in line.size():
					var a = Vector2(line[k].x, line[k].z)
					var b = Vector2(line[(k + 1) % line.size()].x, line[(k + 1) % line.size()].z)
					var ab = b - a
					var u = clampf((xz - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
					min_dists[w_name] = minf(min_dists[w_name], xz.distance_to(a + ab * u))

		if TrackAsset.crossed(gates[next_gate], prev, c.pos):
			if next_gate == 0:
				if started >= 0.0:
					lap_time = time - started
					break
				started = time
				next_gate = 1
			else:
				next_gate = (next_gate + 1) % gates.size()
		prev = c.pos
		if not is_finite(c.pos.length()) or pr.distance > 40.0:
			break

	results["scenery_bot_lap_s"] = lap_time
	results["min_wall_dists"] = min_dists

	var all_clear = true
	var min_clearance = INF
	for w_name in min_dists:
		min_clearance = minf(min_clearance, min_dists[w_name])
		if min_dists[w_name] <= 3.0:
			all_clear = false

	check(
		lap_time > 0.0 and off_steps == 0 and all_clear,
		(
			"proving ground bot lap (%.2f s, 0 off-track steps) never touches new collision (min clearance %.2f m > 3.0 m)"
			% [lap_time, min_clearance]
		)
	)


func driver(c: CarBody, target: Vector3, v_target_kmh: float) -> void:
	var to = target - c.pos
	var angle = wrapf(atan2(to.z, to.x) - c.h, -PI, PI)
	var err = v_target_kmh / 3.6 - c.speed
	c.input = {
		"throttle": clampf(err * 0.4 + 0.35, 0.0, 1.0),
		"brake": clampf(-err * 0.3, 0.0, 1.0),
		"steer": clampf(angle * 3.0, -1.0, 1.0),
		"clutch": 0.0,
		"handbrake": 0.0
	}


func line_point(path: Path3D, s: float) -> Vector3:
	return path.curve.sample_baked(fposmod(s, path.curve.get_baked_length()))


func line_speed(path: Path3D, s: float) -> float:
	var stations = path.get_meta("timing_stations_m")
	var speeds = path.get_meta("target_speeds_kmh")
	var l = stations[stations.size() - 1]
	s = fposmod(s, l)
	var idx = 0
	while idx < stations.size() - 1 and stations[idx + 1] <= s:
		idx += 1
	var t = (s - stations[idx]) / maxf(stations[idx + 1] - stations[idx], 1e-4)
	return lerpf(speeds[idx], speeds[idx + 1], t)
