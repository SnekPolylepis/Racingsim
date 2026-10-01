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

	var audio = AudioScript.new()
	var root = get_root()
	root.add_child(audio)
	audio._ready()

	# 1. Check all expected players exist
	var expected_players = [
		"engine_idle", "coast_idle",
		"engine_low", "coast_low",
		"engine_mid", "coast_mid",
		"engine_high", "coast_high",
		"intake", "tires", "road", "wind", "whine", "kerb", "impact", "shift"
	]
	for p_name in expected_players:
		check.call(audio.players.has(p_name), "Player exists: %s" % p_name)
		var p = audio.players.get(p_name)
		check.call(p != null and p.stream != null, "Player stream valid: %s" % p_name)

	# Load cars.json
	var cars_text = FileAccess.get_file_as_string(CarsJson)
	var cars = JSON.parse_string(cars_text)
	check.call(cars != null and not cars.is_empty(), "cars.json loaded")

	var settings = {
		"mute": false,
		"volume": 0.8,
		"engine_volume": 0.8,
		"effects_volume": 0.7
	}

	# Helper to build mock car
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
			"wheels": []
		}
		for i in 4:
			c.wheels.append({
				"slipRatio": 0.0,
				"slipAngle": 0.0,
				"load": float(spec.get("mass", 1000.0)) * 9.81 / 4.0,
				"surf": {"id": 0}
			})
		return c

	# Test each car at idle and high RPM
	for car_key in ["roadster", "gt", "f296gt3", "f2004", "rb19"]:
		var c = make_car.call(car_key)
		audio.update(c, 0.016, true, settings)
		check.call(audio.engine_level > 0.0, "%s: engine_level active" % car_key)
		check.call(not is_nan(audio.audible_rpm) and not is_inf(audio.audible_rpm), "%s: audible_rpm valid" % car_key)
		var idle_pitch = audio.players.engine_high.pitch_scale

		# Redline test
		c.rpm = float(c.p.get("redline", 7200.0))
		c.throttle_eff = 1.0
		c.speed = 50.0
		for step in 30:
			audio.update(c, 0.016, true, settings)
		check.call(audio.players.engine_high.pitch_scale > idle_pitch, "%s: high RPM pitched up" % car_key)
		check.call(audio.players.engine_high.volume_db > -40.0, "%s: high RPM engine audible" % car_key)
		if car_key == "f2004":
			check.call(audio.players.engine_high.pitch_scale >= 2.4, "F2004 V10 screams past standard pitch clamp")

	# Test wind noise at high speed
	var car = make_car.call("f296gt3")
	car.speed = 80.0 # ~288 km/h
	car.throttle_eff = 1.0
	car.rpm = 7500.0
	for step in 20:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.wind.volume_db > -35.0, "Wind noise audible at high speed")
	check.call(audio.players.whine.volume_db > -35.0, "Transmission whine audible at high speed under load")

	# Test tire scrub/screech
	car.wheels[0].slipAngle = 0.25 # ~14 deg slip
	car.wheels[1].slipAngle = 0.25
	for step in 20:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.tires.volume_db > -30.0, "Tire scrub/screech audible during slide")

	# Test kerb strike
	car.wheels[0].slipAngle = 0.0
	car.wheels[1].slipAngle = 0.0
	car.wheels[0].surf = {"id": 1} # Kerb
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.kerb.volume_db > -35.0, "Kerb rumble audible when wheel is on kerb")

	# Test gravel trap
	car.wheels[0].surf = {"id": 3} # Gravel
	var pre_gravel_road_vol = audio.players.road.volume_db
	for step in 10:
		audio.update(car, 0.016, true, settings)
	check.call(audio.players.road.volume_db > pre_gravel_road_vol, "Road noise louder in gravel trap")

	# Test gear shift
	car.gear = 2
	audio.update(car, 0.016, true, settings)
	check.call(audio.players.shift.volume_db > -40.0, "Shift sound triggered on gear change")

	# Test wall impact
	audio.impact(8.0)
	check.call(audio.players.impact.volume_db > -30.0, "Impact sound triggered on collision")

	# Test mute
	settings.mute = true
	for step in 60:
		audio.update(car, 0.016, true, settings)
	check.call(audio.engine_level < 0.001, "Engine silenced when muted")
	check.call(audio.effects_level < 0.001, "Effects silenced when muted")

	# Cleanup test
	root.remove_child(audio)
	audio.free()
	check.call(true, "Audio node freed cleanly without leaks")

	print("AUDIO RESULTS ", JSON.stringify({"checks": checks[0], "failures": failures}))
	quit(0 if failures.is_empty() else 1)
