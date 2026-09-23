extends RefCounted
## Custom vehicle solver, independent of scene nodes and Godot rigid bodies.
## SI units; XY ground plane; h/pitch/roll radians; wheel order FL, FR, RL, RR.
## car.z is suspension heave, car.elev is road altitude. ax/ay exclude slope gravity.
## Preserve fixed-step order and need clamps; validate changes with handling.gd and laps.gd.
# Direct native port of Car.step/drivetrain. Simulation uses double-precision scalars
# and the original fixed 240 Hz order, including the tire/clutch/diff need clamps.
const G = 9.81
const RHO = 1.22
## Suspension travel before the bump stop engages, metres of corner compression.
const SUSP_TRAVEL = .08
## Bump-stop rate as a multiple of the main spring rate, applied to compression beyond travel.
const BUMP_STOP_RATE = 6.0
## Limit on the road height a wheel may sit away from the chassis tangent plane. This is not a
## smoothing device: the plane already follows the road, including any cross-section profile, so
## this is the genuine residual. It has to admit a Karussell, whose concrete drops more than a
## metre below the outer road across half a car's width. Measured peak on the Caracciola-Karussell
## is 0.64 m, so this sits above the real geometry rather than trimming it; the old 0.12 m cut off
## four fifths of that feature. Beyond this the wheel is certainly in the air and the figure stops
## mattering. The damping term is separately rate-limited, which is what protects the solver.
const MAX_ROAD_DEVIATION = .70
const TrackModel = preload("res://scripts/track3d.gd")
var p = {}
var setup = {}
var wheels = []
var x = 0.0
var y = 0.0
var h = 0.0
var vx = 0.0
var vy = 0.0
var r = 0.0
var ax = 0.0
var ay = 0.0
var speed = 0.0
var z = 0.0
var zd = 0.0
var pitch = 0.0
var pitchd = 0.0
var roll = 0.0
var rolld = 0.0
var elev = 0.0
var grade = 0.0
var bank = 0.0
var g_eff = G
## Ballistic flight. `air` is the height of the car above the road surface beneath it (zero while
## any tyre touches), and `air_vz` is its world vertical velocity while airborne. car.elev stays the
## road altitude, so the car's world altitude in the air is elev + air.
var airborne = false
var air = 0.0
var air_vz = 0.0
var gear = 1
var shift_timer = 0.0
var pending_gear = 1
var engine_w = 0.0
var rpm = 0.0
var brake_hold = 0.0
var steer_angle = 0.0
var tc_active = false
var abs_active = false
var all_off = false
var collided = false
var wear_enabled = true
var auto_clutch = true
var clutch_eng = 0.0
var throttle_eff = 0.0
var rev_limit = false
var vbx = 0.0
var vby = 0.0
var input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
var noise_seed = 12345
## Simulation remains the model-level default for historical harnesses; the application selects Simcade.
var simcade_enabled = false
var simcade_steering = true
static var SIMCADE_DEFAULTS = JSON.parse_string(FileAccess.get_file_as_string("res://data/simcade.json"))
var simcade = SIMCADE_DEFAULTS.duplicate(true)
var asm_active = false
var asm_cut = 0.0
var asm_brakes = [0.0, 0.0, 0.0, 0.0]
## Speed at which steering lock halves (m/s); 0 disables speed-sensitive steering. Set per input device by game.gd.
var steer_falloff = 14.0
## Steering grip assist (radians, 0 = off): stops the driver steering the fronts much past their peak
## slip angle in the direction they are already steering. Countersteer is never limited or forced.
var steer_slip_limit = 0.0
var tc_gain = 1.0
var shift_cooldown = 0.0
var blip_pending = false
## Self-aligning torque about the front steering axes, N m, positive steers right. Output only (telemetry / future FFB).
var steer_torque = 0.0


