extends SceneTree
## Ballistic flight: takeoff over a crest, zero tyre load in the air, and a landing that compresses
## the suspension. Uses a synthetic loop with one sharp crest, driven fast and then slowly as a
## control, so the result depends only on the solver and not on any circuit's survey data.

const TrackModel = preload("res://scripts/track3d.gd")
const CarModel = preload("res://scripts/car.gd")
const Collisions = preload("res://scripts/collisions.gd")

var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures.append(label)
		print("FAIL  ", label)


## Circle of radius r with a Gaussian crest of height h and width sigma (metres of arc) at s = 0.
func crest_doc(r, count, h, sigma):
	var points = []
	var circ = TAU * r
	for i in count:
		var th = TAU * i / count
		var s = wrapf(th * r, -circ / 2, circ / 2)
		points.append(
			{
				"x": r * cos(th),
				"y": r * sin(th),
				"z": h * exp(-s * s / (2 * sigma * sigma)),
				"w": 12.0,
				"bank": 0.0
			}
		)
	return {"schema": 1, "name": "Crest", "points": points, "startS": 0.0}


## Drive one lap at a held speed from 150 m before the crest and record flight.
func run(track, preset, target):
	var car = CarModel.new()
	car.simcade_enabled = false
	car.configure(preset)
	var start = track.length - 150.0
	var pose = track.pos_at(start)
	car.reset_pose({"x": pose.x, "y": pose.y, "h": pose.h})
	car.vx = cos(pose.h) * target
	car.vy = sin(pose.h) * target
	var out = {
		"flights": 0,
		"air_ticks": 0,
		"max_air": 0.0,
		"loaded_in_air": false,
		"landed": false,
		"compressed_on_landing": false,
		"finite": true
	}
	var was_air = false
	var after_landing = -1
	for tick in 30 * 240:
		var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
		var aim = track.pos_at(pr.s + 6 + car.speed * .25)
		var steer = clampf(wrapf(atan2(aim.y - car.y, aim.x - car.x) - car.h, -PI, PI) * 2.4, -1, 1)
		# Hold speed on the ground; coast in the air, where throttle does nothing useful.
		var err = target - car.speed
		car.input = {
			"throttle": 0.0 if car.airborne else clampf(err * .5, 0, 1),
			"brake": 0.0 if car.airborne else clampf(-err * .3, 0, 1),
			"steer": steer,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		car.step(1.0 / 240, track)
		Collisions.step(car, track, 1.0 / 240)
		if not is_finite(car.x + car.y + car.speed + car.air + car.z):
			out.finite = false
			break
		if car.airborne:
			out.air_ticks += 1
			out.max_air = maxf(out.max_air, car.air)
			for w in car.wheels:
				if w.load > 1e-6:
					out.loaded_in_air = true
			if not was_air:
				out.flights += 1
		elif was_air:
			out.landed = true
			after_landing = 0
		if after_landing >= 0:
			after_landing += 1
			if car.z > .01:
				out.compressed_on_landing = true
			if after_landing > 60:
				after_landing = -1
		was_air = car.airborne
		if tick > 240 * 8 and not car.airborne and out.landed:
			break
	out.air_time = out.air_ticks / 240.0
	return out


## Approach a real crest from 80 m out at a held speed and drive 200 m past it.
func drive_over(track, preset, crest, target):
	var car = CarModel.new()
	car.simcade_enabled = false
	car.configure(preset)
	var pose = track.pos_at(crest - 80.0)
	car.reset_pose({"x": pose.x, "y": pose.y, "h": pose.h})
	car.vx = cos(pose.h) * target
	car.vy = sin(pose.h) * target
	var out = {"flights": 0, "air_ticks": 0, "max_air": 0.0, "landed": false, "finite": true}
	var was_air = false
	for tick in 12 * 240:
		var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
		if wrapf(pr.s - crest, -track.length / 2, track.length / 2) > 200.0:
			break
		var aim = track.pos_at(pr.s + 8 + car.speed * .3)
		var steer = clampf(wrapf(atan2(aim.y - car.y, aim.x - car.x) - car.h, -PI, PI) * 2.0, -1, 1)
		var err = target - car.speed
		car.input = {
			"throttle": 0.0 if car.airborne else clampf(err * .5, 0, 1),
			"brake": 0.0 if car.airborne else clampf(-err * .3, 0, 1),
			"steer": steer,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		car.step(1.0 / 240, track)
		Collisions.step(car, track, 1.0 / 240)
		if not is_finite(car.x + car.y + car.speed + car.air):
			out.finite = false
			break
		if car.airborne:
			out.air_ticks += 1
			out.max_air = maxf(out.max_air, car.air)
			if not was_air:
				out.flights += 1
		elif was_air:
			out.landed = true
		was_air = car.airborne
	out.air_time = out.air_ticks / 240.0
	return out


func _initialize():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var track = TrackModel.new()
	# 3 m crest, sigma 14 m: peak vertical curvature about -1/65 per metre, so takeoff needs
	# v^2 > g * 65, roughly 25 m/s. 40 m/s flies; 15 m/s must not.
	track.load_data(crest_doc(400.0, 420, 3.0, 14.0))
	var sharpest = 0.0
	for sm in track.samples:
		sharpest = minf(sharpest, sm.kv)
	print(
		"crest: sharpest vertical curvature %.4f 1/m, takeoff above %.1f m/s"
		% [sharpest, sqrt(9.81 / -sharpest)]
	)

	var fast = run(track, presets.roadster, 40.0)
	check(fast.finite, "fast run stays finite")
	check(fast.flights >= 1, "the car leaves the ground over the crest at 40 m/s")
	check(fast.air_time > .15, "it stays airborne for %.2f s" % fast.air_time)
	check(fast.max_air > .15, "it rises %.2f m clear of the road" % fast.max_air)
	check(not fast.loaded_in_air, "no tyre carries load while airborne")
	check(fast.landed, "it lands again")
	check(fast.compressed_on_landing, "landing compresses the suspension")

	var slow = run(track, presets.roadster, 15.0)
	check(slow.finite, "slow control stays finite")
	check(slow.flights == 0, "at 15 m/s the same crest is driven, not jumped")

	# The Nordschleife's jumps, as authored by trackgen/jumps.gd. Each crest must fly a car without
	# downforce near its modelled takeoff speed; the survey data alone needed 219-322 km/h.
	var nord = TrackModel.new()
	nord.load_data(
		JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Nurburgring-Nordschleife.json"))
	)
	nord.build_barriers()
	var crest_s = {}
	for spec in [["Flugplatz", 160.0], ["Sprunghügel", 150.0], ["Pflanzgarten", 150.0]]:
		for l in nord.data.presentation.labels:
			if l.name == spec[0]:
				var centre = nord.project(Vector3(float(l.x), float(l.y), nord.probe_height(-1))).s
				var crest = 0.0
				var at = centre
				for d in range(-150, 151, 1):
					var k = nord.pose_at(centre + d).kv
					if k < crest:
						crest = k
						at = centre + d
				crest_s[spec[0]] = at
				var kmh = sqrt(9.81 / maxf(-crest, 1e-6)) * 3.6
				check(
					absf(kmh - spec[1]) < spec[1] * .05,
					"%s flies a no-downforce car from %.0f km/h (modelled %.0f)" % [spec[0], kmh, spec[1]]
				)

	# Drive the roadster over Pflanzgarten from 80 m out: it must fly at 175 km/h and not at 120.
	var jump = drive_over(nord, presets.roadster, crest_s["Pflanzgarten"], 175.0 / 3.6)
	check(jump.finite and jump.flights >= 1, "the roadster leaves the ground at Pflanzgarten at 175 km/h")
	check(jump.landed, "and lands again (%.2f s airborne, %.2f m clear)" % [jump.air_time, jump.max_air])
	var crawl = drive_over(nord, presets.roadster, crest_s["Pflanzgarten"], 120.0 / 3.6)
	check(crawl.finite and crawl.flights == 0, "at 120 km/h Pflanzgarten is driven, not jumped")

	print(
		(
			"AIRBORNE %s  %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
