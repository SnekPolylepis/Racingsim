extends "res://scripts/car.gd"
## P2-00 spike: 6-DOF rigid-body chassis on ray suspension (REBUILD-PLAN.md P2).
## World is Godot-native (+Y up, metres). Body frame: +X forward, +Y up, +Z right. Wheels FL, FR, RL, RR.
## Angular velocity is body-frame, right-hand rule: +y yaws left, +x rolls the right side down,
## +z pitches the nose up. Driver steer > 0 still steers right.
##
## Reuses configure(), drivetrain(), axle_split(), stability_request(), pacejka() and the aids from
## car.gd unchanged; only step() is replaced. The tyre block below is the same formula as car.gd's,
## evaluated in each contact patch's own frame. P2-01 moves that shared code into scripts/vehicle/.
## The legacy plan-view fields (x, y, h, vx, vy, r, speed, vbx, vby, ax, ay) are mirrored from the
## 3D state every tick so the inherited aids and the drivetrain read what they always read.

## Wheel centre to suspension top at static ride height, metres. Arbitrary: only moves the mount point.
const STATIC_LENGTH = .15

var pos = Vector3.ZERO
var rot = Quaternion.IDENTITY
var vel = Vector3.ZERO
var ang = Vector3.ZERO
## Principal inertias about body x (roll), y (yaw), z (pitch).
var inertia = Vector3.ONE
## Per wheel: suspension top in the body frame, spring free length, static compression.
var mount = []
var free_length = []
var static_comp = []
var contacts = 0
var accel = Vector3.ZERO


func configure(preset):
	super(preset)
	rig()


## Suspension geometry from the preset: at static ride the CG sits cgHeight above flat ground.
## A spring at its free length carries nothing, so each corner can extend by its static
## compression before unloading, exactly the old model's droop allowance.
func rig():
	inertia = Vector3(p.iroll, p.izz, p.ipitch)
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


## Place the car at rest on the ground below `at`, heading in the legacy sense
## (forward = (cos h, 0, sin h)).
func place(at: Vector3, heading: float, ground_y: float):
	reset_pose({"x": at.x, "y": at.z, "h": heading})
	rig()
	pos = Vector3(at.x, ground_y + setup.cgHeight, at.z)
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
	pos = Vector3(px, surface.height(px, pz), pz) + n * setup.cgHeight
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
	x = pos.x
	y = pos.z
	h = atan2(fwd.z, fwd.x)
	vx = vel.x
	vy = vel.z
	r = -ang.y
	speed = vel.length()
	vbx = vel.dot(fwd)
	vby = vel.dot(right)
	ax = accel.dot(fwd)
	ay = accel.dot(right)
	elev = pos.y - setup.cgHeight


func steering():
	var s = setup
	var m = p.mass
	steer_angle = (
		input.steer * deg_to_rad(s.maxSteer) / ((1 + speed / steer_falloff) if steer_falloff > 0 else 1.0)
	)
	if steer_slip_limit > 0 and speed > 3:
		var beta_f = atan2(vby + r * p.a, maxf(absf(vbx), 1))
		var down = .5 * RHO * (s.clAF + s.clAR) * speed * speed / (m * G)
		var cap = (p.a + p.b) * G * s.tireMu * (1 + down) / maxf(speed * speed, 1) + steer_slip_limit
		if absf(r) > .05 and signf(steer_angle) != signf(r):
			cap = maxf(cap, absf(beta_f) + steer_slip_limit)
		steer_angle = clampf(steer_angle, -cap, cap)
	if simcade_enabled and simcade_steering and speed > 3:
		var down = .5 * RHO * (s.clAF + s.clAR) * speed * speed / (m * G)
		var slip_cap = deg_to_rad(simcade.peak_start_deg) * simcade.steering_peak_fraction
		var cap = (p.a + p.b) * G * s.tireMu * (1 + down) / maxf(speed * speed, 1) + slip_cap
		if steer_angle * r >= 0:
			steer_angle = clampf(steer_angle, -cap, cap)