## Deep-copy preset/default tuning and allocate four mutable wheel states.
func configure(preset):
	p = preset.duplicate(true)
	setup = p.setup.duplicate(true)
	simcade = SIMCADE_DEFAULTS.duplicate(true)
	simcade.merge(p.get("simcade", {}), true)
	wheels.clear()
	for i in 4:
		wheels.append(
			{
				"bx": p.a if i < 2 else -p.b,
				"by": (-1 if i % 2 == 0 else 1) * p.track / 2,
				"omega": 0.0,
				"phase": 0.0,
				"comp": 0.0,
				"load": p.mass * G / 4,
				"surf": TrackModel.SURF[0],
				"temp": 25.0,
				"core": 25.0,
				"roadZ": 0.0,
				"dev": 0.0,
				"devRate": 0.0,
				"mz": 0.0,
				"wear": 0.0,
				"alphaRelax": 0.0,
				"slipRatio": 0.0,
				"slipAngle": 0.0,
				"fx": 0.0,
				"fy": 0.0,
				"ellipse": 0.0,
				"abs": 1.0,
				"brakeT": 0.0,
				"sIdx": -1,
				"wx": 0.0,
				"wy": 0.0,
				"skidding": false
			}
		)
	reset_pose({"x": 0.0, "y": 0.0, "h": 0.0})


func reset_pose(pose):
	asm_cut = 0.0
	asm_active = false
	asm_brakes = [0.0, 0.0, 0.0, 0.0]
	if simcade_enabled:
		tc_gain = 1.0
		shift_cooldown = 0.0
		blip_pending = false
	x = pose.x
	y = pose.y
	h = pose.h
	vx = 0
	vy = 0
	r = 0
	ax = 0
	ay = 0
	speed = 0
	z = 0
	zd = 0
	airborne = false
	air = 0.0
	air_vz = 0.0
	pitch = 0
	pitchd = 0
	roll = 0
	rolld = 0
	gear = 1
	shift_timer = 0
	brake_hold = 0
	collided = false
	engine_w = p.idle * PI / 30
	rpm = p.idle
	steer_angle = 0
	noise_seed = 12345
	for w in wheels:
		for key in [
			"omega",
			"comp",
			"wear",
			"alphaRelax",
			"slipRatio",
			"slipAngle",
			"fx",
			"fy",
			"brakeT",
			"phase",
			"dev",
			"devRate",
			"mz",
			"roadZ"
		]:
			w[key] = 0.0
		w.load = p.mass * G / 4
		# Runs start on warm tyres, as after an out-lap.
		w.temp = 25.0 + .75 * (setup.tempOpt - 25.0)
		if simcade_enabled:
			w.temp = setup.tempOpt
		w.core = w.temp
		w.abs = 1.0
		w.sIdx = -1
		w.surf = TrackModel.SURF[0]
	for key in input:
		input[key] = 0.0


func rnd():
	noise_seed = (noise_seed * 1664525 + 1013904223) & 0xffffffff
	return float(noise_seed) / 4294967296.0


func sg(v):
	return -1.0 if v < 0 else 1.0


const LAT_B = 1.4


## Slip ratio / slip angle (rad) at which the native tyre curves peak for the current setup.
func peak_slip_ratio():
	return 1.75 / maxf(setup.tireBlong, 1)


func peak_slip_angle():
	return 1.9 / maxf(setup.tireBlat * LAT_B, 1)


func tcs_level():
	if setup.has("tcsLevel"):
		return clampf(setup.tcsLevel, 0, 10)
	return simcade.default_tcs if simcade_enabled else (setup.tcIntensity * 10 if setup.tcOn > .5 else 0.0)


func asm_level():
	return clampf(setup.get("asmLevel", simcade.default_asm if simcade_enabled else 0.0), 0, 10)


func set_tcs(level):
	setup.tcsLevel = clampf(level, 0, 10)
	# Keep the browser's original fields meaningful in exported setups.
	setup.tcOn = 1.0 if level > 0 else 0.0
	setup.tcIntensity = level / 10.0


func simcade_curve(value, begin, end):
	var slip = absf(value)
	var force = sin(minf(slip / begin, 1.0) * PI * .5)
	if slip > end:
		force = lerpf(1.0, simcade.sliding_grip, 1 - exp(-(slip - end) / end))
	return signf(value) * force


