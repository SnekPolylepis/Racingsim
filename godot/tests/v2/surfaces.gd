extends SceneTree
## P2-02: TestSurface shapes and their ground truth (REBUILD-PLAN.md P2-02, section 6).
## Gating checks verify the surfaces themselves: normals against finite differences, ray hits on the
## surface at the first crossing (brute force), and each shape's defining quantity. PROBE lines drive
## the current CarBody over the new shapes and report numbers without gating: they are evidence for
## P2-03..P2-06, not acceptance of the chassis.
## Run: tools/Godot.exe --headless --path . --script tests/v2/surfaces.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const DT = 1.0 / 240
var presets
var failures = []
var checks = 0
var probes = {}
var rng = RandomNumberGenerator.new()


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func probe(key, value, what):
	probes[key] = value
	print("PROBE " + what)


func shapes():
	return {
		"flat": TestSurface.flat(),
		"ramp 8°": TestSurface.ramp(8.0),
		"side slope 37°": TestSurface.side_slope(37.0),
		"crest R200": TestSurface.crest(0.0, 200.0, 20.0, 40.0),
		"bowl 20°": TestSurface.bowl(100.0, 20.0),
		"ditch 37°": TestSurface.ditch(1.5, 37.0, 1.1, .5),
		"step 5 cm eased": TestSurface.step(0.0, .05, .04),
		"step 5 cm sharp": TestSurface.step(0.0, .05, 0.0),
	}


## Sample points spread over each shape's interesting region.
func sample_xz(name):
	match name:
		"bowl 20°":
			var a = rng.randf() * TAU
			var r = rng.randf_range(60, 140)
			return Vector2(cos(a) * r, sin(a) * r)
		"ditch 37°":
			return Vector2(rng.randf_range(-50, 50), rng.randf_range(-6, 6))
		"crest R200":
			return Vector2(rng.randf_range(-90, 90), rng.randf_range(-5, 5))
		"step 5 cm eased", "step 5 cm sharp":
			return Vector2(rng.randf_range(-1, 1), rng.randf_range(-5, 5))
	return Vector2(rng.randf_range(-100, 100), rng.randf_range(-100, 100))


## Normal must match the central-difference gradient of height() (skip a sharp step's face).
func normals(name, s):
	var worst = 0.0
	var eps = 1e-4
	for i in 400:
		var p = sample_xz(name)
		if name == "step 5 cm sharp" and absf(p.x) < 2 * eps:
			continue
		var gx = (s.height(p.x + eps, p.y) - s.height(p.x - eps, p.y)) / (2 * eps)
		var gz = (s.height(p.x, p.y + eps) - s.height(p.x, p.y - eps)) / (2 * eps)
		var fd = Vector3(-gx, 1, -gz).normalized()
		worst = maxf(worst, rad_to_deg(fd.angle_to(s.normal(p.x, p.y))))
	check(worst < .01, "%s: normal matches the height gradient within %.5f° (limit 0.01°)" % [name, worst])


## Rays from random points up to 1.5 m above the surface, tilted up to 40° from straight down,
## 3 m long. A hit must lie on the surface and be the first crossing; a miss must have no crossing.
## Brute force samples the ray every 2 mm, so it can itself miss a crossing narrower than that.
func rays(name, s):
	var off_surface = 0.0
	var wrong = 0
	var hits = 0
	for i in 300:
		var p = sample_xz(name)
		var origin = Vector3(p.x, s.height(p.x, p.y) + rng.randf_range(.02, 1.5), p.y)
		var tilt = deg_to_rad(rng.randf_range(0, 40))
		var az = rng.randf() * TAU
		var dir = Vector3(sin(tilt) * cos(az), -cos(tilt), sin(tilt) * sin(az))
		var hit = s.contact(origin, dir, 3.0)
		var first = -1.0
		for k in range(1, 1501):
			var q = origin + dir * (k * .002)
			if q.y - s.height(q.x, q.z) <= 0:
				first = k * .002
				break
		if hit.is_empty():
			if first >= 0:
				wrong += 1
			continue
		hits += 1
		var pt = hit.point
		off_surface = maxf(off_surface, absf(pt.y - s.height(pt.x, pt.z)))
		# The hit may sit on a sharp step's vertical face, where |height error| is up to the rise;
		# judge the face by distance along the ray instead.
		if first < 0 or hit.distance > first + 1e-9 or hit.distance < first - .002 - 1e-9:
			wrong += 1
	var face = name == "step 5 cm sharp"
	check(
		wrong == 0 and (face or off_surface < 1e-5),
		(
			"%s: %d/300 rays hit; all at the first crossing (%d wrong)%s"
			% [name, hits, wrong, "" if face else ", max height error %.9f m" % off_surface]
		)
	)


