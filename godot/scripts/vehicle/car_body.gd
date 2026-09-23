extends "res://scripts/car.gd"
## 6-DOF rigid-body chassis on ray suspension (REBUILD-PLAN.md P2; spike P2-00, rig P2-03).
## World is Godot-native (+Y up, metres). Body frame: +X forward, +Y up, +Z right. Wheels FL, FR, RL, RR.
## Angular velocity is body-frame, right-hand rule: +y yaws left, +x rolls the right side down,
## +z pitches the nose up. Driver steer > 0 still steers right.
##
## Tyre, drivetrain and aids are the shared scripts/vehicle modules (P2-01), evaluated here in each
## contact patch's own frame; only step() is this chassis's own. World position and velocity are
## 64-bit scalars (5.1). Suspension rays start above the mount; anti-roll bars keep acting through a
## lifted wheel; the body box makes contact with the ground when the car bottoms, lands or rolls.
## The legacy plan-view fields (x, y, h, vx, vy, r, speed, vbx, vby, ax, ay) are mirrored from the
## 3D state every tick so the inherited aids and the drivetrain read what they always read.

## Wheel centre to suspension top at static ride height, metres. Arbitrary: only moves the mount point.
const STATIC_LENGTH = .15
## Suspension rays start this far above the mount, so ground that rises past the mount (a steep wall,
## a kerb under a bottomed corner) still returns a hit, and the bump stop sees the real penetration
## instead of a ray that starts inside the surface.
const RAY_LIFT = .5
## Chassis box used for body-to-ground contact, relative to the axles and the static ground plane.
const BODY_OVERHANG = .8
const BODY_SIDE = .12
const BODY_CLEARANCE = .1
const BODY_HEIGHT = 1.25
## Chassis contact: penalty spring and damper per contact point, and sliding friction on the ground.
const BODY_STIFFNESS = 200000.0
const BODY_DAMPING = 12000.0
const BODY_FRICTION = .6
const TyreFootprint = preload("res://scripts/vehicle/tyre_footprint.gd")

## World position and velocity of the CG in 64-bit scalars (5.1 precision contract). Godot's Vector3
## is 32-bit: at 5 km from the origin it cannot represent sub-0.5 mm steps, so a slow car froze.
## `pos` and `vel` remain as Vector3 views for relative, local and presentation use.
var pos_x = 0.0
var pos_y = 0.0
var pos_z = 0.0
var vel_x = 0.0
var vel_y = 0.0
var vel_z = 0.0
var pos: Vector3:
	get:
		return Vector3(pos_x, pos_y, pos_z)
	set(value):
		pos_x = value.x
		pos_y = value.y
		pos_z = value.z
var vel: Vector3:
	get:
		return Vector3(vel_x, vel_y, vel_z)
	set(value):
		vel_x = value.x
		vel_y = value.y
		vel_z = value.z
var rot = Quaternion.IDENTITY
var ang = Vector3.ZERO
## Principal inertias about body x (roll), y (yaw), z (pitch).
var inertia = Vector3.ONE
## Per wheel: suspension top in the body frame, spring free length, static compression.
var mount = []
var free_length = []
var static_comp = []
var contacts = 0
var accel = Vector3.ZERO
## Chassis box contact points in the body frame (sills, then roof), and how many touched this tick.
var body_points = []
var body_contacts = 0
## Tyre footprint contact (P2-06): off gives the single centre ray per wheel, for comparison.
var footprint = true
## Tread width for the footprint, metres (preset "treadWidth", else TyreFootprint.DEFAULT_TREAD).
var tread = TyreFootprint.DEFAULT_TREAD
## Surface queries made by the footprints last tick (centre rays included).
var footprint_rays = 0


func configure(preset):
	super(preset)
	rig()


