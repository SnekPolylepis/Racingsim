extends SceneTree
## P3-02c: variable road station density tests (REBUILD-PLAN.md P3-02c).
## Tests:
##   1. Straight road: coarse 9 with dense 57 range carrying crown and inset ditch;
##      TrackSurface heights match analytic cross-section within 2 mm on both sides
##      of each transition seam and inside the dense range.
##   2. Watertight: every interior edge in baked collision faces is shared by exactly two
##      triangles; rays on a 5 cm grid across both transition seams all hit, and no height
##      jump over 1 mm across the seam.
##   3. UVs continuous across the seams (no jump > 1e-4 in metres).
##   4. Incompatible count (e.g. coarse 9, dense 50) warns and falls back.
##   5. Proving ground regenerated: report uncompressed/compressed scene size and triangle count before/after.
## Run: tools/Godot.exe --headless --path . --script tests/v2/road_density.gd

const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")

const STRAIGHT_Z = -500.0
var test_host: Node3D
var test_road: RoadPath
var checks = 0
var failures = []
var results = {}
var frames = 0
var ran = false


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func ditch_keys() -> Array:
	var base = {"width_left": 7.0, "width_right": 7.0, "crown": 0.08, "ditch_offset": -2.0}
	var none = base.duplicate()
	none["ditch"] = 0.0
	var full = base.duplicate()
	full["ditch"] = 1.0
	return [
		RoadSection.make(0.0, none),
		RoadSection.make(110.0, none),
		RoadSection.make(125.0, full),
		RoadSection.make(175.0, full),
		RoadSection.make(190.0, none),
		RoadSection.make(300.0, none)
	]


func build_straight_road() -> Node3D:
	var host = Node3D.new()
	host.name = "StraightHost"
	var road = RoadPath.new()
	road.name = "Straight"
	road.closed = false
	road.along_step = 1.5
	road.road_stations = 9
	road.dense_ranges = [{"from_m": 100.0, "to_m": 200.0, "road_stations": 57}]
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, STRAIGHT_Z))
	c.add_point(Vector3(300, 0, STRAIGHT_Z))
	road.curve = c
	road.sections.assign(ditch_keys())
	host.add_child(road)
	road.bake()
	test_road = road
	return host


func _initialize() -> void:
	test_host = build_straight_road()
	root.add_child(test_host)

	# Check 4: Incompatible count warns and falls back (non-physics)
	check_incompatible_fallback()


