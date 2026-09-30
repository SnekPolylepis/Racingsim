extends RefCounted
class_name ForceFeedback

## Steering-cue processor and gamepad rumble output (FFB-01).
## DirectInput torque is sent to the connected CSL DD through the Windows wheel bridge.
## Synthesizes self-aligning torque, low-speed centering/damper resistance,
## asymmetric kerb and bump kickback, and dual-motor haptic rumble/impact cues.
## Features soft-saturation clipping protection to preserve road details under high load.

const REF_TORQUE = 30.0
const LOW_SPEED_THRESHOLD = 5.0
const SOFT_CLIP_KNEE = 0.85

var raw_torque: float = 0.0
var norm_torque: float = 0.0
var centering_force: float = 0.0
var kerb_torque: float = 0.0
var bump_torque: float = 0.0
var total_torque: float = 0.0
var output_torque: float = 0.0
var is_clipping: bool = false
var clip_depth: float = 0.0
var weak_vibration: float = 0.0
var strong_vibration: float = 0.0

var kerb_phase: float = 0.0
var impact_decay: float = 0.0
var current_device: int = 0
var was_active: bool = false
var wheel = null


static func _prop(obj, name: String, default = null):
	if obj is Dictionary:
		return obj.get(name, default)
	elif obj != null and name in obj:
		var val = obj.get(name)
		return val if val != null else default
	return default


## Soft saturation curve with linear response up to knee, then smooth asymptotic compression up to 1.0.
## Preserves high-frequency details (bumps, kerb edges) from being hard-squared off during heavy cornering.
static func soft_clip(val: float, knee: float = SOFT_CLIP_KNEE) -> float:
	var a = absf(val)
	if a <= knee:
		return val
	var excess = a - knee
	var headroom = 1.0 - knee
	var compressed = knee + headroom * (1.0 - exp(-excess / headroom))
	return signf(val) * minf(compressed, 1.0)


