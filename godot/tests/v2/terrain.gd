extends SceneTree
## P3-03: Terrain import, road stitching, chunking, collision, and car dynamics (REBUILD-PLAN.md P3-03).
##   1. Analytic heightmap: 200 random points within 1 cm of analytic value, surface == 2 (grass).
##   2. Chunk seams: border rays hit with no gaps (< 1 mm diff across seam).
##   3. Road stitch: straight RoadPath across terrain; verge outer edge matches verge within 2 cm;
##      no terrain above road footprint (lowered >= 0.3 m).
##   4. 296 CarBody rest check on terrain (settles, 4 contacts, surface 2) and drives 200 m across
##      road and terrain at 60 km/h without NaN.
##   5. Performance: 2 km x 2 km, 1 m-per-pixel heightmap (8M tris) bake time and car step µs.
##   6. TrackAsset.validate() passes with terrain present.
## Run: tools/Godot.exe --headless --path . --script tests/v2/terrain.gd

const TerrainPatch = preload("res://scripts/track/terrain.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")

const DT = 1.0 / 240.0

var failures = []
var checks = 0
var frames = 0
var ran = false
var results = {}

var analytic_asset: Node3D
var stitched_asset: Node3D
var runoff_kerb_asset: Node3D
var perf_asset: Node3D


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize() -> void:
	# Build fixtures in non-overlapping regions of world space:
	#   analytic_asset:    centered at (0, 0), x in [-128, 127], z in [-128, 127]
	#   stitched_asset:    centered at (0, 600), x in [-128, 127], z in [472, 727]
	#   runoff_kerb_asset: centered at (0, 1100), x in [-128, 127], z in [972, 1227]
	#   perf_asset:        centered at (2500, 0), x in [1500, 3500], z in [-1000, 1000]
	build_analytic_fixture()
	build_stitched_fixture()
	build_runoff_kerb_fixture()
	build_perf_fixture()


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("TERRAIN RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	test_analytic_heightmap()
	test_chunk_seams()
	test_road_stitch()
	test_road_stitch_runoff_kerb()
	test_car_rest_and_drive()
	test_performance()
	test_validate()
	print("TERRAIN RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


func build_analytic_fixture() -> void:
	analytic_asset = Node3D.new()
	analytic_asset.set_script(TrackAsset)
	analytic_asset.name = "AnalyticAsset"
	analytic_asset.id = "analytic_asset"
	root.add_child(analytic_asset)
	var w = 256
	var h = 256
	var floats = PackedFloat32Array()
	floats.resize(w * h)
	var idx = 0
	for gz in h:
		var vz = -128.0 + gz * 1.0
		for gx in w:
			var vx = -128.0 + gx * 1.0
			floats[idx] = 3.0 * sin(vx / 40.0) * cos(vz / 55.0)
			idx += 1
	var img = Image.create_from_data(w, h, false, Image.FORMAT_RF, floats.to_byte_array())
	var patch = TerrainPatch.new()
	patch.name = "AnalyticTerrain"
	patch.image = img
	patch.metres_per_pixel = 1.0
	patch.origin_offset = Vector2(-128.0, -128.0)
	patch.chunk_size = 64
	analytic_asset.add_child(patch)
	patch.bake()


func build_stitched_fixture() -> void:
	stitched_asset = Node3D.new()
	stitched_asset.set_script(TrackAsset)
	stitched_asset.name = "StitchedAsset"
	stitched_asset.id = "stitched_asset"
	root.add_child(stitched_asset)
	var road = RoadPath.new()
	road.name = "Road"
	road.closed = false
	road.drives_timing = false
	var c = Curve3D.new()
	c.add_point(Vector3(-150.0, 0.0, 600.0))
	c.add_point(Vector3(150.0, 0.0, 600.0))
	road.curve = c
	var sec_dict = {
		"width_left": 5.0,
		"width_right": 5.0,
		"kerb_width": 1.0,
		"kerb_left": RoadSection.Kerb.NONE,
		"kerb_right": RoadSection.Kerb.NONE,
		"runoff_left": 0.0,
		"runoff_right": 0.0,
		"verge_left": 5.95,
		"verge_right": 5.95,
		"verge_slope_deg": 3.0,
	}
	road.sections.assign([RoadSection.make(0.0, sec_dict), RoadSection.make(300.0, sec_dict)])
	stitched_asset.add_child(road)
	road.bake()
	var w = 320
	var h = 256
	var floats = PackedFloat32Array()
	floats.resize(w * h)
	var img = Image.create_from_data(w, h, false, Image.FORMAT_RF, floats.to_byte_array())
	var patch = TerrainPatch.new()
	patch.name = "StitchedTerrain"
	patch.image = img
	patch.metres_per_pixel = 1.0
	patch.origin_offset = Vector2(-160.0, 472.0)
	patch.chunk_size = 64
	patch.blend_m = 8.0
	patch.under_road_drop_m = 0.3
	stitched_asset.add_child(patch)
	patch.bake()


func build_runoff_kerb_fixture() -> void:
	runoff_kerb_asset = Node3D.new()
	runoff_kerb_asset.set_script(TrackAsset)
	runoff_kerb_asset.name = "RunoffKerbAsset"
	runoff_kerb_asset.id = "runoff_kerb_asset"
	root.add_child(runoff_kerb_asset)
	var road = RoadPath.new()
	road.name = "Road"
	road.closed = false
	road.drives_timing = false
	var c = Curve3D.new()
	c.add_point(Vector3(-100.0, 0.0, 1100.0))
	c.add_point(Vector3(100.0, 0.0, 1100.0))
	road.curve = c
	var sec_dict = {
		"width_left": 6.0,
		"width_right": 6.0,
		"kerb_width": 1.0,
		"kerb_height": 0.05,
		"kerb_left": RoadSection.Kerb.RAMP,
		"kerb_right": RoadSection.Kerb.SAUSAGE,
		"runoff_left": 4.0,
		"runoff_right": 4.0,
		"runoff_surface": 4,
		"verge_left": 4.0,
		"verge_right": 4.0,
		"verge_slope_deg": 3.0,
	}
	road.sections.assign([RoadSection.make(0.0, sec_dict), RoadSection.make(200.0, sec_dict)])
	runoff_kerb_asset.add_child(road)
	road.bake()
	var w = 256
	var h = 256
	var floats = PackedFloat32Array()
	floats.resize(w * h)
	var idx = 0
	for gz in h:
		for gx in w:
			var vx = -128.0 + gx * 1.0
			floats[idx] = 0.5 + 0.2 * cos(vx / 25.0)
			idx += 1
	var img = Image.create_from_data(w, h, false, Image.FORMAT_RF, floats.to_byte_array())
	var patch = TerrainPatch.new()
	patch.name = "RunoffKerbTerrain"
	patch.image = img
	patch.metres_per_pixel = 1.0
	patch.origin_offset = Vector2(-128.0, 972.0)
	patch.chunk_size = 64
	patch.blend_m = 8.0
	patch.under_road_drop_m = 0.3
	runoff_kerb_asset.add_child(patch)
	patch.bake()


func build_perf_fixture() -> void:
	perf_asset = Node3D.new()
	perf_asset.set_script(TrackAsset)
	perf_asset.name = "PerfAsset"
	perf_asset.id = "perf_asset"
	root.add_child(perf_asset)
	var img = Image.create(2001, 2001, false, Image.FORMAT_RF)
	var patch = TerrainPatch.new()
	patch.name = "PerfTerrain"
	patch.image = img
	patch.metres_per_pixel = 1.0
	patch.origin_offset = Vector2(1500.0, -1000.0)
	patch.chunk_size = 64
	perf_asset.add_child(patch)
	var t0 = Time.get_ticks_msec()
	patch.bake()
	var bake_dt = Time.get_ticks_msec() - t0
	results["perf_bake_s"] = bake_dt / 1000.0
	results["perf_triangles"] = patch.last_bake.triangles


func test_analytic_heightmap() -> void:
	var surf = TrackSurface.new(analytic_asset)
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var worst_err = 0.0
	var count_ok = 0
	for k in 200:
		var rx = rng.randf_range(-100.0, 100.0)
		var rz = rng.randf_range(-100.0, 100.0)
		var want_h = 3.0 * sin(rx / 40.0) * cos(rz / 55.0)
		var hit = surf.contact(Vector3(rx, 20.0, rz), Vector3.DOWN, 40.0)
		if hit.is_empty():
			continue
		if hit.surface != 2:
			continue
		var err = absf(hit.point.y - want_h)
		worst_err = maxf(worst_err, err)
		if err < 0.01:
			count_ok += 1
	results["analytic_worst_err_m"] = worst_err
	check(
		count_ok == 200 and worst_err < 0.01,
		(
			"analytic heightmap: 200 random points hit, surface == 2 (grass), within 1 cm of analytic (worst %.4f m)"
			% worst_err
		)
	)


func test_chunk_seams() -> void:
	var surf = TrackSurface.new(analytic_asset)
	var worst_seam_gap = 0.0
	var seam_ok = true
	# Test along x = 0 border (-64..64 chunk boundary)
	for k in 25:
		var z = -100.0 + k * 8.0
		var hit_l = surf.contact(Vector3(-0.001, 20.0, z), Vector3.DOWN, 40.0)
		var hit_r = surf.contact(Vector3(0.001, 20.0, z), Vector3.DOWN, 40.0)
		var hit_m = surf.contact(Vector3(0.0, 20.0, z), Vector3.DOWN, 40.0)
		if hit_l.is_empty() or hit_r.is_empty() or hit_m.is_empty():
			seam_ok = false
			continue
		var gap = absf(hit_l.point.y - hit_r.point.y)
		worst_seam_gap = maxf(worst_seam_gap, gap)
		if gap >= 0.001:
			seam_ok = false
	# Test along z = 0 border
	for k in 25:
		var x = -100.0 + k * 8.0
		var hit_n = surf.contact(Vector3(x, 20.0, -0.001), Vector3.DOWN, 40.0)
		var hit_p = surf.contact(Vector3(x, 20.0, 0.001), Vector3.DOWN, 40.0)
		var hit_m = surf.contact(Vector3(x, 20.0, 0.0), Vector3.DOWN, 40.0)
		if hit_n.is_empty() or hit_p.is_empty() or hit_m.is_empty():
			seam_ok = false
			continue
		var gap = absf(hit_n.point.y - hit_p.point.y)
		worst_seam_gap = maxf(worst_seam_gap, gap)
		if gap >= 0.001:
			seam_ok = false
	results["seam_worst_gap_m"] = worst_seam_gap
	check(
		seam_ok and worst_seam_gap < 0.001,
		"chunk seams: border rays hit with no gaps (< 1 mm diff across seam, worst %.5f m)" % worst_seam_gap
	)


func test_road_stitch() -> void:
	var road_node: RoadPath = stitched_asset.get_node("Road")
	var c = road_node.working_curve()
	var keys = road_node.sections
	var surf = TrackSurface.new(stitched_asset)
	# Part 1: verge outer edge matches verge within 2 cm (outer edge at z = 600 +- 12.0)
	var worst_edge_err = 0.0
	var edge_ok = true
	for k in 41:
		var x = -80.0 + k * 4.0
		var s = x + 150.0
		var e_r = RoadBuilder.beyond_edge(c, keys, false, [], s, 1, 0.0)
		var e_l = RoadBuilder.beyond_edge(c, keys, false, [], s, -1, 0.0)
		var hit_r = surf.contact(Vector3(x, 20.0, 612.0), Vector3.DOWN, 40.0)
		var hit_l = surf.contact(Vector3(x, 20.0, 588.0), Vector3.DOWN, 40.0)
		if hit_r.is_empty() or hit_l.is_empty():
			edge_ok = false
			continue
		var err_r = absf(hit_r.point.y - e_r.point.y)
		var err_l = absf(hit_l.point.y - e_l.point.y)
		worst_edge_err = maxf(worst_edge_err, maxf(err_r, err_l))
		if err_r >= 0.02 or err_l >= 0.02:
			edge_ok = false
	results["stitch_worst_edge_err_m"] = worst_edge_err
	# Part 2: no terrain above road footprint (terrain lowered >= 0.3 m below road surface)
	# Temporarily disable road surface collision in PhysicsServer3D to measure terrain surface alone
	var road_rids = []
	for child in stitched_asset.get_node("Surfaces").get_children():
		if str(child.name).begins_with("Road_") and child is StaticBody3D:
			road_rids.append(child.get_rid())
			PhysicsServer3D.body_set_collision_layer(child.get_rid(), 0)
	var min_drop = INF
	var no_poke = true
	var sec_eval = RoadBuilder.section_at(keys, 150.0, 300.0, false)
	for k in 21:
		var x = -50.0 + k * 5.0
		for j in 21:
			var lat = -10.0 + j * 1.0
			var h_road = TerrainPatch.road_surface_height_at(sec_eval, lat)
			var hit_t = surf.contact(Vector3(x, 20.0, 600.0 + lat), Vector3.DOWN, 40.0)
			if hit_t.is_empty():
				continue
			var drop = h_road - hit_t.point.y
			min_drop = minf(min_drop, drop)
			if hit_t.point.y > h_road - 0.3 + 1e-4:
				no_poke = false
	# Re-enable road collision
	for rid in road_rids:
		PhysicsServer3D.body_set_collision_layer(rid, 1)
	results["stitch_min_drop_m"] = min_drop
	check(
		edge_ok and worst_edge_err < 0.02 and no_poke and min_drop >= 0.3 - 1e-4,
		(
			"road stitch: verge outer edge matches within 2 cm (worst %.4f m); no terrain above road footprint (min drop %.3f m >= 0.3 m)"
			% [worst_edge_err, min_drop]
		)
	)


func test_road_stitch_runoff_kerb() -> void:
	var road_node: RoadPath = runoff_kerb_asset.get_node("Road")
	var c = road_node.working_curve()
	var keys = road_node.sections
	var surf = TrackSurface.new(runoff_kerb_asset)
	var worst_edge_err = 0.0
	var edge_ok = true
	# Part 1: verge outer edge matches verge within 2 cm (with kerb and runoff)
	for k in 41:
		var x = -80.0 + k * 4.0
		var s = x + 100.0
		var e_r = RoadBuilder.beyond_edge(c, keys, false, [], s, 1, 0.0)
		var e_l = RoadBuilder.beyond_edge(c, keys, false, [], s, -1, 0.0)
		var hit_r = surf.contact(Vector3(x, 20.0, 1115.0), Vector3.DOWN, 40.0)
		var hit_l = surf.contact(Vector3(x, 20.0, 1085.0), Vector3.DOWN, 40.0)
		if hit_r.is_empty() or hit_l.is_empty():
			edge_ok = false
			continue
		var err_r = absf(hit_r.point.y - e_r.point.y)
		var err_l = absf(hit_l.point.y - e_l.point.y)
		worst_edge_err = maxf(worst_edge_err, maxf(err_r, err_l))
		if err_r >= 0.02 or err_l >= 0.02:
			edge_ok = false
	results["stitch_rk_worst_edge_err_m"] = worst_edge_err
	# Part 2: no terrain above footprint across kerb, runoff, and verge
	var road_rids = []
	for child in runoff_kerb_asset.get_node("Surfaces").get_children():
		if str(child.name).begins_with("Road_") and child is StaticBody3D:
			road_rids.append(child.get_rid())
			PhysicsServer3D.body_set_collision_layer(child.get_rid(), 0)
	var min_drop = INF
	var no_poke = true
	var sec_eval = RoadBuilder.section_at(keys, 100.0, 200.0, false)
	for k in 21:
		var x = -50.0 + k * 5.0
		for j in 29:
			var lat = -14.0 + j * 1.0
			var h_road = TerrainPatch.road_surface_height_at(sec_eval, lat)
			var hit_t = surf.contact(Vector3(x, 20.0, 1100.0 + lat), Vector3.DOWN, 40.0)
			if hit_t.is_empty():
				continue
			var drop = h_road - hit_t.point.y
			min_drop = minf(min_drop, drop)
			if hit_t.point.y > h_road - 0.3 + 1e-4:
				no_poke = false
	for rid in road_rids:
		PhysicsServer3D.body_set_collision_layer(rid, 1)
	results["stitch_rk_min_drop_m"] = min_drop
	check(
		edge_ok and worst_edge_err < 0.02 and no_poke and min_drop >= 0.3 - 1e-4,
		(
			"road stitch with runoff and kerb: verge outer edge matches within 2 cm (worst %.4f m); no terrain above footprint (min drop %.3f m >= 0.3 m)"
			% [worst_edge_err, min_drop]
		)
	)


func test_car_rest_and_drive() -> void:
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	var surf = TrackSurface.new(analytic_asset)
	# Rest check at x = 0, z = 0 on analytic terrain
	c.place(Vector3(0.0, 0.5, 0.0), 0.0, 0.0)
	c.input = {"throttle": 0.0, "brake": 1.0, "steer": 0.0, "clutch": 0.0, "handbrake": 1.0}
	for tick in 480:
		c.step(DT, surf, true)
	var settled = c.speed < 0.1
	var contacts_ok = c.contacts == 4
	var surface_ok = true
	for w in 4:
		if c.contact_hits.size() <= w or c.contact_hits[w].is_empty() or c.contact_hits[w].surface != 2:
			surface_ok = false
	results["car_rest_speed"] = c.speed
	results["car_rest_contacts"] = c.contacts
	# Drive 200 m across road and terrain on stitched_asset
	var stitched_surf = TrackSurface.new(stitched_asset)
	var c2 = CarBody.new()
	c2.configure(presets.f296gt3)
	c2.wear_enabled = false
	var hit_start = stitched_surf.contact(Vector3(-80.0, 20.0, 600.0), Vector3.DOWN, 40.0)
	var start_y = hit_start.point.y if not hit_start.is_empty() else 0.0
	var heading = atan2(15.0, 200.0)
	c2.place(Vector3(-80.0, start_y, 600.0), heading, start_y)
	c2.input = {"throttle": 0.0, "brake": 1.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
	for tick in 10:
		c2.step(DT, stitched_surf, true)
	var dist = 0.0
	var prev_pos = c2.pos
	var has_nan = false
	var t = 0.0
	var saw_road_4_wheels = false
	var saw_terrain_4_wheels = false
	var min_contacts = 4
	while dist < 200.0 and t < 30.0:
		var target_speed = 60.0 / 3.6
		var err_speed = target_speed - c2.speed
		var th = clampf(err_speed * 0.5 + 0.3, 0.0, 1.0)
		var br = clampf(-err_speed * 0.3, 0.0, 1.0)
		c2.input = {"throttle": th, "brake": br, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
		c2.step(DT, stitched_surf, true)
		t += DT
		dist += c2.pos.distance_to(prev_pos)
		prev_pos = c2.pos
		min_contacts = mini(min_contacts, c2.contacts)
		if c2.contacts == 4 and c2.contact_hits.size() >= 4:
			var all_road = true
			var all_terrain = true
			for w in 4:
				var sid = c2.contact_hits[w].get("surface", -1)
				if sid != 0:
					all_road = false
				if sid != 2:
					all_terrain = false
			if all_road:
				saw_road_4_wheels = true
			if saw_road_4_wheels and all_terrain:
				saw_terrain_4_wheels = true
		if is_nan(c2.pos.x) or is_nan(c2.vel.x) or is_nan(c2.speed) or is_nan(c2.rot.x) or is_nan(c2.ang.x):
			has_nan = true
			break
	results["car_drive_dist_m"] = dist
	results["car_drive_time_s"] = t
	results["car_drive_min_contacts"] = min_contacts
	check(
		(
			settled
			and contacts_ok
			and surface_ok
			and dist >= 200.0
			and not has_nan
			and min_contacts == 4
			and saw_road_4_wheels
			and saw_terrain_4_wheels
		),
		(
			"296 CarBody rest check on terrain (settled %.4f m/s, 4 contacts, surface 2) and drives %.1f m in %.2f s crossing road (surface 0) to terrain (surface 2) on 4 wheels"
			% [c.speed, dist, t]
		)
	)


func test_performance() -> void:
	var tris = int(results.get("perf_triangles", 0))
	var bake_s = float(results.get("perf_bake_s", 0.0))
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	var surf = TrackSurface.new(perf_asset)
	c.place(Vector3(2500.0, 0.5, 0.0), 0.0, 0.0)
	# Warmup ticks
	for tick in 20:
		c.step(DT, surf, true)
	var t0 = Time.get_ticks_usec()
	var n_ticks = 100
	for tick in n_ticks:
		c.step(DT, surf, true)
	var step_us = float(Time.get_ticks_usec() - t0) / n_ticks
	results["perf_car_step_us"] = step_us
	check(
		tris == 8000000 and step_us < 300.0,
		(
			"performance: 2 km x 2 km bake %.2f s, %d triangles (8M); car step %.1f µs (budget 300 µs)"
			% [bake_s, tris, step_us]
		)
	)


func test_validate() -> void:
	# Add TimingLine and Grid to analytic_asset so TrackAsset.validate() validates the whole asset
	var timing = Path3D.new()
	timing.name = "TimingLine"
	var curve = Curve3D.new()
	for i in 8:
		var angle = i * TAU / 8.0
		curve.add_point(Vector3(cos(angle) * 50.0, 0.0, sin(angle) * 50.0))
	curve.add_point(Vector3(50.0, 0.0, 0.0))
	timing.curve = curve
	timing.set_meta("start_offset_m", 0.0)
	analytic_asset.add_child(timing)
	timing.owner = analytic_asset
	var grid = Node3D.new()
	grid.name = "Grid"
	analytic_asset.add_child(grid)
	grid.owner = analytic_asset
	var slot0 = Marker3D.new()
	slot0.name = "Slot0"
	slot0.position = Vector3(50.0, 0.0, 0.0)
	grid.add_child(slot0)
	slot0.owner = analytic_asset
	analytic_asset.version = 1
	analytic_asset.id = "analytic_asset"
	var errs = analytic_asset.validate()
	check(errs.is_empty(), "TrackAsset.validate() passes with terrain present: %s" % [errs])