## Advance one fixed tick. `surface` implements contact(origin, direction, max_dist, hint).
func step(dt, surface, automatic = true):
	var s = setup
	var m = p.mass
	sync_legacy()
	steering()
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
	# Suspension: one ray per wheel from its mount along the chassis -Y.
	for i in 4:
		var top = pos + b * mount[i]
		var hit = surface.contact(top, -up, free_length[i] + p.wheelR, wheels[i].sIdx)
		hits.append(hit)
		if hit.is_empty():
			continue
		var n = hit.normal
		var top_vel = vel + w_world.cross(top - pos)
		comp[i] = free_length[i] - (hit.distance - p.wheelR)
		# Compression rate from the mount's velocity into the local tangent plane (first order: ignores
		# the ray direction's own rotation and surface steps, which P2-06's footprint filter handles).
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
	var af = s.arbF * (comp[0] - comp[1]) if not (hits[0].is_empty() or hits[1].is_empty()) else 0.0
	var ar = s.arbR * (comp[2] - comp[3]) if not (hits[2].is_empty() or hits[3].is_empty()) else 0.0
	loads[0] += af
	loads[1] -= af
	loads[2] += ar
	loads[3] -= ar
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
		var cvel = vel + w_world.cross(point - pos)
		var vwx = cvel.dot(fwd)
		var vwy = cvel.dot(side)
		var radius = p.wheelR
		var vabs = absf(vwx)
		var sv = w.omega * radius - vwx
		var kappa = sv / maxf(vabs, 1)
		w.alphaRelax += (atan2(vwy, maxf(vabs, .6)) - w.alphaRelax) * minf(1, dt * maxf(speed, 1.5) / .28)
		w.slipRatio = kappa
		w.slipAngle = w.alphaRelax
		var temp_u = (.65 * w.temp + .35 * w.core - s.tempOpt) / s.tempWindow
		if temp_u > 0:
			temp_u *= .75
		var temp_g = 1 - .2 * (1 - exp(-temp_u * temp_u))
		var wear_scale = 1.0
		var load_scale = 1.0
		if simcade_enabled:
			temp_g = lerpf(1, temp_g, simcade.temperature_effect)
			wear_scale = simcade.wear_effect
			load_scale = simcade.load_sensitivity_scale
		var mu = (
			s.tireMu
			* sf.grip
			* temp_g
			* (1 - .15 * w.wear * wear_scale)
			* clampf(1 - (s.loadSens * load_scale * (w.load / (stf if i < 2 else strr) - 1)), .5, 1.3)
		)
		var peak = mu * w.load
		var fx = pacejka(kappa, s.tireBlong, 1.5, peak, 0.0)
		var fy = -pacejka(w.alphaRelax, s.tireBlat * LAT_B, 1.5, peak, .2)
		if simcade_enabled:
			fx = (
				peak
				* simcade_curve(
					kappa,
					peak_slip_ratio() * simcade.ratio_start_scale,
					peak_slip_ratio() * simcade.ratio_end_scale
				)
			)
			fy = (
				-peak
				* simcade_curve(
					w.alphaRelax, deg_to_rad(simcade.peak_start_deg), deg_to_rad(simcade.peak_end_deg)
				)
			)
		if peak > 0:
			w.ellipse = sqrt(pow(fx / peak, 2) + pow(fy / peak, 2))
			if w.ellipse > 1:
				fx /= w.ellipse
				fy /= w.ellipse
		else:
			w.ellipse = 0
			fx = 0
			fy = 0
		# Semi-implicit need clamps, unchanged: never apply more force than cancels the slip in one tick.
		var need = sv / (dt * (radius * radius / p.wheelI + 4 / m))
		var locked = sv * m / 4 / dt
		if absf(w.omega) < .5 and w.brakeT >= absf(locked) * radius:
			need = locked
		if sg(fx) == sg(need) and absf(fx) > absf(need):
			fx = need
		var fy_need = -vwy * m / 4 / dt
		if sg(fy) == sg(fy_need) and absf(fy) > absf(fy_need):
			fy = fy_need
		w.fx = fx
		w.fy = fy
		if i < 2:
			var apeak = peak_slip_angle()
			w.mz = -fy * (.045 * maxf(0, 1 - absf(w.alphaRelax) / apeak) + .012)
		var fxr = -sg(vwx) * sf.rr * w.load * minf(1, vabs / .5) if vabs > .05 else 0.0
		fxr -= sf.drag * w.load * vwx
		var fyr = -sf.drag * w.load * vwy * .5
		if simcade_enabled and sf.id == 3:
			fxr *= simcade.gravel_drag_scale
			fyr = -sf.drag * w.load * vwy * simcade.gravel_drag_scale
		var f = fwd * (fx + fxr) + side * (fy + fyr) + n * w.load
		force += f
		torque += (point - pos).cross(f)
		torques[i] = -fx * radius
		var power = absf(fx * sv) + absf(fy * vwy)
		var ts = w.temp - 25
		var xfer = .12 * (w.temp - w.core)
		var surface_heat = power * .0005 * s.pressureHeat + .055 * speed * w.load / nominal
		w.temp += (surface_heat - (.021 + .0018 * speed) * ts - .0006 * ts * absf(ts) - xfer) * dt
		w.core += (xfer * .25 - .002 * (w.core - 25)) * dt
		if wear_enabled:
			w.wear = minf(1, w.wear + power * 3e-7 * dt)
		w.skidding = w.ellipse > .92 and sf.id <= 1 and speed > 2
	airborne = contacts == 0
	steer_torque = wheels[0].mz + wheels[1].mz
	drivetrain(dt, torques, automatic)
	# Aero: downforce at each axle along the body's down axis, drag at the CG against the velocity.
	var q = .5 * RHO * speed * speed
	var down_f = -up * q * s.clAF
	var down_r = -up * q * s.clAR
	force += down_f + down_r
	torque += (b * Vector3(p.a, 0, 0)).cross(down_f) + (b * Vector3(-p.b, 0, 0)).cross(down_r)
	force -= vel * (.5 * RHO * s.cdA * speed)
	var body_torque = b.transposed() * torque
	if simcade_enabled:
		var beta = atan2(vby, maxf(absf(vbx), 1))
		var excess = maxf(0, absf(beta) - peak_slip_angle())
		# Dissipative yaw moment beyond the rear slip peak, as car.gd. No direct state clamp.
		body_torque.y -= p.izz * ang.y * simcade.yaw_damping * clampf(excess / peak_slip_angle(), 0, 1)
	# Semi-implicit Euler: velocities first, then positions from the new velocities.
	accel = force / m + Vector3(0, G, 0)
	vel += force / m * dt
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
			var normal_v = n_avg * vel.dot(n_avg)
			vel = normal_v + (vel - normal_v) * .96
			ang.y *= .96
	pos += vel * dt
	var spin = ang.length() * dt
	if spin > 1e-12:
		rot = (rot * Quaternion(ang / ang.length(), spin)).normalized()
	for w in wheels:
		w.phase = fposmod(w.phase + w.omega * dt, TAU)
	sync_legacy()


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
