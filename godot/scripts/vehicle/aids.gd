extends RefCounted
## Shared steering, stability, traction control, and ABS logic.


static func tcs_level(car):
	if car.setup.has("tcsLevel"):
		return clampf(car.setup.tcsLevel, 0, 10)
	return (
		car.simcade.default_tcs
		if car.simcade_enabled
		else (car.setup.tcIntensity * 10 if car.setup.tcOn > .5 else 0.0)
	)


static func asm_level(car):
	return clampf(car.setup.get("asmLevel", car.simcade.default_asm if car.simcade_enabled else 0.0), 0, 10)


static func set_tcs(car, level):
	car.setup.tcsLevel = clampf(level, 0, 10)
	# Keep the legacy setup fields meaningful in exported setups.
	car.setup.tcOn = 1.0 if level > 0 else 0.0
	car.setup.tcIntensity = level / 10.0


static func steering(car, body_x, body_y):
	var s = car.setup
	var p = car.p
	var m = p.mass
	var speed = car.speed
	var input = car.input
	var steer_falloff = car.steer_falloff
	var steer_slip_limit = car.steer_slip_limit
	var simcade_enabled = car.simcade_enabled
	var simcade_steering = car.simcade_steering
	var simcade = car.simcade
	var r = car.r
	var RHO = car.RHO
	var G = car.G
	var steer_angle = car.steer_angle
	steer_angle = (
		input.steer * deg_to_rad(s.maxSteer) / ((1 + speed / steer_falloff) if steer_falloff > 0 else 1.0)
	)
	if steer_slip_limit > 0 and speed > 3:
		# Cap steering at what the tyres can use at this speed: the kinematic angle for a limit corner
		# (wheelbase * max lateral accel / v^2) plus the front peak slip angle. Countersteer against the
		# car's rotation may always follow the front axle's slide angle, so slides can still be caught.
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
	car.steer_angle = steer_angle


static func stability_request(car):
	var p = car.p
	var setup = car.setup
	var simcade = car.simcade
	var speed = car.speed
	var vx = car.vx
	var vy = car.vy
	var h = car.h
	var r = car.r
	var steer_angle = car.steer_angle
	var G = car.G
	car.asm_brakes = [0.0, 0.0, 0.0, 0.0]
	car.asm_cut = 0.0
	car.asm_active = false
	var level = car.asm_level()
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
	car.asm_brakes[wheel] = minf(
		absf(moment) * p.wheelR / (p.track * .5), setup.brakeTorque * simcade.asm_brake_fraction * gain
	)
	car.asm_cut = clampf(
		(absf(slip_error) * simcade.asm_slip_cut_gain + excess) * gain, 0, simcade.asm_torque_cut
	)
	car.asm_active = car.asm_cut > .01 or car.asm_brakes[wheel] > 1


static func traction_control(car, driven, dt):
	var s = car.setup
	var setup = car.setup
	var input = car.input
	var simcade_enabled = car.simcade_enabled
	var speed = car.speed
	var wheels = car.wheels
	var throttle = input.throttle
	car.tc_active = false
	var tc_on = s.tcOn
	var tc_intensity = s.tcIntensity
	if simcade_enabled or setup.has("tcsLevel"):
		tc_on = 1.0 if car.tcs_level() > 0 else 0.0
		tc_intensity = car.tcs_level() / 10.0
	if tc_on > .5 and speed > 1.5:
		var max_k = 0.0
		for i in driven:
			max_k = maxf(max_k, wheels[i].slipRatio)
		# Integral control toward just past the tyre's peak slip: trims harder the further over the
		# target the driven wheels are, and hands throttle back gently once they are below it.
		var limit = car.peak_slip_ratio() * (1.0 + .6 * (1 - tc_intensity))
		# Combined slip: the more the driven tyres are already working sideways, the less wheelspin
		# they can take before the friction ellipse steals lateral grip (power oversteer).
		var lat_use = 0.0
		for i in driven:
			lat_use = maxf(lat_use, absf(wheels[i].slipAngle) / car.peak_slip_angle())
		if lat_use > .3:
			limit *= (
				sqrt(maxf(.04, 1 - minf(lat_use, 1) * minf(lat_use, 1))) * (.5 + .5 * (1 - tc_intensity))
			)
		if max_k > limit:
			car.tc_gain -= minf(max_k - limit, .5) * (18 + 30 * tc_intensity) * dt
		else:
			car.tc_gain += 2.5 * dt
		car.tc_gain = clampf(car.tc_gain, .08, 1)
		throttle *= car.tc_gain
		car.tc_active = car.tc_gain < .97
	else:
		car.tc_gain = 1.0
	return throttle


static func abs_brake(car, w, i, cap, dt):
	var s = car.setup
	var input = car.input
	var asm_brakes = car.asm_brakes
	var speed = car.speed
	if s.absOn > .5 and (input.brake > .05 or asm_brakes[i] > 1) and speed > 2 and input.handbrake < .5:
		var abs_limit = car.peak_slip_ratio() * (1.0 + .6 * (1 - s.absIntensity))
		if w.slipRatio < -abs_limit:
			w.abs = maxf(.15, w.abs - 25 * dt)
			car.abs_active = true
		else:
			w.abs = minf(1, w.abs + 8 * dt)
		cap *= w.abs
	else:
		w.abs = 1
	return cap