func truths():
	var r = TestSurface.ramp(8.0)
	check(
		absf(rad_to_deg(Vector3.UP.angle_to(r.normal(3, 4))) - 8) < 1e-3,
		"ramp: normal 8° from vertical (to 0.001°, float32 vector)"
	)
	var ss = TestSurface.side_slope(37.0)
	var n = ss.normal(0, 0)
	check(
		absf(rad_to_deg(Vector3.UP.angle_to(n)) - 37) < 1e-3 and n.z < 0 and absf(n.x) < 1e-12,
		"side slope: normal 37° from vertical (to 0.001°), tilted towards -z (surface climbs to +z)"
	)
	var c = TestSurface.crest(0.0, 200.0, 20.0, 40.0)
	var h = .5
	var k = (c.height(h, 0) - 2 * c.height(0, 0) + c.height(-h, 0)) / (h * h)
	check(
		absf(k * 200 + 1) < 1e-3 and absf(c.height(0, 0)) < 1e-12,
		"crest: apex curvature %.6f 1/m vs -1/200 = -0.005000" % k
	)
	var b = TestSurface.bowl(100.0, 20.0)
	check(
		(
			absf(rad_to_deg(Vector3.UP.angle_to(b.normal(70, 70))) - 20) < 1e-3
			and absf(b.height(100, 0)) < 1e-12
		),
		"bowl: bank 20° at any radius (to 0.001°), height 0 at R"
	)
	var d = TestSurface.ditch(1.5, 37.0, 1.1, .5)
	var mid_wall = 1.5 + .5 + .55
	var wall_deg = rad_to_deg(Vector3.UP.angle_to(d.normal(0, mid_wall)))
	var depth = -d.height(0, 0)
	check(
		(
			absf(wall_deg - 37) < 1e-3
			and absf(depth - d.ditch_depth()) < 1e-4
			and absf(d.height(0, 10)) < 1e-9
			and absf(d.height(7, 1.2) - d.height(-3, 1.2)) < 1e-12
			and absf(d.height(0, 2.2) - d.height(0, -2.2)) < 1e-12
		),
		(
			"ditch: wall %.6f° (37), depth %.4f m (analytic %.4f), road at 0, uniform along x, symmetric"
			% [wall_deg, depth, d.ditch_depth()]
		)
	)
	var st = TestSurface.step(0.0, .05, 0.0)
	var se = TestSurface.step(0.0, .05, .04)
	check(
		st.height(-1e-9, 0) == 0.0 and st.height(0, 0) == .05 and absf(se.height(.02, 0) - .025) < 1e-12,
		"step: sharp rise of exactly 5 cm at x = 0; eased step at half height mid-way"
	)


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
	return is_finite(c.pos.length()) and is_finite(c.vel.length()) and is_finite(c.ang.length())


