extends SceneTree
## P2-06: tyre footprint contact and kerb behaviour (REBUILD-PLAN.md P2-06, 5.2).
##   envelope    a wheel of radius R stepped in 1 mm increments across a sharp 5 cm TestSurface.step:
##               the footprint's bottom-point height against the exact rigid-wheel envelope
##               max(0, h - (R - sqrt(R^2 - u^2))), u the distance to the edge; the contact normal (the
##               ground's); the largest change between neighbouring positions. Going up and
##               down the step, and with the edge running along the wheel (a kerb met from the side,
##               against the rounded-shoulder tread profile).
##   smooth      on smooth analytic ground (flat, ramp, side slope, crest, bowl, ditch floor) with the
##               chassis tilted by up to 3 degrees, the footprint returns the centre ray bit for bit.
##   dynamic     the 296 GT3 driven over the sharp 5 cm step at 50 and 150 km/h, straight and at 10
##               degrees, and off it; footprint and single ray side by side: the per-tick jump in
##               wheel compression, peak wheel load, and speed lost.
##               The footprint must never be harsher than the single ray, and must spread the climb.
##   rest        a car parked with its front-left tyre's shoulder on a pad edge settles, no creep or jitter.
##   road        a road baked by the road tool (P3-02 ramp kerbs) plus a sharp-edged 5 cm kerb strip, on a
##               TrackSurface (real mesh faces): weaving over the kerbs at 80 km/h, the footprint stays in
##               the 0.3 ms per car tick budget (section 6) and is never harsher than the single ray.
## Normals come from the ground (5.2). Tyre compliance and unsprung mass are not modelled, so a
## rigid-tyre normal leaning off an edge would feed the full climb rate into the damper; see the log.
## Run: tools/Godot.exe --headless --path . --script tests/v2/footprint.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TyreFootprint = preload("res://scripts/vehicle/tyre_footprint.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const DT = 1.0 / 240
const R = .33
const TREAD = .28
const H = .05
var presets
var failures = []
var checks = 0
var results = {}
var frames = 0
var ran = false
var road_host


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


## Footprint of a level wheel whose bottom point would sit at y = 0 on flat ground, origin 1 m above.
func probe(surf, at: Vector3, fwd: Vector3, footprint = true):
	var origin = at + Vector3(0, 1, 0)
	var side = fwd.cross(Vector3.UP)
	var centre = surf.contact(origin, Vector3.DOWN, 2.0, -1)
	if not footprint:
		return centre
	return TyreFootprint.contact(surf, origin, Vector3.DOWN, fwd, side, 2.0, -1, R, TREAD, centre)


## Rigid-wheel lift over a sharp step of height H whose edge is `u` ahead of the bottom point (u <= 0:
## the bottom point is already over the top).
func along_lift(u):
	if u <= 0:
		return H
	if u >= R:
		return 0.0
	return maxf(0.0, H - (R - sqrt(R * R - u * u)))


## Lift of the tread when the edge runs along the wheel `u` to its side: flat tread, then the shoulder.
func across_lift(u):
	if u <= 0:
		return H
	if u > TREAD * .5:
		return 0.0
	return maxf(0.0, H - TyreFootprint.drop(0.0, u, R, TREAD))


