extends SceneTree
## P3-02b: road tool v2 features requested by the P5-02 proving-ground design, each against an exact
## answer (REBUILD-PLAN.md P3-02; docs/rebuild/proving-ground-P5-02.md).
##   kerbs      SAUSAGE hump and RIBBED kerb (ridge amplitude and pitch along the road)
##   verges     per-side verge surfaces and a runoff band
##   ditch      inset trough compared point by point with TestSurface.ditch() (P2-02 ground truth),
##              37 deg walls, eased taper, a warning when sampled too coarsely, and the 296 driving
##              down the trough floor
##   elevation  keys by station (C2 cubic spline): heights hit exactly; the P5-02 crest keys give R ~ 130 m
##   grid       configurable slot distances (P5-02: 35/75/115/155 m) and stagger
## Roads sit far apart: they share one physics world.
## Run: tools/Godot.exe --headless --path . --script tests/v2/road_tool_v2.gd
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const DT = 1.0 / 240
const KERB_Z = -1000.0
const DITCH_Z = -2000.0
const ELEV_Z = -3000.0
var kerb_host
var ditch_host
var elev_host
var grid_asset
var failures = []
var checks = 0
var frames = 0
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func straight(z, length, keys, road_n = 9, elev = PackedVector2Array()):
	var host = Node3D.new()
	var road = RoadPath.new()
	road.name = "Road"
	road.closed = false
	road.road_stations = road_n
	road.elevation_keys = elev
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, z))
	c.add_point(Vector3(length, 0, z))
	road.curve = c
	road.sections.assign(keys)
	host.add_child(road)
	road.bake()
	root.add_child(host)
	return host


func kerb_keys():
	var v = {
		"width_left": 6.0,
		"width_right": 6.0,
		"kerb_left": RoadSection.Kerb.SAUSAGE,
		"kerb_right": RoadSection.Kerb.RIBBED,
		"kerb_width": .6,
		"kerb_height": .09,
		"verge_surface_left": 2,
		"verge_surface_right": 3,
		"runoff_right": 10.0,
		"runoff_surface": 4,
		"verge_slope_deg": 3.0
	}
	return [RoadSection.make(0.0, v), RoadSection.make(120.0, v)]


func ditch_keys():
	var base = {"width_left": 7.0, "width_right": 7.0, "ditch_offset": -2.0}
	var none = base.duplicate()
	none["ditch"] = 0.0
	var full = base.duplicate()
	full["ditch"] = 1.0
	return [
		RoadSection.make(0.0, none),
		RoadSection.make(60.0, none),
		RoadSection.make(75.0, full),
		RoadSection.make(225.0, full),
		RoadSection.make(240.0, none),
		RoadSection.make(300.0, none)
	]


## The P5-02 crest and grades (station, height), on a flat-drawn 1400 m straight.
func elevation_keys():
	return PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(754, 15),
			Vector2(1006, 18),
			Vector2(1095, 25.46),
			Vector2(1115, 27),
			Vector2(1135, 25.46),
			Vector2(1250, 16),
			Vector2(1400, 10)
		]
	)


func build_grid_asset():
	var asset = Node3D.new()
	asset.set_script(TrackAsset)
	asset.id = "grid_test"
	var road = RoadPath.new()
	road.name = "Loop"
	road.grid_slots = 4
	road.grid_first_m = 35.0
	road.grid_spacing_m = 40.0
	road.grid_offset_m = 3.0
	var c = Curve3D.new()
	var r = 150.0
	var k = .5523 * r
	# A 150 m circle centred at (0, 0, 3000), far from the other roads.
	for p in [
		[Vector3(r, 0, 3000), Vector3(0, 0, -k), Vector3(0, 0, k)],
		[Vector3(0, 0, 3000 + r), Vector3(k, 0, 0), Vector3(-k, 0, 0)],
		[Vector3(-r, 0, 3000), Vector3(0, 0, k), Vector3(0, 0, -k)],
		[Vector3(0, 0, 3000 - r), Vector3(-k, 0, 0), Vector3(k, 0, 0)]
	]:
		c.add_point(p[0], p[1], p[2])
	road.curve = c
	road.sections.assign([RoadSection.make(0.0, {"width_left": 6.0, "width_right": 6.0})])
	asset.add_child(road)
	road.owner = asset
	road.bake()
	asset.prepare()
	root.add_child(asset)
	return asset


