extends SceneTree
## P2-07: the driver aids and Simcade on the 6-DOF CarBody, against the pre-rebuild vehicle-dynamics
## targets (formerly tests/dynamics.gd, merged here in P7-01b):
##   Simulation  tyre peaks, 0-100, 100-0 and skidpad bands; lift / brake / power at 90 % of the limit;
##               one minute of cornering heat; full stick at 80 and 160 km/h with the grip assist.
##   Simcade     Simcade vs Simulation within 8 %, tyre plateau, full lock at 80/120/160, keyboard ASM 1,
##               lift / brake / power peaks and recovery with ASM 3 and with aids off, lift-off yaw, trail
##               braking yaw, heat soak, ratio plateau and sliding floor, grass and gravel coasts,
##               differential split, roll balance.
## Ranges are deliberately broad real-world bands, not tuned lap-time expectations. The cars drive on
## analytic flat ground (Straight, Circle below: a 30 m tarmac road, grass beyond, an optional gravel
## patch), which replaced the legacy TrackModel harness in P7-01b.
## Not here: car-vs-wall contact (tests/v2/barrier.gd).
## The roadster's Simcade 100-0 failed this suite's 8 % band on the old planar CarModel (38.37 m vs
## 42.28 m, locked wheels sliding on Simcade's 0.87 floor); CarBody passes it with its own longitudinal
## sliding floor (data/simcade.json "carbody", P2-07).
## Run: tools/Godot.exe --headless --path . --script tests/v2/aids_simcade.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
## Road width of the harness tracks, metres; beyond it is grass.
const ROAD_WIDTH = 30.0
var presets
var failures = []
var checks = 0
var model_simcade = false
var no_aids = false


## Flat ground y = 0 as a section 5.2 surface. Plan coordinates are (x, y) = world (x, z), as the
## CarBody's plan-view mirror (sync_legacy) reads them.
class FlatGround:
	extends RefCounted
	## Plan-view rectangle of gravel (surface 3) off the road; empty for none.
	var gravel = Rect2()

	func surface_id(x: float, y: float) -> int:
		if absf(lateral(x, y)) <= ROAD_WIDTH / 2:
			return 0
		return 3 if gravel.has_point(Vector2(x, y)) else 2

	func lateral(_x: float, _y: float) -> float:
		return 0.0

	func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
		if direction.y >= 0 or origin.y < 0:
			return {}
		var d = origin.y / -direction.y
		if d > max_dist:
			return {}
		var p = origin + direction * d
		return {
			"point": p, "normal": Vector3.UP, "distance": d, "surface": surface_id(p.x, p.z), "hint": hint
		}


## A straight road along +x through y = 0.
class Straight:
	extends FlatGround

	func lateral(_x: float, y: float) -> float:
		return y


## A circular road of radius `radius` about the origin, driven anticlockwise in plan (x, y).
class Circle:
	extends FlatGround
	var radius = 60.0

	func _init(r: float):
		radius = r

	func lateral(x: float, y: float) -> float:
		return Vector2(x, y).length() - radius

	## Centreline pose at arc distance s: {x, y, h}.
	func pos_at(s: float) -> Dictionary:
		var a = s / radius
		return {"x": cos(a) * radius, "y": sin(a) * radius, "h": a + PI / 2}

	## Arc distance and lateral offset of a plan position.
	func project(x: float, y: float, _hint = -1) -> Dictionary:
		return {"s": fposmod(atan2(y, x), TAU) * radius, "lat": lateral(x, y)}


## CarBody driven by the plan-view harness: reset_pose() places it on the ground plane, and state the
## harness writes into the plan-view fields after a reset (vx, vy, r) is taken on at the next step.
class BodyShim:
	extends "res://scripts/vehicle/car_body.gd"
	var pending = false

	func reset_pose(pose):
		super(pose)
		rig()
		pos_x = pose.x
		pos_y = setup.cgHeight
		pos_z = pose.y
		rot = Quaternion(Vector3.UP, -pose.h)
		vel = Vector3.ZERO
		ang = Vector3.ZERO
		pending = true

	func step(dt, surface, automatic = true):
		if pending:
			vel = Vector3(vx, 0, vy)
			ang = Vector3(0, -r, 0)
			pending = false
		super.step(dt, surface, automatic)


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func straight():
	return Straight.new()