func tyre_temperature_grip(w):
	var u = ((.65 * w.temp + .35 * w.core) - setup.tempOpt) / setup.tempWindow
	if u > 0:
		u *= .75
	var grip = 1 - .2 * (1 - exp(-u * u))
	return lerpf(1, grip, simcade.temperature_effect) if simcade_enabled else grip


## ASM requests real wheel brake torques; it never clamps heading, lateral velocity or yaw rate.
func stability_request():
	asm_brakes = [0.0, 0.0, 0.0, 0.0]
	asm_cut = 0.0
	asm_active = false
	var level = asm_level()
	if level <= 0 or speed < 5:
		return
	var forward = vx * cos(h) + vy * sin(h)
	var beta = atan2(-vx * sin(h) + vy * cos(h), maxf(absf(forward), 1))
	var intended = forward * tan(steer_angle) / (p.a + p.b)
	var limit = setup.tireMu * G / maxf(speed, 1)
	intended = clampf(intended, -limit, limit)
	var slip_error = signf(beta) * maxf(0, absf(beta) - deg_to_rad(simcade.asm_slip_deg))
	var error = r - intended - slip_error * simcade.asm_slip_gain
	var excess = maxf(0, absf(error) - simcade.asm_yaw_threshold)
	if excess <= 0 and absf(slip_error) < .001:
		return
	var gain = level / 5.0
	var moment = -signf(error) * excess * p.izz * simcade.asm_yaw_gain * gain
	var oversteer = absf(r) > absf(intended) or absf(slip_error) > .001
	var wheel = (0 if moment < 0 else 1) if oversteer else (2 if moment < 0 else 3)
	asm_brakes[wheel] = minf(
		absf(moment) * p.wheelR / (p.track * .5), setup.brakeTorque * simcade.asm_brake_fraction * gain
	)
	asm_cut = clampf(
		(absf(slip_error) * simcade.asm_slip_cut_gain + excess) * gain, 0, simcade.asm_torque_cut
	)
	asm_active = asm_cut > .01 or asm_brakes[wheel] > 1


func pacejka(v, b, c, d, e):
	var bx = b * v
	return d * sin(c * atan(bx - e * (bx - atan(bx))))


func request_shift(direction):
	if shift_timer > 0:
		return
	var ng = clampi(gear + direction, -1, p.get("gears", 6))
	if ng != gear:
		pending_gear = ng
		shift_timer = setup.shiftTime


