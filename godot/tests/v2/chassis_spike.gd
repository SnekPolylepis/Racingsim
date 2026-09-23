extends SceneTree
## P2-00 spike: 6-DOF CarBody on analytic TestSurfaces (REBUILD-PLAN.md P2-00, section 6).
## Measures rest, flat equivalence against docs/rebuild/baseline.json, crest takeoff speed, free-flight
## angular momentum, a banked bowl at design speed, determinism and cost per tick.
## Run: tools/Godot.exe --headless --path . --script tests/v2/chassis_spike.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
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


## Last number of the Simulation dynamics check whose text starts with `prefix`.
func base(prefix):
	for c in baseline.suites["dynamics-simulation"].checks:
		if c.text.begins_with(prefix):
			return c.values
	return []


func finite(c):
	return (
		is_finite(c.pos.x)
		and is_finite(c.pos.y)
		and is_finite(c.pos.z)
		and is_finite(c.vel.length())
		and is_finite(c.ang.length())
	)


func settle(key):
	var surf = TestSurface.flat()
	var c = make(key)
	c.place(Vector3.ZERO, 0.0, 0.0)
	var peak = 0.0
	for i in 240 * 5:
		c.input = inp(0, 0, 0)
		c.step(DT, surf, true)
		if i > 240:
			peak = maxf(peak, c.vel.length() + c.ang.length())
	var load = 0.0
	for w in c.wheels:
		load += w.load
	var b = c.basis()
	var tilt = rad_to_deg(acos(clampf(b.y.dot(Vector3.UP), -1, 1)))
	check(
		finite(c) and peak < .01 and absf(load / (c.p.mass * CarBody.G) - 1) < .005 and tilt < .05,
		(
			"%s rests on flat: CG %.4f m (cgHeight %.3f), load %.4f mg, tilt %.3f°, motion after 1 s %.6f"
			% [key, c.pos.y, c.setup.cgHeight, load / (c.p.mass * CarBody.G), tilt, peak]
		)
	)


func accel_brake(key):
	var surf = TestSurface.flat()
	var c = make(key)
	c.place(Vector3(-2000, 0, 0), 0.0, 0.0)
	var time = 0.0
	while c.speed < 100 / 3.6 and time < 30:
		c.input = inp(1, 0, 0)
		c.step(DT, surf, true)
		time += DT
	var x0 = c.pos.x
	var stop = 0.0
	var pitch_peak = 0.0
	while c.speed > .3 and stop < 20:
		c.input = inp(0, 1, 0)
		c.step(DT, surf, true)
		stop += DT
		pitch_peak = maxf(pitch_peak, rad_to_deg(asin(clampf(-c.basis().x.y, -1, 1))))
	return [time, c.pos.x - x0, pitch_peak, finite(c)]