func circle(r):
	return Circle.new(r)


func make(key):
	var c = BodyShim.new()
	# Centre contact only keeps this 114-check gate under 240 s.
	c.footprint = false
	c.simcade_enabled = model_simcade
	c.configure(presets[key])
	if no_aids:
		c.set_tcs(0)
		c.setup.asmLevel = 0
		c.setup.absOn = 0
		c.simcade_steering = false
	c.wear_enabled = false
	c.steer_falloff = 0.0
	for w in c.wheels:
		w.temp = c.setup.tempOpt
		w.core = c.setup.tempOpt
	return c


func inp(th, br, st):
	return {"throttle": th, "brake": br, "steer": st, "clutch": 0.0, "handbrake": 0.0}


func zero_to_100(key):
	var t = straight()
	var c = make(key)
	c.reset_pose({"x": -2000.0, "y": 0.0, "h": 0.0})
	var time = 0.0
	while c.speed < 100 / 3.6 and time < 30:
		c.input = inp(1, 0, 0)
		c.step(1.0 / 240, t, true)
		time += 1.0 / 240
	var x0 = c.x
	var stop = 0.0
	while c.speed > .3 and stop < 20:
		c.input = inp(0, 1, 0)
		c.step(1.0 / 240, t, true)
		stop += 1.0 / 240
	return [time, c.x - x0]


