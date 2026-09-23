extends SceneTree
## Headless checks for the native-only handling layer and related fixes:
## curb geometry, two-node tire temperature, aligning torque, suspension travel stops,
## speed-sensitive steering, render-interpolation blending and checkpoint invalidation reasons.
const TrackModel = preload("res://scripts/track3d.gd")
const CarModel = preload("res://scripts/car.gd")
const RaceModel = preload("res://scripts/race.gd")
const Collisions = preload("res://scripts/collisions.gd")
var failures = []
var checks = 0


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func straight_track():
	var t = TrackModel.new()
	var pts = []
	var curbs = {}
	for x in [-400, -200, 0, 200, 400]:
		pts.append({"x": x, "y": 0, "w": 12})
	for x in [400, 200, 0, -200, -400]:
		pts.append({"x": x + (60 if x == 400 else (-60 if x == -400 else 0)), "y": 300, "w": 12})
	for i in pts.size():
		curbs[str(i)] = "on"
	t.load_data({"name": "test", "points": pts, "curbOverride": curbs, "startS": 0.0})
	return t


func make_car():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var car = CarModel.new()
	car.configure(presets.roadster)
	return car


func curb_run():
	var t = straight_track()
	var car = make_car()
	car.reset_pose({"x": -150.0, "y": 6.0, "h": 0.0})
	var max_dev = 0.0
	var on_curb = 0
	var roll = 0.0
	var n = 0
	var loads = []
	for tick in 4 * 240:
		car.input = {
			"throttle": clampf((20 - car.speed) * .4, 0, 1),
			"brake": 0.0,
			"steer": 0.0,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		car.step(1.0 / 240, t)
		if car.wheels[1].surf.id == 1:
			on_curb += 1
		max_dev = maxf(max_dev, car.wheels[1].dev)
		if tick > 240:
			roll += car.roll
			n += 1
			loads.append(car.wheels[1].load)
	var mean = 0.0
	var variance = 0.0
	for l in loads:
		mean += l / loads.size()
	for l in loads:
		variance += (l - mean) * (l - mean) / loads.size()
	return {"dev": max_dev, "curb": on_curb, "roll": roll / n, "shake": sqrt(variance)}


func _initialize():
	# Curbs are geometry: right wheels ride up the curb and carry more load than the left.
	var real = curb_run()
	check(real.curb > 600, "right wheels stay on the curb (%d ticks)" % real.curb)
	check(real.dev > .035, "curb lifts the wheel %.3f m above the road plane" % real.dev)
	check(real.roll < -.01, "body tilts away from raised curb (%.2f°)" % rad_to_deg(real.roll))
	check(real.shake > 200, "curb ridges shake the wheel load (σ %.0f N)" % real.shake)

	# Two-node tires: surface heats faster than the carcass, and cools faster when load is removed.
	var t = straight_track()
	var car = make_car()
	car.reset_pose({"x": -150.0, "y": 0.0, "h": 0.0})
	for w in car.wheels:
		w.temp = 25.0
		w.core = 25.0
	for tick in 12 * 240:
		car.input = {
			"throttle": 1.0,
			"brake": 0.0,
			"steer": .9 if car.speed > 8 else 0.0,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		car.step(1.0 / 240, t)
	var hot = car.wheels[3].temp
	var core = car.wheels[3].core
	check(
		hot > core + 5 and core > 25.5,
		"slides heat the surface (%.1f°) ahead of the core (%.1f°)" % [hot, core]
	)
	for tick in 6 * 240:
		car.input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
		car.step(1.0 / 240, t)
	check(
		hot - car.wheels[3].temp > core - car.wheels[3].core,
		(
			"surface cools faster than the core (%.1f° vs %.1f° drop)"
			% [hot - car.wheels[3].temp, core - car.wheels[3].core]
		)
	)

	# Aligning torque opposes steering and collapses once the front tires pass their slip peak.
	var sat = []
	for steer in [.05, .3, 1.0]:
		car = make_car()
		car.steer_falloff = 0.0
		car.reset_pose({"x": -150.0, "y": 0.0, "h": 0.0})
		car.vx = 18.0
		for w in car.wheels:
			w.omega = 18.0 / car.p.wheelR
		var peak = 0.0
		for tick in 60:
			car.input = {"throttle": .3, "brake": 0.0, "steer": steer, "clutch": 0.0, "handbrake": 0.0}
			car.step(1.0 / 240, t)
			peak = minf(peak, car.steer_torque)
		sat.append(peak)
	check(
		sat[0] < 0 and sat[1] < 0,
		"aligning torque opposes a right-hand steer (%.0f, %.0f N·m)" % [sat[0], sat[1]]
	)
	check(absf(sat[1]) > absf(sat[0]), "aligning torque builds with slip below the peak")
	var front = make_car()
	front.steer_falloff = 0.0
	front.reset_pose({"x": -150.0, "y": 0.0, "h": 0.0})
	front.vx = 18.0
	for w in front.wheels:
		w.omega = 18.0 / front.p.wheelR
	var ratio_small = 0.0
	var ratio_big = 1e9
	for tick in 120:
		front.input = {"throttle": .3, "brake": 0.0, "steer": 1.0, "clutch": 0.0, "handbrake": 0.0}
		front.step(1.0 / 240, t)
		var fy = absf(front.wheels[0].fy) + absf(front.wheels[1].fy)
		if fy > 500:
			var r = absf(front.steer_torque) / fy
			if absf(front.wheels[0].alphaRelax) < .03:
				ratio_small = maxf(ratio_small, r)
			if absf(front.wheels[0].alphaRelax) > .2:
				ratio_big = minf(ratio_big, r)
	check(ratio_big < ratio_small or ratio_small == 0.0, "pneumatic trail shrinks at large slip angles")

	# Suspension travel stops do not accumulate velocity.
	car = make_car()
	car.reset_pose({"x": -150.0, "y": 0.0, "h": 0.0})
	car.pitch = .12
	car.pitchd = 6.0
	car.roll = -.12
	car.rolld = -6.0
	car.input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
	car.step(1.0 / 240, t)
	check(car.pitchd <= 0.0 and car.rolld >= 0.0, "pitch/roll velocity is stopped at the travel limit")

	# Speed-sensitive steering can be turned off.
	car = make_car()
	car.reset_pose({"x": -150.0, "y": 0.0, "h": 0.0})
	car.vx = 40.0
	car.input = {"throttle": 0.0, "brake": 0.0, "steer": 1.0, "clutch": 0.0, "handbrake": 0.0}
	car.step(1.0 / 240, t)
	var assisted = car.steer_angle
	car.steer_falloff = 0.0
	car.step(1.0 / 240, t)
	check(
		is_equal_approx(car.steer_angle, deg_to_rad(car.setup.maxSteer)) and assisted < car.steer_angle * .4,
		"falloff 0 gives full lock at 144 km/h (assisted %.1f°)" % rad_to_deg(assisted)
	)

	# Render interpolation blends positions and wraps wheel phase the short way.
	var a = {
		"x": 0.0,
		"y": 0.0,
		"h": 0.0,
		"z": 0.0,
		"pitch": 0.0,
		"roll": 0.0,
		"steer": 0.0,
		"phase": [TAU - .1, 0.0, 0.0, 0.0],
		"dev": [0.0, 0.0, 0.0, 0.0],
		"brake": 0.0,
		"handbrake": 0.0,
		"sIdx": 0
	}
	var b = a.duplicate(true)
	b.x = 2.0
	b.phase[0] = .1
	var m = CarModel.blend(a, b, .5)
	check(
		is_equal_approx(m.x, 1.0) and absf(wrapf(m.phase[0], -PI, PI)) < .001,
		"snapshot blend interpolates and wraps phase"
	)

	# Race: a checkpoint passed far outside the gate invalidates the lap with a reason.
	for strict in [true, false]:
		var track = straight_track()
		var race = RaceModel.new()
		race.off_track_invalidate = strict
		var probe = make_car()
		var reason = ""
		for s in range(-5, int(track.length * 1.02)):
			var p = track.pos_at(float(s))
			var off = 12.0 if absf(fposmod(float(s), track.length) - track.checkpoints[1]) < 3 else 0.0
			probe.x = p.x - sin(p.h) * off
			probe.y = p.y + cos(p.h) * off
			race.update(probe, track, .05)
			if not race.invalid_reason.is_empty():
				reason = race.invalid_reason
		if strict:
			check(
				(
					reason == "missed CP 2"
					and race.completed == 1
					and not race.last_valid
					and race.last_reason == "missed CP 2"
				),
				'missed checkpoint is reported ("%s")' % race.last_reason
			)
		else:
			check(
				race.completed == 1 and race.last_valid,
				"runoff is allowed at checkpoints when off-track laps count"
			)

	# Auto barriers: generated along the lap and one-sided, so even a 300 km/h hit cannot tunnel through.
	var bt = straight_track()
	bt.build_barriers()
	check(bt.barriers.size() > 100, "auto barriers generated (%d segments)" % bt.barriers.size())
	var inside = 0
	for o in bt.barriers:
		var mid = Vector2((o.x1 + o.x2) / 2, (o.y1 + o.y2) / 2)
		var pr = bt.project(mid.x, mid.y)
		if absf(pr.lat) < pr.width / 2 + 6:
			inside += 1
	check(inside == 0, "barriers keep clear of the road")
	var crash = make_car()
	var target = bt.barriers[bt.barriers.size() / 4]
	var aim = Vector2((target.x1 + target.x2) / 2, (target.y1 + target.y2) / 2)
	var pr0 = bt.project(aim.x, aim.y)
	var start_pt = Vector2(pr0.px, pr0.py)
	var heading = (aim - start_pt).angle()
	crash.reset_pose({"x": start_pt.x, "y": start_pt.y, "h": heading})
	crash.vx = cos(heading) * 83
	crash.vy = sin(heading) * 83
	var side0 = signf((Vector2(crash.x, crash.y) - aim).dot(aim - start_pt))
	var crossed_wall = false
	var hit_wall = false
	for tick in 240:
		crash.input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
		crash.step(1.0 / 240, bt)
		Collisions.step(crash, bt, 1.0 / 240)
		hit_wall = hit_wall or crash.collided
		if (
			signf((Vector2(crash.x, crash.y) - aim).dot(aim - start_pt)) != side0
			and (Vector2(crash.x, crash.y) - aim).length() < 20
		):
			crossed_wall = true
	check(hit_wall and not crossed_wall, "a 300 km/h head-on hit does not pass through an auto barrier")

	# Tarmac runoff (paint 3): near-road grip but outside track limits; storage accepts it.
	var rt = straight_track()
	var probe_w = {"sIdx": -1}
	var cell = Vector2(0, 30)
	rt.data.paint[str(floori(cell.x / 2)) + "," + str(floori(cell.y / 2))] = 3
	var sf = rt.surface_at(cell.x, cell.y, probe_w)
	check(sf.id == 4 and sf.grip > .9, "tarmac runoff surface (grip %.2f)" % sf.grip)
	check(
		preload("res://scripts/storage.gd").new().validate_track(rt.data).is_empty(),
		"storage accepts runoff paint"
	)

	# Sectors: three splits per lap, purple on first valid lap, yellow when slower, ideal = sum of bests.
	var st = straight_track()
	var rc = RaceModel.new()
	var pc = make_car()
	var lap_flags = []
	for lap in 3:
		var dt = .05 if lap != 1 else .06
		for s in range(0, int(st.length), 1):
			var p = st.pos_at(float(s) - 5.0)
			pc.x = p.x
			pc.y = p.y
			rc.update(pc, st, dt)
		lap_flags.append(rc.flags.duplicate())
	var p0 = st.pos_at(-3.0)
	pc.x = p0.x
	pc.y = p0.y
	rc.update(pc, st, .05)
	p0 = st.pos_at(2.0)
	pc.x = p0.x
	pc.y = p0.y
	rc.update(pc, st, .05)
	check(
		rc.completed >= 2 and rc.last_sectors.min() > 0,
		"three sector splits per lap (%s)" % str(rc.last_sectors)
	)
	check(
		(
			rc.best_sectors.min() > 0
			and is_equal_approx(rc.ideal(), rc.best_sectors[0] + rc.best_sectors[1] + rc.best_sectors[2])
		),
		"ideal lap is the sum of best sectors (%.2f)" % rc.ideal()
	)
	check(
		rc.last_flags.has("yellow") or rc.last_flags.has("green"),
		"slower lap sectors are not purple (%s)" % str(rc.last_flags)
	)
	check(rc.sectors_dirty, "new best sectors request a save")

	print(
		(
			"HANDLING %s  %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
