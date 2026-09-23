extends SceneTree
## P2-05 gates (REBUILD-PLAN.md section 6) not already covered by the P2-00 spike (which gates
## determinism, bowl, crest, flight and landing):
##   energy   flat, no aero, free-rolling coast in neutral for 10 s from 30 m/s: total kinetic energy
##            (body translation and rotation, wheel spin) plus the rolling-resistance work within 0.5 % of
##            the start (the plan asks for no rolling resistance; the surface table is read-only, so its
##            work is accounted instead, which is the stricter test: nothing else may dissipate).
##   wall     a 37 degree concrete side slope at 150 km/h, steered to hold a line along it for 5 s: all
##            four tyres down, no body contact, never below the surface, holds its line; the body rolls
##            relative to the surface by the car's own roll gradient times the tyres' lateral share
##            (g sin 37 = 0.60 g), the only thing that should roll it off the surface normal.
## Run: tools/Godot.exe --headless --path . --script tests/v2/energy_wall.gd
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


func kinetic(c):
	var e = .5 * c.p.mass * c.vel.length_squared() + .5 * c.ang.dot(c.inertia * c.ang)
	for w in c.wheels:
		e += .5 * c.p.wheelI * w.omega * w.omega
	return e


## The surface table is read-only, so rolling resistance stays on and its work is accounted instead:
## rr x wheel load x contact speed per tick (tarmac has no surface drag). The rest must be conserved.
func energy():
	var rr = CarBody.TrackModel.SURF[0].rr
	var worst = 0.0
	var rows = []
	for key in presets:
		var c = make(key)
		c.setup.cdA = 0.0
		c.setup.clAF = 0.0
		c.setup.clAR = 0.0
		c.place(Vector3.ZERO, 0.0, 0.0)
		c.launch(30.0)
		c.gear = 0
		var flat = TestSurface.flat()
		for i in 240:
			c.input = inp(0, 0, 0)
			c.step(DT, flat, false)
		var e0 = kinetic(c)
		var dissipated = 0.0
		for i in 240 * 10:
			c.input = inp(0, 0, 0)
			c.step(DT, flat, false)
			for w in c.wheels:
				dissipated += rr * w.load * c.speed * DT
		var change = (kinetic(c) + dissipated) / e0 - 1
		worst = maxf(worst, absf(change))
		rows.append(
			"%s %+.5f%% (rolling resistance took %.1f%%)" % [key, change * 100, dissipated / e0 * 100]
		)
		results["energy %s" % key] = {"unaccounted": change, "rolling_resistance": dissipated / e0}
	check(
		worst < .005,
		(
			"free-rolling coast in neutral, 10 s from 30 m/s, no aero: kinetic energy + rolling-resistance work changes %s (limit 0.5 %%)"
			% ", ".join(rows)
		)
	)


## Roll of the body about its forward axis relative to the ground, degrees, on the flat 150 m skidpad
## at the limit (the spike's procedure), per g of lateral acceleration.
func roll_gradient(key):
	var surf = TestSurface.flat()
	var c = make(key)
	var r = 150.0
	c.place(Vector3(r, 0, 0), PI / 2, 0.0)
	var target = 8.0
	var best = [0.0, 0.0]
	var time = 0.0
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
		if absf(lat) < 2.0 and absf(e) < .6 and c.speed > best[0]:
			best = [c.speed, absf(rad_to_deg(asin(clampf(c.basis().z.y, -1, 1))))]
		if absf(lat) > 4:
			break
		target += .6 / 240
	return best[1] / (best[0] * best[0] / r / 9.81)


func wall():
	var angle = 37.0
	var surf = TestSurface.side_slope(angle)
	var n = surf.normal(0, 0)
	for key in presets:
		var c = make(key)
		c.place_on(surf, 0.0, 0.0, 0.0)
		c.launch(150 / 3.6)
		var line = 0.0
		var drift = 0.0
		var min_contacts = 4
		var body = 0
		var sunk = 0
		var rel = []
		for i in 240 * 5:
			# Aim 25 m ahead on the line z = 0; steer > 0 turns right, up the slope (+z).
			var want = atan2(line - c.pos_z, 25.0)
			var e = 150 / 3.6 - c.speed
			c.input = inp(clampf(e * .5 + .3, 0, 1), clampf(-e * .3, 0, 1), clampf((want - c.h) * 2.5, -1, 1))
			c.step(DT, surf, true)
			min_contacts = mini(min_contacts, c.contacts)
			body += c.body_contacts
			if c.pos_y < surf.height(c.pos_x, c.pos_z):
				sunk += 1
			if i >= 240:
				drift = maxf(drift, absf(c.pos_z - line))
				# Body roll off the surface normal, about the forward axis; positive = rolled downhill.
				var up = c.basis().y
				var fwd = c.basis().x
				rel.append(rad_to_deg(atan2((up - n * up.dot(n)).dot(fwd.cross(n)), up.dot(n))))
		var mean = rel.reduce(func(a, b): return a + b, 0.0) / rel.size()
		var lateral_g = sin(deg_to_rad(angle))
		var want_roll = roll_gradient(key) * lateral_g
		results["wall %s" % key] = {
			"drift_m": drift, "rel_roll_deg": mean, "expected_deg": want_roll, "min_contacts": min_contacts
		}
		check(
			(
				finite(c)
				and min_contacts == 4
				and body == 0
				and sunk == 0
				and drift < 1.0
				and absf(absf(mean) - want_roll) < 1.0
			),
			(
				"%s along a 37° concrete slope at 150 km/h for 5 s: 4 tyres down throughout, body contacts %d, below surface %d ticks, off line %.2f m, body %.2f° off the surface normal (roll gradient x 0.60 g = %.2f°)"
				% [key, body, sunk, drift, absf(mean), want_roll]
			)
		)


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	energy()
	wall()
	print(
		"ENERGY WALL RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
