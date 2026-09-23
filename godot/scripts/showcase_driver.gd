extends RefCounted
## Path-following demonstration/test driver. Produces ordinary inputs; never edits car motion.
var tick = 0
var held = {}
var digital = false
var human_errors = false
var input_bus = false
var kemmel_top = 0.0
var maximum_slip = 0.0
var off_steps = 0
var contacts = 0
var markers = {}
var interventions = {"la_source_late": 0, "bus_stop_late": 0, "raidillon_power": 0}
## Speed plan limits. The defaults are the original, very conservative ones (a 302 s Spa lap in the
## 296) and are what showcase_laps.gd and the performance benchmark use, so their results stay
## comparable. `corner_accel` is the lateral acceleration assumed in corners (m/s², v² = a / curvature),
## `brake_gain` the v² allowance per metre of approach (twice the assumed deceleration), `top_speed`
## the cap (m/s) and `plan_distance` how far ahead corners are scanned (m).
var top_speed = 45.0
var corner_accel = 3.2
var brake_gain = 6.0
var plan_distance = 170
## Corner scan spacing (m), and how often the speed plan is recomputed (every Nth tick; 1 = every tick).
var plan_step = 5
var plan_every = 1
var planned = 0.0


func reset():
	tick = 0
	held.clear()
	kemmel_top = 0
	maximum_slip = 0
	off_steps = 0
	contacts = 0
	markers.clear()
	interventions = {"la_source_late": 0, "bus_stop_late": 0, "raidillon_power": 0}


func command(car, track, falloff = 0.0):
	if markers.is_empty():
		for label in track.data.get("presentation", {}).get("labels", []):
			markers[label.name] = track.project(label.x, label.y).s
	var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
	var target = track.pos_at(pr.s + 5 + car.speed * .30)
	var steer = clampf(wrapf(atan2(target.y - car.y, target.x - car.x) - car.h, -PI, PI) * 2.2, -1, 1)
	if falloff > 0:
		steer *= 1 + car.speed / falloff
	var wanted = top_speed
	var late = 0.0
	if human_errors:
		for item in [["La Source", "la_source_late"], ["Bus Stop", "bus_stop_late"]]:
			if fposmod(markers.get(item[0], -1000) - pr.s, track.length) < 160:
				late = 4.0
				interventions[item[1]] += 1
	# Speed plan over the next plan_distance metres. curv_at() is pos_at().curv without building the pose.
	if plan_every <= 1 or tick % plan_every == 1:
		for d in range(0, plan_distance, plan_step):
			wanted = minf(
				wanted,
				sqrt(corner_accel / maxf(absf(track.curv_at(pr.s + d)), .0001) + brake_gain * (d + late))
			)
		planned = wanted
	wanted = planned
	var error = wanted - car.speed
	var throttle = clampf(error * .5, 0, 1)
	var brake = clampf(-error * .35, 0, 1)
	var after_raidillon = fposmod(pr.s - markers.get("Raidillon", -1000), track.length)
	if human_errors and after_raidillon > 70 and after_raidillon < 160:
		throttle = 1.0
		brake = 0.0
		interventions.raidillon_power += 1
	return {
		"throttle": throttle, "brake": brake, "steer": clampf(steer, -1, 1), "clutch": 0.0, "handbrake": 0.0
	}


func key_event(controls, code, pressed):
	if held.get(code, false) == pressed and (not pressed or controls.held_keys.has(code)):
		return
	held[code] = pressed
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	if input_bus:
		event.set_meta("showcase_input", true)
		Input.parse_input_event(event)
	else:
		controls.handle(event, true)


func feed(controls, car, track, settings):
	tick += 1
	var assist = float(settings.steer_assist_kb if digital else settings.steer_assist_pad)
	var desired = command(car, track, 14.0 / assist if assist > .001 else 0.0)
	if digital:
		var steering_error = desired.steer - controls.raw.steer
		key_event(controls, KEY_LEFT, steering_error < -.012)
		key_event(controls, KEY_RIGHT, steering_error > .012)
		key_event(controls, KEY_UP, desired.throttle > .12)
		key_event(controls, KEY_DOWN, desired.brake > .10)
	else:
		var steer = (
			signf(desired.steer)
			* (pow(absf(desired.steer), 1.0 / controls.linearity) * (1 - controls.dead) + controls.dead)
		)
		for item in [
			[JOY_AXIS_LEFT_X, steer],
			[JOY_AXIS_TRIGGER_RIGHT, desired.throttle],
			[JOY_AXIS_TRIGGER_LEFT, desired.brake]
		]:
			var event = InputEventJoypadMotion.new()
			event.device = 31
			event.axis = item[0]
			event.axis_value = item[1]
			if input_bus:
				event.set_meta("showcase_input", true)
				Input.parse_input_event(event)
			else:
				controls.handle(event, true)
	if input_bus:
		Input.flush_buffered_events()


func release(controls):
	for code in held.keys():
		key_event(controls, code, false)
	if not digital:
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_RIGHT, JOY_AXIS_TRIGGER_LEFT]:
			var event = InputEventJoypadMotion.new()
			event.device = 31
			event.axis = axis
			event.axis_value = 0
			if input_bus:
				event.set_meta("showcase_input", true)
				Input.parse_input_event(event)
			else:
				controls.handle(event, true)
	if input_bus:
		Input.flush_buffered_events()


func observe(car, track, hit):
	var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
	if (
		fposmod(pr.s - markers.get("Kemmel", 0), track.length)
		< fposmod(markers.get("Les Combes", 1) - markers.get("Kemmel", 0), track.length)
	):
		kemmel_top = maxf(kemmel_top, car.speed * 3.6)
	if car.speed > 4:
		maximum_slip = maxf(maximum_slip, absf(rad_to_deg(wrapf(atan2(car.vy, car.vx) - car.h, -PI, PI))))
	off_steps += int(car.all_off)
	contacts += int(hit)