## Sweep a wheel across a sharp step at x = 0 in 1 mm steps. `dir` +1 climbs (heading +x), -1 descends
## (heading -x, from the top). `along` false turns the wheel to run along the edge (heading +z) and
## sweeps it sideways onto the top.
func sweep(dir, along):
	var surf = TestSurface.step(0.0, H)
	var worst = 0.0
	var worst_single = 0.0
	var jump = 0.0
	var jump_single = 0.0
	var tilt = 0.0
	var prev = NAN
	var prev_single = NAN
	var prev_want = NAN
	var want_jump = 0.0
	var fwd = Vector3(dir, 0, 0) if along else Vector3(0, 0, 1)
	for k in range(-400, 401):
		var x = k * .001
		var hit = probe(surf, Vector3(x, 0, 0), fwd)
		var single = probe(surf, Vector3(x, 0, 0), fwd, false)
		var lift = 1.0 - hit.distance
		var lift_single = 1.0 - single.distance
		# Distance from the bottom point to the edge, towards the edge; <= 0 on the top.
		var u = -x
		var want = along_lift(u) if along else across_lift(u)
		worst = maxf(worst, absf(lift - want))
		worst_single = maxf(worst_single, absf(lift_single - want))
		if not is_nan(prev):
			jump = maxf(jump, absf(lift - prev))
			jump_single = maxf(jump_single, absf(lift_single - prev_single))
			want_jump = maxf(want_jump, absf(want - prev_want))
		prev = lift
		prev_single = lift_single
		prev_want = want
		# Normals come from the ground (5.2): both the step's faces are level.
		tilt = maxf(tilt, rad_to_deg(hit.normal.angle_to(Vector3.UP)))
	# Descending is the same geometry mirrored: heading -x from the top, the edge falls away behind.
	return {
		"worst_mm": worst * 1000,
		"single_worst_mm": worst_single * 1000,
		"jump_mm": jump * 1000,
		"single_jump_mm": jump_single * 1000,
		"envelope_jump_mm": want_jump * 1000,
		"normal_tilt_deg": tilt
	}


func envelope():
	var up = sweep(1, true)
	results["envelope along"] = up
	check(
		up.worst_mm < 2.0 and up.jump_mm < up.envelope_jump_mm + 1.0 and up.normal_tilt_deg < .01,
		(
			"5 cm step met head-on: lift within %.2f mm of the rigid-wheel envelope, largest change per mm %.2f mm (envelope's own %.2f), normal tilt %.3f deg (single ray: %.1f mm off, jumps %.1f mm)"
			% [
				up.worst_mm,
				up.jump_mm,
				up.envelope_jump_mm,
				up.normal_tilt_deg,
				up.single_worst_mm,
				up.single_jump_mm
			]
		)
	)
	var down = sweep(-1, true)
	results["envelope down"] = down
	check(
		down.worst_mm < 2.0 and down.jump_mm < down.envelope_jump_mm + 1.0,
		(
			"5 cm step rolling off (edge behind): lift within %.2f mm of the envelope, largest change per mm %.2f mm (envelope's own %.2f) (single ray: %.1f mm off, jumps %.1f mm)"
			% [down.worst_mm, down.jump_mm, down.envelope_jump_mm, down.single_worst_mm, down.single_jump_mm]
		)
	)
	var across = sweep(1, false)
	results["envelope across"] = across
	check(
		across.worst_mm < 3.0 and across.jump_mm < across.envelope_jump_mm + 3.0,
		(
			"5 cm step met from the side: lift within %.2f mm of the flat-tread, rounded-shoulder profile, largest change per mm %.2f mm (profile's own %.2f) (single ray: %.1f mm off, jumps %.1f mm)"
			% [
				across.worst_mm,
				across.jump_mm,
				across.envelope_jump_mm,
				across.single_worst_mm,
				across.single_jump_mm
			]
		)
	)