## Advance exactly one fixed physics tick using normalized input and track surface queries.
## Do not replace dt with render time or change need clamps without handling/lap validation.
func step(dt, track, automatic = true):
	var s = setup
	var m = p.mass
	var ch = cos(h)
	var sh = sin(h)
	speed = sqrt(vx * vx + vy * vy)
	steer_angle = (
		input.steer * deg_to_rad(s.maxSteer) / ((1 + speed / steer_falloff) if steer_falloff > 0 else 1.0)
	)
	if steer_slip_limit > 0 and speed > 3:
		# Cap steering at what the tyres can use at this speed: the kinematic angle for a limit corner
		# (wheelbase * max lateral accel / v^2) plus the front peak slip angle. Countersteer against the
		# car's rotation may always follow the front axle's slide angle, so slides can still be caught.
		var body_x = vx * ch + vy * sh
		var body_y = -vx * sh + vy * ch
		var beta_f = atan2(body_y + r * p.a, maxf(absf(body_x), 1))
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
	stability_request()
	var el = track.elev_at(x, y, wheels[0].sIdx)
	var cos_s = 1 / sqrt(1 + el.gx * el.gx + el.gy * el.gy)
	var gfx = -m * G * cos_s * el.gx
	var gfy = -m * G * cos_s * el.gy
	# Acceleration the road asks of the car along its normal: gravity's normal share plus the
	# centripetal term of following vertical curvature. Negative means the road falls away faster
	# than gravity alone could pull the car after it.
	var normal_accel = G * cos_s + speed * speed * el.kv
	elev = el.z
	bank = el.bank
	grade = el.gx * ch + el.gy * sh
	var stf = m * G * p.b / (p.a + p.b) / 2
	var strr = m * G * p.a / (p.a + p.b) / 2
	var q = speed * speed * .5 * RHO
	var dff = q * s.clAF
	var dfr = q * s.clAR
	# Vertical velocity of the road beneath the car, from the surface gradient and plan velocity.
	var road_vz = el.gx * vx + el.gy * vy
	if airborne:
		air_vz -= (G + (dff + dfr) / m) * dt
		air += (air_vz - road_vz) * dt
		if air <= 0:
			# Touchdown. The closing speed into the road becomes suspension compression rate, so the
			# springs, dampers and bump stop absorb the landing instead of it vanishing.
			airborne = false
			air = 0.0
			zd = maxf(zd, road_vz - air_vz)
	elif speed > 5 and m * normal_accel + dff + dfr < 0:
		# Takeoff: no tyre force can hold the car on a road curving away this fast. It leaves the
		# lip with the road's own vertical velocity and follows a ballistic arc from there.
		airborne = true
		air = 0.0
		air_vz = road_vz
	g_eff = 0.0 if airborne else clampf(normal_accel, 0.0, 3 * G)
	if airborne:
		# Gravity acts straight down in the air; it has no component along a road it is not on.
		gfx = 0.0
		gfy = 0.0
	var forces = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		var w = wheels[i]
		var front = i < 2
		var d = z + pitch * w.bx + roll * w.by
		# Curbs are real geometry (w.dev), so they do not add random bump.
		var bump = (
			(rnd() - .5) * w.surf.bump * minf(1, speed / 10) if w.surf.bump > 0 and w.surf.id != 1 else 0.0
		)
		if simcade_enabled:
			bump *= simcade.rough_bump_scale
		var dd = zd + pitchd * w.bx + rolld * w.by + bump
		d += w.dev
		dd += w.devRate
		var k = s.springF if front else s.springR
		var c = (s.bumpF if front else s.bumpR) if dd > 0 else (s.reboundF if front else s.reboundR)
		forces[i] = k * d + c * dd
		# Bump stop: beyond travel the corner stiffens sharply instead of staying linear forever.
		var over = d - SUSP_TRAVEL
		if over > 0:
			forces[i] += k * BUMP_STOP_RATE * over
		w.comp = d
	var af = s.arbF * (wheels[0].comp - wheels[1].comp)
	var ar = s.arbR * (wheels[2].comp - wheels[3].comp)
	forces[0] += af
	forces[1] -= af
	forces[2] += ar
	forces[3] -= ar
	# A tyre can push the chassis away from the road; it cannot pull it down. Once a corner reaches
	# zero load the wheel has left the ground, and any further extension applies no force at all.
	# Previously the load was floored here but the raw spring force still drove heave, pitch and
	# roll, so a lifted wheel went on hauling the chassis downwards.
	for i in 4:
		var static_load = stf if i < 2 else strr
		forces[i] = -static_load if airborne else maxf(forces[i], -static_load)
		wheels[i].load = static_load + forces[i]
	var zdd = (dff + dfr - forces.reduce(func(a, b): return a + b, 0.0)) / m + g_eff - G
	var pdd = (
		(
			-m * ax * s.cgHeight
			- (forces[0] + forces[1]) * p.a
			+ (forces[2] + forces[3]) * p.b
			+ dff * p.a
			- dfr * p.b
		)
		/ p.ipitch
	)
	var moment = 0.0
	for i in 4:
		moment += forces[i] * wheels[i].by
	var rdd = (-m * ay * s.cgHeight - moment) / p.iroll
	if airborne:
		# Nothing reacts against the body in the air. The wheels drop to full droop, and the chassis
		# keeps the pitch and roll it left the ground with.
		var droop = -(stf / s.springF + strr / s.springR) * .5
		z = move_toward(z, droop, dt * .6)
		zd = 0.0
		pitchd = 0.0
		rolld = 0.0
	else:
		zd += zdd * dt
		z = clampf(z + zd * dt, -.15, .15)
		pitchd += pdd * dt
		pitch = clampf(pitch + pitchd * dt, -.12, .12)
		rolld += rdd * dt
		roll = clampf(roll + rolld * dt, -.12, .12)
	# Travel stops: kill velocity into a limit so it cannot wind up while clamped and snap back later.
	if absf(z) >= .15 and zd * z > 0:
		zd = 0.0
	if absf(pitch) >= .12 and pitchd * pitch > 0:
		pitchd = 0.0
	if absf(roll) >= .12 and rolld * roll > 0:
		rolld = 0.0
	var nominal = m * G / 4
	var sumx = 0.0
	var sumy = 0.0
	var summ = 0.0
	var torques = [0.0, 0.0, 0.0, 0.0]
	all_off = true
	for i in 4:
		var w = wheels[i]
		var ox = w.bx * ch - w.by * sh
		var oy = w.bx * sh + w.by * ch
		w.wx = x + ox
		w.wy = y + oy
		var vcx = vx - r * oy
		var vcy = vy + r * ox
		var wa = h + (steer_angle if i < 2 else 0.0)
		var cw = cos(wa)
		var sw = sin(wa)
		var vwx = vcx * cw + vcy * sw
		var vwy = -vcx * sw + vcy * cw
		w.surf = track.surface_at(w.wx, w.wy, w)
		var sf = w.surf
		if sf.id <= 1:
			all_off = false
		# Road height under this wheel relative to the tangent plane at the CG: crest/dip curvature,
		# bank twist, cross-section profile and curbs.
		var nd = clampf(
			w.roadZ - (el.z + el.gx * ox + el.gy * oy), -MAX_ROAD_DEVIATION, MAX_ROAD_DEVIATION
		)
		if simcade_enabled and sf.id == 1:
			nd *= simcade.curb_scale
		# Low-pass the input rate (~12 Hz) as a stand-in for tire sidewall compliance, which the model has no spring for.
		w.devRate += (clampf((nd - w.dev) / dt, -3, 3) - w.devRate) * minf(1, dt * 75)
		w.dev = nd
		var radius = p.wheelR
		var vabs = absf(vwx)
		var sv = w.omega * radius - vwx
		var kappa = sv / maxf(vabs, 1)
		w.alphaRelax += (atan2(vwy, maxf(vabs, .6)) - w.alphaRelax) * minf(1, dt * maxf(speed, 1.5) / .28)
		w.slipRatio = kappa
		w.slipAngle = w.alphaRelax
		var temp_u = (.65 * w.temp + .35 * w.core - s.tempOpt) / s.tempWindow
		if temp_u > 0:
			temp_u *= .75  # native: grip fades more gently above the window than below it
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
			# Native load sensitivity is relative to each axle's own static load: tyres are sized for their
			# axle, so a rear-heavy car's rears are not penalised just for carrying the engine.
			* clampf(1 - (s.loadSens * load_scale * (w.load / (stf if i < 2 else strr) - 1)), .5, 1.3)
		)
		var peak = mu * w.load
		var fx
		var fy
		# Native curves peak where real tyres do (slip ratio ~0.12-0.15, slip angle ~7-8 deg for the
		# presets) and fall away beyond to ~70-80 % of peak when locked, spinning or fully sideways.
		fx = pacejka(kappa, s.tireBlong, 1.5, peak, 0.0)
		fy = -pacejka(w.alphaRelax, s.tireBlat * LAT_B, 1.5, peak, .2)
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
			# Pneumatic trail collapses toward the slip-angle peak, so aligning torque drops as the front lets go.
			var apeak = peak_slip_angle()
			w.mz = -fy * (.045 * maxf(0, 1 - absf(w.alphaRelax) / apeak) + .012)
		var fxr = -sg(vwx) * sf.rr * w.load * minf(1, vabs / .5) if vabs > .05 else 0.0
		fxr -= sf.drag * w.load * vwx
		var fyr = -sf.drag * w.load * vwy * .5
		if simcade_enabled and sf.id == 3:
			fxr *= simcade.gravel_drag_scale
			fyr = -sf.drag * w.load * vwy * simcade.gravel_drag_scale
		var fxw = (fx + fxr) * cw - (fy + fyr) * sw
		var fyw = (fx + fxr) * sw + (fy + fyr) * cw
		sumx += fxw
		sumy += fyw
		summ += ox * fyw - oy * fxw
		torques[i] = -fx * radius
		var power = absf(fx * sv) + absf(fy * vwy)
		var heat = power * .0006 * s.pressureHeat + .02 * speed * w.load / nominal
		# Two nodes: a fast surface (slip heat in, air cooling out) coupled to a slow carcass core.
		var ts = w.temp - 25
		var xfer = .12 * (w.temp - w.core)
		# Slip heat reaches the surface at 0.75x the old single-node rate plus extra carcass-flex heat
		# from rolling, so tyres live in their window instead of spiking on every slide.
		var surface_heat = power * .0005 * s.pressureHeat + .055 * speed * w.load / nominal
		w.temp += (surface_heat - (.021 + .0018 * speed) * ts - .0006 * ts * absf(ts) - xfer) * dt
		w.core += (xfer * .25 - .002 * (w.core - 25)) * dt
		if wear_enabled:
			w.wear = minf(1, w.wear + power * 3e-7 * dt)
		w.skidding = w.ellipse > .92 and sf.id <= 1 and speed > 2
	steer_torque = wheels[0].mz + wheels[1].mz
	drivetrain(dt, torques, automatic)
	var drag = .5 * RHO * s.cdA * speed
	sumx -= drag * vx
	sumy -= drag * vy
	var axw = sumx / m
	var ayw = sumy / m
	vx += (axw + gfx / m) * dt
	vy += (ayw + gfy / m) * dt
	if simcade_enabled:
		var beta = atan2(-vx * sh + vy * ch, maxf(absf(vx * ch + vy * sh), 1))
		var excess = maxf(0, absf(beta) - peak_slip_angle())
		# Dissipative physical moment only beyond the rear slip peak. No direct state clamp.
		summ -= p.izz * r * simcade.yaw_damping * clampf(excess / peak_slip_angle(), 0, 1)
	r += summ / p.izz * dt
	if speed < .4 and input.throttle < .02 and sqrt(gfx * gfx + gfy * gfy) < .02 * m * G:
		vx *= .96
		vy *= .96
		r *= .96
	x += vx * dt
	y += vy * dt
	h += r * dt
	ax = axw * ch + ayw * sh
	ay = -axw * sh + ayw * ch
	vbx = vx * ch + vy * sh
	vby = -vx * sh + vy * ch
	for w in wheels:
		w.phase = fposmod(w.phase + w.omega * dt, TAU)


