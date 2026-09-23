extends RefCounted
## Shared gearbox, clutch, differential, brake and wheel-spin step.
const VehicleAids = preload("res://scripts/vehicle/aids.gd")


static func request_shift(car, direction):
	if car.shift_timer > 0:
		return
	var ng = clampi(car.gear + direction, -1, car.p.get("gears", 6))
	if ng != car.gear:
		car.pending_gear = ng
		car.shift_timer = car.setup.shiftTime


static func axle_split(car, left, right, torque, torques, drive, dt):
	var setup = car.setup
	var p = car.p
	var wheels = car.wheels
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


static func step(car, dt, torques, automatic):
	var p = car.p
	var setup = car.setup
	var wheels = car.wheels
	var input = car.input
	var speed = car.speed
	var auto_clutch = car.auto_clutch
	var asm_cut = car.asm_cut
	var asm_brakes = car.asm_brakes
	var s = setup
	var idle = p.idle * PI / 30
	var red = p.redline * PI / 30
	car.shift_cooldown = maxf(0, car.shift_cooldown - dt)
	if car.shift_timer > 0:
		car.shift_timer -= dt
		if car.shift_timer <= 0:
			# Native: auto-blip on downshifts (automatic, or manual with auto clutch) so the engine is
			# already spinning at wheel speed when the clutch bites instead of locking the driven wheels.
			car.blip_pending = (
				car.pending_gear < car.gear and car.pending_gear >= 1 and (automatic or auto_clutch)
			)
			car.gear = car.pending_gear
	var driven = [2, 3] if int(s.layout) == 0 else ([0, 1] if int(s.layout) == 1 else [0, 1, 2, 3])
	var ratio = (
		0.0
		if car.gear == 0
		else (-p.reverse * s.finalDrive if car.gear < 0 else s["gear" + str(car.gear)] * s.finalDrive)
	)
	if automatic and car.shift_timer <= 0:
		# Native automatic: decide from ground speed only (not engine speed, which drops during a shift
		# and used to cascade the box down to 1st under braking), never downshift into over-revving.
		var ground_rpm = absf(speed / p.wheelR * ratio) * 30 / PI
		if car.gear >= 1 and car.shift_cooldown <= 0:
			if ground_rpm > p.redline * .96 and car.gear < p.get("gears", 6) and input.throttle > .1:
				car.request_shift(1)
				car.shift_cooldown = .4
			elif car.gear > 1:
				var lower_rpm = ground_rpm * s["gear" + str(car.gear - 1)] / s["gear" + str(car.gear)]
				var lugging = ground_rpm < p.redline * (.62 if input.throttle > .6 else .45)
				if lugging and lower_rpm < p.redline * .86:
					car.request_shift(-1)
					car.shift_cooldown = .4
	if automatic and car.shift_timer <= 0:
		if speed < .3 and input.brake > .5 and input.throttle < .05:
			car.brake_hold += dt
			if car.brake_hold > .8:
				car.gear = 1 if car.gear < 0 else -1
				car.brake_hold = -2
		elif input.brake < .3:
			car.brake_hold = 0
		if car.gear == 0:
			car.gear = 1
	var carrier = 0.0
	var text = 0.0
	for i in driven:
		carrier += wheels[i].omega
		text += torques[i]
	carrier /= driven.size()
	if car.blip_pending:
		car.blip_pending = false
		car.engine_w = clampf(maxf(car.engine_w, absf(carrier * ratio)), idle, red * .99)
	var engagement = 0.0
	if car.shift_timer <= 0 and ratio != 0:
		var base = clampf((absf(carrier * ratio) - idle * .55) / (idle * .7), 0, 1)
		engagement = base if input.throttle < .02 else maxf(base, input.throttle * .55 + .1)
		engagement = minf(engagement, 1 - input.clutch)
		if not automatic and not auto_clutch:
			engagement = 1 - input.clutch
	car.clutch_eng = engagement
	var throttle = VehicleAids.traction_control(car, driven, dt)
	throttle *= 1.0 - asm_cut
	car.rev_limit = car.engine_w > red
	if car.rev_limit:
		throttle = 0
	var idle_throttle = clampf((idle - car.engine_w) / (idle * .25), 0, .5)
	throttle = maxf(throttle, idle_throttle)
	if car.shift_timer > 0 and automatic:
		throttle = minf(throttle, idle_throttle)
	car.throttle_eff = throttle
	var f = clampf(car.engine_w / red, 0, 1)
	var curve = p.torqueCurve
	var k = 1
	while k < curve.size() - 1 and curve[k][0] < f:
		k += 1
	var shape = lerpf(curve[k - 1][1], curve[k][1], (f - curve[k - 1][0]) / (curve[k][0] - curve[k - 1][0]))
	var te = (
		p.engineTorque * shape * throttle - p.engineBrake * maxf(0, car.engine_w - idle * .8) * (1 - throttle)
	)
	var tc = 0.0
	var tin = 0.0
	if ratio != 0 and engagement > 0:
		var isum = p.wheelI * driven.size()
		var aa = dt / p.engineI
		var bb = ratio * ratio * dt / isum
		var need = (car.engine_w - carrier * ratio + te * aa - text * ratio * dt / isum) / (aa + bb)
		tc = clampf(need, -p.clutchTorque * engagement, p.clutchTorque * engagement)
		tin = tc * ratio
	car.engine_w = maxf(idle * .35, car.engine_w + (te - tc) * dt / p.engineI)
	car.rpm = car.engine_w * 30 / PI
	var drive = [0.0, 0.0, 0.0, 0.0]
	if int(s.layout) == 0:
		car.axle_split(2, 3, tin, torques, drive, dt)
	elif int(s.layout) == 1:
		car.axle_split(0, 1, tin, torques, drive, dt)
	else:
		var wf = (wheels[0].omega + wheels[1].omega) / 2
		var wr = (wheels[2].omega + wheels[3].omega) / 2
		var cap = 20 + absf(tin) * s.awdLock
		var need = -((wf - wr) * 2 * p.wheelI / dt + torques[0] + torques[1] - torques[2] - torques[3]) / 2
		var lock = clampf(need, -cap, cap)
		car.axle_split(0, 1, tin * (1 - s.awdRear) + lock, torques, drive, dt)
		car.axle_split(2, 3, tin * s.awdRear - lock, torques, drive, dt)
	car.abs_active = false
	for i in 4:
		var w = wheels[i]
		w.omega += (drive[i] + torques[i]) * dt / p.wheelI
		var cap = s.brakeTorque * input.brake * (s.brakeBias if i < 2 else 1 - s.brakeBias) / 2
		if i >= 2:
			cap += s.handbrakeTorque * input.handbrake / 2
		cap = VehicleAids.abs_brake(car, w, i, cap, dt)
		cap += asm_brakes[i] * w.abs
		w.brakeT = cap
		var dw = cap * dt / p.wheelI
		w.omega = 0.0 if absf(w.omega) <= dw else w.omega - car.sg(w.omega) * dw
