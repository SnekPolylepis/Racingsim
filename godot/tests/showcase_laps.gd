extends SceneTree
const Car = preload("res://scripts/car.gd")
const Track = preload("res://scripts/track3d.gd")
const Race = preload("res://scripts/race.gd")
const Controls = preload("res://scripts/controls.gd")
const Driver = preload("res://scripts/showcase_driver.gd")
const Collisions = preload("res://scripts/collisions.gd")
const Game = preload("res://scripts/game.gd")


func _initialize():
	var track = Track.new()
	track.load_data(JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Spa-Francorchamps.json")))
	track.build_barriers()
	var preset = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json")).f296gt3
	var results = []
	var failures = []
	for mode in ["Simulation-pad", "Simcade-pad", "Simcade-keyboard", "Simcade-human"]:
		var settings = Game.DEFAULT_SETTINGS.duplicate(true)
		var car = Car.new()
		car.simcade_enabled = not mode.begins_with("Simulation")
		car.configure(preset)
		car.reset_pose(track.grid_pose())
		var controls = Controls.new()
		controls.configure(settings)
		var driver = Driver.new()
		driver.digital = "keyboard" in mode or "human" in mode
		driver.human_errors = "human" in mode
		var race = Race.new()
		var top_speed = 0.0
		for tick in 600 * 240:
			driver.feed(controls, car, track, settings)
			car.input = controls.update(1.0 / 240, car.speed)
			var assist = settings.steer_assist_pad if controls.pad_active else settings.steer_assist_kb
			car.steer_falloff = 14.0 / assist if assist > .001 else 0.0
			var grip = settings.steer_grip_pad if controls.pad_active else settings.steer_grip_kb
			car.steer_slip_limit = car.peak_slip_angle() * .85 if grip else 0.0
			car.step(1.0 / 240, track)
			Collisions.step(car, track, 1.0 / 240)
			driver.observe(car, track, car.collided)
			race.update(car, track, 1.0 / 240)
			top_speed = maxf(top_speed, car.speed * 3.6)
			if race.completed > 0:
				break
		var row = {
			"case": mode,
			"lap": race.last,
			"valid": race.last_valid,
			"off_steps": driver.off_steps,
			"contacts": driver.contacts,
			"kemmel_kmh": driver.kemmel_top,
			"top_kmh": top_speed,
			"peak_slip_deg": driver.maximum_slip,
			"interventions": driver.interventions
		}
		results.append(row)
		print("SHOWCASE LAP " + JSON.stringify(row))
		if not race.last_valid or driver.off_steps > 0 or driver.contacts > 0 or driver.maximum_slip >= 15:
			failures.append(mode)
		if driver.human_errors and driver.interventions.values().min() <= 0:
			failures.append("Missing human-style intervention")
	var output = "res://tests/showcase"
	DirAccess.make_dir_recursive_absolute(output)
	var file = FileAccess.open(output.path_join("laps.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "failures": failures}, "  "))
	print("SHOWCASE LAPS " + ("PASS" if failures.is_empty() else "FAIL") + " " + str(failures))
	quit(0 if failures.is_empty() else 1)