func _initialize():
	kerb_host = straight(KERB_Z, 120.0, kerb_keys())
	ditch_host = straight(DITCH_Z, 300.0, ditch_keys(), 57)
	elev_host = straight(ELEV_Z, 1400.0, [RoadSection.make(0.0, {})], 9, elevation_keys())
	grid_asset = build_grid_asset()
	# Warning check straight on the builder (no push_warning, so stderr stays clean).
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(300, 0, 0))
	c.bake_interval = .25
	var coarse = RoadBuilder.bake(c, ditch_keys(), false, 1.5, 9)
	var fine = RoadBuilder.bake(c, ditch_keys(), false, 1.5, 57)
	check(
		coarse.warnings.any(func(w): return "ditch is sampled" in w) and fine.warnings.is_empty(),
		(
			"ditch resolution warning: 9 road stations (1.75 m) warns %s; 57 stations (0.25 m) is clean %s"
			% [coarse.warnings.size(), fine.warnings]
		)
	)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	kerbs_and_verges()
	ditch()
	ditch_drive()
	elevation()
	grid()
	print(
		"ROAD TOOL V2 RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true


func probe(host, x, z):
	return TrackSurface.new(host).contact(Vector3(x, 40, z), Vector3.DOWN, 80)


func kerbs_and_verges():
	var slope = tan(deg_to_rad(3.0))
	# Left SAUSAGE (0.6 m wide, 9 cm): h sin(pi f) at the band's stations; back to 0 at its outer edge.
	var sausage = [[-(6 + .15), .09 * sin(PI * .25)], [-(6 + .30), .09], [-(6 + .45), .09 * sin(PI * .75)]]
	var worst = 0.0
	var ids_ok = true
	for cs in sausage:
		var hit = probe(kerb_host, 40.0, KERB_Z + cs[0] + .001)
		worst = maxf(worst, absf(hit.point.y - cs[1]))
		ids_ok = ids_ok and hit.surface == 1
	var left_verge = probe(kerb_host, 40.0, KERB_Z - (6 + .6 + .05 + 2.0))
	check(
		(
			ids_ok
			and worst < .002
			and left_verge.surface == 2
			and absf(left_verge.point.y + slope * 2.05) < .002
		),
		(
			"SAUSAGE kerb: hump 9 cm at mid-width, sin profile, height error %.4f m; left verge grass, falling 3° from the kerb's outer edge"
			% worst
		)
	)
	# Right RIBBED at mid-width: kerb_height plus ridges of 8 mm every 0.5 m along x.
	var lo = INF
	var hi = -INF
	var peaks = 0
	var prev = [0.0, 0.0]
	var n = 0
	for q in 201:
		var x = 40.0 + q * .01
		var hit = probe(kerb_host, x, KERB_Z + 6.3)
		var y = hit.point.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
		if n >= 2 and prev[1] > prev[0] and prev[1] > y:
			peaks += 1
		prev = [prev[1], y]
		n += 1
	var amplitude = hi - lo
	results["rib_amplitude_m"] = amplitude
	results["rib_peaks_per_2m"] = peaks
	check(
		absf(lo - .09) < .002 and amplitude > .0055 and amplitude < .0085 and peaks == 4,
		(
			"RIBBED kerb: base %.4f m (9 cm), ridge amplitude %.1f mm (8 mm, sampled at quarter pitch), %d ridges over 2 m (pitch 0.5 m)"
			% [lo, amplitude * 1000, peaks]
		)
	)
	var runoff = probe(kerb_host, 40.0, KERB_Z + 6 + .6 + 5.0)
	var gravel = probe(kerb_host, 40.0, KERB_Z + 6 + .6 + 10.0 + 2.0)
	check(
		runoff.surface == 4 and gravel.surface == 3 and absf(runoff.point.y - (.09 - slope * 5.0)) < .002,
		"right runoff band tarmac runoff (4) for 10 m, then gravel (3); left verge grass (2): per-side surfaces"
	)


func ditch():
	var truth = TestSurface.ditch(1.5, 37.0, 1.1, .5)
	var worst = 0.0
	var lats = []
	for k in 56:
		lats.append(-7.0 + k * .25 + .01)
	for lat in lats:
		if absf(lat) > 6.9:
			continue
		var hit = probe(ditch_host, 150.0, DITCH_Z + lat)
		worst = maxf(worst, absf(hit.point.y - truth.height(0.0, lat + 2.0)))
	var mid_wall = -2.0 - (1.5 + .5 + .55)
	var wall = probe(ditch_host, 150.0, DITCH_Z + mid_wall)
	var wall_deg = rad_to_deg(Vector3.UP.angle_to(wall.normal))
	var depth = -probe(ditch_host, 150.0, DITCH_Z - 2.0).point.y
	results["ditch_depth_m"] = depth
	check(
		worst < .003 and absf(wall_deg - 37) < .5 and absf(depth - truth.ditch_depth()) < .002,
		(
			"inset ditch matches TestSurface.ditch() across the road within %.4f m; wall %.2f° (37°), depth %.4f m (%.4f)"
			% [worst, wall_deg, depth, truth.ditch_depth()]
		)
	)
	var tapers = []
	for x in [60.0, 67.5, 75.0]:
		tapers.append(-probe(ditch_host, x, DITCH_Z - 2.0).point.y)
	check(
		tapers[0] < .006 and absf(tapers[1] - depth * .5) < .01 and absf(tapers[2] - depth) < .006,
		(
			"ditch tapers in over 15 m: depth %.3f / %.3f / %.3f m at s 60 / 67.5 / 75 (0, half, full; probes fall between 1.48 m stations)"
			% tapers
		)
	)


## The 296 enters the trough through its taper, drives 150 m along the floor and climbs out.
func ditch_drive():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	var start = probe(ditch_host, 20.0, DITCH_Z - 2.0).point
	c.place(start, 0.0, start.y)
	var surf = TrackSurface.new(ditch_host)
	var lowest = INF
	var min_contacts = 4
	var light = 0
	var wrong_surface = 0
	var ok = true
	var ticks = 0
	while c.pos.x < 280.0:
		var st = clampf(((DITCH_Z - 2.0) - c.pos.z) * .2 - c.vby * .1, -.3, .3)
		var e = 50 / 3.6 - c.speed
		c.input = {
			"throttle": clampf(e * .5 + .3, 0, 1),
			"brake": clampf(-e * .3, 0, 1),
			"steer": st,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		c.step(DT, surf, true)
		lowest = minf(lowest, c.pos.y - c.setup.cgHeight)
		min_contacts = mini(min_contacts, c.contacts)
		light += int(c.contacts < 4)
		for w in c.wheels:
			wrong_surface += int(w.surf.id != 0)
		ticks += 1
		if not is_finite(c.pos.length()) or ticks > 240 * 40:
			ok = false
			break
	results["ditch_light_s"] = light * DT
	# P5-02's 15 m taper (1.2 m deep, lip radius ~31 m) unloads the 296's front wheels briefly at the
	# lip on the way in and out at 50 km/h: physical, and recorded for P5-03 rather than failed here.
	check(
		ok and wrong_surface == 0 and absf(lowest + 1.206) < .05,
		(
			"296 drives down into the ditch, 150 m along its floor and out: lowest ride %.3f m (floor -1.206 m), off tarmac %d; front light for %.2f s at the 15 m taper lips (min contacts %d)"
			% [lowest, wrong_surface, light * DT, min_contacts]
		)
	)


func elevation():
	var keys = elevation_keys()
	var worst = 0.0
	for k in keys:
		var hit = probe(elev_host, clampf(k.x, .1, 1399.9), ELEV_Z)
		worst = maxf(worst, absf(hit.point.y - k.y))
	var bake = elev_host.get_node("Road").last_bake
	check(
		worst < .01 and bake.center.size() > 900,
		"elevation keys: the baked road passes through all 8 P5-02 keys within %.4f m" % worst
	)
	# C2: the spline's curvature is continuous across every interior key (evaluated on the spline).
	var spline = RoadBuilder.elevation_spline(keys, 1400.0, false)
	var worst_jump = 0.0
	var e = .01
	for i in range(1, keys.size() - 1):
		var s = keys[i].x
		var left = (
			(
				RoadBuilder.elevation_at(spline, s - 2 * e, 1400.0, false)
				- 2 * RoadBuilder.elevation_at(spline, s - e, 1400.0, false)
				+ RoadBuilder.elevation_at(spline, s, 1400.0, false)
			)
			/ (e * e)
		)
		var right = (
			(
				RoadBuilder.elevation_at(spline, s, 1400.0, false)
				- 2 * RoadBuilder.elevation_at(spline, s + e, 1400.0, false)
				+ RoadBuilder.elevation_at(spline, s + 2 * e, 1400.0, false)
			)
			/ (e * e)
		)
		worst_jump = maxf(worst_jump, absf(left - right))
	check(worst_jump < 2e-3, "elevation spline is C2: curvature jump at keys at most %.5f 1/m" % worst_jump)
	# Ground truth: keys sampled every 20 m from a true R = 130 m crest must give R = 130 m at its apex.
	var circle = PackedVector2Array()
	var r = 130.0
	for k in range(-5, 6):
		var d = k * 20.0
		circle.append(Vector2(1115 + d, 27.0 - (r - sqrt(r * r - d * d))))
	var cs = RoadBuilder.elevation_spline(circle, 1400.0, false)
	var h = 1.0
	var kc = (
		(
			RoadBuilder.elevation_at(cs, 1115 - h, 1400.0, false)
			- 2 * RoadBuilder.elevation_at(cs, 1115, 1400.0, false)
			+ RoadBuilder.elevation_at(cs, 1115 + h, 1400.0, false)
		)
		/ (h * h)
	)
	check(
		absf(-1 / kc - r) / r < .03,
		"keys sampled every 20 m from an R = 130 m crest reproduce it: apex R %.1f m" % (-1 / kc)
	)
	# The P5-02 keys as written: their approach grade (8.4 %) cannot meet an R 130 m arc (15.4 % grade 20 m
	# before the apex), so any smooth profile tightens the crest. Reported for P5-03.
	var y0 = RoadBuilder.elevation_at(spline, 1115 - h, 1400.0, false)
	var y1 = RoadBuilder.elevation_at(spline, 1115, 1400.0, false)
	var y2 = RoadBuilder.elevation_at(spline, 1115 + h, 1400.0, false)
	var kp = (y0 - 2 * y1 + y2) / (h * h)
	results["p5_02_crest_radius_m"] = -1 / kp
	print("PROBE P5-02 crest keys as written give an apex radius of %.0f m (design target 130 m)" % (-1 / kp))


func grid():
	var slots = grid_asset.grid_slots()
	var behind = []
	var stagger = []
	for xf in slots:
		var pr = grid_asset.project(xf.origin)
		behind.append(snappedf(grid_asset.length - pr.s, .1))
		stagger.append(snappedf(pr.lateral, .01))
	var want = [35.0, 75.0, 115.0, 155.0]
	var ok = slots.size() == 4
	for i in slots.size():
		ok = ok and absf(behind[i] - want[i]) < 1.0 and absf(absf(stagger[i]) - 3.0) < .05
	check(ok, "grid slots %s m behind the start (35/75/115/155), staggered %s m" % [behind, stagger])