## Suspension geometry from the preset: at static ride the CG sits cgHeight above flat ground.
## A spring at its free length carries nothing, so each corner can extend by its static
## compression before unloading, exactly the old model's droop allowance.
func rig():
	inertia = Vector3(p.iroll, p.izz, p.ipitch)
	tread = float(p.get("treadWidth", TyreFootprint.DEFAULT_TREAD))
	mount.clear()
	free_length.clear()
	static_comp.clear()
	var stf = p.mass * G * p.b / (p.a + p.b) / 2
	var strr = p.mass * G * p.a / (p.a + p.b) / 2
	for i in 4:
		var front = i < 2
		var comp = (stf if front else strr) / (setup.springF if front else setup.springR)
		static_comp.append(comp)
		free_length.append(STATIC_LENGTH + comp)
		mount.append(Vector3(wheels[i].bx, -setup.cgHeight + p.wheelR + STATIC_LENGTH, wheels[i].by))
	# Chassis box: sills at ground clearance and roof at body height (both above the static ground
	# plane), front and rear overhang beyond the axles, a little wider than the track.
	var front_x = p.a + BODY_OVERHANG
	var rear_x = -p.b - BODY_OVERHANG
	var side = p.track * .5 + BODY_SIDE
	var sill = -setup.cgHeight + BODY_CLEARANCE
	var roof = -setup.cgHeight + BODY_HEIGHT
	body_points.clear()
	for bx in [front_x, 0.0, rear_x]:
		for bz in [-side, side]:
			body_points.append(Vector3(bx, sill, bz))
	for bx in [p.a * .4, -p.b * .6]:
		for bz in [-side * .8, side * .8]:
			body_points.append(Vector3(bx, roof, bz))


## Place the car at rest on the ground below `at`, heading in the legacy sense
## (forward = (cos h, 0, sin h)).
func place(at: Vector3, heading: float, ground_y: float):
	reset_pose({"x": at.x, "y": at.z, "h": heading})
	rig()
	pos_x = at.x
	pos_y = ground_y + setup.cgHeight
	pos_z = at.z
	rot = Quaternion(Vector3.UP, -heading)
	vel = Vector3.ZERO
	ang = Vector3.ZERO
	sync_legacy()


## Place the car at rest on `surface` at (px, pz), body aligned with the surface normal there.
func place_on(surface, px: float, pz: float, heading: float):
	place(Vector3(px, 0, pz), heading, 0.0)
	var n = surface.normal(px, pz)
	var want = Vector3(cos(heading), 0, sin(heading))
	var fwd = (want - n * want.dot(n)).normalized()
	rot = Basis(fwd, n, fwd.cross(n)).get_rotation_quaternion()
	pos_x = px + n.x * setup.cgHeight
	pos_y = surface.height(px, pz) + n.y * setup.cgHeight
	pos_z = pz + n.z * setup.cgHeight
	sync_legacy()


## Give a placed car forward speed with rolling wheels, in the gear a driver would be in
## (engine below 75 % of redline), engine speed matched. Mirrors tests/dynamics.gd stick().
func launch(v: float):
	vel = basis().x * v
	for w in wheels:
		w.omega = v / p.wheelR
	for g in range(1, int(p.get("gears", 6)) + 1):
		gear = g
		engine_w = v / p.wheelR * setup["gear" + str(g)] * setup.finalDrive
		if engine_w * 30 / PI < p.redline * .75:
			break
	sync_legacy()


func basis():
	return Basis(rot)


func sync_legacy():
	var b = basis()
	var fwd = b.x
	var right = b.z
	x = pos_x
	y = pos_z
	h = atan2(fwd.z, fwd.x)
	vx = vel_x
	vy = vel_z
	r = -ang.y
	speed = sqrt(vel_x * vel_x + vel_y * vel_y + vel_z * vel_z)
	vbx = vel_x * fwd.x + vel_y * fwd.y + vel_z * fwd.z
	vby = vel_x * right.x + vel_y * right.y + vel_z * right.z
	ax = accel.dot(fwd)
	ay = accel.dot(right)
	elev = pos_y - setup.cgHeight


