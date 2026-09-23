extends SceneTree
## P3-02: the road tool (RoadPath + RoadSection + road_builder) against analytic cross-sections, then a
## complete track built only with the tool and lapped by the 6-DOF car (REBUILD-PLAN.md P3-02 gate).
##
## Part A, a 200 m straight along +x at z = -500 (right of travel = +z) with keys:
##   s 0..60     crown 8 cm, flat; ramp kerb on the right (1 m, 5 cm); no kerb left; grass verge 3 deg
##   s 140..200  no crown, banked 10 deg (left edge raised); eased from s 60 (under the twist warning)
## Heights, bank, surface ids and tessellation are checked through TrackSurface (physics-server rays).
## Part B, a ~890 m closed loop (rounded rectangle, R 40 m corners banked 6 deg with kerbs and gravel,
## a 6 m hill on the back straight), baked into a TrackAsset, validated, saved, reloaded and lapped.
## The lap-time floor is 0.95 x (centreline length / speed): the steering controller cuts the 40 m
## corners, so it drives a shorter line; the check exists to catch a miscounted lap (2x off).
## Run: tools/Godot.exe --headless --path . --script tests/v2/road_tool.gd
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackLoader = preload("res://scripts/track/track_loader.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const DIR = "user://native-tests/v2/road_tool"
const DT = 1.0 / 240
const K = 22.1  # Bezier handle for a 40 m quarter circle (0.5523 R)
## Part A's straight sits well away from the loop: both live in the same physics world.
const STRAIGHT_Z = -500.0
var straight
var loop_asset
var failures = []
var checks = 0
var frames = 0
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func build_straight():
	var host = Node3D.new()
	host.name = "StraightHost"
	var road = RoadPath.new()
	road.name = "Straight"
	road.closed = false
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, STRAIGHT_Z))
	c.add_point(Vector3(200, 0, STRAIGHT_Z))
	road.curve = c
	var crowned = {
		"crown": .08,
		"kerb_right": RoadSection.Kerb.RAMP,
		"kerb_width": 1.0,
		"kerb_height": .05,
		"verge_slope_deg": 3.0,
		"verge_surface": 2
	}
	var banked = {"crown": 0.0, "bank_deg": 10.0, "kerb_right": RoadSection.Kerb.RAMP, "verge_surface": 2}
	road.sections.assign(
		[
			RoadSection.make(0.0, crowned),
			RoadSection.make(60.0, crowned),
			RoadSection.make(140.0, banked),
			RoadSection.make(200.0, banked)
		]
	)
	host.add_child(road)
	road.bake()
	return host


func build_loop():
	var asset = Node3D.new()
	asset.set_script(TrackAsset)
	asset.name = "ProvingLoop"
	asset.id = "proving_loop_test"
	asset.display_name = "Road-tool proving loop (test fixture)"
	var road = RoadPath.new()
	road.name = "Main"
	road.closed = true
	road.grid_slots = 4
	var c = Curve3D.new()
	# Rounded rectangle, right-hand corners (turning towards +z from +x), hill mid back-straight. The
	# start is mid bottom-straight, so the grid sits on flat, unbanked road.
	var pts = [
		[Vector3(140, 0, 0), Vector3.ZERO, Vector3.ZERO],
		[Vector3(280, 0, 0), Vector3.ZERO, Vector3(K, 0, 0)],
		[Vector3(320, 0, 40), Vector3(0, 0, -K), Vector3.ZERO],
		[Vector3(320, 0, 80), Vector3.ZERO, Vector3(0, 0, K)],
		[Vector3(280, 0, 120), Vector3(K, 0, 0), Vector3(-30, 0, 0)],
		[Vector3(140, 6, 120), Vector3(30, 0, 0), Vector3(-30, 0, 0)],
		[Vector3(0, 0, 120), Vector3(30, 0, 0), Vector3(-K, 0, 0)],
		[Vector3(-40, 0, 80), Vector3(0, 0, K), Vector3.ZERO],
		[Vector3(-40, 0, 40), Vector3.ZERO, Vector3(0, 0, -K)],
		[Vector3(0, 0, 0), Vector3(-K, 0, 0), Vector3.ZERO]
	]
	for p in pts:
		c.add_point(p[0], p[1], p[2])
	road.curve = c
	asset.add_child(road)
	road.owner = asset
	# Section keys: corner profile across each arc; on long straights, back to the straight profile over
	# 60 m either side (smoothstep peak 0.15 deg/m; 15 m transitions twisted enough to lift a 296 wheel).
	var work = road.working_curve()
	var straight_profile = {"crown": .06, "verge_surface": 2}
	var corner_profile = {
		"crown": 0.0,
		"bank_deg": 6.0,
		"kerb_left": RoadSection.Kerb.RAMP,
		"kerb_right": RoadSection.Kerb.RAMP,
		"verge_surface": 3
	}
	var arcs = [
		[pts[1][0], pts[2][0]], [pts[3][0], pts[4][0]], [pts[6][0], pts[7][0]], [pts[8][0], pts[9][0]]
	]
	var keys = []
	var length = work.get_baked_length()
	var spans = []
	for arc in arcs:
		var a = work.get_closest_offset(arc[0])
		var b = work.get_closest_offset(arc[1])
		spans.append([a, b if b >= a else b + length])
	for i in spans.size():
		var a = spans[i][0]
		var b = spans[i][1]
		keys.append(RoadSection.make(fposmod(a, length), corner_profile))
		keys.append(RoadSection.make(fposmod(b, length), corner_profile))
		# Only flatten out on a straight long enough for both 60 m transitions; a short straight between
		# two corners (the 40 m ends of the rectangle) stays banked, as on a real circuit.
		var next_a = spans[(i + 1) % spans.size()][0]
		var gap = fposmod(next_a - b, length)
		if gap >= 120:
			keys.append(RoadSection.make(fposmod(b + 60, length), straight_profile))
			keys.append(RoadSection.make(fposmod(next_a - 60, length), straight_profile))
	road.sections.assign(keys)
	road.bake()
	return asset