## Same controller and limit search as tests/dynamics.gd skidpad(), on an analytic circle.
func skidpad(key, radius):
	var surf = TestSurface.flat()
	var c = make(key)
	c.place(Vector3(radius, 0, 0), PI / 2, 0.0)
	var target = 8.0
	var best = 0.0
	var time = 0.0
	var roll_peak = 0.0
	while time < 150:
		var phi = atan2(c.pos.z, c.pos.x)
		var lat = Vector2(c.pos.x, c.pos.z).length() - radius
		var ahead_phi = phi + (6 + c.speed * .35) / radius
		var ahead = Vector2(cos(ahead_phi), sin(ahead_phi)) * radius
		var st = clampf(wrapf(atan2(ahead.y - c.pos.z, ahead.x - c.pos.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = target - c.speed
		c.input = inp(clampf(e * .6 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(DT, surf, true)
		time += DT
		if absf(lat) < 2.0 and absf(e) < .6:
			best = maxf(best, c.speed)
			roll_peak = maxf(roll_peak, absf(rad_to_deg(asin(clampf(c.basis().z.y, -1, 1)))))
		if absf(lat) > 4:
			break
		target += .6 / 240
	return [best * best / radius / 9.81, roll_peak, finite(c)]


## Drive over a crest at a held speed; returns true if all four tyres leave the ground.
func crest_run(key, surf, v):
	var c = make(key)
	c.setup.clAF = 0.0
	c.setup.clAR = 0.0
	var start = surf.crest_x - surf.crest_plateau - surf.crest_ramp - 120
	c.place_on(surf, start, 0.0, 0.0)
	c.launch(v)
	var left = false
	var airtime = 0.0
	var landed_ok = true
	for i in 240 * 8:
		var e = v - c.speed
		c.input = inp(clampf(e * .8 + .5, 0, 1), clampf(-e * .3, 0, 1), 0.0)
		c.step(DT, surf, true)
		if c.contacts == 0:
			left = true
			airtime += DT
		if not finite(c):
			landed_ok = false
			break
	return {"left": left, "airtime": airtime, "finite": landed_ok, "car": c}


func crest_threshold(key):
	var radius = 200.0
	var surf = TestSurface.crest(0.0, radius, 20.0, 40.0)
	var theory = sqrt(9.81 * radius)
	var lo = theory * .8
	var hi = theory * 1.2
	var fast = crest_run(key, surf, hi)
	var slow = crest_run(key, surf, lo)
	if not fast.left or slow.left:
		check(
			false,
			"%s crest bracket: flies at 1.2x %s, stays down at 0.8x %s" % [key, fast.left, not slow.left]
		)
		return
	for i in 8:
		var mid = (lo + hi) * .5
		if crest_run(key, surf, mid).left:
			hi = mid
		else:
			lo = mid
	var measured = (lo + hi) * .5
	results["crest_takeoff_ratio"] = measured / theory
	check(
		absf(measured / theory - 1) < .03,
		(
			"%s leaves a R=%.0f m crest at %.1f km/h; theory sqrt(gR) = %.1f km/h (ratio %.3f)"
			% [key, radius, measured * 3.6, theory * 3.6, measured / theory]
		)
	)
	var jump = crest_run(key, surf, theory * 1.15)
	var c = jump.car
	var settled = c.contacts == 4 and absf(c.ang.length()) < .05
	check(
		jump.finite and jump.left and settled,
		(
			"%s at 1.15x: airborne %.2f s, lands and settles (contacts %d, |ω| %.3f rad/s after landing)"
			% [key, jump.airtime, c.contacts, c.ang.length()]
		)
	)


func flight(key):
	var surf = TestSurface.void_space()
	var c = make(key)
	c.setup.clAF = 0.0
	c.setup.clAR = 0.0
	c.place(Vector3(0, 500, 0), 0.0, 500.0)
	c.ang = Vector3(1.2, 2.0, -.7)
	var l0 = c.angular_momentum_world()
	var e0 = .5 * c.ang.dot(c.inertia * c.ang)
	for i in 240 * 3:
		c.input = inp(0, 0, 0)
		c.step(DT, surf, true)
	var l1 = c.angular_momentum_world()
	var e1 = .5 * c.ang.dot(c.inertia * c.ang)
	var dl = (l1 - l0).length() / l0.length()
	results["flight_dL"] = dl
	check(
		dl < .01 and absf(e1 / e0 - 1) < .01,
		"%s tumbling 3 s in free flight: |ΔL|/|L| %.4f, ΔE %.4f (gyroscopic term)" % [key, dl, e1 / e0 - 1]
	)


## Banked cone at its design speed v = sqrt(g R tan θ): the bank supplies the centripetal force,
## so the tyres should carry almost no lateral force and the body should roll with the road.
func bowl(key):
	var radius = 100.0
	var bank = 20.0
	var surf = TestSurface.bowl(radius, bank)
	var v = sqrt(9.81 * radius * tan(deg_to_rad(bank)))
	var c = make(key)
	c.setup.clAF = 0.0
	c.setup.clAR = 0.0
	c.place_on(surf, radius, 0.0, PI / 2)
	c.launch(v)
	var lat_sum = 0.0
	var n = 0
	var lat_err = 0.0
	for i in 240 * 30:
		var phi = atan2(c.pos.z, c.pos.x)
		var ahead_phi = phi + (6 + c.speed * .35) / radius
		var ahead = Vector2(cos(ahead_phi), sin(ahead_phi)) * radius
		var st = clampf(wrapf(atan2(ahead.y - c.pos.z, ahead.x - c.pos.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = v - c.speed
		c.input = inp(clampf(e * .6 + .2, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(DT, surf, true)
		if i > 240 * 15:
			# Per-wheel magnitudes: opposing front/rear forces must not cancel into a pass.
			for w in c.wheels:
				lat_sum += absf(w.fy)
			lat_err = maxf(lat_err, absf(Vector2(c.pos.x, c.pos.z).length() - radius))
			n += 1
	var lat_share = lat_sum / n / (c.p.mass * 9.81)
	var n_road = surf.normal(c.pos.x, c.pos.z)
	var rel = rad_to_deg(acos(clampf(c.basis().y.dot(n_road), -1, 1)))
	var world_roll = rad_to_deg(acos(clampf(c.basis().y.dot(Vector3.UP), -1, 1)))
	results["bowl_lateral_share"] = lat_share
	check(
		finite(c) and lat_share < .05 and lat_err < 1.5 and absf(world_roll - bank) < 1.5,
		(
			"%s on a %.0f° bank at design speed %.1f km/h: sum of |tyre lateral| %.1f%% of mg, path error %.2f m, body %.1f° from vertical (%.2f° from road normal)"
			% [key, bank, v * 3.6, lat_share * 100, lat_err, world_roll, rel]
		)
	)


## Drop from 1 m at 50 km/h: the bump stops must take the hit without blowing up, and the car
## must be back at rest ride height and attitude within 2 s of touching down.
func landing(key):
	var surf = TestSurface.flat()
	var c = make(key)
	c.place(Vector3.ZERO, 0.0, 1.0)
	c.launch(50 / 3.6)
	# Neutral, manual: an automatic downshift while coasting pitches the car through engine braking,
	# which is a drivetrain event, not the landing this measures.
	c.gear = 0
	var touched = -1
	var last_unsettled = 0
	var peak_load = 0.0
	var ok = true
	for i in 240 * 4:
		c.input = inp(0, 0, 0)
		c.step(DT, surf, false)
		if touched < 0 and c.contacts > 0:
			touched = i
		for w in c.wheels:
			peak_load = maxf(peak_load, w.load)
		if not finite(c):
			ok = false
			break
		# Settled: heave within 1 cm of ride height, vertical speed and pitch/roll rates near zero.
		var calm = (
			c.contacts == 4
			and absf(c.pos.y - c.setup.cgHeight) < .01
			and absf(c.vel.y) < .02
			and absf(c.ang.x) < .02
			and absf(c.ang.z) < .02
		)
		if not calm:
			last_unsettled = i
	var settle = (last_unsettled - touched) / 240.0
	check(
		ok and touched > 0 and settle < 2.0 and last_unsettled < 240 * 4 - 240,
		(
			"%s dropped 1 m at 50 km/h: peak tyre load %.1f x static, settled %.2f s after touchdown (limit 2 s)"
			% [key, peak_load / (c.p.mass * 9.81 / 4), settle]
		)
	)


## Every piece of mutable solver state, serialized exactly (var_to_str keeps full float precision).
func state_hash(c):
	var state = [
		c.pos,
		c.vel,
		c.rot,
		c.ang,
		c.accel,
		c.contacts,
		c.airborne,
		c.wheels,
		c.gear,
		c.pending_gear,
		c.shift_timer,
		c.shift_cooldown,
		c.blip_pending,
		c.brake_hold,
		c.engine_w,
		c.rpm,
		c.clutch_eng,
		c.throttle_eff,
		c.rev_limit,
		c.steer_angle,
		c.steer_torque,
		c.tc_gain,
		c.tc_active,
		c.abs_active,
		c.asm_active,
		c.asm_cut,
		c.asm_brakes,
		c.noise_seed,
		c.all_off
	]
	return var_to_str(state).sha256_text()


## Plan section 6: the same 60 s input twice must give an identical full-state hash. The run goes
## over the crest, brakes hard (ABS), powers out of a slide (TC) with ASM on, and shifts both ways.
func determinism():
	var hashes = []
	for k in 2:
		var surf = TestSurface.crest(0.0, 200.0, 20.0, 40.0)
		var c = make("f296gt3")
		c.setup.asmLevel = 5
		c.place_on(surf, -300.0, 0.0, 0.0)
		for i in 240 * 60:
			var phase = i % (240 * 15)
			var th = 1.0 if phase < 240 * 9 else 0.0
			var br = 1.0 if phase >= 240 * 9 and phase < 240 * 12 else 0.0
			c.input = inp(th, br, sin(i * .013) * .6)
			c.step(DT, surf, true)
		hashes.append(state_hash(c))
	check(
		hashes[0] == hashes[1],
		"two identical 60 s runs end in the same full-state hash (%s)" % hashes[0].left(12)
	)


## Review finding: a tilted ray can pass over a hump with both ends above the surface.
## A horizontal ray at y = -1 mm across the R = 200 m apex from x = -1 to +1 must hit at the first
## crossing, x = -sqrt(2 R 0.001) = -0.632 m.
func ray_over_hump():
	var surf = TestSurface.crest(0.0, 200.0, 20.0, 40.0)
	var hit = surf.contact(Vector3(-1, -.001, 0), Vector3(1, 0, 0), 2.0)
	var want = 1.0 - sqrt(2 * 200.0 * .001)
	check(
		not hit.is_empty() and absf(hit.distance - want) < 1e-4,
		(
			"ray across a hump with both ends above it hits the first crossing (%s, want %.4f m)"
			% ["no hit" if hit.is_empty() else "%.4f m" % hit.distance, want]
		)
	)


## Cost per tick. Flat uses a closed-form ray hit, so it is close to the chassis cost alone; the crest
## adds 40-step bisection ray casts, standing in for a heavier real track query.
func cost():
	for which in ["flat", "crest"]:
		var surf = TestSurface.flat() if which == "flat" else TestSurface.crest(0.0, 200.0, 20.0, 40.0)
		var c = make("f296gt3")
		c.place_on(surf, -300.0, 0.0, 0.0)
		var n = 240 * 20
		var t0 = Time.get_ticks_usec()
		for i in n:
			c.input = inp(1, 0, sin(i * .01) * .3)
			c.step(DT, surf, true)
		var us = float(Time.get_ticks_usec() - t0) / n
		results["us_per_tick_" + which] = us
		check(us < 300, "cost %.1f µs per tick on %s (budget 300 µs)" % [us, which])


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	baseline = JSON.parse_string(FileAccess.get_file_as_string("res://docs/rebuild/baseline.json"))
	for key in presets:
		settle(key)
	var flat = {}
	for key in presets:
		var ab = accel_brake(key)
		var sk = skidpad(key, 150)
		var b_acc = base("%s 0-100" % key)
		var b_brk = base("%s 100-0" % key)
		var b_lat = base("%s holds" % key)
		var r_acc = ab[0] / b_acc[-1]
		var r_brk = ab[1] / b_brk[-1]
		b_lat = [b_lat[-2]]  # "<car> holds X g on a 150 m skidpad": X is second to last
		var r_lat = sk[0] / b_lat[0]
		flat[key] = {"accel": ab[0], "brake": ab[1], "lat_g": sk[0], "pitch": ab[2], "roll": sk[1]}
		check(
			ab[3] and absf(r_acc - 1) < .03,
			"%s 0-100 km/h %.2f s (baseline %.2f, %+.1f%%)" % [key, ab[0], b_acc[-1], (r_acc - 1) * 100]
		)
		check(
			ab[3] and absf(r_brk - 1) < .03,
			(
				"%s 100-0 km/h %.1f m (baseline %.1f, %+.1f%%), peak dive %.2f°"
				% [key, ab[1], b_brk[-1], (r_brk - 1) * 100, ab[2]]
			)
		)
		check(
			sk[2] and absf(r_lat - 1) < .03,
			(
				"%s skidpad %.2f g (baseline %.2f, %+.1f%%), body roll %.2f°"
				% [key, sk[0], b_lat[0], (r_lat - 1) * 100, sk[1]]
			)
		)
	results["flat"] = flat
	crest_threshold("gt")
	flight("f296gt3")
	bowl("f296gt3")
	for key in presets:
		landing(key)
	determinism()
	ray_over_hump()
	cost()
	print("SPIKE RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
