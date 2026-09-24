extends SceneTree
## P4-02: lap timing on a TrackAsset (scripts/race.gd update_asset) against the proving ground's 3D gates.
##   exact       a scripted car moving along the lap line at a constant speed: lap and sector times equal
##               distance / speed to within a tick, the lap is valid, the first lap is a new best
##   ghost       5.4 samples at ~30 Hz (9 numbers each); an identical second lap has ~zero delta and the
##               ghost pose sits on the car; a slower third lap's delta grows to the expected loss
##   cut         passing a checkpoint gate more than 15 m off the line (outside the gate) invalidates the lap
##   off track   car.all_off during the lap invalidates it
##   backwards   crossing the start line in reverse starts no lap
##   reset       a reset mid-lap ends the attempt; the next crossing starts a fresh lap
##   files       storage.validate_ghost accepts a schema-2 document of these samples, rejects 6-field ones
##   real lap    the bot on CarBody: race.gd's lap equals the laps gate's timing (tests/v2/laps.gd method)
## Run: tools/Godot.exe --headless --path . --script tests/v2/race.gd
const RaceModel = preload("res://scripts/race.gd")
const Storage = preload("res://scripts/storage.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const DT = 1.0 / 240
var asset
var failures = []
var checks = 0
var results = {}
var frames = 0
var ran = false


## The fields race.gd reads from a car.
class FakeCar:
	extends RefCounted
	var pos = Vector3.ZERO
	var rot = Quaternion.IDENTITY
	var all_off = false
	var collided = false


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize():
	asset = load("res://trackgen/proving_ground.gd").build_asset()
	asset.prepare()
	root.add_child(asset)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("RACE RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	scripted()
	real_lap()
	print("RACE RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


## Pose the fake car at absolute station s, `lateral` metres right of the lap line, facing along it.
func pose(car, s, lateral = 0.0, backwards = false):
	var st = asset.station(s)
	var right = st.tangent.cross(Vector3.UP).normalized()
	car.pos = st.pos + right * lateral + Vector3.UP * .4
	var fwd = -st.tangent if backwards else st.tangent
	car.rot = Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)).orthonormalized().get_rotation_quaternion()


## Drive the fake car from lap distance `from` for `metres` at `speed`; `hook(car, d)` may alter each tick
## (d = lap distance). Returns the ticks driven.
func drive(race, car, from, metres, speed, hook = Callable()):
	var start = asset.start_offset()
	var travelled = 0.0
	var ticks = 0
	while travelled < metres:
		travelled += speed * DT
		var d = fposmod(from + travelled, asset.length)
		pose(car, start + d)
		car.all_off = false
		if hook.is_valid():
			hook.call(car, d)
		race.update_asset(car, asset, DT)
		ticks += 1
	return ticks


func scripted():
	var length = asset.length
	var v = 30.0
	var tol = 1.5 * DT
	var sector_at = asset.sector_offsets()
	# Exact timing: from 20 m before the line, one lap and a bit.
	var race = RaceModel.new()
	var car = FakeCar.new()
	drive(race, car, length - 20.0, 20.0 + length + 5.0, v)
	var want = length / v
	var s_want = [sector_at[0] / v, (sector_at[1] - sector_at[0]) / v, (length - sector_at[1]) / v]
	var s_err = 0.0
	for i in 3:
		s_err = maxf(s_err, absf(race.last_sectors[i] - s_want[i]))
	results["exact"] = {"lap": race.last, "want": want, "sector_err_s": s_err}
	check(
		race.completed == 1 and race.last_valid and absf(race.last - want) < tol and s_err < tol,
		(
			"scripted lap at 30 m/s: %.4f s for %.4f s (%.1f m), valid %s; sectors within %.4f s of distance / speed"
			% [race.last, want, length, race.last_valid, s_err]
		)
	)
	check(
		race.best == race.last and race.ghost == race.last_recording and race.best_sectors.min() > 0,
		(
			"first valid lap is the best: best %.4f s, ghost %d samples, best sectors set"
			% [race.best, race.ghost.size()]
		)
	)
	# Ghost format and a second, identical lap.
	var widths_ok = true
	for sample in race.ghost:
		widths_ok = widths_ok and sample.size() == 9
	var rate = race.ghost.size() / race.best
	var worst_delta = 0.0
	var worst_pose = 0.0
	var probe = func(c, d):
		if d > 50.0 and d < length - 50.0 and race.delta != null:
			worst_delta = maxf(worst_delta, absf(race.delta))
			var x = race.ghost_xform()
			if x != null:
				worst_pose = maxf(worst_pose, x.origin.distance_to(c.pos))
	drive(race, car, 5.0, length, v, probe)
	results["ghost"] = {"rate_hz": rate, "worst_delta_s": worst_delta, "worst_pose_m": worst_pose}
	check(
		widths_ok and rate > 28.0 and rate < 32.0 and worst_delta < .05 and worst_pose < .5,
		(
			"ghost: %d samples of 9 numbers (%.1f Hz); identical second lap delta within %.3f s, ghost pose within %.2f m of the car"
			% [race.ghost.size(), rate, worst_delta, worst_pose]
		)
	)
	# A slower third lap: delta at the line is the time lost.
	var final_delta = [0.0]
	var track_delta = func(c, d):
		if race.delta != null and d < length - 1.0:
			final_delta[0] = race.delta
	# Lap 2 ended 5 m past the line (the lap began there at speed v); carry on from there.
	drive(race, car, 5.0, length - 5.0, v * .9, track_delta)
	var lost = (length - 5.0) / (v * .9) - (length - 5.0) / v
	check(
		absf(final_delta[0] - lost) < .1 and race.best < race.last,
		(
			"10 %% slower lap: delta near the line %+.2f s (expected %+.2f s); best kept %.3f s"
			% [final_delta[0], lost, race.best]
		)
	)
	# Cut: 20 m off the line through the first checkpoint gate.
	var gates = asset.gates()
	var cp = -1
	for k in gates.size():
		if gates[k].kind == "checkpoint":
			cp = k
			break
	var cut_at = gates[cp].offset
	var cutter = func(c, d):
		if absf(d - cut_at) < 8.0:
			pose(c, asset.start_offset() + d, 20.0)
	race = RaceModel.new()
	drive(race, car, length - 20.0, 20.0 + length + 5.0, v, cutter)
	check(
		race.completed == 1 and not race.last_valid and race.last_reason.begins_with("missed checkpoint"),
		"passing checkpoint %d (%.0f m) 20 m off the line: lap invalid (%s)" % [cp, cut_at, race.last_reason]
	)
	# Off track for half a second mid-lap.
	var offer = func(c, d):
		if d > 300.0 and d < 315.0:
			c.all_off = true
	race = RaceModel.new()
	drive(race, car, length - 20.0, 20.0 + length + 5.0, v, offer)
	check(
		race.completed == 1 and not race.last_valid and race.last_reason == "off track",
		"all four wheels off for 15 m: lap invalid (%s)" % race.last_reason
	)
	# Backwards across the line: no lap starts.
	race = RaceModel.new()
	var start = asset.start_offset()
	for i in 240:
		pose(car, start + 10.0 - i * .1, 0.0, true)
		race.update_asset(car, asset, DT)
	check(not race.active and race.completed == 0, "reversing across the start line starts no lap")
	# Reset mid-lap: the attempt ends; the next crossing starts a fresh lap.
	race = RaceModel.new()
	drive(race, car, length - 20.0, 20.0 + 400.0, v)
	race.reset()
	var was_active = race.active
	drive(race, car, 400.0, length - 400.0 + 5.0, v)
	check(
		not was_active and race.active and race.completed == 0 and race.lap_time < .3,
		(
			"reset mid-lap ends the attempt: no lap completed, a fresh lap timing %.3f s after the line"
			% race.lap_time
		)
	)
	# Ghost documents.
	race = RaceModel.new()
	drive(race, car, length - 20.0, 20.0 + length + 5.0, v)
	var storage = Storage.new()
	var good = {"schema": 2, "time": race.best, "samples": race.ghost}
	var legacy_width = []
	for sample in race.ghost:
		legacy_width.append(sample.slice(0, 6))
	var bad = {"schema": 2, "time": race.best, "samples": legacy_width}
	var e_good = storage.validate_ghost(good)
	var e_bad = storage.validate_ghost(bad)
	check(
		e_good.is_empty() and not e_bad.is_empty(),
		(
			"schema-2 ghost document validates (%s); 6-number samples are rejected (%s)"
			% [e_good if e_good else "ok", e_bad]
		)
	)


## The bot's lap timed by race.gd equals the laps gate's own timing (first line crossing to the next).
func real_lap():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets["f296gt3"])
	c.wear_enabled = false
	var pole = asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var surf = asset.surface()
	var bot = BotDriver.new(asset.get_node("BotLine"), c, surf)
	var race = RaceModel.new()
	var start_gate = asset.gates()[0]
	var prev = c.pos
	var time = 0.0
	var started = -1.0
	var gate_lap = -1.0
	while time < 200.0 and race.completed == 0:
		c.input = bot.command(c)
		c.step(DT, surf, true)
		time += DT
		race.update_asset(c, asset, DT)
		if TrackAsset.crossed(start_gate, prev, c.pos):
			if started >= 0 and gate_lap < 0:
				gate_lap = time - started
			elif started < 0:
				started = time
		prev = c.pos
	results["real_lap"] = {"race": race.last, "gates": gate_lap}
	check(
		race.completed == 1 and race.last_valid and absf(race.last - gate_lap) < 1e-6,
		(
			"f296gt3 bot lap on CarBody: race.gd %.3f s, valid %s, sectors %.2f / %.2f / %.2f s; laps-gate timing %.3f s"
			% [
				race.last,
				race.last_valid,
				race.last_sectors[0],
				race.last_sectors[1],
				race.last_sectors[2],
				gate_lap
			]
		)
	)
