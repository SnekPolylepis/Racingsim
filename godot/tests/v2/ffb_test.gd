extends SceneTree

const FFBScript = preload("res://scripts/ffb.gd")

func _initialize():
	var checks = [0]
	var failures = []
	var check = func(ok: bool, desc: String):
		checks[0] += 1
		if not ok:
			failures.append(desc)
			print("FAIL: ", desc)
		else:
			print("PASS: ", desc)

	var ffb = FFBScript.new()
	check.call(ffb != null, "FFB instance created")

	# 1. Soft-clip mathematical properties
	check.call(is_zero_approx(FFBScript.soft_clip(0.0)), "soft_clip(0) == 0")
	check.call(is_equal_approx(FFBScript.soft_clip(0.5), 0.5), "soft_clip linear below knee (0.5)")
	check.call(is_equal_approx(FFBScript.soft_clip(0.85), 0.85), "soft_clip linear at knee (0.85)")
	var sc_1 = FFBScript.soft_clip(1.0)
	check.call(sc_1 > 0.85 and sc_1 < 1.0, "soft_clip smoothly compresses 1.0 (got %.4f)" % sc_1)
	var sc_2 = FFBScript.soft_clip(2.0)
	check.call(sc_2 > sc_1 and sc_2 <= 1.0, "soft_clip monotonic at 2.0 (got %.4f)" % sc_2)
	var sc_100 = FFBScript.soft_clip(100.0)
	check.call(sc_100 <= 1.0 and sc_100 >= 0.99, "soft_clip bounded by 1.0 at extreme overload (got %.4f)" % sc_100)
	check.call(is_equal_approx(FFBScript.soft_clip(-0.5), -0.5), "soft_clip symmetry negative")
	check.call(is_equal_approx(FFBScript.soft_clip(-1.5), -FFBScript.soft_clip(1.5)), "soft_clip odd symmetry")

	# Mock car setup
	var mock_car = {
		"speed": 0.0,
		"steer_torque": 0.0,
		"input": {"steer": 0.0},
		"ang": Vector3.ZERO,
		"wheels": [
			{"surf": {"id": 0}, "load": 2500.0, "slipRatio": 0.0},
			{"surf": {"id": 0}, "load": 2500.0, "slipRatio": 0.0},
			{"surf": {"id": 0}, "load": 2500.0, "slipRatio": 0.0},
			{"surf": {"id": 0}, "load": 2500.0, "slipRatio": 0.0}
		]
	}

	var default_settings = {
		"ffb_enabled": true,
		"ffb_gain": 1.0,
		"ffb_damper": 0.3,
		"ffb_kerb": 1.0,
		"ffb_road": 0.8
	}

	# 2. Standstill centering damper
	mock_car.speed = 0.0
	mock_car.input.steer = 0.6
	var s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(s.centering_force < 0.0, "Centering force opposes right steer at standstill (got %.4f)" % s.centering_force)
	check.call(s.output_torque < 0.0, "Output torque opposes steer at standstill (got %.4f)" % s.output_torque)

	mock_car.input.steer = -0.6
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(s.centering_force > 0.0, "Centering force opposes left steer at standstill (got %.4f)" % s.centering_force)

	# 3. High-speed fading of low-speed centering
	mock_car.speed = 25.0  # well above LOW_SPEED_THRESHOLD
	mock_car.input.steer = 0.6
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(absf(s.centering_force) < 0.01, "Low-speed centering fades to near zero at 25 m/s (got %.4f)" % s.centering_force)

	# 4. Self-aligning torque (pneumatic trail)
	mock_car.input.steer = 0.0
	mock_car.steer_torque = -15.0  # 15 Nm resisting steer
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(is_equal_approx(s.norm_torque, 0.5), "Normalized aligning torque 15 Nm / 30 Nm = 0.5 (got %.4f)" % s.norm_torque)
	check.call(s.output_torque > 0.4 and s.output_torque <= 0.5, "Output torque reflects aligning torque (got %.4f)" % s.output_torque)
	check.call(not s.is_clipping, "Not clipping at 0.5 normalized torque")

	# 5. Clipping under heavy load
	mock_car.steer_torque = -45.0  # 45 Nm / 30 Nm = 1.5 norm
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(s.is_clipping, "Clipping detected at 1.5 total torque")
	check.call(s.clip_depth > 0.4, "Clip depth measured (got %.4f)" % s.clip_depth)
	check.call(s.output_torque <= 1.0 and s.output_torque > 0.85, "Soft-saturated output compressed below 1.0 (got %.4f)" % s.output_torque)

	# 6. Kerb cues
	mock_car.steer_torque = 0.0
	mock_car.speed = 20.0
	mock_car.wheels[0].surf.id = 1  # Front Left on kerb
	mock_car.wheels[1].surf.id = 0  # Front Right on asphalt
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(absf(s.kerb_torque) > 0.0, "Kerb torque active when left wheel on kerb (got %.4f)" % s.kerb_torque)
	check.call(s.weak_vibration > 0.2, "Weak motor vibration active on kerb (got %.4f)" % s.weak_vibration)

	mock_car.wheels[0].surf.id = 0
	mock_car.wheels[1].surf.id = 0

	# 7. Road surface textures (gravel)
	mock_car.wheels[0].surf.id = 3  # gravel
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, default_settings, 0)
	check.call(s.weak_vibration >= 0.4, "Gravel texture triggers weak motor vibration (got %.4f)" % s.weak_vibration)
	mock_car.wheels[0].surf.id = 0

	# 8. Impact jolt
	s = ffb.update(mock_car, 1.0 / 240.0, 3.0, true, default_settings, 0)
	check.call(s.strong_vibration > 0.5, "Heavy impact triggers strong vibration (got %.4f)" % s.strong_vibration)

	# 9. Inactive / pause safety
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, false, default_settings, 0)
	check.call(s.output_torque == 0.0, "Output torque zero when inactive")
	check.call(s.weak_vibration == 0.0 and s.strong_vibration == 0.0, "Vibrations zero when inactive")

	# 10. Disabled in settings
	var disabled_settings = default_settings.duplicate()
	disabled_settings.ffb_enabled = false
	mock_car.steer_torque = -20.0
	s = ffb.update(mock_car, 1.0 / 240.0, 0.0, true, disabled_settings, 0)
	check.call(s.output_torque == 0.0, "Output torque zero when ffb_enabled is false")

	# 11. Clear method
	ffb.clear()
	var state = ffb.get_state()
	check.call(state.output_torque == 0.0, "Clear resets output torque")
	check.call(state.weak_vibration == 0.0, "Clear resets weak vibration")
	check.call(state.strong_vibration == 0.0, "Clear resets strong vibration")

	print("\n=== FFB TEST SUMMARY ===")
	print("Total checks: %d, Failures: %d" % [checks[0], failures.size()])
	print("FFB RESULTS ", JSON.stringify({"checks": checks[0], "failures": failures}))
	quit(0 if failures.is_empty() else 1)