func _physics_process(_delta) -> bool:
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("ROAD DENSITY RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true

	check_analytic_surface_match()
	check_watertight_and_grid()
	check_uv_continuity()
	check_proving_ground_size()

	print(
		"ROAD DENSITY RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	test_host.free()
	quit(0 if failures.is_empty() else 1)
	return true


func probe(surf: TrackSurface, x: float, z: float) -> Dictionary:
	return surf.contact(Vector3(x, 10, z), Vector3.DOWN, 20)


## Check 1: Analytic surface match within 2 mm on both sides of each transition and inside dense range
func check_analytic_surface_match() -> void:
	var surf = TrackSurface.new(test_host)
	var bake = test_road.last_bake
	var keys = test_road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)

	# Stations tested:
	#   x = 80  (coarse 9, before transition 1)
	#   x = 105 (dense 57, after transition 1, crowned, ditch 0)
	#   x = 150 (dense 57, inside dense range, full ditch)
	#   x = 195 (dense 57, before transition 2, crowned, ditch 0)
	#   x = 220 (coarse 9, after transition 2)
	var x_samples = [80.0, 105.0, 150.0, 195.0, 220.0]
	var worst_err = 0.0

	for x in x_samples:
		var sec = RoadBuilder.section_at(keys, x, 300.0, false)
		# Probe across the road width (-6.8 to +6.8 m in 0.5 m steps)
		for step_i in 28:
			var lat = -6.75 + step_i * 0.5
			var hit = probe(surf, x, STRAIGHT_Z + lat)
			if hit.is_empty():
				worst_err = INF
				continue
			var expected_y = RoadBuilder.road_height(sec, lat)
			var err = absf(hit.point.y - expected_y)
			worst_err = maxf(worst_err, err)

	results["worst_surface_error_m"] = worst_err
	check(
		worst_err < 0.002,
		"analytic cross-section matches within 2 mm across transitions and in ditch: worst %.4f m" % worst_err
	)


## Check 2: Watertight edge map and 5 cm ray grid across both seams
func check_watertight_and_grid() -> void:
	var surf = TrackSurface.new(test_host)
	var bake = test_road.last_bake

	# 2a. Edge map: every interior edge in baked collision faces must be shared by exactly 2 triangles
	var edge_counts = {}
	var edge_endpoints = {}
	for sid in bake.faces:
		var faces = bake.faces[sid]
		for i in range(0, faces.size(), 3):
			var v0 = faces[i]
			var v1 = faces[i + 1]
			var v2 = faces[i + 2]
			var edges = [[v0, v1], [v1, v2], [v2, v0]]
			for e in edges:
				var k = edge_key(e[0], e[1])
				edge_counts[k] = edge_counts.get(k, 0) + 1
				if not edge_endpoints.has(k):
					edge_endpoints[k] = [e[0], e[1]]

	var interior_tested = 0
	var interior_ok = true
	var bad_counts = []
	# For an open straight road along X from 0 to 300 m with width 7 + kerb 0.6 + runoff 0.05 + verge 6 = 13.65 m:
	# Outer boundary edges lie at x <= 0.01, x >= 299.99, or |z - STRAIGHT_Z| >= 13.60 m.
	var half_width_outer = 7.0 + 0.6 + 0.05 + 6.0
	for k in edge_counts:
		var pts = edge_endpoints[k]
		var mid_x = (pts[0].x + pts[1].x) * 0.5
		var mid_z = absf((pts[0].z + pts[1].z) * 0.5 - STRAIGHT_Z)
		var is_boundary = mid_x <= 0.05 or mid_x >= 299.95 or mid_z >= half_width_outer - 0.05
		if not is_boundary:
			interior_tested += 1
			var cnt = edge_counts[k]
			if cnt != 2:
				interior_ok = false
				if bad_counts.size() < 5:
					bad_counts.append({"edge": k, "count": cnt})

	results["interior_edges_tested"] = interior_tested
	check(
		interior_ok and interior_tested > 1000,
		(
			"watertight collision mesh: %d interior edges all shared by exactly 2 triangles (bad: %s)"
			% [interior_tested, bad_counts]
		)
	)

	# 2b. 5 cm ray grid across both transition seams:
	# Transition 1: around x = 100 m (98.5 to 101.5 m)
	# Transition 2: around x = 200 m (198.5 to 201.5 m)
	var all_hit = true
	var max_step_jump = 0.0
	for seam_center in [100.0, 200.0]:
		for lat_i in range(-120, 121):
			var lat = lat_i * 0.05
			var prev_y = null
			for x_i in range(-30, 31):
				var x = seam_center + x_i * 0.05
				var hit = probe(surf, x, STRAIGHT_Z + lat)
				if hit.is_empty():
					all_hit = false
					continue
				if prev_y != null:
					var jump = absf(hit.point.y - prev_y)
					max_step_jump = maxf(max_step_jump, jump)
				prev_y = hit.point.y

	results["max_seam_height_jump_m"] = max_step_jump
	check(
		all_hit and max_step_jump < 0.001,
		(
			"5 cm ray grid across seams: all hit, max 5 cm step height jump %.4f mm (limit < 1.0 mm)"
			% [max_step_jump * 1000.0]
		)
	)


func edge_key(p0: Vector3, p1: Vector3) -> String:
	var a = Vector3(snappedf(p0.x, 1e-4), snappedf(p0.y, 1e-4), snappedf(p0.z, 1e-4))
	var b = Vector3(snappedf(p1.x, 1e-4), snappedf(p1.y, 1e-4), snappedf(p1.z, 1e-4))
	if a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))):
		return "%.4f,%.4f,%.4f:%.4f,%.4f,%.4f" % [a.x, a.y, a.z, b.x, b.y, b.z]
	else:
		return "%.4f,%.4f,%.4f:%.4f,%.4f,%.4f" % [b.x, b.y, b.z, a.x, a.y, a.z]


## Check 3: UVs continuous across the seams (no jump > 1e-4 in metres)
func check_uv_continuity() -> void:
	var bake = test_road.last_bake
	var pos_to_uvs = {}

	for sid in bake.faces:
		var faces = bake.faces[sid]
		var uvs = bake.uvs[sid]
		for i in faces.size():
			var p = faces[i]
			var uv = uvs[i]
			var k = "%.4f,%.4f,%.4f" % [snappedf(p.x, 1e-4), snappedf(p.y, 1e-4), snappedf(p.z, 1e-4)]
			if not pos_to_uvs.has(k):
				pos_to_uvs[k] = []
			pos_to_uvs[k].append(uv)

	var max_uv_jump = 0.0
	for k in pos_to_uvs:
		var uv_list = pos_to_uvs[k]
		if uv_list.size() > 1:
			var base = uv_list[0]
			for m in range(1, uv_list.size()):
				var d = base.distance_to(uv_list[m])
				max_uv_jump = maxf(max_uv_jump, d)

	results["max_uv_jump_m"] = max_uv_jump
	check(
		max_uv_jump < 1e-4,
		"UVs continuous across shared vertices and seams: max discrepancy %.6f m (< 1e-4)" % max_uv_jump
	)


