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
const VehicleTyre = preload("res://scripts/vehicle/tyre.gd")
const VehicleAids = preload("res://scripts/vehicle/aids.gd")
const VehicleDrivetrain = preload("res://scripts/vehicle/drivetrain.gd")
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
	return VehicleTyre.peak_slip_ratio(self)


func peak_slip_angle():
	return VehicleTyre.peak_slip_angle(self)


func tcs_level():
	return VehicleAids.tcs_level(self)


func asm_level():
	return VehicleAids.asm_level(self)


func set_tcs(level):
	VehicleAids.set_tcs(self, level)


func simcade_curve(value, begin, end):
	return VehicleTyre.simcade_curve(self, value, begin, end)


func tyre_temperature_grip(w):
	return VehicleTyre.tyre_temperature_grip(self, w)


## ASM requests real wheel brake torques; it never clamps heading, lateral velocity or yaw rate.
func stability_request():
	VehicleAids.stability_request(self)


func steering(body_x, body_y):
	VehicleAids.steering(self, body_x, body_y)


func pacejka(v, b, c, d, e):
	return VehicleTyre.pacejka(v, b, c, d, e)


func request_shift(direction):
	VehicleDrivetrain.request_shift(self, direction)


## Advance exactly one fixed physics tick using normalized input and track surface queries.
## Do not replace dt with render time or change need clamps without handling/lap validation.
func step(dt, track, automatic = true):
	var s = setup
	var m = p.mass
	var ch = cos(h)
	var sh = sin(h)
	speed = sqrt(vx * vx + vy * vy)
	var body_x = vx * ch + vy * sh
	var body_y = -vx * sh + vy * ch
	steering(body_x, body_y)
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
		var nd = clampf(w.roadZ - (el.z + el.gx * ox + el.gy * oy), -MAX_ROAD_DEVIATION, MAX_ROAD_DEVIATION)
		if simcade_enabled and sf.id == 1:
			nd *= simcade.curb_scale
		# Low-pass the input rate (~12 Hz) as a stand-in for tire sidewall compliance, which the model has no spring for.
		w.devRate += (clampf((nd - w.dev) / dt, -3, 3) - w.devRate) * minf(1, dt * 75)
		w.dev = nd
		var tyre = VehicleTyre.contact_forces(self, w, i, sf, vwx, vwy, dt, stf, strr)
		var fx = tyre[0]
		var fy = tyre[1]
		var fxr = tyre[2]
		var fyr = tyre[3]
		var sv = tyre[4]
		var radius = tyre[5]
		var fxw = (fx + fxr) * cw - (fy + fyr) * sw
		var fyw = (fx + fxr) * sw + (fy + fyr) * cw
		sumx += fxw
		sumy += fyw
		summ += ox * fyw - oy * fxw
		torques[i] = -fx * radius
		VehicleTyre.finish_contact(self, w, fx, fy, sv, vwy, nominal, dt, sf)
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
	VehicleDrivetrain.axle_split(self, left, right, torque, torques, drive, dt)


## Advance gearing/clutch/engine/brakes and wheel torques in the established solver order.
func drivetrain(dt, torques, automatic):
	VehicleDrivetrain.step(self, dt, torques, automatic)