## Smooth ground: the footprint is the centre ray, bit for bit, whatever the chassis tilt (<= 3 deg).
func smooth():
	var surfaces = {
		"flat": TestSurface.flat(),
		"8 deg ramp": TestSurface.ramp(8.0),
		"12 deg side slope": TestSurface.side_slope(12.0),
		"R 200 crest": TestSurface.crest(0.0, 200.0, 20.0, 40.0),
		"20 deg bowl": TestSurface.bowl(100.0, 20.0),
		"ditch floor": TestSurface.ditch(1.5, 37.0, 1.1, .5)
	}
	var rng = RandomNumberGenerator.new()
	rng.seed = 6
	var differ = []
	var tried = 0
	for name in surfaces:
		var surf = surfaces[name]
		for k in 200:
			var x = rng.randf_range(-30, 30)
			var z = rng.randf_range(-.5, .5) if name == "ditch floor" else rng.randf_range(-30, 30)
			if name == "20 deg bowl":
				x = 100.0 + rng.randf_range(-5, 5)
			var ground = surf.height(x, z)
			var n = surf.normal(x, z)
			var tilt = Basis(
				Vector3(rng.randf(), 0, rng.randf()).normalized(), deg_to_rad(rng.randf_range(0, 3))
			)
			var up = (tilt * n).normalized()
			var heading = rng.randf_range(-PI, PI)
			var fwd = (
				Vector3(cos(heading), 0, sin(heading)) - up * Vector3(cos(heading), 0, sin(heading)).dot(up)
			)
			fwd = fwd.normalized()
			var origin = Vector3(x, ground, z) + up * 1.0
			var centre = surf.contact(origin, -up, 2.0, -1)
			var copy = centre.duplicate()
			var hit = TyreFootprint.contact(surf, origin, -up, fwd, fwd.cross(up), 2.0, -1, R, TREAD, centre)
			tried += 1
			if hit.distance != copy.distance or hit.normal != copy.normal or hit.point != copy.point:
				differ.append(name)
	results["smooth_differ"] = differ.size()
	check(
		differ.is_empty(),
		(
			"smooth ground (flat, ramp, side slope, crest, bowl, ditch floor; chassis tilted up to 3 deg): footprint equals the centre ray bit for bit in %d/%d poses"
			% [tried - differ.size(), tried]
		)
	)


## Drive the 296 across the step at `kmh`, `yaw_deg` off square, climbing (up) or descending.
func cross(kmh, yaw_deg, up, footprint):
	var surf = TestSurface.step(0.0, H) if up else TestSurface.step(0.0, -H)
	var c = make("f296gt3")
	c.footprint = footprint
	c.setup.cdA = 0.0
	var heading = deg_to_rad(yaw_deg)
	c.place(Vector3(-15 * cos(heading), 0, -15 * sin(heading)), heading, 0.0)
	c.launch(kmh / 3.6)
	var static_load = c.p.mass * 9.81 / 4
	var v0 = c.speed
	var peak = 0.0
	var jump = 0.0
	var prev = [0.0, 0.0, 0.0, 0.0]
	var ok = true
	var min_contacts = 4
	var ticks = int((30.0 / (kmh / 3.6)) / DT)
	for i in ticks:
		c.input = inp(0, 0, 0)
		c.step(DT, surf, true)
		ok = ok and finite(c)
		for k in 4:
			var w = c.wheels[k]
			peak = maxf(peak, w.load / static_load)
			if i > 0:
				jump = maxf(jump, absf(w.comp - prev[k]))
			prev[k] = w.comp
		min_contacts = mini(min_contacts, c.contacts)
	var yaw_rate = absf(c.ang.y)
	return {
		"ok": ok,
		"peak_load": peak,
		"comp_jump_mm": jump * 1000,
		"speed_lost_kmh": (v0 - c.speed) * 3.6,
		"min_contacts": min_contacts,
		"yaw_rate_after": yaw_rate
	}


func dynamic():
	var rows = []
	var all_ok = true
	var harsher = []
	var climb = 0.0
	var runs = 0
	for spec in [
		[50, 0, true], [150, 0, true], [50, 10, true], [150, 10, true], [50, 0, false], [150, 0, false]
	]:
		var fp = cross(spec[0], spec[1], spec[2], true)
		var single = cross(spec[0], spec[1], spec[2], false)
		var name = "%s %d km/h at %d deg" % ["up" if spec[2] else "down", spec[0], spec[1]]
		results["cross " + name] = {"footprint": fp, "single": single}
		all_ok = all_ok and fp.ok and single.ok
		runs += 1
		if fp.peak_load > single.peak_load * 1.02 or fp.comp_jump_mm > single.comp_jump_mm + .1:
			harsher.append(name)
		if name == "up 50 km/h at 0 deg":
			climb = fp.comp_jump_mm
		rows.append(
			(
				"%s: jump %.1f mm (single %.1f), peak load %.2fx (single %.2fx), lost %.2f km/h (single %.2f)"
				% [
					name,
					fp.comp_jump_mm,
					single.comp_jump_mm,
					fp.peak_load,
					single.peak_load,
					fp.speed_lost_kmh,
					single.speed_lost_kmh
				]
			)
		)
	for row in rows:
		print("      " + row)
	check(
		all_ok,
		"the 296 crosses a sharp 5 cm step up and down at 50 and 150 km/h, square and at 10 deg: no NaN"
	)
	check(
		harsher.is_empty(),
		(
			"footprint is never harsher than the single ray (peak load within 2 %%, per-tick compression jump no larger) in %d/%d crossings %s"
			% [runs - harsher.size(), runs, harsher]
		)
	)
	# At 50 km/h the tyre's curve rolls onto the 5 cm edge over sqrt(2 R h) ~ 0.18 m, about 3 ticks: no
	# tick may take more than 60 %% of the step (the single ray takes all of it in one).
	check(
		climb <= H * 1000 * .6,
		(
			"climbing the step square at 50 km/h, the largest per-tick compression jump is %.1f mm of the 50 mm step (limit 30 mm)"
			% climb
		)
	)


