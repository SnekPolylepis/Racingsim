extends SceneTree
## P4-03 "props": knock-over trackside props (scripts/props/prop_body.gd, prop_set.gd) against the ground,
## walls and the 6-DOF CarBody, inside the physics frame.
##   rest        a cone left awake on flat ground and on an 8 degree ramp: does not move, falls asleep.
##   drop        a cone dropped from 1 m tumbling onto the proving ground's road (TrackSurface): lands,
##               never below the road, comes to rest on it.
##   hits        the 296 GT3 (1300 kg) coasting into a cone at 30, 100 and 200 km/h, braking once it
##               hits: the cone flies off ahead at 1-1.5x the car's speed and up off the road (the nose
##               rake, PropBody.NOSE_RAKE), never ends a tick inside the car's hull or below the
##               ground, comes to rest; the car loses a little speed in the hit (at most the head-on
##               bound (1 + e) m v / (M + m)), well under 1 km/h at 100 km/h.
##   momentum    the same hit in the void (no ground, no drag): the car-cone system keeps its horizontal
##               momentum exactly, and loses kinetic energy.
##   kinds       a bollard and a marker board hit at 100 km/h: fly and rest.
##   wall        a cone thrown at a 0.15 m armco rail at 25 m/s: never through, bounces back.
##   determinism the 100 km/h hit twice: identical final state.
##   proving     the proving ground's Props/ are found, seated on tarmac, asleep, clear of the BotLine.
##   cost        50 cones on the proving ground's road beside the car's path (asleep, µs per tick), and
##               awake: a car knocking a row of cones (µs per awake cone per tick).
## Run: tools/Godot.exe --headless --path . --script tests/v2/props.gd
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const GatesEnv = preload("res://tests/v2/gates_env.gd")
const TestSurface = preload("res://scripts/surface/test_surface.gd")
const PropBody = preload("res://scripts/props/prop_body.gd")
const PropSet = preload("res://scripts/props/prop_set.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const ProvingGround = preload("res://trackgen/proving_ground.gd")
const DT = 1.0 / 240
const WALL_Z = 50.0
var presets
var failures = []
var checks = 0
var results = {}
var frames = 0
var ran = false
var host
var proving


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize():
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	# An armco rail along x with its face at z = WALL_Z, track side z < WALL_Z (as tests/v2/barrier.gd).
	host = Node3D.new()
	var w = WallPath.new()
	w.name = "Armco"
	w.kind = WallBuilder.Kind.ARMCO
	w.track_side = WallPath.Side.LEFT
	var curve = Curve3D.new()
	curve.add_point(Vector3(-50, 0, WALL_Z))
	curve.add_point(Vector3(50, 0, WALL_Z))
	w.curve = curve
	host.add_child(w)
	w.bake()
	root.add_child(host)
	# The proving ground in its own physics world (the wall host sits at the origin too).
	proving = ProvingGround.build_asset()
	proving.prepare()
	var world = SubViewport.new()
	world.own_world_3d = true
	world.size = Vector2i(2, 2)
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(world)
	world.add_child(proving)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("PROPS RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	rest()
	drop()
	hits()
	momentum()
	kinds()
	wall()
	determinism()
	proving_props()
	cost()
	print("PROPS RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


func make_car(key = "f296gt3"):
	var c = CarBody.new()
	c.configure(presets[key])
	c.wear_enabled = false
	c.steer_falloff = 0.0
	for w in c.wheels:
		w.temp = c.setup.tempOpt
		w.core = c.setup.tempOpt
	return c


func coast():
	return {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}


func tilt_deg(p) -> float:
	return rad_to_deg(acos(clampf(p.basis().y.dot(Vector3.UP), -1.0, 1.0)))


## Lowest hull point's height above a flat ground at y = 0.
func lowest(p) -> float:
	var b = p.basis()
	var y = INF
	for q in p.points:
		y = minf(y, p.pos_y + (b * q).y)
	return y


## How deep the prop's deepest hull point is inside the car's hull box, metres; 0 when outside.
func inside_car(p, c) -> float:
	var b = c.basis()
	var centre = c.pos + b * c.hull_center
	var pb = p.basis()
	var worst = 0.0
	for q in p.points:
		var l = b.transposed() * (p.pos + pb * q - centre)
		var h = c.hull_half
		if absf(l.x) >= h.x or absf(l.y) >= h.y or absf(l.z) >= h.z:
			continue
		var d = minf(h.x - absf(l.x), minf(h.z - absf(l.z), h.y - absf(l.y)))
		worst = maxf(worst, d)
	return worst


func rest():
	for grade in [0.0, 8.0]:
		var ground = TestSurface.flat() if grade == 0.0 else TestSurface.ramp(grade)
		var props = PropSet.new(ground)
		var p = props.add("cone", Transform3D(Basis(), Vector3(5, 0, 0)))
		props.step(DT, [])
		var start = p.pos
		var tilt0 = tilt_deg(p)
		p.wake()
		props.awake.append(p)
		var slept = -1
		for i in 5 * 240:
			props.step(DT, [])
			if p.asleep and slept < 0:
				slept = i
		var drift = p.pos.distance_to(start)
		var tilt = absf(tilt_deg(p) - tilt0)
		results["rest %d deg" % grade] = {"drift_m": drift, "tilt_deg": tilt, "asleep_tick": slept}
		check(
			drift < .001 and tilt < .1 and slept >= 0 and slept < 240,
			(
				"cone left awake at rest on %s: moved %.5f m, tilted %.4f deg, asleep after %.2f s"
				% ["flat ground" if grade == 0.0 else "an 8 deg ramp", drift, tilt, slept * DT]
			)
		)


func drop():
	var props = PropSet.new(proving.surface(), proving)
	var at = proving.station(300.0).pos
	var tipped = Basis(Vector3(1, 0, 1).normalized(), 1.1)
	var p = props.add("cone", Transform3D(tipped, at + Vector3(0, 1.0, 0)), false)
	p.ang = Vector3(3, 1, -2)
	props.step(DT, [])
	var below = 0.0
	var slept = -1
	for i in 10 * 240:
		props.step(DT, [])
		var hit = proving.surface().contact(p.pos + Vector3(0, 2, 0), Vector3.DOWN, 5.0, -1)
		if not hit.is_empty():
			var b = p.basis()
			for q in p.points:
				below = maxf(below, (hit.point - (p.pos + b * q)).dot(hit.normal))
		if p.asleep:
			slept = i
			break
	var surf = proving.surface().contact(p.pos + Vector3(0, 1, 0), Vector3.DOWN, 3.0, -1)
	results["drop"] = {"below_m": below, "asleep_s": slept * DT, "surface": surf.get("surface", -1)}
	check(
		slept >= 0 and below < .01 and surf.get("surface", -1) == 0,
		(
			"cone dropped 1 m tumbling onto the proving ground's road: at most %.4f m below the road, asleep after %.2f s, on surface %d"
			% [below, slept * DT, surf.get("surface", -1)]
		)
	)


## The car coasting into a prop of `kind` at x = 30 m, heading +x, braking hard from the first contact.
## Returns a summary. `with_prop` false gives the reference run for the car's speed loss, braking from
## tick `brake_tick`.
func hit_run(kmh: float, kind = "cone", with_prop = true, brake_tick = -1):
	var ground = TestSurface.flat()
	var c = make_car()
	c.place(Vector3(0, 0, 0), 0.0, 0.0)
	c.launch(kmh / 3.6)
	var props = PropSet.new(ground)
	var p = props.add(kind, Transform3D(Basis(), Vector3(30, 0, 0)))
	var r = {
		"contact_ticks": 0,
		"first": -1,
		"car_v_before": 0.0,
		"top": 0.0,
		"top_height": 0.0,
		"inside": 0.0,
		"below": 0.0,
		"rest_s": -1.0,
		"travel": 0.0,
		"car_v_after": 0.0,
		"brake_from": brake_tick
	}
	var seconds = 25.0
	for i in int(seconds / DT):
		c.input = coast()
		var braking = r.brake_from
		if braking >= 0 and i >= braking:
			c.input.brake = 1.0
		var v_before = c.speed
		c.step(DT, ground, true)
		if with_prop:
			var n = props.step(DT, [c])
			if n > 0:
				r.contact_ticks += 1
				if r.first < 0:
					r.first = i
					r.brake_from = i + 1
					r.car_v_before = v_before
			r.top = maxf(r.top, p.vel.length())
			r.top_height = maxf(r.top_height, lowest(p))
			r.inside = maxf(r.inside, inside_car(p, c))
			r.below = minf(r.below, lowest(p))
			if r.first >= 0 and p.asleep and r.rest_s < 0:
				r.rest_s = (i - r.first) * DT
		# Just after the first hit (the head-on bound is per hit; a fast cone can come down on the nose).
		if braking >= 0 and i == braking + 1:
			r.car_v_after = c.speed
		if r.rest_s >= 0 and c.speed < .1:
			break
	r.travel = p.pos.distance_to(Vector3(30, p.cg, 0))
	r["hash"] = hash(
		[c.pos_x, c.pos_y, c.pos_z, c.vel, c.rot, c.ang, p.pos_x, p.pos_y, p.pos_z, p.rot, p.ang]
	)
	r["car"] = c
	r["prop"] = p
	return r


func hits():
	for kmh in [30.0, 100.0, 200.0]:
		var r = hit_run(kmh)
		var ref = hit_run(kmh, "cone", false, r.brake_from)
		var loss = (ref.car_v_after - r.car_v_after) * 3.6
		var v = r.car_v_before
		var m = r.prop.mass
		var big_m = r.car.p.mass
		var bound = (1 + r.prop.restitution) * m * v / (big_m + m) * 3.6
		var ratio = r.top / maxf(v, 1e-9)
		results["hit %d" % kmh] = {
			"car_loss_kmh": loss,
			"bound_kmh": bound,
			"cone_top_ratio": ratio,
			"cone_top_height_m": r.top_height,
			"inside_m": r.inside,
			"below_m": r.below,
			"rest_s": r.rest_s,
			"travel_m": r.travel,
			"contact_ticks": r.contact_ticks
		}
		check(
			(
				r.first >= 0
				and (kmh < 100.0 or r.top_height > .3)
				and ratio > 1.0
				and ratio < 1.5
				and r.inside < .01
				and r.below > -.01
				and r.rest_s > 0
				and loss > 0
				and loss <= bound * 1.02
				and (kmh != 100.0 or loss < .5)
			),
			(
				"%d km/h into a cone: it flies at %.2fx the car's speed, up to %.2f m off the ground, rests %.0f m away after %.1f s; at most %.4f m inside the hull, %.4f m below the ground; car loses %.3f km/h (bound %.3f), %d contact ticks"
				% [
					kmh,
					ratio,
					r.top_height,
					r.travel,
					r.rest_s,
					r.inside,
					-r.below,
					loss,
					bound,
					r.contact_ticks
				]
			)
		)


## A 100 km/h hit in the void: car and cone both in free fall, no drag on the cone. Across each
## props.step() the car and the cone only exchange impulses (gravity on the cone is vertical), so their
## horizontal momentum is unchanged, and the pair loses energy: at most the kinetic energy of their
## relative motion, 1/2 mu v^2 with mu = m M / (m + M).
func momentum():
	var c = make_car()
	c.place(Vector3(0, 0, 0), 0.0, 0.0)
	c.launch(100.0 / 3.6)
	var void_space = TestSurface.void_space()
	var props = PropSet.new(void_space)
	var p = props.add("cone", Transform3D(Basis(), Vector3(8, 0, .3)), false)
	p.drag_area = 0.0
	var m_car = c.p.mass
	var touched = 0
	var drift = 0.0
	var exchanged = 0.0
	var lost = 0.0
	var v_rel = 0.0
	for i in 240:
		c.input = coast()
		c.step(DT, void_space, true)
		# 64-bit scalars throughout (a Vector2 would round to 32 bits).
		var px0 = c.vel_x * m_car + p.vel_x * p.mass
		var pz0 = c.vel_z * m_car + p.vel_z * p.mass
		var ppx0 = p.vel_x * p.mass
		var ppz0 = p.vel_z * p.mass
		var e0 = energy(c, p)
		var rel = (p.vel - c.vel).length()
		var n = props.step(DT, [c])
		if n == 0:
			continue
		if touched == 0:
			v_rel = rel
		touched += n
		var dx = c.vel_x * m_car + p.vel_x * p.mass - px0
		var dz = c.vel_z * m_car + p.vel_z * p.mass - pz0
		drift += sqrt(dx * dx + dz * dz)
		var ex = p.vel_x * p.mass - ppx0
		var ez = p.vel_z * p.mass - ppz0
		exchanged += sqrt(ex * ex + ez * ez)
		lost += e0 - energy(c, p)
	var mu = p.mass * m_car / (p.mass + m_car)
	var most = .5 * mu * v_rel * v_rel
	var dp = drift / maxf(exchanged, 1e-9)
	results["momentum"] = {
		"contacts": touched, "exchanged_ns": exchanged, "rel_dp": dp, "lost_j": lost, "most_j": most
	}
	check(
		touched > 0 and exchanged > 50.0 and dp < 1e-9 and lost > 0 and lost <= most,
		(
			"100 km/h hit in free fall: %d contact points exchange %.1f N s; horizontal momentum kept to %s of it; %.0f J lost of at most %.0f J"
			% [touched, exchanged, String.num_scientific(dp), lost, most]
		)
	)


## Kinetic plus potential energy of the car body and the prop.
func energy(c, p) -> float:
	var ke = .5 * c.p.mass * c.vel.length_squared() + .5 * c.ang.dot(c.inertia * c.ang) + p.kinetic()
	return ke + (c.p.mass * c.pos_y + p.mass * p.pos_y) * PropBody.G


func kinds():
	for kind in ["bollard", "marker_board"]:
		var r = hit_run(100.0, kind)
		results["hit 100 " + kind] = {
			"top_ratio": r.top / maxf(r.car_v_before, 1e-9),
			"inside_m": r.inside,
			"below_m": r.below,
			"rest_s": r.rest_s
		}
		var ratio = r.top / maxf(r.car_v_before, 1e-9)
		check(
			(
				r.first >= 0
				and ratio > 1.0
				and ratio < 1.5
				and r.inside < .01
				and r.below > -.01
				and r.rest_s > 0
			),
			(
				"100 km/h into a %s: flies at %.2fx, at most %.4f m inside the hull, %.4f m below the ground, rests after %.1f s"
				% [kind, ratio, r.inside, -r.below, r.rest_s]
			)
		)


func wall():
	var ground = TestSurface.flat()
	var props = PropSet.new(ground, host)
	var p = props.add("cone", Transform3D(Basis(), Vector3(0, 0, WALL_Z - 3)), false)
	p.pos_y += .4
	p.vel = Vector3(0, 1.5, 25)
	var past = -INF
	var back = 0.0
	for i in 4 * 240:
		props.step(DT, [])
		var b = p.basis()
		for q in p.points:
			past = maxf(past, p.pos_z + (b * q).z - WALL_Z)
		back = minf(back, p.vel_z)
	results["wall"] = {"past_m": past, "rebound": -back}
	check(
		past < .01 and back < -1.0 and p.pos_z < WALL_Z,
		(
			"cone thrown at the armco at 25 m/s: at most %+.4f m past the face, bounces back at %.1f m/s"
			% [past, -back]
		)
	)


func determinism():
	var a = hit_run(100.0)
	var b = hit_run(100.0)
	results["determinism"] = a.hash == b.hash
	check(a.hash == b.hash, "100 km/h hit run twice: identical final car and cone state")


func proving_props():
	var props = PropSet.from_asset(proving)
	var n = props.props.size()
	props.step(DT, [])
	var line = proving.get_node("BotLine").curve
	var clear = INF
	var on_tarmac = 0
	for p in props.props:
		var hit = proving.surface().contact(p.pos + Vector3(0, 1, 0), Vector3.DOWN, 3.0, -1)
		if hit.get("surface", -1) == 0:
			on_tarmac += 1
		var near = line.get_closest_point(p.pos)
		clear = minf(clear, Vector2(near.x - p.pos.x, near.z - p.pos.z).length())
	for i in 240:
		props.step(DT, [])
	results["proving"] = {
		"props": n, "on_tarmac": on_tarmac, "botline_clear_m": clear, "awake": props.awake_count()
	}
	check(
		n >= 3 and on_tarmac == n and props.awake_count() == 0 and clear > 4.0,
		(
			"proving ground: %d props, %d on tarmac, all asleep, at least %.1f m from the BotLine"
			% [n, on_tarmac, clear]
		)
	)


func cost():
	var surf = proving.surface()
	var c = make_car()
	var props = PropSet.new(surf, proving)
	# 50 cones 4.5 m right of the lap line, every 12 m, and the car driving the line past them.
	for k in 50:
		var st = proving.station(20.0 + k * 12.0)
		var right = st.tangent.cross(Vector3.UP).normalized()
		props.add("cone", Transform3D(Basis(), st.pos + right * 4.5))
	props.step(DT, [])
	var ticks = 0
	var t_asleep = 0
	for k in 600:
		var st = proving.station(10.0 + k * .12)
		var fwd = st.tangent
		c.place(st.pos, atan2(fwd.z, fwd.x), st.pos.y)
		c.launch(28.8)
		c.mark_pose()
		c.pos_x += fwd.x * .12
		c.pos_z += fwd.z * .12
		var t0 = Time.get_ticks_usec()
		props.step(DT, [c])
		t_asleep += Time.get_ticks_usec() - t0
		ticks += 1
	var asleep_us = float(t_asleep) / ticks
	var woke = props.awake_count()
	# Awake: a car at 100 km/h through a row of 10 cones on flat ground, µs per awake cone per tick.
	var flat = TestSurface.flat()
	var row = PropSet.new(flat)
	for k in 10:
		row.add("cone", Transform3D(Basis(), Vector3(20 + k * 3.0, 0, -.6 + .12 * k)))
	var car = make_car()
	car.place(Vector3.ZERO, 0.0, 0.0)
	car.launch(100.0 / 3.6)
	var t_awake = 0
	var cone_ticks = 0
	for i in 3 * 240:
		car.input = coast()
		car.step(DT, flat, true)
		var t0 = Time.get_ticks_usec()
		row.step(DT, [car])
		t_awake += Time.get_ticks_usec() - t0
		cone_ticks += row.awake_count()
	var awake_us = float(t_awake) / maxf(cone_ticks, 1)
	results["cost_us"] = {"asleep_50": asleep_us, "per_awake_cone": awake_us, "woken_passing": woke}
	check(
		woke == 0 and (not GatesEnv.perf() or (asleep_us < 15.0 and awake_us < 150.0)),
		(
			"cost: 50 sleeping cones beside a passing car %.1f µs per tick (none woken); %.1f µs per awake cone per tick%s"
			% [asleep_us, awake_us, GatesEnv.perf_note()]
		)
	)
