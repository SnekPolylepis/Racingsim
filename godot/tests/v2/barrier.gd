extends SceneTree
## P4-03: car-vs-wall contact for the 6-DOF CarBody (REBUILD-PLAN.md P4-03, section 6 Barrier row).
## Real WallPath walls (concrete 0.4 m, armco 0.15 m, tyre wall 0.9 m thick; concave collision on layer 2),
## one per 300 m, each 100 m long along x with its inner face at z = 100 and the track at z < 100. The car
## drives on TestSurface.flat and meets the walls through WallQuery / WallContact inside the physics frame.
##   head-on    300 km/h square into each kind, Simulation and Simcade: the hull never ends a tick past
##              the wall face (no pass-through, 0.35 m per tick against a 0.15 m rail), energy only lost.
##   glancing   150 km/h at 10 degrees into concrete: rebound speed within the wall's restitution of the
##              closing speed, keeps sliding along, energy only lost.
##   resting    parked against the wall for 3 s: no creep or jitter, no penetration.
##   over       airborne 3 m above a 1 m wall: no contact (walls have height; collisions.gd's did not).
##   oblique    300 km/h at 45 degrees into armco: no pass-through.
##   corner     a concrete wall (face z = 100) meets a tyre wall (face x = CORNER_X) at a right angle:
##              a hull pressed into both reports each wall's kind with its own face normal
##              (F-P4-03-corners). 150 km/h at 45 degrees into it, and into one L-shaped concrete wall
##              bending 90 degrees at x = L_X, both handling models: never past either face, energy only
##              lost. (One wall body reports one face normal, from its deepest point; see WallQuery.)
##   cost       WallContact per tick, clear of walls and in contact.
## Run: tools/Godot.exe --headless --path . --script tests/v2/barrier.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const DT = 1.0 / 240
const FACE_Z = 100.0
## x of each wall's middle, and its kind.
const WALLS = {"concrete": 0.0, "armco": 300.0, "tyre": 600.0}
## The corner: the concrete wall runs along x to CORNER_X, the tyre wall along z back from the face.
const CORNER_X = 950.0
## The single L-shaped concrete wall: along x to L_X, then back along z.
const L_X = 1250.0
var host
var presets
var failures = []
var checks = 0
var results = {}
var frames = 0
var ran = false
var ground = TestSurface.flat()


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func make(key, simcade = false):
	var c = CarBody.new()
	c.simcade_enabled = simcade
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
	return .5 * c.p.mass * c.vel.length_squared() + .5 * c.ang.dot(c.inertia * c.ang)


