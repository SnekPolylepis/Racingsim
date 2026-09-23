extends "res://tests/dynamics.gd"
## P2-07: the driver aids and Simcade on the 6-DOF CarBody, against the legacy targets. This suite IS
## tests/dynamics.gd (Simulation behaviour bands and the whole `-- --simcade` suite), with make()
## returning a CarBody that drives on flat ground under the harness's TrackModel, so every procedure,
## controller and threshold is the legacy one, unedited:
##   Simulation  tyre peaks, 0-100, 100-0 and skidpad bands; lift / brake / power at 90 % of the limit;
##               one minute of cornering heat; full stick at 80 and 160 km/h with the grip assist.
##   Simcade     Simcade vs Simulation within 8 %, tyre plateau, full lock at 80/120/160, keyboard ASM 1,
##               lift / brake / power peaks and recovery with ASM 3 and with aids off, lift-off yaw, trail
##               braking yaw, heat soak, ratio plateau and sliding floor, grass and gravel coasts,
##               differential split, roll balance.
## Not ported: the planar "glancing contact" impulse check (scripts/collisions.gd acts on the planar
## state; car-vs-wall contact for CarBody is P4-03), and the bundled-track curvature checks (legacy
## JSON tracks, not the car).
## The roadster's Simcade 100-0 fails this suite's 8 % band on CarModel (baseline: 38.37 m vs 42.28 m,
## locked wheels sliding on Simcade's 0.87 floor); CarBody passes it with its own longitudinal sliding
## floor (data/simcade.json "carbody", P2-07).
## Run: tools/Godot.exe --headless --path . --script tests/v2/aids_simcade.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")


## The harness's TrackModel as a flat §5.2 surface: the ground plane y = 0, with the TrackModel's surface
## (tarmac, grass, gravel paint) under each contact.
class FlatTrack:
	extends RefCounted
	var track

	func _init(t):
		track = t

	func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
		if direction.y >= 0 or origin.y < 0:
			return {}
		var d = origin.y / -direction.y
		if d > max_dist:
			return {}
		var p = origin + direction * d
		var w = {"sIdx": hint}
		var sf = track.surface_at(p.x, p.z, w)
		return {"point": p, "normal": Vector3.UP, "distance": d, "surface": sf.id, "hint": int(w.sIdx)}


## CarBody driven by the legacy harness: reset_pose() places it on the ground plane, and state the
## harness writes into the planar fields after a reset (vx, vy, r) is taken on at the next step.
class BodyShim:
	extends "res://scripts/vehicle/car_body.gd"
	var pending = false
	var surfaces = {}

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

	func step(dt, track, automatic = true):
		if pending:
			vel = Vector3(vx, 0, vy)
			ang = Vector3(0, -r, 0)
			pending = false
		if not surfaces.has(track):
			surfaces[track] = FlatTrack.new(track)
		super.step(dt, surfaces[track], automatic)


func make(key):
	var c = BodyShim.new()
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


## tests/dynamics.gd _initialize()'s Simulation car checks, unchanged, without the track checks.
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


## tests/dynamics.gd's version without the planar collision-impulse check.
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
				for x in range(-800, -400):
					for y in range(12, 25):
						terrain.data.paint[str(x) + "," + str(y)] = 2
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


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	simulation_checks()
	var simulation_failures = failures.duplicate()
	run_simcade()
	print(
		"AIDS SIMCADE RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "simulation_failures": simulation_failures})
	)
	quit(0 if failures.is_empty() else 1)