## A parked car with its front-left wheel on the step edge: settles, no creep, no jitter.
func rest():
	var c = make("f296gt3")
	var fl = Vector3(c.p.a, 0, -c.p.track * .5)
	# A 5 cm pad outboard of the front-left wheel, its edge 10 cm from the wheel's centre line: under
	# the tread's rounded shoulder, which leans the contact normal sideways.
	var surf = TestSurface.block(fl.x, fl.z - .4, .5, .3, H)
	c.place(Vector3.ZERO, 0.0, 0.0)
	var start = c.pos
	var drift = 0.0
	var spin = 0.0
	for i in 240 * 4:
		c.input = inp(0, 0, 0)
		c.step(DT, surf, true)
		if i >= 240 * 3:
			drift = maxf(drift, c.speed)
			spin = maxf(spin, c.ang.length())
	var moved = Vector2(c.pos_x - start.x, c.pos_z - start.z).length()
	results["rest on edge"] = {"moved_m": moved, "speed": drift, "spin": spin, "fl_load": c.wheels[0].load}
	check(
		finite(c) and drift < .01 and spin < .01 and moved < .05,
		(
			"parked with the front-left tyre's shoulder on the edge of a 5 cm pad: after 3 s speed %.4f m/s, spin %.4f rad/s, moved %.3f m in 4 s"
			% [drift, spin, moved]
		)
	)


## A 200 m straight with ramp kerbs both sides (road tool, P3-02) for the TrackSurface cost run.
func build_road():
	var host = Node3D.new()
	var road = RoadPath.new()
	road.name = "Road"
	road.closed = false
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(300, 0, 0))
	road.curve = c
	var sec = {
		"kerb_left": RoadSection.Kerb.RAMP,
		"kerb_right": RoadSection.Kerb.RAMP,
		"kerb_width": 1.0,
		"kerb_height": .05,
		"verge_surface": 2
	}
	road.sections.assign([RoadSection.make(0.0, sec), RoadSection.make(300.0, sec)])
	host.add_child(road)
	road.bake()
	# A sharp-edged 5 cm kerb strip on the left of the road (a box on layer 1, kerb surface), so the
	# weave crosses real edges and the footprint bisects them.
	var strip = StaticBody3D.new()
	strip.set_meta("surface", 1)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(260, .1, .6)
	shape.shape = box
	strip.add_child(shape)
	strip.position = Vector3(150, 0, -3.5)
	host.add_child(strip)
	return host


