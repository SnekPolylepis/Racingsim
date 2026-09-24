extends SceneTree
## P2-04: static friction and the 3D need clamps (REBUILD-PLAN.md P2-04).
##   hold      braked cars parked on grades and side slopes up to 37 degrees do not creep (P2-02 measured
##             6-8 mm/s on 8 degrees and 26-35 mm/s across 37 degrees before static friction).
##   limit     static friction is still friction: on grass (grip 0.55) a braked car holds a 20 degree grade
##             and slides down a 40 degree one (tan 40 = 0.84 > roadster tyre mu 1.15 x 0.55 = 0.63).
##   rolling   an unbraked car in neutral still rolls down a grade at the analytic rate (static friction
##             only holds the wheel in its own rolling direction when the brake holds the wheel).
##   release   brakes released on an 8 degree grade: the car rolls away; brakes applied again at walking
##             pace: it stops and holds.
##   flat      on level ground the hold force is exactly zero: a braked car at rest stays put, no jitter.
## Run: tools/Godot.exe --headless --path . --script tests/v2/static_friction.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const DT = 1.0 / 240
var presets
var failures = []
var checks = 0
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func make(key):
	var c = CarBody.new()
	c.configure(presets[key])
	c.wear_enabled = false
	c.steer_falloff = 0.0
	for w in c.wheels:
		w.temp = c.setup.tempOpt
		w.core = c.setup.tempOpt
	return c


func inp(th, br, st):
	return {"throttle": th, "brake": br, "steer": st, "clutch": 0.0, "handbrake": 0.0}


func finite(c):
	return is_finite(c.pos_x + c.pos_y + c.pos_z) and is_finite(c.vel.length()) and is_finite(c.ang.length())


## Parked with the brakes on: creep speed over 5 s after 3 s settling, m/s.
func creep(key, s):
	var c = make(key)
	c.place_on(s, 0.0, 0.0, 0.0)
	var start = Vector3.ZERO
	for i in 240 * 8:
		c.input = inp(0, 1, 0)
		c.step(DT, s, true)
		if i == 240 * 3:
			start = c.pos
	return [(c.pos - start).length() / 5.0, finite(c), c]


func hold():
	var worst = 0.0
	var rows = []
	var ok = true
	for key in ["roadster", "f296gt3"]:
		for spec in [
			["8° grade", TestSurface.ramp(8.0)],
			["20° grade", TestSurface.ramp(20.0)],
			["30° grade", TestSurface.ramp(30.0)],
			["20° side slope", TestSurface.side_slope(20.0)],
			["37° side slope", TestSurface.side_slope(37.0)]
		]:
			var r = creep(key, spec[1])
			ok = ok and r[1]
			worst = maxf(worst, r[0])
			rows.append("%s %s %.4f mm/s" % [key, spec[0], r[0] * 1000])
			results["creep_mm_s %s %s" % [key, spec[0]]] = r[0] * 1000
	for row in rows:
		print("      " + row)
	check(
		ok and worst < 1e-4,
		(
			"braked roadster and 296 parked on 8/20/30° grades and 20/37° side slopes: worst creep %.4f mm/s (limit 0.1; was 6-35 mm/s)"
			% (worst * 1000)
		)
	)


## On grass the tyre's friction limit is roadster mu 1.15 x grip 0.55 = 0.63, tan 32°.
func limit():
	var held = creep("roadster", grass(TestSurface.ramp(20.0)))
	var slid = make("roadster")
	var s = grass(TestSurface.ramp(40.0))
	slid.place_on(s, 0.0, 0.0, 0.0)
	for i in 240 * 3:
		slid.input = inp(0, 1, 0)
		slid.step(DT, s, true)
	results["grass 20° creep_mm_s"] = held[0] * 1000
	results["grass 40° speed_after_3s"] = slid.speed
	check(
		held[1] and held[0] < 1e-4 and finite(slid) and slid.speed > 2.0,
		(
			"on grass a braked roadster holds a 20° grade (creep %.4f mm/s) and slides down a 40° one (%.2f m/s after 3 s): static friction stops at the friction limit"
			% [held[0] * 1000, slid.speed]
		)
	)


func grass(s):
	s.surface_id = 2
	return s


## Unbraked, in neutral, from rest down an 8° grade, aero off: a = g (sin θ - rr cos θ) m / (m + 4 I / R²).
func rolling():
	for key in ["roadster", "f296gt3"]:
		var s = TestSurface.ramp(-8.0)
		var c = make(key)
		c.setup.cdA = 0.0
		c.setup.clAF = 0.0
		c.setup.clAR = 0.0
		c.place_on(s, 0.0, 0.0, 0.0)
		c.gear = 0
		for i in 240 * 3:
			c.input = inp(0, 0, 0)
			c.step(DT, s, false)
		var th = deg_to_rad(8.0)
		var rr = CarBody.SURF[0].rr
		var m = c.p.mass
		var a = 9.81 * (sin(th) - rr * cos(th)) * m / (m + 4 * c.p.wheelI / (c.p.wheelR * c.p.wheelR))
		var want = a * 3.0
		results["rolling %s" % key] = {"speed": c.speed, "want": want}
		check(
			finite(c) and absf(c.speed / want - 1) < .03,
			(
				"%s unbraked in neutral rolls from rest down an 8° grade: %.3f m/s after 3 s vs analytic %.3f (%+.1f%%)"
				% [key, c.speed, want, (c.speed / want - 1) * 100]
			)
		)


## Hold, release, roll away, brake to a stop, hold again.
func release():
	var s = TestSurface.ramp(-8.0)
	var c = make("f296gt3")
	c.place_on(s, 0.0, 0.0, 0.0)
	c.gear = 0
	for i in 240 * 2:
		c.input = inp(0, 1, 0)
		c.step(DT, s, false)
	var held = c.speed
	for i in 240 * 2:
		c.input = inp(0, 0, 0)
		c.step(DT, s, false)
	var rolled = c.speed
	var stopped_at = -1.0
	for i in 240 * 4:
		c.input = inp(0, .6, 0)
		c.step(DT, s, false)
		if stopped_at < 0 and c.speed < .01:
			stopped_at = i * DT
	var start = c.pos
	for i in 240 * 3:
		c.input = inp(0, .6, 0)
		c.step(DT, s, false)
	var after = (c.pos - start).length() / 3.0
	results["release"] = {"held": held, "rolled": rolled, "stopped_at": stopped_at, "creep_after": after}
	check(
		finite(c) and held < 1e-4 and rolled > 1.5 and stopped_at > 0 and after < 1e-4,
		(
			"296 on an 8° grade: held at %.5f m/s, rolls away at %.2f m/s after 2 s without brakes, stops %.2f s after 60 %% brake, then creeps %.4f mm/s"
			% [held, rolled, stopped_at, after * 1000]
		)
	)


func flat():
	var s = TestSurface.flat()
	var worst = 0.0
	for key in ["roadster", "f296gt3"]:
		var c = make(key)
		c.place(Vector3.ZERO, 0.0, 0.0)
		for i in 240 * 4:
			c.input = inp(0, 1, 0)
			c.step(DT, s, true)
			if i > 240:
				worst = maxf(worst, c.speed + c.ang.length())
	check(
		worst < 1e-6,
		"braked cars at rest on level ground: speed + spin stays below %.3f µm/s (limit 1)" % (worst * 1e6)
	)


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	hold()
	limit()
	rolling()
	release()
	flat()
	print(
		"STATIC FRICTION RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
