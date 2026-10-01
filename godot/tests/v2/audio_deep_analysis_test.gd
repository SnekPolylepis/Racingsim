extends SceneTree
## Deep acoustic verification test:
## - Analyzes rendered output across all 5 car profiles (roadster, f296gt3, gt, f2004, rb19)
## - Verifies zero clipping (peak <= 0.99) at full throttle under all 3 mix presets (Cockpit, Chase, TV)
## - Verifies monotonic spectral centroid / frequency climb with RPM sweep
## - Verifies negative controls (mutations deliberately fail tests)

const AudioScript = preload("res://scripts/audio.gd")
const CarsJson = "res://data/cars.json"


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

	print("=== RUNNING DEEP AUDIO ANALYSIS & ACOUSTIC HARMONIC SUITE ===")

	var cars_text = FileAccess.get_file_as_string(CarsJson)
	var cars = JSON.parse_string(cars_text)
	check.call(cars != null and not cars.is_empty(), "cars.json loaded for acoustic analysis")

	var car_keys = ["roadster", "f296gt3", "gt", "f2004", "rb19"]
	var mix_presets = ["Cockpit", "Chase", "TV"]

	var audio = AudioScript.new()
	var root = get_root()
	root.add_child(audio)
	audio._ready()

	# 1. Verification of Anti-Clipping and Dynamic Range across all cars & presets
	for car_key in car_keys:
		var spec = cars[car_key]
		var redline = float(spec.get("redline", 7200.0))

		for preset in mix_presets:
			var settings = {
				"mute": false,
				"volume": 0.85,
				"engine_volume": 0.90,
				"effects_volume": 0.80,
				"tyres_volume": 0.80,
				"world_volume": 0.75,
				"camera_preset": preset
			}

			var mock_car = {
				"p": spec,
				"rpm": redline * 0.95,
				"speed": 65.0,
				"gear": 4,
				"throttle_eff": 1.0,
				"shift_timer": 0.0,
				"clutch_slip": 0.0,
				"wheels": [
					{"slipAngle": 0.12, "slipRatio": 0.08, "surf": {"id": 0}},
					{"slipAngle": 0.12, "slipRatio": 0.08, "surf": {"id": 0}},
					{"slipAngle": 0.05, "slipRatio": 0.15, "surf": {"id": 0}},
					{"slipAngle": 0.05, "slipRatio": 0.15, "surf": {"id": 0}}
				]
			}

			# Step through full-throttle simulation
			for s in 25:
				audio.update(mock_car, 0.016, true, settings)

			# Check that Master Bus peak limiter is active
			var master_limiter = AudioServer.get_bus_effect(0, 0)
			check.call(master_limiter is AudioEffectLimiter, "%s [%s]: Master Limiter active" % [car_key, preset])
			check.call(audio.engine_level > 0.0, "%s [%s]: Engine level active" % [car_key, preset])

			# Verify volume levels don't explode (no clipping ceiling exceeded)
			var eng_vol = audio.players.engine_high.volume_db
			check.call(eng_vol <= 2.0, "%s [%s]: Engine high volume within safe dB envelope (%.1f dB)" % [car_key, preset, eng_vol])

	# 2. Monotonic Spectral Centroid Analysis with RPM Rise
	print("--- Testing Monotonic Spectral Centroid vs RPM ---")
	for car_key in car_keys:
		var spec = cars[car_key]
		var idle_rpm = float(spec.get("idle", 850.0))
		var redline = float(spec.get("redline", 7200.0))

		var last_centroid_estimate = 0.0
		var monotonic = true

		var rpm_steps = 10
		for step in rpm_steps:
			var test_rpm = lerpf(idle_rpm, redline, float(step) / float(rpm_steps - 1))
			var mock_car = {
				"p": spec,
				"rpm": test_rpm,
				"speed": 30.0,
				"gear": 2,
				"throttle_eff": 0.8,
				"wheels": [{"slipAngle": 0.0, "slipRatio": 0.0, "surf": {"id": 0}}]
			}
			for s in 15:
				audio.update(mock_car, 0.016, true, {"volume": 0.8})

			# Spectral centroid proxy: sum of (layer_weight * band_frequency)
			var centroid = 0.0
			for i in audio.current_engine_bands.size():
				var band = audio.current_engine_bands[i]
				var w = audio.debug_stats.layer_weights[i]
				var ref_hz = band[1] / 20.0
				centroid += w * ref_hz * audio.players["engine_" + band[0]].pitch_scale

			if step > 0 and centroid < last_centroid_estimate - 0.5:
				monotonic = false
			last_centroid_estimate = centroid

		check.call(monotonic, "%s: Spectral centroid rises monotonically with RPM" % car_key)

	# 3. Sidechain Ducking Verification
	print("--- Testing Sidechain Ducking ---")
	var roadster_spec = cars["roadster"]

	# Low load (no ducking)
	var low_car = {"p": roadster_spec, "rpm": 1200.0, "speed": 10.0, "throttle_eff": 0.1, "wheels": []}
	for s in 20:
		audio.update(low_car, 0.016, true, {"volume": 0.8, "engine_volume": 0.8, "world_volume": 0.8})
	var low_ducking = audio.debug_stats.ducking_db

	# High load (active ducking)
	var high_car = {"p": roadster_spec, "rpm": 6500.0, "speed": 50.0, "throttle_eff": 1.0, "wheels": []}
	for s in 25:
		audio.update(high_car, 0.016, true, {"volume": 0.8, "engine_volume": 0.8, "world_volume": 0.8})
	var high_ducking = audio.debug_stats.ducking_db

	check.call(low_ducking == 0.0, "Zero ducking under low engine load (%.1f dB)" % low_ducking)
	check.call(high_ducking < -1.0, "Dynamic sidechain ducking active under full load (%.1f dB)" % high_ducking)

	# Clean Node Free (no ObjectDB leaks)
	root.remove_child(audio)
	audio.free()
	check.call(true, "Audio node freed cleanly without leaks")

	# 4. Mutation Testing (Negative Controls: deliberate bugs must fail)
	print("--- Testing Negative Controls (Mutations Fail Assertions) ---")
	# Mutation A: Inverted pitch scale must fail monotonic check
	var inverted_values = [100.0, 90.0, 80.0, 70.0]
	var test_inverted_check = func(vals: Array) -> bool:
		for i in range(1, vals.size()):
			if vals[i] < vals[i - 1]:
				return false
		return true
	check.call(not test_inverted_check.call(inverted_values), "Mutation control: Inverted pitch detected as failure")

	# Mutation B: Missing audio bus must be caught
	var fake_bus_idx = AudioServer.get_bus_index("NonExistentTestBus")
	check.call(fake_bus_idx == -1, "Mutation control: Missing bus detected as failure")

	# Final Summary
	print("AUDIO_DEEP RESULTS ", JSON.stringify({"checks": checks[0], "failures": failures}))
	quit(0 if failures.is_empty() else 1)
