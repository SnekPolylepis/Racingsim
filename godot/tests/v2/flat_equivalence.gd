extends SceneTree
## P2-05 flat equivalence (REBUILD-PLAN.md section 6): the 6-DOF CarBody on TestSurface.flat against the
## planar CarModel's figures on flat roads, per car and per handling model. CarModel (scripts/car.gd) was
## deleted in P7-01b; its figures, measured with the same controllers and procedures, are recorded in
## docs/rebuild/carmodel-reference.json:
##   tyre peaks     peak slip angle and ratio: exactly equal (shared tyre module)
##   0-100, 100-0   full throttle from rest, then full brake to 0.3 m/s
##   skidpad        steady-state limit on a 150 m circle (the baseline's radius; the plan's "60 m" is not
##                  what the pre-rebuild baseline measured)
##   top speed      full throttle until the speed gains under 0.02 m/s over 2 s (at most 120 s)
## Gate: within +/-3 % of CarModel, on CarBody's massless wheel (compliance off): the 6-DOF chassis
## reproduces the planar model. Tyre compliance and unsprung mass (P2-comp) are a deliberate departure
## (series tyre rate, softer transient load transfer), gated separately within +/-5 %.
## Both handling models gate. Simcade's aids and transient handling (ASM, recovery) are P2-07's; these
## straight-line and steady-state figures already match, and P2-07 must keep them matching.
## Run: tools/Godot.exe --headless --path . --script tests/v2/flat_equivalence.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const DT = 1.0 / 240
const REFERENCE = "res://docs/rebuild/carmodel-reference.json"
var presets
var reference
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


## CarBody on TestSurface.flat (P2-00 spike procedures).
func body(key, simcade, compliant = false):
	var out = {}
	var surf = TestSurface.flat()
	var c = prepare(CarBody.new(), key, simcade)
	c.compliance = compliant
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


func _initialize():
	# `-- --car key` runs one car, so tools/run_gates.ps1 can run the three in parallel.
	presets = GatesEnv.only_car(JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json")))
	reference = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE)).figures
	var names = {"accel": "0-100 s", "brake": "100-0 m", "skidpad": "skidpad g", "top": "top speed m/s"}
	for simcade in [false, true]:
		var model = "simcade" if simcade else "simulation"
		for key in presets:
			var old = reference["%s %s" % [model, key]]
			var new = body(key, simcade)
			var soft = body(key, simcade, true)
			results["%s %s" % [model, key]] = {"carmodel": old, "carbody": new, "carbody_compliant": soft}
			var peaks_exact = (
				absf(old.peak_angle - new.peak_angle) < 1e-12
				and absf(old.peak_ratio - new.peak_ratio) < 1e-12
			)
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
			var worst_soft = 0.0
			var soft_parts = []
			for k in ["accel", "brake", "skidpad", "top"]:
				var ratio = soft[k] / old[k] - 1
				worst_soft = maxf(worst_soft, absf(ratio))
				soft_parts.append("%s %+.2f%%" % [names[k], ratio * 100])
			check(
				worst_soft <= .05,
				"%s %s with compliance, vs CarModel (within 5 %%): %s" % [model, key, ", ".join(soft_parts)]
			)
	print(
		"FLAT EQUIVALENCE RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
