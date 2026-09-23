extends SceneTree
## P2-05 flat equivalence (REBUILD-PLAN.md section 6): the 6-DOF CarBody on TestSurface.flat against the
## planar CarModel on a flat TrackModel, same controllers and procedures (copied from tests/dynamics.gd and
## the P2-00 spike), per car and per handling model:
##   tyre peaks     peak slip angle and ratio: exactly equal (shared tyre module)
##   0-100, 100-0   full throttle from rest, then full brake to 0.3 m/s
##   skidpad        steady-state limit on a 150 m circle (the baseline's radius; the plan's "60 m" is not
##                  what tests/dynamics.gd or the baseline measure)
##   top speed      full throttle until the speed gains under 0.02 m/s over 2 s (at most 120 s)
## Gate: within +/-3 % of CarModel measured live. CarModel is unchanged since the pre-rebuild baseline;
## the live Simulation figures are cross-checked against docs/rebuild/baseline.json to prove it.
## Both handling models gate. Simcade's aids and transient handling (ASM, recovery) are P2-07's; these
## straight-line and steady-state figures already match, and P2-07 must keep them matching.
## Run: tools/Godot.exe --headless --path . --script tests/v2/flat_equivalence.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const CarModel = preload("res://scripts/car.gd")
const TrackModel = preload("res://scripts/track3d.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const DT = 1.0 / 240
var presets
var baseline
var failures = []
var checks = 0
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func inp(th, br, st):
	return {"throttle": th, "brake": br, "steer": st, "clutch": 0.0, "handbrake": 0.0}


func prepare(c, key, simcade):
	c.simcade_enabled = simcade
	c.configure(presets[key])
	c.wear_enabled = false
	c.steer_falloff = 0.0
	for w in c.wheels:
		w.temp = c.setup.tempOpt
		w.core = c.setup.tempOpt
	return c


# --- Legacy CarModel on flat TrackModels (tests/dynamics.gd procedures) ---


func straight(half):
	var t = TrackModel.new()
	var pts = []
	for x in range(-half, half + 1, 500):
		pts.append({"x": x, "y": 0, "w": 30})
	for x in range(half, -half - 1, -500):
		pts.append({"x": x, "y": 800, "w": 30})
	t.load_data({"name": "s", "points": pts, "startS": 0.0, "curbAuto": false})
	return t


func circle(r):
	var t = TrackModel.new()
	var pts = []
	for i in 32:
		pts.append({"x": cos(TAU * i / 32) * r, "y": sin(TAU * i / 32) * r, "w": 30})
	t.load_data({"name": "c", "points": pts, "startS": 0.0, "curbAuto": false})
	return t


func legacy(key, simcade):
	var out = {}
	var t = straight(3000)
	var c = prepare(CarModel.new(), key, simcade)
	out.peak_angle = c.peak_slip_angle()
	out.peak_ratio = c.peak_slip_ratio()
	c.reset_pose({"x": -2000.0, "y": 0.0, "h": 0.0})
	var time = 0.0
	while c.speed < 100 / 3.6 and time < 30:
		c.input = inp(1, 0, 0)
		c.step(DT, t, true)
		time += DT
	out.accel = time
	var x0 = c.x
	var stop = 0.0
	while c.speed > .3 and stop < 20:
		c.input = inp(0, 1, 0)
		c.step(DT, t, true)
		stop += DT
	out.brake = c.x - x0
	var r = 150.0
	var ring = circle(r)
	c = prepare(CarModel.new(), key, simcade)
	var p = ring.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var target = 8.0
	var best = 0.0
	time = 0.0
	while time < 150:
		var pr = ring.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = ring.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = target - c.speed
		c.input = inp(clampf(e * .6 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(DT, ring, true)
		time += DT
		if absf(pr.lat) < 2.0 and absf(e) < .6:
			best = maxf(best, c.speed)
		if absf(pr.lat) > 4:
			break
		target += .6 / 240
	out.skidpad = best * best / r / 9.81
	var long = straight(12000)
	c = prepare(CarModel.new(), key, simcade)
	c.reset_pose({"x": -11500.0, "y": 0.0, "h": 0.0})
	out.top = top_speed(c, func(): c.step(DT, long, true))
	return out


# --- CarBody on TestSurface.flat (P2-00 spike procedures) ---


func body(key, simcade):
	var out = {}
	var surf = TestSurface.flat()
	var c = prepare(CarBody.new(), key, simcade)
	out.peak_angle = c.peak_slip_angle()
	out.peak_ratio = c.peak_slip_ratio()
	c.place(Vector3(-2000, 0, 0), 0.0, 0.0)
	var time = 0.0
	while c.speed < 100 / 3.6 and time < 30:
		c.input = inp(1, 0, 0)
		c.step(DT, surf, true)
		time += DT
	out.accel = time
	var x0 = c.pos_x
	var stop = 0.0
	while c.speed > .3 and stop < 20:
		c.input = inp(0, 1, 0)
		c.step(DT, surf, true)
		stop += DT
	out.brake = c.pos_x - x0
	var r = 150.0
	c = prepare(CarBody.new(), key, simcade)
	c.place(Vector3(r, 0, 0), PI / 2, 0.0)
	var target = 8.0
	var best = 0.0
	time = 0.0
	while time < 150:
		var phi = atan2(c.pos_z, c.pos_x)
		var lat = Vector2(c.pos_x, c.pos_z).length() - r
		var ahead_phi = phi + (6 + c.speed * .35) / r
		var ahead = Vector2(cos(ahead_phi), sin(ahead_phi)) * r
		var st = clampf(wrapf(atan2(ahead.y - c.pos_z, ahead.x - c.pos_x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = target - c.speed
		c.input = inp(clampf(e * .6 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(DT, surf, true)
		time += DT
		if absf(lat) < 2.0 and absf(e) < .6:
			best = maxf(best, c.speed)
		if absf(lat) > 4:
			break
		target += .6 / 240
	out.skidpad = best * best / r / 9.81
	c = prepare(CarBody.new(), key, simcade)
	c.place(Vector3(-4000, 0, 0), 0.0, 0.0)
	out.top = top_speed(c, func(): c.step(DT, surf, true))
	return out


## Full throttle from rest until the speed gains less than 0.02 m/s over 2 s, at most 120 s.
func top_speed(c, step):
	var window = []
	for i in 240 * 120:
		c.input = inp(1, 0, 0)
		step.call()
		window.append(c.speed)
		if window.size() > 480:
			window.pop_front()
			if window[-1] - window[0] < .02:
				break
	return c.speed


## Last number of the baseline check whose text starts with `prefix`, in `suite`.
func base(suite, prefix):
	for c in baseline.suites[suite].checks:
		if c.text.begins_with(prefix):
			return c.values
	return []


func _initialize():
	# `-- --car key` runs one car, so tools/run_gates.ps1 can run the three in parallel.
	presets = GatesEnv.only_car(JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json")))
	baseline = JSON.parse_string(FileAccess.get_file_as_string("res://docs/rebuild/baseline.json"))
	var names = {"accel": "0-100 s", "brake": "100-0 m", "skidpad": "skidpad g", "top": "top speed m/s"}
	for simcade in [false, true]:
		var model = "simcade" if simcade else "simulation"
		for key in presets:
			var old = legacy(key, simcade)
			var new = body(key, simcade)
			results["%s %s" % [model, key]] = {"carmodel": old, "carbody": new}
			var peaks_exact = old.peak_angle == new.peak_angle and old.peak_ratio == new.peak_ratio
			var worst = 0.0
			var parts = []
			for k in ["accel", "brake", "skidpad", "top"]:
				var ratio = new[k] / old[k] - 1
				worst = maxf(worst, absf(ratio))
				parts.append("%s %.3f vs %.3f (%+.2f%%)" % [names[k], new[k], old[k], ratio * 100])
			var line = (
				"%s %s: tyre peaks %s; %s"
				% [model, key, "exact" if peaks_exact else "DIFFER", ", ".join(parts)]
			)
			check(peaks_exact and worst <= .03, line)
		if not simcade:
			# The live CarModel is the baseline model: its Simulation figures match the recorded ones.
			var off = []
			for key in presets:
				var old = results["simulation %s" % key].carmodel
				var b_acc = base("dynamics-simulation", "%s 0-100" % key)[-1]
				var b_brk = base("dynamics-simulation", "%s 100-0" % key)[-1]
				var b_lat = base("dynamics-simulation", "%s holds" % key)[-2]
				if (
					absf(old.accel - b_acc) > .006
					or absf(old.brake - b_brk) > .06
					or absf(old.skidpad - b_lat) > .006
				):
					off.append(key)
			check(
				off.is_empty(),
				(
					"live CarModel Simulation 0-100 / 100-0 / skidpad match docs/rebuild/baseline.json to its printed precision %s"
					% [off]
				)
			)
	print(
		"FLAT EQUIVALENCE RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