## Coasting in neutral down a uniform grade with aero off. Ground truth including rolling resistance
## and wheel inertia: a = g (sin θ - rr cos θ) * m / (m + 4 I / R²).
func ramp_coast(key):
	var grade = -3.0
	var s = TestSurface.ramp(grade)
	var c = make(key)
	c.setup.cdA = 0.0
	c.setup.clAF = 0.0
	c.setup.clAR = 0.0
	c.place_on(s, 0.0, 0.0, 0.0)
	c.launch(10.0)
	c.gear = 0
	for i in 240:
		c.input = inp(0, 0, 0)
		c.step(DT, s, false)
	var v0 = c.speed
	for i in 240 * 5:
		c.input = inp(0, 0, 0)
		c.step(DT, s, false)
	var measured = (c.speed - v0) / 5.0
	var th = deg_to_rad(-grade)
	var rr = CarBody.SURF[0].rr
	var m = c.p.mass
	var want = 9.81 * (sin(th) - rr * cos(th)) * m / (m + 4 * c.p.wheelI / (c.p.wheelR * c.p.wheelR))
	check(
		finite(c) and absf(measured / want - 1) < .01,
		(
			"%s coasting in neutral down a 3° grade: %.4f m/s² vs analytic %.4f (%+.2f%%; rolling resistance and wheel inertia included)"
			% [key, measured, want, (measured / want - 1) * 100]
		)
	)


## Parked on a slope: a real tyre holds (static friction) whenever µ exceeds the slope's tangent.
## Reports creep speed; the current tyre model has no low-speed stiffness, so this is a probe.
func parked(key, s, label, brake):
	var c = make(key)
	c.place_on(s, 0.0, 0.0, 0.0)
	var start = Vector3.ZERO
	for i in 240 * 8:
		c.input = inp(0, brake, 0)
		c.step(DT, s, true)
		if i == 240 * 3:
			start = c.pos
	var creep = (c.pos - start).length() / 5.0
	var roll = rad_to_deg(Vector3.UP.angle_to(c.basis().y))
	probe(
		"%s %s creep_mm_s" % [key, label],
		creep * 1000,
		(
			"%s parked on %s (%s): creeps %.1f mm/s over 5 s after 3 s settling; body %.2f° from vertical"
			% [key, label, "brakes on" if brake > 0 else "no brakes", creep * 1000, roll]
		)
	)
	check(finite(c), "%s parked on %s stays finite" % [key, label])


