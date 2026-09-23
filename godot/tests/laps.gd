extends SceneTree
const TrackModel = preload("res://scripts/track3d.gd")
const CarModel = preload("res://scripts/car.gd")
const RaceModel = preload("res://scripts/race.gd")
const Collisions = preload("res://scripts/collisions.gd")


func _initialize():
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	for filename in ["Monza", "Spa-Francorchamps"]:
		var track = TrackModel.new()
		track.load_data(
			JSON.parse_string(FileAccess.get_file_as_string("res://tracks/" + filename + ".json"))
		)
		track.build_barriers()
		var car = CarModel.new()
		car.simcade_enabled = "--simcade" in OS.get_cmdline_user_args()
		car.configure(presets.roadster)
		car.reset_pose(track.grid_pose())
		var race = RaceModel.new()
		var off = 0
		var hits = 0
		for tick in 500 * 240:
			var pr = track.project(car.x, car.y, car.wheels[0].sIdx)
			var target = track.pos_at(pr.s + 5 + car.speed * .30)
			var steer = clampf(wrapf(atan2(target.y - car.y, target.x - car.x) - car.h, -PI, PI) * 2.2, -1, 1)
			var wanted = 38.0
			for d in range(0, 120, 5):
				wanted = minf(wanted, sqrt(3.2 / maxf(absf(track.pos_at(pr.s + d).curv), .0001) + 7 * d))
			var error = wanted - car.speed
			car.input = {
				"throttle": clampf(error * .5, 0, 1),
				"brake": clampf(-error * .35, 0, 1),
				"steer": steer,
				"clutch": 0.0,
				"handbrake": 0.0
			}
			car.step(1.0 / 240, track)
			Collisions.step(car, track, 1.0 / 240)
			race.update(car, track, 1.0 / 240)
			if car.all_off:
				off += 1
			if car.collided:
				hits += 1
			if not is_finite(car.x + car.y + car.speed):
				push_error("Non-finite physics")
				quit(1)
				return
			if race.best > 0:
				break
		print(
			"Simcade " if car.simcade_enabled else "Simulation ",
			filename,
			" best=",
			race.best,
			" offSteps=",
			off,
			" ghost=",
			race.ghost.size(),
			" barriers=",
			track.barriers.size(),
			" contacts=",
			hits
		)
		if car.simcade_enabled:
			# Simulation times for the MX-5 NA preset, re-recorded when the circuit moved onto the
			# 3-space ribbon: lap distance now includes the vertical component and curvature is the
			# true 3-D decomposition, so both circuits are marginally longer and slower than the
			# plan-view figures. Simcade must stay within 4%.
			var baseline = {"Monza": 261.504166666, "Spa-Francorchamps": 325.174999999}
			if absf(race.best / baseline[filename] - 1) > .04:
				push_error("Simcade lap differs from Simulation baseline by more than 4%")
				quit(1)
				return
		if race.best <= 0 or off != 0 or race.ghost.size() < 100 or hits != 0 or track.barriers.size() < 50:
			push_error("Lap regression failed")
			quit(1)
			return
	print("ALL NATIVE LAPS PASS")
	quit()
