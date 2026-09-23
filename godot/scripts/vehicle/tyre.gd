extends RefCounted
## Shared tyre calculations for the planar CarModel and 6-DOF CarBody.
## Inputs are the already-resolved contact velocity, load, and surface; callers apply forces in
## their own coordinate frames between contact_forces() and finish_contact().
const LAT_B = 1.4
## Contact-patch speed below which a sticky tyre holds with static friction (full below it, gone by
## twice it), m/s.
const STICK_SPEED = .3


static func sg(v):
	return -1.0 if v < 0 else 1.0


static func peak_slip_ratio(car):
	return 1.75 / maxf(car.setup.tireBlong, 1)


static func peak_slip_angle(car):
	return 1.9 / maxf(car.setup.tireBlat * LAT_B, 1)


static func simcade_curve(car, value, begin, end):
	var slip = absf(value)
	var force = sin(minf(slip / begin, 1.0) * PI * .5)
	if slip > end:
		force = lerpf(1.0, car.simcade.sliding_grip, 1 - exp(-(slip - end) / end))
	return signf(value) * force


static func tyre_temperature_grip(car, w):
	var u = ((.65 * w.temp + .35 * w.core) - car.setup.tempOpt) / car.setup.tempWindow
	if u > 0:
		u *= .75
	var grip = 1 - .2 * (1 - exp(-u * u))
	return lerpf(1, grip, car.simcade.temperature_effect) if car.simcade_enabled else grip


static func pacejka(v, b, c, d, e):
	var bx = b * v
	return d * sin(c * atan(bx - e * (bx - atan(bx))))


## `hold` and `sticky` are for the 6-DOF CarBody (P2-04); the planar CarModel passes neither and is
## unchanged. `hold` is the external force on this wheel's share of the car along the contact's
## forward (x) and side (y) axes (gravity on a slope), which the one-tick need clamps must also cancel
## to bring the contact to rest. `sticky` adds static friction: a nearly still contact patch takes the
## force that holds it, up to the friction limit (longitudinally only while the brake holds the wheel).
static func contact_forces(car, w, i, sf, vwx, vwy, dt, stf, strr, hold = Vector2.ZERO, sticky = false):
	var s = car.setup
	var p = car.p
	var m = p.mass
	var speed = car.speed
	var simcade_enabled = car.simcade_enabled
	var simcade = car.simcade
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
				car,
				kappa,
				peak_slip_ratio(car) * simcade.ratio_start_scale,
				peak_slip_ratio(car) * simcade.ratio_end_scale
			)
		)
		fy = (
			-peak
			* simcade_curve(
				car, w.alphaRelax, deg_to_rad(simcade.peak_start_deg), deg_to_rad(simcade.peak_end_deg)
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
	# Preserve the semi-implicit one-tick need clamps for standstill and drivetrain stability.
	var need
	var locked
	var fy_need
	if sticky:
		# The force that leaves no slip after this tick with `hold` also acting on the car: for a free
		# wheel it spins the wheel up as the car accelerates; a locked wheel keeps omega.
		need = (sv - 4 * hold.x * dt / m) / (dt * (radius * radius / p.wheelI + 4 / m))
		locked = sv * m / 4 / dt - hold.x
		fy_need = -vwy * m / 4 / dt - hold.y
	else:
		need = sv / (dt * (radius * radius / p.wheelI + 4 / m))
		locked = sv * m / 4 / dt
		fy_need = -vwy * m / 4 / dt
	var braked = absf(w.omega) < .5 and w.brakeT >= absf(locked) * radius
	if sticky:
		# The wheel stays locked when the brake out-torques what the tyre can put on it: the stopping
		# force, but never more than the friction limit. Testing only the stopping force (the old test)
		# calls a firmly braked wheel free at walking pace, whose clamp then allows just the force that
		# spins it up, and a braked car settled at 0.16 m/s down an 8 deg grade.
		braked = absf(w.omega) < .5 and w.brakeT >= minf(absf(locked), peak) * radius
	if braked:
		need = locked
	if sg(fx) == sg(need) and absf(fx) > absf(need):
		fx = need
	if sg(fy) == sg(fy_need) and absf(fy) > absf(fy_need):
		fy = fy_need
	if sticky and peak > 0:
		# Static friction: below STICK_SPEED the contact patch takes the force that holds it (within the
		# friction limit), fading to the slip curves by twice that. Without it the slip curves give too
		# little force at millimetre-per-second slip, and a braked car crept down an 8 deg ramp at 6-8 mm/s
		# and across a 37 deg side slope at 26-35 mm/s (P2-02).
		var stick = 1 - smoothstep(STICK_SPEED, 2 * STICK_SPEED, maxf(vabs, absf(vwy)))
		if stick > 0:
			var hx = need if braked else fx
			var hy = fy_need
			var use = sqrt(hx * hx + hy * hy) / peak
			if use > 1:
				hx /= use
				hy /= use
			fx = lerpf(fx, hx, stick)
			fy = lerpf(fy, hy, stick)
	w.fx = fx
	w.fy = fy
	if i < 2:
		# Pneumatic trail collapses toward the slip-angle peak, so aligning torque drops as the front lets go.
		var apeak = peak_slip_angle(car)
		w.mz = -fy * (.045 * maxf(0, 1 - absf(w.alphaRelax) / apeak) + .012)
	var fxr = -sg(vwx) * sf.rr * w.load * minf(1, vabs / .5) if vabs > .05 else 0.0
	fxr -= sf.drag * w.load * vwx
	var fyr = -sf.drag * w.load * vwy * .5
	if simcade_enabled and sf.id == 3:
		fxr *= simcade.gravel_drag_scale
		fyr = -sf.drag * w.load * vwy * simcade.gravel_drag_scale
	return [fx, fy, fxr, fyr, sv, radius]


static func finish_contact(car, w, fx, fy, sv, vwy, nominal, dt, sf):
	var s = car.setup
	var speed = car.speed
	var power = absf(fx * sv) + absf(fy * vwy)
	# Two nodes: a fast surface (slip heat in, air cooling out) coupled to a slow carcass core.
	var ts = w.temp - 25
	var xfer = .12 * (w.temp - w.core)
	# Slip heat reaches the surface at 0.75x the old single-node rate plus extra carcass-flex heat
	# from rolling, so tyres live in their window instead of spiking on every slide.
	var surface_heat = power * .0005 * s.pressureHeat + .055 * speed * w.load / nominal
	w.temp += (surface_heat - (.021 + .0018 * speed) * ts - .0006 * ts * absf(ts) - xfer) * dt
	w.core += (xfer * .25 - .002 * (w.core - 25)) * dt
	if car.wear_enabled:
		w.wear = minf(1, w.wear + power * 3e-7 * dt)
	w.skidding = w.ellipse > .92 and sf.id <= 1 and speed > 2