## The Karussell line: ease from the ditch floor onto the middle of the 37° wall and hold it at
## 80 km/h. On the straight wall this is a side slope, so the ground truth is the body tilting ~37°
## with all four tyres loaded. A heading-based steering controller tracks the lateral target.
func ditch_drive(key):
	var s = TestSurface.ditch(1.5, 37.0, 1.1, .5)
	var mid_wall = s.ditch_floor + s.ditch_fillet + s.ditch_wall * .5
	var c = make(key)
	c.place_on(s, 0.0, 0.0, 0.0)
	c.launch(80 / 3.6)
	var min_contacts = 4
	var peak = 0.0
	var buried = 0
	var hold_tilt = 0.0
	var hold_err = 0.0
	var n = 0
	for i in 240 * 10:
		var t = i * DT
		var target_z = mid_wall * smoothstep(1.0, 5.0, t)
		var want_h = clampf((target_z - c.pos.z) * .12, -.12, .12)
		var st = clampf((want_h - c.h) * 4.0 - c.r * .2, -1, 1)
		var e = 80 / 3.6 - c.speed
		c.input = inp(clampf(e * .5 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(DT, s, true)
		min_contacts = mini(min_contacts, c.contacts)
		for k in 4:
			var w = c.wheels[k]
			peak = maxf(peak, w.load / (c.p.mass * 9.81 / 4))
			# A ray that starts inside the ground reports distance 0: full compression plus the radius.
			if w.load > 0 and w.comp >= c.free_length[k] + c.p.wheelR - c.static_comp[k] - 1e-6:
				buried += 1
		if t > 7:
			hold_tilt += rad_to_deg(Vector3.UP.angle_to(c.basis().y))
			hold_err = maxf(hold_err, absf(c.pos.z - mid_wall))
			n += 1
		if not finite(c):
			break
	check(finite(c), "%s driving onto the 37° ditch wall at 80 km/h stays finite" % key)
	probe(
		"%s ditch wall" % key,
		{
			"min_contacts": min_contacts,
			"peak_load_x_static": peak,
			"buried_wheel_ticks": buried,
			"hold_tilt_deg": hold_tilt / maxf(n, 1),
			"hold_lateral_error_m": hold_err
		},
		(
			"%s on the 37° ditch wall at 80 km/h: body %.1f° from vertical while holding, lateral error %.2f m, min contacts %d, peak tyre load %.1f x static, wheel-ticks with the ray starting inside the ground %d"
			% [key, hold_tilt / maxf(n, 1), hold_err, min_contacts, peak, buried]
		)
	)


## Straight over a 5 cm step at two speeds: finite; report the load spike and any airtime.
func step_hit(key, sharp):
	for kph in [50, 120]:
		var s = TestSurface.step(0.0, .05, 0.0 if sharp else .04)
		var c = make(key)
		c.place_on(s, -30.0, 0.0, 0.0)
		c.launch(kph / 3.6)
		var peak = 0.0
		var air = 0.0
		for i in 240 * 3:
			var e = kph / 3.6 - c.speed
			c.input = inp(clampf(e * .5 + .3, 0, 1), 0, 0)
			c.step(DT, s, true)
			for w in c.wheels:
				peak = maxf(peak, w.load / (c.p.mass * 9.81 / 4))
			if c.contacts == 0:
				air += DT
			if not finite(c):
				break
		var label = "sharp" if sharp else "eased"
		check(finite(c), "%s over a %s 5 cm step at %d km/h stays finite" % [key, label, kph])
		probe(
			"%s step %s %d" % [key, label, kph],
			{"peak_load_x_static": peak, "airtime_s": air},
			(
				"%s %s 5 cm step at %d km/h: peak tyre load %.1f x static, airborne %.3f s"
				% [key, label, kph, peak, air]
			)
		)


## Godot's Vector3 is 32-bit in standard builds. car.gd kept plan position in 64-bit floats; CarBody
## stores pos in a Vector3. Drift a car sideways at 1 cm/s in free fall for 1 s, near the origin and
## 5 km out (Nordschleife scale): 64-bit state would move 0.0100 m in both places.
func precision():
	var s = TestSurface.void_space()
	var moved = []
	for x0 in [0.0, 5000.0]:
		var c = make("f296gt3")
		c.setup.cdA = 0.0
		c.place(Vector3(x0, 1000, 0), 0.0, 1000.0)
		c.vel = Vector3(.01, 0, 0)
		var start = c.pos_x
		for i in 240:
			c.input = inp(0, 0, 0)
			c.step(DT, s, true)
		moved.append(c.pos_x - start)
	probe(
		"position_precision",
		{"moved_at_0m": moved[0], "moved_at_5km": moved[1]},
		(
			"1 cm/s for 1 s moves the car %.6f m at x = 0 and %.6f m at x = 5 km (expect 0.010000; read from the 64-bit state since P2-03)"
			% [moved[0], moved[1]]
		)
	)


func _initialize():
	rng.seed = 20260922
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var all = shapes()
	for name in all:
		normals(name, all[name])
		rays(name, all[name])
	truths()
	for key in presets:
		ramp_coast(key)
	for key in ["roadster", "f296gt3"]:
		parked(key, TestSurface.ramp(8.0), "an 8° ramp", 1.0)
		parked(key, TestSurface.side_slope(37.0), "a 37° side slope", 1.0)
	ditch_drive("f296gt3")
	step_hit("f296gt3", true)
	step_hit("f296gt3", false)
	precision()
	print("SURFACES RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "probes": probes}))
	quit(0 if failures.is_empty() else 1)