func _initialize():
	straight = build_straight()
	root.add_child(straight)
	var built = build_loop()
	var errors = built.validate()
	check(errors.is_empty(), "the tool-built loop validates as a TrackAsset %s" % [errors])
	var bodies = built.get_node("Surfaces").get_child_count()
	var grid = built.get_node("Grid")
	var manual_slot = Marker3D.new()
	manual_slot.name = "ManualSlot"
	grid.add_child(manual_slot)
	manual_slot.owner = built
	var other_road_slot = Marker3D.new()
	other_road_slot.name = "OtherRoadSlot"
	other_road_slot.set_meta("_road_path_source", "OtherRoad")
	grid.add_child(other_road_slot)
	other_road_slot.owner = built
	built.get_node("Main").bake()
	var own_slots = 0
	for child in grid.get_children():
		if child.get_meta("_road_path_source", "") == "Main":
			own_slots += 1
	check(
		(
			built.get_node("Surfaces").get_child_count() == bodies
			and grid.get_child_count() == 6
			and own_slots == 4
			and is_instance_valid(manual_slot)
			and is_instance_valid(other_road_slot)
			and manual_slot.get_parent() == grid
			and other_road_slot.get_parent() == grid
		),
		(
			"re-baking replaces 4 own slots and %d surface bodies; preserves authored and other-road slots"
			% bodies
		)
	)
	# The two sentinels are not racing grid slots for the lap fixture below.
	if is_instance_valid(manual_slot):
		grid.remove_child(manual_slot)
		manual_slot.free()
	if is_instance_valid(other_road_slot):
		grid.remove_child(other_road_slot)
		other_road_slot.free()
	var bake = built.get_node("Main").last_bake
	results["loop"] = {
		"length_m": bake.length, "max_along_m": bake.max_along, "max_across_road_m": bake.max_across_road
	}
	var max_uv_step = 0.0
	var max_uv_station = 0.0
	for sid in bake.uvs:
		var uv = bake.uvs[sid]
		for i in range(0, uv.size(), 3):
			max_uv_step = maxf(max_uv_step, absf(uv[i + 1].y - uv[i].y))
			max_uv_station = maxf(max_uv_station, uv[i + 1].y)
	check(
		(
			bake.max_along <= 1.5 + 1e-6
			and bake.max_across_road <= 10.0 / 8 + 1e-3
			and max_uv_step <= 1.5 + 1e-6
			and absf(max_uv_station - bake.length) < .01
		),
		(
			"tessellation %.3f m along / %.3f m across; road UVs advance <= %.3f m and unwrap at %.1f m"
			% [bake.max_along, bake.max_across_road, max_uv_step, max_uv_station]
		)
	)
	check(
		bake.max_twist_deg_per_m < .2,
		"loop bank twist at most %.3f deg/m (warning threshold 0.2)" % bake.max_twist_deg_per_m
	)
	var ids = bake.faces.keys()
	ids.sort()
	check(ids == [0, 1, 2, 3], "loop bakes tarmac, kerb, grass and gravel surfaces %s" % [ids])
	var folder = DIR + "/proving_loop_test"
	DirAccess.make_dir_recursive_absolute(folder)
	var packed = PackedScene.new()
	var pack_err = packed.pack(built)
	var save_err = ResourceSaver.save(packed, folder + "/proving_loop_test.scn")
	built.free()
	var loaded = TrackLoader.load_asset(folder + "/proving_loop_test.scn")
	loop_asset = loaded.asset
	check(
		pack_err == OK and save_err == OK and loop_asset != null and loaded.errors.is_empty(),
		"saved and reloaded through the loader: %s" % [loaded.errors]
	)
	root.add_child(loop_asset)
	var loaded_road = loop_asset.get_node("Main")
	loaded_road.bake()
	var owned = true
	var loaded_grid = loop_asset.get_node("Grid")
	for child in loaded_grid.get_children():
		owned = owned and child.owner == loop_asset and child.get_meta("_road_path_source", "") == "Main"
	check(
		loaded_grid.get_child_count() == 4 and owned,
		"saved road re-bakes to 4 owned grid slots without duplicates"
	)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	straight_checks()
	loop_checks()
	lap()
	print("ROAD TOOL RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


## Height of the surface below (x, z), and its surface id and normal, through TrackSurface.
func probe(surf, x, z):
	var hit = surf.contact(Vector3(x, 5, z), Vector3.DOWN, 10)
	return hit


func straight_checks():
	var surf = TrackSurface.new(straight)
	var bake = straight.get_node("Straight").last_bake
	check(
		bake.max_along <= 1.5 + 1e-6 and bake.max_across_road <= 1.25 + 1e-3,
		"straight: %.3f m along, %.3f m across the road" % [bake.max_along, bake.max_across_road]
	)
	# Crowned, flat section at x = 30. [lateral, expected height, expected surface].
	var slope = tan(deg_to_rad(3.0))
	var cases = [
		[0.0, .08, 0],
		[2.5, .06, 0],
		[-2.5, .06, 0],
		# Probes stay just inside strip boundaries: on a seam either strip is a fair answer.
		[4.99, .08 * (1 - .998 * .998), 0],
		[5.5, .025, 1],
		[5.95, .0475, 1],
		[9.0, .05 - slope * 3.0, 2],
		[-5.5, -slope * .5, 2],
		[-9.0, -slope * 4.0, 2]
	]
	var worst = 0.0
	var ids_ok = true
	for cs in cases:
		var hit = probe(surf, 30.0, STRAIGHT_Z + cs[0])
		if hit.is_empty():
			ids_ok = false
			continue
		worst = maxf(worst, absf(hit.point.y - cs[1]))
		ids_ok = ids_ok and hit.surface == cs[2]
	check(
		ids_ok and worst < .002,
		(
			"crowned section: crown 8 cm, half-width 6 cm, edges 0, ramp kerb 2.5/5 cm, 3° grass verge; worst height error %.4f m, surfaces as keyed"
			% worst
		)
	)
	# Banked section at x = 170: a point `lat` across the banked road sits at z = lat cos b, y = -lat sin b.
	var b = deg_to_rad(10.0)
	var bank_worst = 0.0
	var tilt_worst = 0.0
	for lat in [-4.9, -2.5, 2.5, 4.9]:
		var hit = probe(surf, 170.0, STRAIGHT_Z + lat * cos(b))
		if hit.is_empty():
			bank_worst = INF
			continue
		bank_worst = maxf(bank_worst, absf(hit.point.y - (-lat * sin(b))))
		tilt_worst = maxf(tilt_worst, absf(rad_to_deg(Vector3.UP.angle_to(hit.normal)) - 10.0))
	var left_high = probe(surf, 170.0, STRAIGHT_Z - 4.99 * cos(b))
	check(
		bank_worst < .002 and tilt_worst < .05 and not left_high.is_empty() and left_high.point.y > .8,
		(
			"banked section: surface on the 10° plane within %.4f m, normal tilt within %.3f° of 10°, left edge raised to %.3f m (+5 sin 10° = 0.868)"
			% [bank_worst, tilt_worst, left_high.get("point", Vector3.ZERO).y]
		)
	)
	# Easing: bank climbs monotonically from 0 at s 60 to 10° at s 140, midway ~5°. Bank is read from
	# the height difference across ±4 m, so the symmetric crown cancels.
	var tilts = []
	for x in [60.0, 80.0, 100.0, 120.0, 140.0]:
		var left = probe(surf, x, STRAIGHT_Z - 4.0)
		var right = probe(surf, x, STRAIGHT_Z + 4.0)
		if left.is_empty() or right.is_empty():
			tilts.append(-1.0)
			continue
		tilts.append(rad_to_deg(atan2(left.point.y - right.point.y, right.point.z - left.point.z)))
	var monotonic = true
	for i in range(1, tilts.size()):
		monotonic = monotonic and tilts[i] >= tilts[i - 1] - 1e-3
	check(
		monotonic and tilts[0] < .05 and absf(tilts[2] - 5.0) < .3 and absf(tilts[4] - 10.0) < .05,
		(
			"bank eases smoothly between keys: %s deg at s 60/80/100/120/140"
			% [tilts.map(func(v): return snappedf(v, .01))]
		)
	)


func loop_checks():
	var surf = loop_asset.surface()
	var lap_len = loop_asset.length
	var curve_len = loop_asset.get_node("Main").working_curve().get_baked_length()
	results["loop_lap_m"] = lap_len
	check(
		absf(lap_len / curve_len - 1) < .005,
		"timing line %.1f m follows the road's own centreline (%.1f m) within 0.5%%" % [lap_len, curve_len]
	)
	# First corner apex (arc from (280,0,0) to (320,0,40), centre (280,0,40)): banked 6 deg with kerbs.
	var apex = Vector3(280, 0, 40) + Vector3(cos(-PI / 4), 0, sin(-PI / 4)) * 40
	var hit = surf.contact(apex + Vector3.UP * 3, Vector3.DOWN, 6)
	var tilt = rad_to_deg(Vector3.UP.angle_to(hit.normal)) if not hit.is_empty() else -1.0
	var outward = (apex - Vector3(280, 0, 40)).normalized()
	var kerb = surf.contact(apex + outward * 5.5 + Vector3.UP * 3, Vector3.DOWN, 6)
	var gravel = surf.contact(apex + outward * 10.0 + Vector3.UP * 3, Vector3.DOWN, 8)
	check(
		absf(tilt - 6.0) < .3 and kerb.get("surface", -1) == 1 and gravel.get("surface", -1) == 3,
		(
			"first corner apex: banked %.2f° (keyed 6°), kerb (1) at 5.5 m out, gravel (3) beyond: %d / %d"
			% [tilt, kerb.get("surface", -1), gravel.get("surface", -1)]
		)
	)
	var crest = surf.contact(Vector3(140, 12, 120), Vector3.DOWN, 12)
	check(
		not crest.is_empty() and absf(crest.point.y - 6.06) < .05,
		"hill crest at 6 m (plus 6 cm crown): %.3f m" % crest.get("point", Vector3.ZERO).y
	)
	var slots_ok = true
	for xf in loop_asset.grid_slots():
		var g = surf.contact(xf.origin + Vector3.UP, Vector3.DOWN, 2)
		slots_ok = slots_ok and not g.is_empty() and g.surface == 0 and absf(g.point.y - xf.origin.y) < .02
	check(slots_ok, "all grid slots sit on tarmac")


## The 296 GT3 from pole at 60 km/h through every gate, as in the P3-01 lap. Kerbs are allowed; grass
## and gravel are not.
func lap():
	var surf = loop_asset.surface()
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	var pole = loop_asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var gates = loop_asset.gates()
	var next = 0
	var started = -1.0
	var lap_time = -1.0
	var hint = -1
	var off = 0
	var min_contacts = 4
	var t = 0.0
	var prev = c.pos
	var step_us = 0
	var ticks = 0
	var speed = 60 / 3.6
	while t < 150 and lap_time < 0:
		var pr = loop_asset.project(c.pos, hint)
		hint = pr.idx
		var target = loop_asset.station(pr.s + 10 + c.speed * .5).pos
		var want = atan2(target.z - c.pos.z, target.x - c.pos.x)
		var st = clampf(wrapf(want - c.h, -PI, PI) * 2.5, -1, 1)
		var e = speed - c.speed
		c.input = {
			"throttle": clampf(e * .5 + .3, 0, 1),
			"brake": clampf(-e * .3, 0, 1),
			"steer": st,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		var t0 = Time.get_ticks_usec()
		c.step(DT, surf, true)
		step_us += Time.get_ticks_usec() - t0
		ticks += 1
		t += DT
		min_contacts = mini(min_contacts, c.contacts)
		for w in c.wheels:
			if w.surf.id > 1:
				off += 1
		if c.contacts < 4 and OS.get_cmdline_user_args().has("--diag"):
			print(
				(
					"LOSS t=%.3f s=%.1f pos=%s contacts=%d loads=%s comps=%s"
					% [
						t,
						pr.s,
						c.pos,
						c.contacts,
						c.wheels.map(func(w): return snappedf(w.load, 1)),
						c.wheels.map(func(w): return snappedf(w.comp, .001))
					]
				)
			)
		if TrackAsset.crossed(gates[next], prev, c.pos):
			if next == 0:
				if started >= 0:
					lap_time = t - started
				else:
					started = t
				next = 1
			else:
				next = (next + 1) % gates.size()
		prev = c.pos
	var nominal = loop_asset.length / speed
	results["lap_s"] = lap_time
	results["car_step_us"] = float(step_us) / ticks
	check(
		lap_time > nominal * .95 and lap_time < nominal * 1.15 and min_contacts == 4 and off == 0,
		(
			"296 GT3 laps the tool-built loop through all %d gates: %.2f s (one lap at 60 km/h ≈ %.1f s), min contacts %d, wheel-ticks on grass/gravel %d"
			% [gates.size(), lap_time, nominal, min_contacts, off]
		)
	)
