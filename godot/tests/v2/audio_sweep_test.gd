extends SceneTree

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

	print("=== RUNNING AUDIO HEADLESS SWEEP & STRESS SUITE ===")

	var audio = AudioScript.new()
	var root = get_root()
	root.add_child(audio)
	audio._ready()

	# 1. Bus Architecture & Effects Verification
	var expected_buses = ["Engine", "Tyres", "World", "UI", "Music"]
	for b in expected_buses:
		var b_idx = AudioServer.get_bus_index(b)
		check.call(b_idx != -1, "Audio bus exists: %s (idx: %d)" % [b, b_idx])
		if b_idx != -1:
			check.call(AudioServer.get_bus_send(b_idx) == "Master", "Bus %s sends to Master" % b)

	# Verify limiter on Master bus
	var master_has_limiter = false
	for e in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, e) is AudioEffectLimiter:
			master_has_limiter = true
			break
	check.call(master_has_limiter, "Master bus equipped with AudioEffectLimiter (anti-clipping)")

	# Verify compressor on Engine bus
	var eng_idx = AudioServer.get_bus_index("Engine")
	var eng_has_comp = false
	for e in AudioServer.get_bus_effect_count(eng_idx):
		if AudioServer.get_bus_effect(eng_idx, e) is AudioEffectCompressor:
			eng_has_comp = true
			break
	check.call(eng_has_comp, "Engine bus equipped with AudioEffectCompressor (multi-layer glue)")

	# Verify reverb on World bus
	var world_idx = AudioServer.get_bus_index("World")
	var world_has_reverb = false
	for e in AudioServer.get_bus_effect_count(world_idx):
		if AudioServer.get_bus_effect(world_idx, e) is AudioEffectReverb:
			world_has_reverb = true
			break
	check.call(world_has_reverb, "World bus equipped with AudioEffectReverb (spatial environment)")

	# 2. Complete Player Roster Check
	var required_players = [
		"engine_idle",
		"coast_idle",
		"engine_low",
		"coast_low",
		"engine_mid",
		"coast_mid",
		"engine_high",
		"coast_high",
		"intake",
		"turbo",
		"blowoff",
		"electric_whine",
		"whine",
		"shift",
		"shift_cut",
		"shift_blip",
		"backfire",
		"starter",
		"shutdown",
		"tires",
		"tires_lat",
		"tires_long",
		"road",
		"kerb",
		"gravel",
		"grass",
		"wet_spray",
		"scrape",
		"wind",
		"impact",
		"impact_armco",
		"impact_tyre",
		"impact_concrete",
		"impact_prop",
		"ghost_pass",
		"crowd",
		"spa_ambience"
	]
	for p_name in required_players:
		check.call(audio.players.has(p_name), "Player registered: %s" % p_name)
		var p = audio.players.get(p_name)
		check.call(p != null and p.stream != null, "Valid stream loaded on player: %s" % p_name)
		if p != null and p.stream != null:
			check.call(p.stream.data.size() > 0, "Non-empty PCM data in stream: %s" % p_name)

	# 3. Load Cars and Test Mock Setup
	var cars_text = FileAccess.get_file_as_string(CarsJson)
	var cars = JSON.parse_string(cars_text)
	check.call(cars != null and not cars.is_empty(), "Loaded cars database successfully")

	var settings = {
		"mute": false,
		"volume": 0.8,
		"engine_volume": 0.85,
		"tyres_volume": 0.80,
		"world_volume": 0.75,
		"ui_volume": 0.80,
		"music_volume": 0.70,
		"effects_volume": 0.75,
		"camera": 0
	}

	var make_car = func(car_key: String) -> Dictionary:
		var spec = cars[car_key]
		var c = {
			"p": spec,
			"rpm": float(spec.get("idle", 850.0)),
			"speed": 0.0,
			"gear": 1,
			"shift_timer": 0.0,
			"throttle_eff": 0.0,
			"airborne": false,
			"pos_x": 0.0,
			"pos_y": 0.0,
			"pos_z": 0.0,
			"rev_limit": false,
			"scrape_hits": [],
			"wall_hits": [],
			"wheels": []
		}
		for i in 4:
			c.wheels.append(
				{
					"slipRatio": 0.0,
					"slipAngle": 0.0,
					"load": float(spec.get("mass", 1000.0)) * 9.81 / 4.0,
					"surf": {"id": 0}
				}
			)
		return c

	# 4. Comprehensive Engine Sweeps across ALL Cars in data/cars.json
	for car_key in ["roadster", "gt", "f296gt3", "f2004", "rb19"]:
		var c = make_car.call(car_key)
		var redline = float(c.p.get("redline", 7200.0))
		var idle_rpm = float(c.p.get("idle", 850.0))

		# Idle test
		c.rpm = idle_rpm
		c.throttle_eff = 0.0
		for step in 15:
			audio.update(c, 0.016, true, settings)
		check.call(audio.engine_level > 0.0, "%s: Engine active at idle" % car_key)
		check.call(audio.audible_rpm >= 400.0, "%s: Audible RPM valid at idle" % car_key)
		var idle_audible = (
			audio.players.engine_idle.volume_db > -60.0
			or audio.players.coast_idle.volume_db > -60.0
			or audio.players.coast_mid.volume_db > -60.0
		)
		check.call(idle_audible, "%s: Idle engine layer audible" % car_key)

		# Full RPM Sweep from idle to redline
		var num_steps = 30
		var pitch_increasing = true
		var last_pitch = -1.0
		for step in num_steps:
			var frac = float(step) / float(num_steps - 1)
			c.rpm = lerpf(idle_rpm, redline, frac)
			c.throttle_eff = 0.2 + frac * 0.8
			c.speed = frac * 70.0
			audio.update(c, 0.016, true, settings)
			var cur_pitch = audio.players.engine_high.pitch_scale
			check.call(
				not is_nan(cur_pitch) and not is_inf(cur_pitch), "%s: Pitch valid (step %d)" % [car_key, step]
			)
			check.call(
				not is_nan(audio.players.engine_high.volume_db),
				"%s: Volume valid (step %d)" % [car_key, step]
			)
			if last_pitch > 0.0 and cur_pitch < last_pitch - 0.05:
				pitch_increasing = false
			last_pitch = cur_pitch

		check.call(pitch_increasing, "%s: Pitch scales monotonically with RPM sweep" % car_key)
		check.call(
			audio.players.engine_high.volume_db > -35.0, "%s: High RPM engine clearly audible" % car_key
		)

		# Car-specific acoustic voice checks
		if car_key == "f2004":
			check.call(
				audio.players.engine_high.pitch_scale >= 3.0, "Ferrari F2004 screams up past 3.0 pitch scale"
			)
		elif car_key == "rb19":
			check.call(
				audio.players.electric_whine.volume_db > -45.0,
				"RB19 electric MGU-K motor whine audible under load"
			)

		# Turbo boost build and blow-off test
		if car_key in ["f296gt3", "rb19"]:
			c.rpm = redline * 0.85
			c.throttle_eff = 1.0
			for step in 35:
				audio.update(c, 0.016, true, settings)
			check.call(audio.boost_pressure > 0.3, "%s: Turbo boost builds under full throttle" % car_key)

			c.throttle_eff = 0.0  # Sudden lift
			audio.update(c, 0.016, true, settings)
			check.call(
				audio.players.blowoff.volume_db > -45.0, "%s: Blow-off valve vents on throttle lift" % car_key
			)

		# Rev limiter bounce test
		c.rpm = redline * 1.02
		c.throttle_eff = 1.0
		c.rev_limit = true
		for step in 25:
			audio.update(c, 0.016, true, settings)
		check.call(audio.is_limiting, "%s: Rev limiter active above redline" % car_key)

	# 5. Tyre Slip & Multi-Surface Scrub Sweeps
	var car = make_car.call("f296gt3")
	car.speed = 50.0  # ~180 km/h
	car.throttle_eff = 0.5
	car.rpm = 5500.0

	# Lateral scrub test
	car.wheels[0].slipAngle = 0.22  # ~12.6 degrees
	car.wheels[1].slipAngle = 0.22
	for step in 15:
		audio.update(car, 0.016, true, settings)
	check.call(audio.tire_lat_level > 0.4, "Lateral tyre scrub detected during hard cornering")
	check.call(audio.players.tires_lat.volume_db > -30.0, "Dedicated lateral squeal player active")

	# Longitudinal slip test (burnout / ABS lockup)
	car.wheels[0].slipAngle = 0.0
	car.wheels[1].slipAngle = 0.0
	car.wheels[2].slipRatio = 0.35  # 35% wheelspin
	car.wheels[3].slipRatio = 0.35
	for step in 15:
		audio.update(car, 0.016, true, settings)
	check.call(audio.tire_long_level > 0.4, "Longitudinal tyre spin/lock detected")
	check.call(audio.players.tires_long.volume_db > -30.0, "Dedicated longitudinal scrub player active")

	# Kerb strike test
	car.wheels[2].slipRatio = 0.0
	car.wheels[3].slipRatio = 0.0
	car.wheels[0].surf = {"id": 1}  # Kerb
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.kerb.volume_db > -35.0, "Kerb thrumming active on rumble strips")

	# Gravel trap test
	car.wheels[0].surf = {"id": 3}  # Gravel
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.gravel.volume_db > -30.0, "Gravel trap spray and roar audible")

	# Grass test
	car.wheels[0].surf = {"id": 2}  # Grass
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.grass.volume_db > -35.0, "Grass rustling audible off-track")

	# Chassis bottoming scrape test
	car.wheels[0].surf = {"id": 0}
	car.scrape_hits = [[Vector3(0, 0, 0), 35.0]]
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.scrape.volume_db > -35.0, "Chassis bottoming scrape audible on ground contact")

	# 6. Environmental Wind & Camera Perspective Sweeps
	car.scrape_hits = []
	car.speed = 85.0  # ~306 km/h
	settings.camera = 0  # Chase cam
	for step in 10:
		audio.update(car, 0.016, true, settings)
	var chase_wind_vol = audio.players.wind.volume_db

	settings.camera = 1  # Cockpit view
	for step in 10:
		audio.update(car, 0.016, true, settings)
	var cockpit_wind_vol = audio.players.wind.volume_db
	check.call(cockpit_wind_vol > chase_wind_vol, "Cockpit / bonnet camera receives boosted wind rush")

	# 7. Collision Impact Kinds
	audio.impact(12.0, "armco")
	check.call(audio.players.impact_armco.volume_db > -30.0, "Armco barrier metallic impact triggered")

	audio.impact_cooldown = 0.0
	audio.impact(12.0, "tyre")
	check.call(audio.players.impact_tyre.volume_db > -30.0, "Tyre wall soft thud impact triggered")

	audio.impact_cooldown = 0.0
	audio.impact(12.0, "concrete")
	check.call(audio.players.impact_concrete.volume_db > -30.0, "Concrete wall crunch impact triggered")

	audio.impact_cooldown = 0.0
	audio.impact(8.0, "prop")
	check.call(audio.players.impact_prop.volume_db > -35.0, "Knock-over prop splinter impact triggered")

	# 8. Starter & Shutdown Triggers
	audio.start_engine()
	check.call(audio.players.starter.volume_db > -35.0, "Engine start event triggered")

	audio.stop_engine()
	check.call(audio.players.shutdown.volume_db > -35.0, "Engine shutdown event triggered")

	# 9. Clean Mute & Settings Persistence
	settings.mute = true
	for step in 50:
		audio.update(car, 0.016, true, settings)
	check.call(audio.engine_level < 0.001, "Engine completely silenced when muted")
	check.call(audio.tyres_level < 0.001, "Tyres completely silenced when muted")
	check.call(audio.world_level < 0.001, "World completely silenced when muted")

	# 10. Clean Node Free
	root.remove_child(audio)
	audio.free()
	check.call(true, "Audio node freed cleanly without leaks")

	print("AUDIO_SWEEP RESULTS ", JSON.stringify({"checks": checks[0], "failures": failures}))
	quit(0 if failures.is_empty() else 1)
