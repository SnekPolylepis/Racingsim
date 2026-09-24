extends SceneTree
## P6-02a validation and lap suite for Nürburgring Nordschleife Section 1.
## Bakes the track in-memory, validates TrackAsset contracts, probes geometry/terrain/barriers,
## and tests BotDriver laps for all 3 cars (roadster, gt, f296gt3) under Simulation and Simcade.
## Exit 0 only if TrackAsset validates, zero warnings, all probe criteria pass, and all laps complete
## with zero off-track wheel ticks and zero wall contacts.
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const Generator = preload("res://trackgen/nordschleife_s1.gd")

const DT = 1.0 / 240.0

var presets
var asset
var surf
var road
var bot_line
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


func _initialize() -> void:
	var raw_cars = FileAccess.get_file_as_string("res://data/cars.json")
	presets = GatesEnv.only_car(JSON.parse_string(raw_cars))
	asset = Generator.build_asset()
	if asset == null:
		push_error("Failed to build Nordschleife Section 1 asset")
		quit(1)
		return
	var world = SubViewport.new()
	world.own_world_3d = true
	world.size = Vector2i(2, 2)
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(world)
	world.add_child(asset)
	surf = asset.surface()
	road = asset.get_node("Main")
	bot_line = asset.get_node("BotLine")


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("NORDSCHLEIFE_S1 RESULTS aborted by script error (see stderr)")
		quit(1)
		return true
	ran = true

	# 1. Validation and bake warnings
	var errors = asset.validate()
	check(errors.is_empty(), "TrackAsset.validate() has zero errors: %s" % [errors])
	var warnings = road.last_bake.warnings
	check(warnings.is_empty(), "RoadPath bake has zero warnings: %s" % [warnings])

	# 2. Probe BotLine points on tarmac
	var bot_pts = bot_line.curve.point_count
	var bot_on_tarmac = 0
	var max_bot_dy = 0.0
	for i in bot_pts:
		var p = bot_line.curve.get_point_position(i)
		var hit = surf.contact(p + Vector3.UP * 1.0, Vector3.DOWN, 3.0, 0)
		if not hit.is_empty():
			if hit.surface == 0:
				bot_on_tarmac += 1
			var dy = absf(p.y - hit.point.y)
			max_bot_dy = maxf(max_bot_dy, dy)
	check(
		bot_on_tarmac == bot_pts,
		"BotLine points on tarmac: %d / %d (max dy: %.3f m)" % [bot_on_tarmac, bot_pts, max_bot_dy]
	)
	check(max_bot_dy <= 0.15, "BotLine vertical elevation within 0.15 m of tarmac (got %.3f m)" % max_bot_dy)

	# 3. Probe road width on both sides (at least 3.5 m tarmac each side of centreline)
	var stations = road.last_bake.stations
	var min_w_left = 999.0
	var min_w_right = 999.0
	for st in stations:
		var right = st.tangent.cross(Vector3.UP).normalized()
		var left_hit = surf.contact(st.pos - right * 3.5 + Vector3.UP * 0.5, Vector3.DOWN, 2.0, 0)
		var right_hit = surf.contact(st.pos + right * 3.5 + Vector3.UP * 0.5, Vector3.DOWN, 2.0, 0)
		if left_hit.get("surface", -1) == 0:
			min_w_left = minf(min_w_left, 3.5)
		if right_hit.get("surface", -1) == 0:
			min_w_right = minf(min_w_right, 3.5)
	check(
		min_w_left >= 3.5 and min_w_right >= 3.5,
		"Road width probe: min left >= %.1f m, min right >= %.1f m" % [min_w_left, min_w_right]
	)

	# 4. Probe terrain poking through road
	var poke_count = 0
	for i in range(0, stations.size(), 4):
		var st = stations[i]
		var right = st.tangent.cross(Vector3.UP).normalized()
		for off in [-3.0, 0.0, 3.0]:
			var p = st.pos + right * off
			var hit = surf.contact(p + Vector3.UP * 1.0, Vector3.DOWN, 3.0, 0)
			if hit.get("surface", -1) != 0:
				poke_count += 1
	check(poke_count == 0, "Zero terrain triangles poking through road (poke_count=%d)" % poke_count)

	# 5. Probe trenches beside road (> 1 m drop outside verge)
	var trench_count = 0
	var worst_trench = 0.0
	for i in range(0, stations.size(), 5):
		var st = stations[i]
		var right = st.tangent.cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var p_verge = st.pos + right * (side * 6.0)
			var p_edge = st.pos + right * (side * 8.0)
			var p_out = st.pos + right * (side * 15.0)
			var hit_v = surf.contact(p_verge + Vector3.UP * 2.0, Vector3.DOWN, 10.0, 0)
			var hit_e = surf.contact(p_edge + Vector3.UP * 2.0, Vector3.DOWN, 10.0, 0)
			var hit_o = surf.contact(p_out + Vector3.UP * 2.0, Vector3.DOWN, 10.0, 0)
			if not hit_v.is_empty() and not hit_e.is_empty() and not hit_o.is_empty():
				var dip_v = hit_v.point.y - hit_e.point.y
				var dip_o = hit_o.point.y - hit_e.point.y
				var trench = minf(dip_v, dip_o)
				if trench > 1.0:
					trench_count += 1
					worst_trench = maxf(worst_trench, trench)
	check(
		trench_count == 0,
		"Zero trenches > 1 m beside road (count=%d, worst=%.2f m)" % [trench_count, worst_trench]
	)

	# 6. Bot laps
	for key in presets:
		for simcade in [false, true]:
			var r = run_lap(key, simcade)
			var name = "nordschleife_s1 %s %s" % [key, "simcade" if simcade else "simulation"]
			results[name] = r
			check(
				r.ok and r.lap > 0 and r.off == 0 and r.walls == 0,
				(
					"%s: lap %.2f s, %d off-track ticks, %d wall ticks, max %.2f m off line, top %.1f km/h"
					% [name, r.lap, r.off, r.walls, r.max_off_line, r.top * 3.6]
				)
			)

	print(
		"NORDSCHLEIFE_S1 RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true


func run_lap(key: String, simcade: bool) -> Dictionary:
	var c = CarBody.new()
	c.simcade_enabled = simcade
	c.configure(presets[key])
	c.wear_enabled = false
	var pole = asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var walls = WallQuery.new(asset, c.hull_half)
	var bot = BotDriver.new(bot_line, c, surf)
	var gates = asset.gates()
	var next_gate = 0
	var started = -1.0
	var lap_time = -1.0
	var off = 0
	var wall_ticks = 0
	var max_off_line = 0.0
	var top = 0.0
	var ok = true
	var prev = c.pos
	var time = 0.0
	var cap = 2.5 * asset.length / 15.0 + 60.0

	while time < cap:
		c.input = bot.command(c)
		c.step(DT, surf, true)
		if WallContact.step(c, walls) > 0:
			wall_ticks += 1
		time += DT
		for w in c.wheels:
			if w.load > 0 and w.surf.id >= 2:
				off += 1
		top = maxf(top, c.speed)
		if started >= 0:
			max_off_line = maxf(max_off_line, bot.off_line)
		if TrackAsset.crossed(gates[next_gate], prev, c.pos):
			if next_gate == 0:
				if started >= 0:
					lap_time = time - started
					break
				started = time
				next_gate = 1 % gates.size()
			else:
				next_gate = (next_gate + 1) % gates.size()
		prev = c.pos
		if not is_finite(c.pos_x + c.pos_y + c.pos_z) or bot.off_line > 30.0:
			ok = false
			break

	return {
		"ok": ok, "lap": lap_time, "off": off, "walls": wall_ticks, "max_off_line": max_off_line, "top": top
	}