## Presentation state for render interpolation. Captured before each physics tick and blended by game.gd.
func snapshot():
	var phases = []
	var devs = []
	for w in wheels:
		phases.append(w.phase)
		devs.append(w.dev)
	return {
		"x": x,
		"y": y,
		"h": h,
		"z": z,
		"air": air,
		"pitch": pitch,
		"roll": roll,
		"steer": steer_angle,
		"phase": phases,
		"dev": devs,
		"brake": input.brake,
		"handbrake": input.handbrake,
		"sIdx": wheels[0].sIdx
	}


static func blend(a, b, t):
	var out = b.duplicate(true)
	for key in ["x", "y", "h", "z", "pitch", "roll", "steer"]:
		out[key] = lerpf(a[key], b[key], t)
	out.air = lerpf(a.get("air", 0.0), b.get("air", 0.0), t)
	for i in b.phase.size():
		out.phase[i] = lerp_angle(a.phase[i], b.phase[i], t)
		out.dev[i] = lerpf(a.dev[i], b.dev[i], t)
	return out


## Distribute axle torque and limit locking torque to the one-step equalization need.
func axle_split(left, right, torque, torques, drive, dt):
	var s = setup
	var cap = 0.0
	if int(s.diffType) == 2:
		cap = 1e9
	elif int(s.diffType) == 1:
		cap = s.diffPreload + absf(torque) * (s.diffPower if torque >= 0 else s.diffCoast)
	var need = (
		-((wheels[left].omega - wheels[right].omega) * p.wheelI / dt + torques[left] - torques[right]) / 2
	)
	var lock = clampf(need, -cap, cap)
	drive[left] = torque / 2 + lock
	drive[right] = torque / 2 - lock