## How far the hull reaches past the wall face (z > FACE_Z), metres; negative = clear of it.
func past_face(c):
	var b = c.basis()
	var reach = -INF
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var corner = c.pos + b * (c.hull_center + c.hull_half * Vector3(sx, sy, sz))
				reach = maxf(reach, corner.z - FACE_Z)
	return reach


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	host = Node3D.new()
	var kinds = {
		"concrete": WallBuilder.Kind.CONCRETE, "armco": WallBuilder.Kind.ARMCO, "tyre": WallBuilder.Kind.TYRE
	}
	for name in WALLS:
		var w = WallPath.new()
		w.name = name.capitalize()
		w.kind = kinds[name]
		w.track_side = WallPath.Side.LEFT
		var curve = Curve3D.new()
		curve.add_point(Vector3(WALLS[name] - 50, 0, FACE_Z))
		curve.add_point(Vector3(WALLS[name] + 50, 0, FACE_Z))
		w.curve = curve
		host.add_child(w)
		w.bake()
	# Corner walls. A freehand wall's outward side is tangent x up when the track is on its left, so the
	# concrete one runs +x (outward +z) and the tyre one runs -z (outward +x); they overlap past the corner.
	# CornerL is one concrete wall with the same two faces, bending 90° at x = L_X.
	for spec in [
		[
			"CornerConcrete",
			WallBuilder.Kind.CONCRETE,
			Vector3(CORNER_X - 100, 0, FACE_Z),
			Vector3(CORNER_X + 10, 0, FACE_Z)
		],
		[
			"CornerTyre",
			WallBuilder.Kind.TYRE,
			Vector3(CORNER_X, 0, FACE_Z + 10),
			Vector3(CORNER_X, 0, FACE_Z - 100)
		],
		[
			"CornerL",
			WallBuilder.Kind.CONCRETE,
			Vector3(L_X - 100, 0, FACE_Z),
			Vector3(L_X, 0, FACE_Z),
			Vector3(L_X, 0, FACE_Z - 100)
		]
	]:
		var w = WallPath.new()
		w.name = spec[0]
		w.kind = spec[1]
		w.track_side = WallPath.Side.LEFT
		var curve = Curve3D.new()
		for point in spec.slice(2):
			curve.add_point(point)
		w.curve = curve
		host.add_child(w)
		w.bake()
	root.add_child(host)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("BARRIER RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	head_on()
	glancing()
	resting()
	over()
	oblique()
	corner()
	cost()
	print("BARRIER RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


## Drive at `kmh` from `start` with heading `h` (legacy sense) for `seconds`, walls on; returns a summary.
func run(key, simcade, start: Vector3, h: float, kmh: float, seconds: float, steer = 0.0):
	var c = make(key, simcade)
	var query = WallQuery.new(host, c.hull_half)
	c.place(start, h, 0.0)
	c.launch(kmh / 3.6)
	var worst_past = -INF
	var ke0 = kinetic(c)
	var ke_after_first = INF
	var first_contact = -1
	var vn_before = 0.0
	var rebound = 0.0
	var ok = true
	for i in int(seconds / DT):
		c.input = inp(0, 0, steer)
		var vz_before = c.vel_z
		c.step(DT, ground, true)
		var hits = WallContact.step(c, query)
		if hits > 0 and first_contact < 0:
			first_contact = i
			vn_before = vz_before
		if first_contact >= 0:
			# A glancing hit lasts several ticks while the car yaws: take the fastest the CG ever moves
			# away from the wall afterwards, and the energy once the first contact is over.
			rebound = maxf(rebound, -c.vel_z)
			if hits == 0 and ke_after_first == INF:
				ke_after_first = kinetic(c)
		worst_past = maxf(worst_past, past_face(c))
		ok = ok and finite(c)
	return {
		"car": c,
		"past": worst_past,
		"ke0": ke0,
		"ke1": ke_after_first,
		"ke_end": kinetic(c),
		"contact_tick": first_contact,
		"vn_before": vn_before,
		"rebound": rebound,
		"end_z": c.pos_z,
		"ok": ok
	}


func head_on():
	var rows = []
	var all_ok = true
	for simcade in [false, true]:
		for name in WALLS:
			var r = run("f296gt3", simcade, Vector3(WALLS[name], 0, FACE_Z - 60), PI / 2, 300, 2.0)
			var model = "simcade" if simcade else "simulation"
			results["head-on %s %s" % [model, name]] = {
				"past_m": r.past, "end_z": r.end_z, "contact_tick": r.contact_tick
			}
			var ok = r.ok and r.contact_tick >= 0 and r.past < .01 and r.end_z < FACE_Z and r.ke_end < r.ke0
			all_ok = all_ok and ok
			rows.append(
				(
					"%s %s: hull at most %+.3f m past the face, CG ends %.2f m short"
					% [model, name, r.past, FACE_Z - r.end_z]
				)
			)
	for row in rows:
		print("      " + row)
	check(
		all_ok,
		"296 at 300 km/h square into concrete, armco (0.15 m) and tyre walls, both handling models: never through, energy only lost"
	)


func glancing():
	var angle = deg_to_rad(10.0)
	var start = Vector3(WALLS.concrete - 40, 0, FACE_Z - 40 * tan(angle) - 3)
	var r = run("f296gt3", false, start, angle, 150, 2.5)
	var c = r.car
	var bounce = WallContact.RESPONSE.concrete[0]
	var rebound = r.rebound / maxf(r.vn_before, 1e-6)
	var along = c.vel_x
	results["glancing"] = {
		"rebound_ratio": rebound,
		"vn_before": r.vn_before,
		"rebound": r.rebound,
		"along": along,
		"past": r.past
	}
	# The CG may leave a little faster than bounce x closing speed: the car yaws off the wall, and the
	# rotation it picked up carries the far end outward. 0.1 above the restitution bounds that.
	check(
		(
			r.ok
			and r.contact_tick >= 0
			and r.past < .01
			and rebound <= bounce + .1
			and along > 25
			and r.ke1 <= r.ke0
		),
		(
			"150 km/h at 10° into concrete: rebounds at %.2f of the %.2f m/s closing speed (restitution %.2f), still %.1f m/s along the wall, hull at most %+.3f m past the face, energy %.1f%% after contact"
			% [rebound, r.vn_before, bounce, along, r.past, r.ke1 / r.ke0 * 100]
		)
	)


func resting():
	var c = make("f296gt3")
	var query = WallQuery.new(host, c.hull_half)
	# Side-on against the wall: body z extent half-width, so the CG sits hull_half.z + 5 mm from the face.
	c.place(Vector3(WALLS.concrete, 0, FACE_Z - c.hull_half.z - .005), 0.0, 0.0)
	var worst_speed = 0.0
	var worst_away = 0.0
	var worst_past = -INF
	var touching = 0
	for i in 240 * 3:
		# Steer and creep toward the wall: the car must lean on it, neither pass through nor bounce off.
		c.input = inp(.05, 0, .3)
		c.step(DT, ground, true)
		touching += 1 if WallContact.step(c, query) > 0 else 0
		if i > 240:
			worst_speed = maxf(worst_speed, absf(c.vel_z))
			worst_away = maxf(worst_away, -c.vel_z)
		worst_past = maxf(worst_past, past_face(c))
	results["resting"] = {
		"lateral_speed": worst_speed, "away_speed": worst_away, "past": worst_past, "ticks_touching": touching
	}
	check(
		finite(c) and worst_past < .005 and worst_speed < .1 and worst_away < .02 and touching > 240,
		(
			"creeping and steering into the concrete wall for 3 s: CG across the wall at most %.3f m/s (away %.3f), hull at most %+.4f m past the face, touching on %d of 720 ticks"
			% [worst_speed, worst_away, worst_past, touching]
		)
	)


func over():
	var c = make("f296gt3")
	var query = WallQuery.new(host, c.hull_half)
	# Well above the 1.0 m concrete wall, moving across it; the ground is far below (void for this test).
	c.place(Vector3(WALLS.concrete, 0, FACE_Z - 10), PI / 2, 4.0)
	c.vel = Vector3(0, 0, 30)
	var hits = 0
	for i in 240:
		c.pos_y = 4.0 + c.setup.cgHeight
		c.vel_y = 0.0
		c.mark_pose()
		c.pos_z += c.vel_z * DT
		hits += WallContact.step(c, query)
	check(
		hits == 0 and c.pos_z > FACE_Z + 5,
		(
			"flying 3 m over the 1 m concrete wall at 108 km/h: %d wall contacts, crossed to z %.1f"
			% [hits, c.pos_z]
		)
	)


func oblique():
	var angle = deg_to_rad(45.0)
	var start = Vector3(WALLS.armco - 30, 0, FACE_Z - 30)
	var r = run("f296gt3", false, start, angle, 300, 1.5)
	results["oblique armco"] = {"past": r.past, "end_z": r.end_z}
	check(
		r.ok and r.contact_tick >= 0 and r.past < .01 and r.end_z < FACE_Z and r.ke_end < r.ke0,
		(
			"300 km/h at 45° into the 0.15 m armco: hull at most %+.3f m past the face, CG ends %.2f m short, energy only lost"
			% [r.past, FACE_Z - r.end_z]
		)
	)


## How far the hull reaches past either corner face (z > FACE_Z or x > face_x), metres.
func past_corner(c, face_x):
	var b = c.basis()
	var reach = -INF
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var p = c.pos + b * (c.hull_center + c.hull_half * Vector3(sx, sy, sz))
				reach = maxf(reach, maxf(p.z - FACE_Z, p.x - face_x))
	return reach


func corner():
	corner_case("concrete/tyre corner", CORNER_X, true)
	corner_case("L-shaped concrete wall", L_X, false)


## `two_walls`: concrete face z = FACE_Z and tyre face x = face_x, and the static contact check runs;
## otherwise one concrete wall with both faces, driven into only.
func corner_case(label: String, face_x: float, two_walls: bool):
	if two_walls:
		corner_contacts(label, face_x)
	# Driven into the corner at 45°: no pass-through either way, in both handling models.
	var rows = []
	var all_ok = true
	for simcade in [false, true]:
		var c = make("f296gt3", simcade)
		var query = WallQuery.new(host, c.hull_half)
		c.place(Vector3(face_x - 40, 0, FACE_Z - 40), PI / 4, 0.0)
		c.launch(150 / 3.6)
		var ke0 = kinetic(c)
		var worst = -INF
		var touched = false
		var ok = true
		for i in int(2.0 / DT):
			c.input = inp(0, 0, 0)
			c.step(DT, ground, true)
			touched = WallContact.step(c, query) > 0 or touched
			worst = maxf(worst, past_corner(c, face_x))
			ok = ok and finite(c)
		var model = "simcade" if simcade else "simulation"
		results[label + " " + model] = {"past": worst, "end": c.pos}
		ok = ok and touched and worst < .01 and c.pos.x < face_x and c.pos.z < FACE_Z and kinetic(c) < ke0
		all_ok = all_ok and ok
		rows.append("%s: hull at most %+.3f m past either face" % [model, worst])
	for row in rows:
		print("      " + row)
	check(
		all_ok,
		"150 km/h at 45° into the " + label + ", both handling models: never through, energy only lost"
	)


## A parked hull pressed 1 cm into both walls of the corner: every contact names its own wall and face.
func corner_contacts(label: String, face_x: float):
	var c = make("f296gt3")
	var query = WallQuery.new(host, c.hull_half)
	c.place(Vector3(face_x - 20, 0, FACE_Z - 20), 0.0, 0.0)
	var b = c.basis()
	var reach = Vector3(-INF, 0, -INF)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p = b * (c.hull_center + c.hull_half * Vector3(sx, 0, sz))
			reach = Vector3(maxf(reach.x, p.x), 0, maxf(reach.z, p.z))
	var centre = Vector3(face_x + .01 - reach.x, c.pos.y, FACE_Z + .01 - reach.z) + b * c.hull_center
	var cs = query.contacts(Transform3D(b, centre))
	var seen = {}
	var faces = {"z": false, "x": false}
	var normals_ok = true
	for k in cs:
		seen[k.kind] = true
		faces.z = faces.z or k.normal.dot(Vector3(0, 0, -1)) > .9
		faces.x = faces.x or k.normal.dot(Vector3(-1, 0, 0)) > .9
		var want = Vector3(0, 0, -1) if k.kind == "concrete" else Vector3(-1, 0, 0)
		normals_ok = normals_ok and k.normal.dot(want) > .9
	results[label + " contacts"] = cs.map(func(k): return [k.kind, k.normal, snappedf(k.depth, .001)])
	var kinds_ok = seen.has("concrete") and seen.has("tyre")
	check(
		kinds_ok and normals_ok and faces.z and faces.x,
		(
			"hull pressed into both faces of the %s: %d contacts, kinds %s, each with its own face normal"
			% [label, cs.size(), seen.keys()]
		)
	)


func cost():
	var c = make("f296gt3")
	var query = WallQuery.new(host, c.hull_half)
	# Moving 0.1 m per tick (86 km/h) so the sweep runs: in the open, then sliding along the wall face.
	c.place(Vector3(WALLS.concrete - 40, 0, 0), 0.0, 0.0)
	var t0 = Time.get_ticks_usec()
	for i in 480:
		c.mark_pose()
		c.pos_x += .1
		WallContact.step(c, query)
	var clear = float(Time.get_ticks_usec() - t0) / 480
	c.place(Vector3(WALLS.concrete - 40, 0, FACE_Z - c.hull_half.z), 0.0, 0.0)
	t0 = Time.get_ticks_usec()
	for i in 480:
		c.mark_pose()
		c.pos_x += .1
		WallContact.step(c, query)
	var touching = float(Time.get_ticks_usec() - t0) / 480
	results["cost_us"] = {"clear": clear, "touching": touching}
	check(
		(clear < 60 and touching < 150) or not GatesEnv.perf(),
		(
			"wall contact costs %.1f µs per tick clear of walls, %.1f µs touching one%s"
			% [clear, touching, GatesEnv.perf_note()]
		)
	)