## Advance one fixed tick. `surface` implements contact(origin, direction, max_dist, hint).
func step(dt, surface, automatic = true):
	var s = setup
	var m = p.mass
	sync_legacy()
	steering(vbx, vby)
	stability_request()
	var b = basis()
	var up = b.y
	var w_world = b * ang
	var stf = m * G * p.b / (p.a + p.b) / 2
	var strr = m * G * p.a / (p.a + p.b) / 2
	var nominal = m * G / 4
	var force = Vector3(0, -m * G, 0)
	var torque = Vector3.ZERO
	var hits = []
	var comp = [0.0, 0.0, 0.0, 0.0]
	var rate = [0.0, 0.0, 0.0, 0.0]
	var here = pos
	var v = vel
	footprint_rays = 0
	# Suspension: a centre ray per wheel along the chassis -Y, starting RAY_LIFT above the mount, then
	# the tyre footprint around it (P2-06).
	for i in 4:
		var top = here + b * mount[i]
		var reach = RAY_LIFT + free_length[i] + p.wheelR
		var hit = surface.contact(top + up * RAY_LIFT, -up, reach, wheels[i].sIdx)
		var ray_offset = RAY_LIFT
		# If the first hit is above the mount, check for a lower deck inside wheel reach. A raised
		# road still needs the lifted ray, but a close overhead deck must not replace the road below.
		if not hit.is_empty() and hit.distance < RAY_LIFT:
			var lower = surface.contact(top, -up, free_length[i] + p.wheelR, wheels[i].sIdx)
			if not lower.is_empty() and lower.distance > 1e-4:
				hit = lower
				ray_offset = 0.0
				reach = free_length[i] + p.wheelR
		if footprint:
			var sa = steer_angle if i < 2 else 0.0
			hit = TyreFootprint.contact(
				surface,
				top + up * ray_offset,
				-up,
				b * Vector3(cos(sa), 0, sin(sa)),
				b * Vector3(-sin(sa), 0, cos(sa)),
				reach,
				wheels[i].sIdx,
				p.wheelR,
				tread,
				hit
			)
			if not hit.is_empty():
				footprint_rays += hit.rays
		hits.append(hit)
		if hit.is_empty():
			continue
		var n = hit.normal
		var top_vel = v + w_world.cross(top - here)
		# Beyond free_length + wheel radius of compression the ground is above the mount; the bump
		# stop then answers the real penetration, continuously.
		comp[i] = free_length[i] - (hit.distance - ray_offset - p.wheelR)
		# Compression rate from the mount's velocity into the contact normal (first order: ignores the
		# ray direction's own rotation). On a kerb edge the footprint's normal leans back from the edge,
		# so the rate includes the climb the tyre's curvature makes onto it.
		rate[i] = -n.dot(top_vel) / maxf(n.dot(up), .05)
	var loads = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		if hits[i].is_empty():
			continue
		var front = i < 2
		var k = s.springF if front else s.springR
		var c = (s.bumpF if front else s.bumpR) if rate[i] > 0 else (s.reboundF if front else s.reboundR)
		loads[i] = k * comp[i] + c * rate[i]
		var over = comp[i] - static_comp[i] - SUSP_TRAVEL
		if over > 0:
			loads[i] += k * BUMP_STOP_RATE * over
	for axle in [[0, 1, s.arbF, s.springF], [2, 3, s.arbR, s.springR]]:
		var add = arb_pair(
			axle[2],
			axle[3],
			comp[axle[0]],
			comp[axle[1]],
			not hits[axle[0]].is_empty(),
			not hits[axle[1]].is_empty()
		)
		loads[axle[0]] += add[0]
		loads[axle[1]] += add[1]
	contacts = 0
	all_off = true
	var torques = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		var w = wheels[i]
		var hit = hits[i]
		w.comp = comp[i] - static_comp[i]
		w.load = maxf(0.0, loads[i]) if not hit.is_empty() else 0.0
		if hit.is_empty() or w.load <= 0:
			w.load = 0.0
			w.fx = 0.0
			w.fy = 0.0
			w.ellipse = 0.0
			w.mz = 0.0
			w.skidding = false
			torques[i] = 0.0
			cool(w, dt)
			continue
		contacts += 1
		var n = hit.normal
		var point = hit.point
		w.sIdx = hit.hint
		w.roadZ = point.y
		w.wx = point.x
		w.wy = point.z
		w.surf = TrackModel.SURF[hit.surface]
		var sf = w.surf
		if sf.id <= 1:
			all_off = false
		# Contact frame: wheel heading projected into the tangent plane; right = forward x normal.
		var sa = steer_angle if i < 2 else 0.0
		var heading = b * Vector3(cos(sa), 0, sin(sa))
		var fwd = (heading - n * heading.dot(n)).normalized()
		var side = fwd.cross(n)
		var cvel = v + w_world.cross(point - here)
		var vwx = cvel.dot(fwd)
		var vwy = cvel.dot(side)
		var tyre = VehicleTyre.contact_forces(self, w, i, sf, vwx, vwy, dt, stf, strr)
		var fx = tyre[0]
		var fy = tyre[1]
		var fxr = tyre[2]
		var fyr = tyre[3]
		var sv = tyre[4]
		var radius = tyre[5]
		var f = fwd * (fx + fxr) + side * (fy + fyr) + n * w.load
		force += f
		torque += (point - here).cross(f)
		torques[i] = -fx * radius
		VehicleTyre.finish_contact(self, w, fx, fy, sv, vwy, nominal, dt, sf)
	airborne = contacts == 0
	steer_torque = wheels[0].mz + wheels[1].mz
	drivetrain(dt, torques, automatic)
	# Aero: downforce at each axle along the body's down axis, drag at the CG against the velocity.
	var q = .5 * RHO * speed * speed
	var down_f = -up * q * s.clAF
	var down_r = -up * q * s.clAR
	force += down_f + down_r
	torque += (b * Vector3(p.a, 0, 0)).cross(down_f) + (b * Vector3(-p.b, 0, 0)).cross(down_r)
	force -= v * (.5 * RHO * s.cdA * speed)
	var chassis = body_contact(surface, b, up, v, w_world, here, dt)
	force += chassis[0]
	torque += chassis[1]
	var body_torque = b.transposed() * torque
	if simcade_enabled:
		var beta = atan2(vby, maxf(absf(vbx), 1))
		var excess = maxf(0, absf(beta) - peak_slip_angle())
		# Dissipative yaw moment beyond the rear slip peak, as car.gd. No direct state clamp.
		body_torque.y -= p.izz * ang.y * simcade.yaw_damping * clampf(excess / peak_slip_angle(), 0, 1)
	# Semi-implicit Euler: velocities first, then positions from the new velocities. Linear state
	# integrates in 64-bit scalars.
	accel = force / m + Vector3(0, G, 0)
	vel_x += force.x / m * dt
	vel_y += force.y / m * dt
	vel_z += force.z / m * dt
	ang += body_torque / inertia * dt
	ang = gyro(ang, dt)
	if contacts > 0 and speed < .4 and input.throttle < .02:
		# Standstill hold, as car.gd: bleed tangential creep when gravity along the ground is negligible.
		var n_avg = Vector3.ZERO
		for hit in hits:
			if not hit.is_empty():
				n_avg += hit.normal
		n_avg = n_avg.normalized()
		var g_tan = Vector3(0, -G, 0) - n_avg * n_avg.dot(Vector3(0, -G, 0))
		if g_tan.length() < .02 * G:
			var normal_speed = n_avg.x * vel_x + n_avg.y * vel_y + n_avg.z * vel_z
			var normal_v = n_avg * normal_speed
			vel_x = normal_v.x + (vel_x - normal_v.x) * .96
			vel_y = normal_v.y + (vel_y - normal_v.y) * .96
			vel_z = normal_v.z + (vel_z - normal_v.z) * .96
			ang.y *= .96
	pos_x += vel_x * dt
	pos_y += vel_y * dt
	pos_z += vel_z * dt
	var spin = ang.length() * dt
	if spin > 1e-12:
		rot = (rot * Quaternion(ang / ang.length(), spin)).normalized()
	for w in wheels:
		w.phase = fposmod(w.phase + w.omega * dt, TAU)
	sync_legacy()


