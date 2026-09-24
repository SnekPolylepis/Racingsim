extends SceneTree
## Drives the Caracciola-Karussell and asserts the car actually falls into the concrete.
##
## This is the regression for the complaint the 3-D work exists to answer: the circuit looked
## three dimensional but drove flat. Two things caused that, and both are checked here.
##
## The road surface had no cross-section, so a Karussell was flat road with a cross-slope, and the
## per-wheel road deviation fed to the suspension was clamped to 12 cm, which is smaller than the
## feature. A car could not drop a wheel into a trough that the physics could not describe.
##
## The control is the same car on the same circuit through Antoniusbuche, a flat straight, where
## none of this should do anything at all.

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


func station_of(track, label_name):
	for l in track.data.presentation.labels:
		if l.name == label_name:
			return track.project(Vector3(float(l.x), float(l.y), track.probe_height(-1))).s
	return -1.0


## Drive from `entry` metres before the corner to `exit` metres after, holding a steady speed with
## a simple pursuit controller, and report what the chassis did.
func drive(track, presets, start_s, distance, target_speed):
	var car = CarModel.new()
	car.simcade_enabled = false
	car.configure(presets.roadster)
	var pose = track.pos_at(start_s)
	car.reset_pose({"x": pose.x, "y": pose.y, "h": pose.h})
	car.vx = cos(pose.h) * target_speed
	car.vy = sin(pose.h) * target_speed
	var out = {"roll": 0.0, "dev": 0.0, "lift": 0, "min_load": 1e9, "travelled": 0.0, "finite": true}
	var begun = car.x
	for tick in 120 * 240:
		var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
		var travelled = wrapf(pr.s - start_s, -track.length / 2, track.length / 2)
		if travelled > distance:
			break
		out.travelled = travelled
		# Aim a little ahead of the projection and hold the target speed.
		var aim = track.pos_at(pr.s + 6 + car.speed * .25)
		var steer = clampf(wrapf(atan2(aim.y - car.y, aim.x - car.x) - car.h, -PI, PI) * 2.4, -1, 1)
		var err = target_speed - car.speed
		car.input = {
			"throttle": clampf(err * .5, 0, 1),
			"brake": clampf(-err * .3, 0, 1),
			"steer": steer,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		car.step(1.0 / 240, track)
		Collisions.step(car, track, 1.0 / 240)
		if not is_finite(car.x + car.y + car.speed + car.roll):
			out.finite = false
			break
		out.roll = maxf(out.roll, absf(car.roll))
		var lightest = 1e9
		for w in car.wheels:
			out.dev = maxf(out.dev, absf(w.dev))
			lightest = minf(lightest, w.load)
		out.min_load = minf(out.min_load, lightest)
		if lightest <= 0.01:
			out.lift += 1
	return out


func _initialize():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var track = TrackModel.new()
	track.load_data(
		JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Nurburgring-Nordschleife.json"))
	)
	track.build_barriers()

	var karussell_s = station_of(track, "Caracciola-Karussell")
	var flat_s = station_of(track, "Antoniusbuche")
	check(karussell_s > 0 and flat_s > 0, "located the Karussell and the control straight")

	# Control first: a flat straight must stay flat.
	var flat = drive(track, presets, flat_s - 60, 220.0, 30.0)
	check(flat.finite, "control run stays finite")
	check(flat.dev < .05, "flat straight barely deviates (%.3f m)" % flat.dev)
	check(rad_to_deg(flat.roll) < 2.0, "flat straight barely rolls (%.2f deg)" % rad_to_deg(flat.roll))
	check(flat.lift == 0, "no wheel lifts on the flat straight")

	# The Karussell itself. The concrete is a metre-plus trough, so the chassis must drop into it:
	# the per-wheel road deviation has to exceed what the old 12 cm clamp allowed, and the car has
	# to roll into the banking rather than ride across the top of it.
	var kar = drive(track, presets, karussell_s - 70, 190.0, 22.0)
	check(kar.finite, "Karussell run stays finite")
	check(kar.travelled > 150.0, "drove %.0f m through the corner" % kar.travelled)
	check(kar.dev > .12, "wheels leave the old 12 cm clamp behind: peak deviation %.2f m" % kar.dev)
	check(
		rad_to_deg(kar.roll) > 2.5,
		(
			"chassis rolls into the banking (%.2f deg, flat control %.2f deg)"
			% [rad_to_deg(kar.roll), rad_to_deg(flat.roll)]
		)
	)
	check(kar.roll > flat.roll * 2.0, "Karussell roll is far beyond the control run")
	check(kar.min_load < flat.min_load, "a corner unloads over the concrete that never unloads flat")

	print(
		(
			"KARUSSELL %s  %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