## Advance gearing/clutch/engine/brakes and wheel torques in the established solver order.
func drivetrain(dt, torques, automatic):
	var s = setup
	var idle = p.idle * PI / 30
	var red = p.redline * PI / 30
	shift_cooldown = maxf(0, shift_cooldown - dt)
	if shift_timer > 0:
		shift_timer -= dt
		if shift_timer <= 0:
			# Native: auto-blip on downshifts (automatic, or manual with auto clutch) so the engine is
			# already spinning at wheel speed when the clutch bites instead of locking the driven wheels.
			blip_pending = (pending_gear < gear and pending_gear >= 1 and (automatic or auto_clutch))
			gear = pending_gear
	var driven = [2, 3] if int(s.layout) == 0 else ([0, 1] if int(s.layout) == 1 else [0, 1, 2, 3])
	var ratio = (
		0.0
		if gear == 0
		else (-p.reverse * s.finalDrive if gear < 0 else s["gear" + str(gear)] * s.finalDrive)
	)
	if automatic and shift_timer <= 0:
		# Native automatic: decide from ground speed only (not engine speed, which drops during a shift
		# and used to cascade the box down to 1st under braking), never downshift into over-revving.
		var ground_rpm = absf(speed / p.wheelR * ratio) * 30 / PI
		if gear >= 1 and shift_cooldown <= 0:
			if ground_rpm > p.redline * .96 and gear < p.get("gears", 6) and input.throttle > .1:
				request_shift(1)
				shift_cooldown = .4
			elif gear > 1:
				var lower_rpm = ground_rpm * s["gear" + str(gear - 1)] / s["gear" + str(gear)]
				var lugging = ground_rpm < p.redline * (.62 if input.throttle > .6 else .45)
				if lugging and lower_rpm < p.redline * .86:
					request_shift(-1)
					shift_cooldown = .4
	if automatic and shift_timer <= 0:
		if speed < .3 and input.brake > .5 and input.throttle < .05:
			brake_hold += dt
			if brake_hold > .8:
				gear = 1 if gear < 0 else -1
				brake_hold = -2
		elif input.brake < .3:
			brake_hold = 0
		if gear == 0:
			gear = 1
	var carrier = 0.0
	var text = 0.0
	for i in driven:
		carrier += wheels[i].omega
		text += torques[i]
	carrier /= driven.size()
	if blip_pending:
		blip_pending = false
		engine_w = clampf(maxf(engine_w, absf(carrier * ratio)), idle, red * .99)
	var engagement = 0.0
	if shift_timer <= 0 and ratio != 0:
		var base = clampf((absf(carrier * ratio) - idle * .55) / (idle * .7), 0, 1)
		engagement = base if input.throttle < .02 else maxf(base, input.throttle * .55 + .1)
		engagement = minf(engagement, 1 - input.clutch)
		if not automatic and not auto_clutch:
			engagement = 1 - input.clutch
	clutch_eng = engagement
	var throttle = input.throttle
	tc_active = false
	var tc_on = s.tcOn
	var tc_intensity = s.tcIntensity
	if simcade_enabled or setup.has("tcsLevel"):
		tc_on = 1.0 if tcs_level() > 0 else 0.0
		tc_intensity = tcs_level() / 10.0
	if tc_on > .5 and speed > 1.5:
		var max_k = 0.0
		for i in driven:
			max_k = maxf(max_k, wheels[i].slipRatio)
		# Integral control toward just past the tyre's peak slip: trims harder the further over the
		# target the driven wheels are, and hands throttle back gently once they are below it.
		var limit = peak_slip_ratio() * (1.0 + .6 * (1 - tc_intensity))
		# Combined slip: the more the driven tyres are already working sideways, the less wheelspin
		# they can take before the friction ellipse steals lateral grip (power oversteer).
		var lat_use = 0.0
		for i in driven:
			lat_use = maxf(lat_use, absf(wheels[i].slipAngle) / peak_slip_angle())
		if lat_use > .3:
			limit *= (
				sqrt(maxf(.04, 1 - minf(lat_use, 1) * minf(lat_use, 1))) * (.5 + .5 * (1 - tc_intensity))
			)
		if max_k > limit:
			tc_gain -= minf(max_k - limit, .5) * (18 + 30 * tc_intensity) * dt
		else:
			tc_gain += 2.5 * dt
		tc_gain = clampf(tc_gain, .08, 1)
		throttle *= tc_gain
		tc_active = tc_gain < .97
	else:
		tc_gain = 1.0
	throttle *= 1.0 - asm_cut
	rev_limit = engine_w > red
	if rev_limit:
		throttle = 0
	var idle_throttle = clampf((idle - engine_w) / (idle * .25), 0, .5)
	throttle = maxf(throttle, idle_throttle)
	if shift_timer > 0 and automatic:
		throttle = minf(throttle, idle_throttle)
	throttle_eff = throttle
	var f = clampf(engine_w / red, 0, 1)
	var curve = p.torqueCurve
	var k = 1
	while k < curve.size() - 1 and curve[k][0] < f:
		k += 1
	var shape = lerpf(curve[k - 1][1], curve[k][1], (f - curve[k - 1][0]) / (curve[k][0] - curve[k - 1][0]))
	var te = (
		p.engineTorque * shape * throttle - p.engineBrake * maxf(0, engine_w - idle * .8) * (1 - throttle)
	)
	var tc = 0.0
	var tin = 0.0
	if ratio != 0 and engagement > 0:
		var isum = p.wheelI * driven.size()
		var aa = dt / p.engineI
		var bb = ratio * ratio * dt / isum
		var need = (engine_w - carrier * ratio + te * aa - text * ratio * dt / isum) / (aa + bb)
		tc = clampf(need, -p.clutchTorque * engagement, p.clutchTorque * engagement)
		tin = tc * ratio
	engine_w = maxf(idle * .35, engine_w + (te - tc) * dt / p.engineI)
	rpm = engine_w * 30 / PI
	var drive = [0.0, 0.0, 0.0, 0.0]
	if int(s.layout) == 0:
		axle_split(2, 3, tin, torques, drive, dt)
	elif int(s.layout) == 1:
		axle_split(0, 1, tin, torques, drive, dt)
	else:
		var wf = (wheels[0].omega + wheels[1].omega) / 2
		var wr = (wheels[2].omega + wheels[3].omega) / 2
		var cap = 20 + absf(tin) * s.awdLock
		var need = -((wf - wr) * 2 * p.wheelI / dt + torques[0] + torques[1] - torques[2] - torques[3]) / 2
		var lock = clampf(need, -cap, cap)
		axle_split(0, 1, tin * (1 - s.awdRear) + lock, torques, drive, dt)
		axle_split(2, 3, tin * s.awdRear - lock, torques, drive, dt)
	abs_active = false
	for i in 4:
		var w = wheels[i]
		w.omega += (drive[i] + torques[i]) * dt / p.wheelI
		var cap = s.brakeTorque * input.brake * (s.brakeBias if i < 2 else 1 - s.brakeBias) / 2
		if i >= 2:
			cap += s.handbrakeTorque * input.handbrake / 2
		if s.absOn > .5 and (input.brake > .05 or asm_brakes[i] > 1) and speed > 2 and input.handbrake < .5:
			var abs_limit = peak_slip_ratio() * (1.0 + .6 * (1 - s.absIntensity))
			if w.slipRatio < -abs_limit:
				w.abs = maxf(.15, w.abs - 25 * dt)
				abs_active = true
			else:
				w.abs = minf(1, w.abs + 8 * dt)
			cap *= w.abs
		else:
			w.abs = 1
		cap += asm_brakes[i] * w.abs
		w.brakeT = cap
		var dw = cap * dt / p.wheelI
		w.omega = 0.0 if absf(w.omega) <= dw else w.omega - sg(w.omega) * dw