## Calculate and output force feedback cues.
## Called each physics tick from the vehicle simulation loop.
func update(
	car, dt: float, impact: float, active: bool, settings: Dictionary, device_id: int = 0
) -> Dictionary:
	current_device = device_id
	var enabled = settings.get("ffb_enabled", true)
	if not active or not enabled or car == null:
		if was_active:
			stop(device_id)
		return get_state()

	was_active = true
	var gain = float(settings.get("ffb_gain", 1.0))
	var damper = float(settings.get("ffb_damper", 0.25))
	var kerb_scale = float(settings.get("ffb_kerb", 1.0))
	var road_scale = float(settings.get("ffb_road", 0.8))

	# 1. Self-aligning torque from front tyres (wheels[0].mz + wheels[1].mz)
	# Positive steer_torque steers right; on the steering wheel, FFB opposes driver steering to provide natural weight.
	raw_torque = float(_prop(car, "steer_torque", 0.0))
	norm_torque = -raw_torque / REF_TORQUE

	# 2. Centering & scrub damper at low speed / standstill
	# Real tyres experience scrub friction and mechanical caster resistance when turning at low speed.
	# At speed > LOW_SPEED_THRESHOLD, tyre pneumatic trail provides natural self-centering.
	var speed = float(_prop(car, "speed", 0.0))
	var low_speed_blend = 1.0 - clampf(speed / LOW_SPEED_THRESHOLD, 0.0, 1.0)
	var steer_in = 0.0
	var car_input = _prop(car, "input")
	if car_input is Dictionary:
		steer_in = float(car_input.get("steer", 0.0))
	centering_force = -steer_in * damper * low_speed_blend
	# High-speed dynamic yaw damping: attenuates violent tank-slappers
	var ang = _prop(car, "ang")
	var ang_y = ang.y if ang is Vector3 else 0.0
	centering_force -= ang_y * 0.04 * (1.0 - low_speed_blend)

	# 3. Asymmetric kerb and suspension bump kickback (torque cues)
	kerb_torque = 0.0
	bump_torque = 0.0
	var wheels = _prop(car, "wheels", [])
	if wheels is Array and wheels.size() >= 2:
		var w_fl = wheels[0]
		var w_fr = wheels[1]
		# Kerb surface kickback
		var fl_on_kerb = _prop(_prop(w_fl, "surf", {}), "id", 0) == 1
		var fr_on_kerb = _prop(_prop(w_fr, "surf", {}), "id", 0) == 1
		if fl_on_kerb or fr_on_kerb:
			var rib_pitch = 0.35  # meters
			kerb_phase += (maxf(speed, 5.0) / rib_pitch) * dt * TAU
			var pulse = sin(kerb_phase)
			# Left wheel kerb kicks steering right (+), right wheel kerb kicks left (-)
			var kick_dir = (1.0 if fl_on_kerb else 0.0) - (1.0 if fr_on_kerb else 0.0)
			if kick_dir == 0.0:
				kick_dir = 0.5 * sin(kerb_phase * 0.5)
			kerb_torque = kick_dir * pulse * 0.3 * kerb_scale

		# Suspension load asymmetry / bump kick
		var load_fl = float(_prop(w_fl, "load", 0.0))
		var load_fr = float(_prop(w_fr, "load", 0.0))
		var total_front_load = maxf(100.0, load_fl + load_fr)
		var load_diff = (load_fl - load_fr) / total_front_load
		bump_torque = clampf(load_diff * 0.25, -0.35, 0.35) * road_scale

	# 4. Total steering torque calculation and soft-saturation clipping
	total_torque = (norm_torque + centering_force + kerb_torque + bump_torque) * gain
	is_clipping = absf(total_torque) > 1.0
	clip_depth = maxf(0.0, absf(total_torque) - 1.0)
	output_torque = soft_clip(total_torque, SOFT_CLIP_KNEE)
	if wheel != null:
		wheel.active = active and enabled and settings.get("wheel_enabled", true) and (wheel.present & 1) != 0
		wheel.torque = output_torque * clampf(float(settings.get("wheel_gain", 0.35)), 0.0, 1.0)

	# 5. Dual-motor haptic rumble cues
	# Weak motor: High-frequency texture (kerb rumble, gravel/grass chatter, tyre scrub)
	var weak_rumble = 0.0
	if wheels is Array and wheels.size() >= 2:
		var w_fl = wheels[0]
		var w_fr = wheels[1]
		if _prop(_prop(w_fl, "surf", {}), "id", 0) == 1 or _prop(_prop(w_fr, "surf", {}), "id", 0) == 1:
			weak_rumble = maxf(
				weak_rumble, clampf(speed / 25.0, 0.2, 0.9) * kerb_scale * (0.6 + 0.4 * sin(kerb_phase * 2.0))
			)
		var surf_id_l = _prop(_prop(w_fl, "surf", {}), "id", 0)
		var surf_id_r = _prop(_prop(w_fr, "surf", {}), "id", 0)
		if surf_id_l == 3 or surf_id_r == 3:  # Gravel
			weak_rumble = maxf(weak_rumble, 0.6 * road_scale)
		elif surf_id_l == 2 or surf_id_r == 2:  # Grass
			weak_rumble = maxf(weak_rumble, 0.35 * road_scale)

		# Front tyre scrub vibration when near or past grip limit
		var slip_fl = absf(float(_prop(w_fl, "slipRatio", 0.0)))
		var slip_fr = absf(float(_prop(w_fr, "slipRatio", 0.0)))
		var max_slip = maxf(slip_fl, slip_fr)
		var scrub_vibe = clampf((max_slip - 0.08) * 3.0, 0.0, 0.5)
		weak_rumble = maxf(weak_rumble, scrub_vibe)

	weak_vibration = clampf(weak_rumble, 0.0, 1.0)

	# Strong motor: Low-frequency forces, vehicle load, and collision impacts
	if impact > 0.15:
		impact_decay = maxf(impact_decay, clampf(impact / 4.0, 0.25, 1.0))
	else:
		impact_decay = maxf(0.0, impact_decay - dt * 5.0)

	var load_rumble = clampf(absf(output_torque) * 0.35, 0.0, 0.4)
	strong_vibration = clampf(impact_decay + load_rumble, 0.0, 1.0)

	# 6. Apply hardware vibration
	if device_id >= 0:
		Input.start_joy_vibration(device_id, weak_vibration, strong_vibration, 0.05)

	return get_state()


## Stop all vibration immediately and reset transient states.
func stop(device_id: int = -1):
	if wheel != null:
		wheel.stop()
	var dev = device_id if device_id >= 0 else current_device
	if dev >= 0:
		Input.stop_joy_vibration(dev)
	raw_torque = 0.0
	norm_torque = 0.0
	centering_force = 0.0
	kerb_torque = 0.0
	bump_torque = 0.0
	total_torque = 0.0
	output_torque = 0.0
	is_clipping = false
	clip_depth = 0.0
	weak_vibration = 0.0
	strong_vibration = 0.0
	impact_decay = 0.0
	was_active = false


## Reset on race restart or track reload.
func clear():
	stop()
	kerb_phase = 0.0


## Return read-only snapshot dictionary for telemetry, debug displays, or regression gates.
func get_state() -> Dictionary:
	return {
		"raw_torque": raw_torque,
		"norm_torque": norm_torque,
		"centering_force": centering_force,
		"kerb_torque": kerb_torque,
		"bump_torque": bump_torque,
		"total_torque": total_torque,
		"output_torque": output_torque,
		"is_clipping": is_clipping,
		"clip_depth": clip_depth,
		"weak_vibration": weak_vibration,
		"strong_vibration": strong_vibration,
		"device_id": current_device,
		"active": was_active
	}