func skidpad(key, r):
	var t = circle(r)
	var c = make(key)
	var p = t.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var target = 8.0
	var best = 0.0
	var time = 0.0
	while time < 150:
		var pr = t.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = t.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = target - c.speed
		c.input = inp(clampf(e * .6 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(1.0 / 240, t, true)
		time += 1.0 / 240
		if absf(pr.lat) < 2.0 and absf(e) < .6:
			best = maxf(best, c.speed)
		if absf(pr.lat) > 4:
			break
		target += .6 / 240
	return best * best / r / 9.81


## Full controller stick (0.3 s ramp, response exponent 1.6) at speed with the grip assist and the
## default controller speed sensitivity; returns the peak body slip angle in degrees.
func stick(key, kph, keyboard = false, asm_override = -1):
	var t = straight()
	var c = make(key)
	c.steer_falloff = 14.0 if keyboard else 40.0
	if asm_override >= 0:
		c.setup.asmLevel = asm_override
	c.steer_slip_limit = c.peak_slip_angle() * .85
	c.reset_pose({"x": -1500.0, "y": 0.0, "h": 0.0})
	c.vx = kph / 3.6
	for w in c.wheels:
		w.omega = c.vx / c.p.wheelR
	# Start in the gear a driver would be in (engine near 70 % of redline), engine speed matched.
	for g in range(1, 7):
		c.gear = g
		var ratio = c.setup["gear" + str(g)] * c.setup.finalDrive
		c.engine_w = c.vx / c.p.wheelR * ratio
		if c.engine_w * 30 / PI < c.p.redline * .75:
			break
	var worst = 0.0
	for i in 240 * 3:
		c.input = inp(
			.2, 0, clampf((i - 24) * 3.5 / 240, 0, 1) if keyboard else pow(clampf((i - 24) / 72.0, 0, 1), 1.6)
		)
		c.step(1.0 / 240, t, true)
		worst = maxf(worst, absf(atan2(c.vby, maxf(absf(c.vbx), 1))))
	return rad_to_deg(worst)


## Hold 90 % of the car's limit on a 60 m circle, then lift, floor the throttle or brake for 2 s.
## Returns the worst body slip angle (deg) during the action.
func mid_corner(key, action, lim):
	var t = circle(60)
	var c = make(key)
	var p = t.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var v = sqrt(lim * 9.81 * 60) * .9
	var worst = 0.0
	for tick in 240 * 20:
		var pr = t.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = t.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = v - c.speed
		var th = clampf(e * .6 + .3, 0, 1)
		var br = clampf(-e * .3, 0, 1)
		if tick > 240 * 16:
			th = {"lift": 0.0, "power": 1.0, "brake": 0.0}[action]
			br = .6 if action == "brake" else 0.0
		c.input = inp(th, br, st)
		c.step(1.0 / 240, t, true)
		if tick > 240 * 16:
			worst = maxf(worst, absf(atan2(c.vby, maxf(absf(c.vbx), 1))))
	return rad_to_deg(worst)


## One minute at 90 % of the limit on a 60 m circle: the hottest tyre surface must stay inside the
## working window (optimum + window), i.e. hard cornering alone does not cook the tyres.
func heat_soak(key, lim):
	var t = circle(60)
	var c = make(key)
	var p = t.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var v = sqrt(lim * 9.81 * 60) * .9
	var hottest = 0.0
	for tick in 240 * 60:
		var pr = t.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = t.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = v - c.speed
		c.input = inp(clampf(e * .6 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
		c.step(1.0 / 240, t, true)
		for w in c.wheels:
			hottest = maxf(hottest, w.temp)
	return hottest


## Simulation car checks. The roadster is a 1990 MX-5 NA on period 185/60R14 street rubber with no ABS
## or traction control, so it brakes and corners far below the two race cars (published: about
## 8.6-9.0 s to 100 km/h and 40-43 m from 100). Without traction control, full throttle at 90 % of
## grip steps its rear out, hence its looser power limit.
func simulation_checks():
	var bands = {
		"roadster": {"accel": [7.5, 10.0], "lat": [0.62, 0.95], "brake": [34, 48]},
		"gt": {"accel": [3.5, 6.0], "lat": [1.4, 2.1], "brake": [25, 40]},
		"f296gt3": {"accel": [3.2, 5.5], "lat": [1.6, 2.4], "brake": [25, 40]}
	}
	for key in presets:
		var c = make(key)
		var pa = rad_to_deg(c.peak_slip_angle())
		check(
			pa > 5 and pa < 10 and c.peak_slip_ratio() > .08 and c.peak_slip_ratio() < .18,
			"%s tyre peaks at %.1f° slip angle, %.2f slip ratio" % [key, pa, c.peak_slip_ratio()]
		)
		var a = zero_to_100(key)
		check(
			a[0] > bands[key].accel[0] and a[0] < bands[key].accel[1], "%s 0-100 km/h in %.2f s" % [key, a[0]]
		)
		check(
			a[1] > bands[key].brake[0] and a[1] < bands[key].brake[1], "%s 100-0 km/h in %.1f m" % [key, a[1]]
		)
		var g = skidpad(key, 150)
		check(
			g > bands[key].lat[0] and g < bands[key].lat[1], "%s holds %.2f g on a 150 m skidpad" % [key, g]
		)
		var lim = {"roadster": 0.75, "gt": 1.5, "f296gt3": 1.6}[key]
		for action in ["lift", "brake", "power"]:
			var slip_mc = mid_corner(key, action, lim)
			var power_allowed = {"roadster": 32.0, "gt": 25.0, "f296gt3": 25.0}
			var allowed = power_allowed[key] if action == "power" else 10.0
			check(
				slip_mc < allowed,
				(
					"%s %s mid-corner at 90%% of the limit: body slip %.0f° (default aids)"
					% [key, action, slip_mc]
				)
			)
		var hot = heat_soak(key, lim)
		check(
			hot < c.setup.tempOpt + c.setup.tempWindow,
			(
				"%s one minute at 90%% cornering: hottest tyre %.0f °C (window %d±%d)"
				% [key, hot, c.setup.tempOpt, c.setup.tempWindow]
			)
		)
		for kph in [80, 160]:
			var slip = stick(key, kph)
			check(
				slip < 40,
				"%s full stick at %d km/h with grip assist: peak body slip %.0f° (no spin)" % [key, kph, slip]
			)


## Simcade: compare the same manoeuvres against fresh Simulation measurements, not relaxed bands.
func run_simcade():
	for key in presets:
		model_simcade = false
		var baseline = zero_to_100(key)
		var baseline_g = skidpad(key, 150)
		model_simcade = true
		var a = zero_to_100(key)
		var g = skidpad(key, 150)
		check(
			absf(a[0] / baseline[0] - 1) <= .08,
			"%s Simcade 0-100 %.3f s / Simulation %.3f s" % [key, a[0], baseline[0]]
		)
		check(
			absf(a[1] / baseline[1] - 1) <= .08,
			"%s Simcade 100-0 %.3f m / Simulation %.3f m" % [key, a[1], baseline[1]]
		)
		check(
			absf(g / baseline_g - 1) <= .08,
			"%s Simcade skidpad %.3f g / Simulation %.3f g" % [key, g, baseline_g]
		)
		var c = make(key)
		var minimum = 1.0
		for deg in range(5, 14):
			minimum = minf(
				minimum,
				c.simcade_curve(
					deg_to_rad(deg), deg_to_rad(c.simcade.peak_start_deg), deg_to_rad(c.simcade.peak_end_deg)
				)
			)
		check(minimum >= .95, "%s tyre plateau 5-13 degrees minimum %.3f" % [key, minimum])
		for kph in [80, 120, 160]:
			var slip = stick(key, kph, true)
			check(slip < 15, "%s full lock at %d km/h: %.2f deg body slip" % [key, kph, slip])
		var weakest_asm = stick(key, 160, true, 1)
		check(weakest_asm < 15, "%s keyboard 160 km/h ASM 1: %.2f deg" % [key, weakest_asm])
		var limit = skidpad(key, 60)
		for off in [false, true]:
			no_aids = off
			for action in ["lift", "brake", "power"]:
				var result = transient(key, action, limit)
				check(
					result.peak <= (25 if off else 8),
					"%s %s ASM %d peak %.2f deg at 90%% limit" % [key, action, 0 if off else 3, result.peak]
				)
				check(
					result.recovery < 3,
					(
						"%s %s ASM %d recovery %.2f deg after 2s neutral"
						% [key, action, 0 if off else 3, result.recovery]
					)
				)
				if not off and action == "lift":
					check(
						result.yaw_increase > .0001,
						"%s lift-off yaw increase %.5f rad/s" % [key, result.yaw_increase]
					)
				if not off and action == "brake":
					check(
						result.yaw_peak > .05,
						(
							"%s trail braking yaw %.3f rad/s versus zero straight braking yaw"
							% [key, result.yaw_peak]
						)
					)
		no_aids = false
		var hot = heat_soak(key, limit)
		var grip = c.tyre_temperature_grip({"temp": hot, "core": hot})
		check(grip >= .95, "%s one-minute heat soak %.1f C, conservative grip floor %.4f" % [key, hot, grip])
	simcade_setup_and_surface_checks()
	print(
		(
			"SIMCADE DYNAMICS %s %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)


func transient(key, action, limit):
	var t = circle(60)
	var c = make(key)
	var p = t.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var target = sqrt(limit * .9 * 9.81 * 60)
	var peak = 0.0
	var yaw_before = 0.0
	var yaw_peak = 0.0
	var recovery = 0.0
	for tick in 240 * 22:
		var pr = t.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = t.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2.0, -1, 1)
		var e = target - c.speed
		var th = clampf(e * .6 + .3, 0, 1)
		var br = clampf(-e * .3, 0, 1)
		if tick == 240 * 16:
			yaw_before = absf(c.r)
		if tick >= 240 * 16:
			th = 1.0 if action == "power" else 0.0
			br = .6 if action == "brake" else 0.0
		if tick >= 240 * 20:
			st = 0.0
			th = 0.0
			br = 0.0
		c.input = inp(th, br, st)
		c.step(1.0 / 240, t, true)
		var beta = absf(rad_to_deg(atan2(c.vby, maxf(absf(c.vbx), 1))))
		if tick >= 240 * 16 and tick < 240 * 20:
			peak = maxf(peak, beta)
			yaw_peak = maxf(yaw_peak, absf(c.r))
		if tick >= 240 * 21.9:
			recovery = maxf(recovery, beta)
	return {"peak": peak, "recovery": recovery, "yaw_increase": yaw_peak - yaw_before, "yaw_peak": yaw_peak}


func simcade_setup_and_surface_checks():
	for key in presets:
		var c = make(key)
		var plateau = c.simcade_curve(
			c.peak_slip_ratio() * 1.7,
			c.peak_slip_ratio() * c.simcade.ratio_start_scale,
			c.peak_slip_ratio() * c.simcade.ratio_end_scale
		)
		var slide = c.simcade_curve(
			PI / 2, deg_to_rad(c.simcade.peak_start_deg), deg_to_rad(c.simcade.peak_end_deg)
		)
		check(
			plateau >= .95 and slide >= .85 and slide <= .88,
			"%s ratio plateau %.3f, sliding floor %.3f" % [key, plateau, slide]
		)
		for surface in [2, 3]:
			var terrain = straight()
			if surface == 3:
				terrain.gravel = Rect2(-1600, 24, 800, 26)
			c.reset_pose({"x": -1500.0, "y": 35.0, "h": 0.0})
			c.vx = 30
			c.gear = 4
			c.engine_w = c.vx / c.p.wheelR * c.setup.gear4 * c.setup.finalDrive
			for w in c.wheels:
				w.omega = c.vx / c.p.wheelR
			var worst = 0.0
			for tick in 240 * 3:
				c.input = inp(0, 0, 0)
				c.step(1.0 / 240, terrain)
				worst = maxf(worst, absf(rad_to_deg(atan2(c.vby, maxf(absf(c.vbx), 1)))))
			check(
				worst < 3 and c.speed < (27 if surface == 2 else 15),
				"%s surface %d coast: %.2f m/s, %.3f deg slip" % [key, surface, c.speed, worst]
			)
		var split = []
		for diff in [0, 2]:
			c.setup.diffType = diff
			c.wheels[2].omega = 60
			c.wheels[3].omega = 70
			var drive = [0., 0., 0., 0.]
			c.axle_split(2, 3, 800., [0., 0., 0., 0.], drive, 1. / 240)
			split.append(absf(drive[2] - drive[3]))
		check(
			split[1] - split[0] > 100,
			"%s differential torque split open %.1f / locked %.1f Nm" % [key, split[0], split[1]]
		)
		var soft_front = roll_balance(key, 5000, 50000)
		var stiff_front = roll_balance(key, 50000, 5000)
		check(
			stiff_front - soft_front > .05,
			(
				"%s front share of mid-corner load transfer: soft %.3f / stiff %.3f"
				% [key, soft_front, stiff_front]
			)
		)


func roll_balance(key, front, rear):
	var c = make(key)
	c.setup.arbF = front
	c.setup.arbR = rear
	var t = circle(60)
	var p = t.pos_at(0.0)
	c.reset_pose({"x": p.x, "y": p.y, "h": p.h})
	var total = 0.0
	for tick in 240 * 12:
		var pr = t.project(c.x, c.y, c.wheels[0].sIdx)
		var ahead = t.pos_at(pr.s + 6 + c.speed * .35)
		var st = clampf(wrapf(atan2(ahead.y - c.y, ahead.x - c.x) - c.h, -PI, PI) * 2, -1, 1)
		c.input = inp(clampf((18 - c.speed) * .6 + .3, 0, 1), clampf((c.speed - 18) * .3, 0, 1), st)
		c.step(1. / 240, t)
		if tick >= 240 * 10:
			var df = absf(c.wheels[1].load - c.wheels[0].load)
			var dr = absf(c.wheels[3].load - c.wheels[2].load)
			total += df / maxf(df + dr, 1)
	return total / 480


## `-- --car key` runs one car and `-- --part simulation|simcade` one half, so tools/run_gates.ps1 can
## run the six pieces in parallel (the whole suite is four minutes on one core).
func _initialize():
	presets = GatesEnv.only_car(JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json")))
	var part = GatesEnv.part()
	if part != "simcade":
		simulation_checks()
	var simulation_failures = failures.duplicate()
	if part != "simulation":
		run_simcade()
	print(
		"AIDS SIMCADE RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "simulation_failures": simulation_failures})
	)
	quit(0 if failures.is_empty() else 1)