## Chassis-to-ground contact at the body box points, so a rolled, bottomed or landing car rests on its
## sills or roof instead of passing through the surface. Each point is probed with a ray from the CG
## (inside the body) out to the point; a hit short of the point means the point is below the surface.
## Force per point: penalty spring on the penetration along the surface normal, damping only while
## closing, and sliding friction clamped like the tyre need clamps to what stops the slide this tick.
## Probed only when contact is plausible (a wheel off the ground, tilted past ~25°, a corner near its
## bump stop, or falling fast), so ordinary driving costs nothing; roof points only when inverted
## past ~60°. Returns [force, torque] in world axes about the CG.
func body_contact(surface, b, up, v, w_world, here, dt):
	body_contacts = 0
	var total_f = Vector3.ZERO
	var total_t = Vector3.ZERO
	var bottomed = false
	for w in wheels:
		bottomed = bottomed or w.comp > SUSP_TRAVEL * .6
	if contacts == 4 and up.y > .9 and not bottomed and vel_y > -3.0:
		return [total_f, total_t]
	var count = body_points.size() if up.y < .5 else 6
	for k in count:
		var arm = b * body_points[k]
		var reach = arm.length()
		var hit = surface.contact(here, arm / reach, reach, -1)
		if hit.is_empty():
			continue
		var n = hit.normal
		var depth = (hit.point - (here + arm)).dot(n)
		if depth <= 0:
			continue
		var pv = v + w_world.cross(arm)
		var vn = pv.dot(n)
		var fn = maxf(0.0, BODY_STIFFNESS * depth - BODY_DAMPING * minf(vn, 0.0))
		var vt = pv - n * vn
		var slide = vt.length()
		var f = n * fn
		if slide > 1e-6:
			f -= vt / slide * minf(BODY_FRICTION * fn, slide * p.mass * .25 / dt)
		total_f += f
		total_t += arm.cross(f)
		body_contacts += 1
	return [total_f, total_t]