## Weave across the road, over both kerbs, on a TrackSurface: cost per car tick with the footprint.
func road_cost():
	var surf = TrackSurface.new(road_host)
	var hit = surf.contact(Vector3(20, 5, 0), Vector3.DOWN, 10)
	var half = 0.0
	for z in range(0, 200):
		var h = surf.contact(Vector3(20, 5, z * .05), Vector3.DOWN, 10)
		if not h.is_empty() and h.surface == 1:
			half = z * .05
			break
	var measured = {}
	for footprint in [false, true]:
		var c = make("f296gt3")
		c.footprint = footprint
		c.place(Vector3(10, hit.point.y, 0), 0.0, hit.point.y)
		c.launch(80 / 3.6)
		var us = 0
		var worst = 0
		var n = 0
		var rays = 0
		var on_kerb = 0
		var ok = true
		var min_contacts = 4
		var peak = 0.0
		var yaw = 0.0
		while c.pos_x < 280 and n < 240 * 20:
			# Weave across the road: a look-ahead point on a sine that swings the wheels over the kerb
			# strip and onto both ramp kerbs; speed held at 80 km/h (as tests/v2/road_tool.gd lap()).
			var ahead = c.pos_x + 12
			var want = atan2(sin(ahead * .05) * (half + .3) - c.pos_z, ahead - c.pos_x)
			var st = clampf(wrapf(want - c.h, -PI, PI) * 2.5, -1, 1)
			var e = 80 / 3.6 - c.speed
			c.input = inp(clampf(e * .5 + .3, 0, 1), clampf(-e * .3, 0, 1), st)
			var t0 = Time.get_ticks_usec()
			c.step(DT, surf, true)
			var took = Time.get_ticks_usec() - t0
			us += took
			worst = maxi(worst, took)
			n += 1
			rays += c.footprint_rays
			ok = ok and finite(c)
			min_contacts = mini(min_contacts, c.contacts)
			yaw = maxf(yaw, absf(c.ang.y))
			for w in c.wheels:
				peak = maxf(peak, w.load / (c.p.mass * 9.81 / 4))
			if c.contacts < 3 and OS.get_cmdline_user_args().has("--diag"):
				print(
					(
						"DIAG fp=%s x=%.2f z=%.3f y=%.3f contacts=%d loads=%s comps=%s ang=%s vy=%.3f"
						% [
							footprint,
							c.pos_x,
							c.pos_z,
							c.pos_y,
							c.contacts,
							c.wheels.map(func(w): return snappedf(w.load, 1)),
							c.wheels.map(func(w): return snappedf(w.comp, .001)),
							c.ang,
							c.vel_y
						]
					)
				)
			for w in c.wheels:
				if w.surf.id == 1:
					on_kerb += 1
		measured["footprint" if footprint else "single"] = {
			"us_per_tick": float(us) / n,
			"worst_us": worst,
			"rays_per_tick": float(rays) / n,
			"kerb_wheel_ticks": on_kerb,
			"ok": ok,
			"end_x": c.pos_x,
			"end_speed_kmh": c.speed * 3.6,
			"ticks": n,
			"min_contacts": min_contacts,
			"peak_load": peak,
			"max_yaw_rate": yaw
		}
	results["road cost"] = measured
	var fp = measured.footprint
	var single = measured.single
	check(
		fp.ok and fp.kerb_wheel_ticks > 240 and fp.us_per_tick < 300,
		(
			"TrackSurface road with ramp kerbs and a sharp 5 cm kerb strip, weaving over them at 80 km/h: %.1f µs per car tick with the footprint (%.1f rays, slowest tick %d µs), single ray %.1f µs (budget 300 µs mean); %d wheel-ticks on kerb"
			% [fp.us_per_tick, fp.rays_per_tick, fp.worst_us, single.us_per_tick, fp.kerb_wheel_ticks]
		)
	)
	# Mesh kerb faces are real faces: rays that strike them must not carry the tyre (it once gave
	# 500 kN spikes and spun the car here).
	check(
		(
			fp.peak_load <= single.peak_load * 1.02
			and fp.max_yaw_rate <= single.max_yaw_rate + .05
			and fp.min_contacts >= single.min_contacts
		),
		(
			"on that road the footprint is never harsher than the single ray: peak wheel load %.2fx static (single %.2fx), yaw rate up to %.2f rad/s (single %.2f), at least %d wheels down (single %d)"
			% [
				fp.peak_load,
				single.peak_load,
				fp.max_yaw_rate,
				single.max_yaw_rate,
				fp.min_contacts,
				single.min_contacts
			]
		)
	)


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	envelope()
	smooth()
	dynamic()
	rest()
	road_host = build_road()
	root.add_child(road_host)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("FOOTPRINT RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	road_cost()
	print("FOOTPRINT RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true