## Check 4: Incompatible count (e.g. coarse 9, dense 50) warns and falls back
func check_incompatible_fallback() -> void:
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(200, 0, 0))
	c.bake_interval = 0.25
	var bad_ranges = [{"from_m": 50.0, "to_m": 150.0, "road_stations": 50}]
	var bake = RoadBuilder.bake(
		c, [RoadSection.make(0.0, {})], false, 1.5, 9, PackedVector2Array(), bad_ranges
	)

	var has_incompat_warn = bake.warnings.any(
		func(w): return "incompatible with coarse" in w and "50" in w and "9" in w
	)
	# Should fall back to coarse 9 everywhere: max_across_road is ~1.75 m (14.0 / 8), not 14.0 / 49 (~0.28)
	var fell_back = bake.max_across_road > 1.0

	check(
		has_incompat_warn and fell_back,
		(
			"incompatible dense count 50 warns and falls back to coarse 9 (max across: %.3f m): %s"
			% [bake.max_across_road, bake.warnings]
		)
	)


## Check 5: Proving ground regenerated size and triangle report
func check_proving_ground_size() -> void:
	var scn_path = "res://tracks3d/proving_ground/proving_ground.scn"
	var packed = ResourceLoader.load(scn_path)
	var scene = packed.instantiate()

	var total_tris = 0
	var road_tris = 0
	for child in scene.get_node("Surfaces").get_children():
		if child is StaticBody3D:
			for col in child.get_children():
				if col is CollisionShape3D and col.shape is ConcavePolygonShape3D:
					var cnt = col.shape.get_faces().size() / 3
					total_tris += cnt
					if "_s0" in child.name:
						road_tris += cnt

	var uncompressed_path = "user://native-tests/v2/road_density/pg_uncompressed.scn"
	DirAccess.make_dir_recursive_absolute("user://native-tests/v2/road_density")
	ResourceSaver.save(packed, uncompressed_path)
	var uncomp_bytes = FileAccess.get_file_as_bytes(uncompressed_path).size()
	var comp_bytes = FileAccess.get_file_as_bytes(scn_path).size()

	results["proving_ground"] = {
		"before":
		{"comp_bytes": 8954818, "uncomp_bytes": 32754545, "total_col_tris": 265120, "road_col_tris": 189056},
		"after":
		{
			"comp_bytes": comp_bytes,
			"uncomp_bytes": uncomp_bytes,
			"total_col_tris": total_tris,
			"road_col_tris": road_tris
		}
	}

	print(
		(
			(
				"PROVING GROUND SIZE REPORT:\n"
				+ "  Compressed bytes:   %d (%.2f MB) -> %d (%.2f MB) [-%.1f%%]\n"
				+ "  Uncompressed bytes: %d (%.2f MB) -> %d (%.2f MB) [-%.1f%%]\n"
				+ "  Total collision tris: %d -> %d [-%.1f%%]\n"
				+ "  Road collision tris:  %d -> %d [-%.1f%%]"
			)
			% [
				8954818,
				8954818 / 1048576.0,
				comp_bytes,
				comp_bytes / 1048576.0,
				(1.0 - float(comp_bytes) / 8954818.0) * 100.0,
				32754545,
				32754545 / 1048576.0,
				uncomp_bytes,
				uncomp_bytes / 1048576.0,
				(1.0 - float(uncomp_bytes) / 32754545.0) * 100.0,
				265120,
				total_tris,
				(1.0 - float(total_tris) / 265120.0) * 100.0,
				189056,
				road_tris,
				(1.0 - float(road_tris) / 189056.0) * 100.0
			]
		)
	)

	check(
		comp_bytes < 5000000 and road_tris < 50000,
		(
			"proving ground compressed scene %d bytes (< 5 MB budget) and road tris %d (was 189,056)"
			% [comp_bytes, road_tris]
		)
	)
	scene.free()