## Anti-roll bar load added to the left and right wheels of one axle (spring rate k both sides).
## Both on the ground: +arb (cl - cr) and its opposite, as before.
## One wheel off the ground: that wheel is massless, so it rises until its own spring balances the bar,
## c_air = arb c_ground / (k + arb). The bar then adds arb (c_ground - c_air) = c_ground arb k / (k + arb)
## to the grounded wheel (the bar in series with the lifted wheel's spring), and nothing to the body
## at the lifted corner, whose spring force and bar force cancel. Neither on the ground: nothing.
static func arb_pair(arb, k, cl, cr, left_down, right_down):
	if left_down and right_down:
		var f = arb * (cl - cr)
		return [f, -f]
	if left_down:
		return [cl * arb * k / (k + arb), 0.0]
	if right_down:
		return [0.0, cr * arb * k / (k + arb)]
	return [0.0, 0.0]


## Torque-free Euler equations I w' = -w x (I w) advanced one tick with RK4. Explicit Euler on this
## term gains rotational energy every step (1.4 % in 3 s of tumbling); RK4 keeps a free spin's
## energy and angular momentum to O(dt^4) for four cheap evaluations.
func gyro(w0: Vector3, dt: float) -> Vector3:
	var k1 = -w0.cross(inertia * w0) / inertia
	var w1 = w0 + k1 * (dt * .5)
	var k2 = -w1.cross(inertia * w1) / inertia
	var w2 = w0 + k2 * (dt * .5)
	var k3 = -w2.cross(inertia * w2) / inertia
	var w3 = w0 + k3 * dt
	var k4 = -w3.cross(inertia * w3) / inertia
	return w0 + (k1 + 2 * k2 + 2 * k3 + k4) * (dt / 6)


## Tyre off the ground: no slip heat, the surface still cools toward the core and air.
func cool(w, dt):
	var ts = w.temp - 25
	var xfer = .12 * (w.temp - w.core)
	w.temp += (-(.021 + .0018 * speed) * ts - .0006 * ts * absf(ts) - xfer) * dt
	w.core += (xfer * .25 - .002 * (w.core - 25)) * dt


func angular_momentum_world():
	return basis() * (inertia * ang)


func snapshot():
	var phases = []
	for w in wheels:
		phases.append(w.phase)
	return {"xform": Transform3D(basis(), pos), "steer": steer_angle, "phase": phases}
