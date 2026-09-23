extends SceneTree
## Owner-requested minimal smoke: 20 simulated seconds, Ferrari 296, grid slot 1, authored BotLine.
## Run: tools/Godot.exe --headless --path . --script trackgen/spa_drive_smoke.gd
const Drive = preload("res://scripts/proving/track_drive.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
const DT = 1.0 / 240.0
const TICKS = 20 * 240
var asset
var frames = 0
var ran = false


func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	# Check the scene produced by the preceding bake check, falling back to the normal dev loader.
	var path = "res://tracks3d/spa/spa.scn"
	asset = Drive.load_asset("spa", path if FileAccess.file_exists(path) else "")
	if asset == null:
		print("SPA DRIVE RESULTS ", JSON.stringify({"pass": false, "error": "no TrackAsset"}))
		quit(1)
		return
	root.add_child(asset)
	var errors = asset.validate()
	if not errors.is_empty() or asset.get_node_or_null("BotLine") == null:
		print(
			"SPA DRIVE RESULTS ",
			JSON.stringify({"pass": false, "errors": errors, "error": "invalid asset or absent BotLine"})
		)
		quit(1)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("SPA DRIVE RESULTS ", JSON.stringify({"pass": false, "error": "script aborted; see stderr"}))
		quit(1)
		return true
	ran = true
	var car = CarBody.new()
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	car.configure(presets.f296gt3)
	car.wear_enabled = false
	car.steer_falloff = 0.0
	Drive.place_on_grid(car, asset.grid_slots()[0])
	var surface = asset.surface()
	var walls = WallQuery.new(asset, car.hull_half)
	var path: Path3D = asset.get_node("BotLine")
	var hint = -1
	var distance = 0.0
	var max_lateral = 0.0
	var wall_ticks = 0
	var offroad_ticks = 0
	var ticks = 0
	var finite = true
	for i in TICKS:
		var projected = asset.project(car.pos, hint)
		hint = projected.idx
		max_lateral = maxf(max_lateral, absf(projected.lateral))
		var target = bot_sample(path, projected.s + 9.0 + car.speed * .5)
		var h_target = atan2(target.pos.z - car.pos.z, target.pos.x - car.pos.x)
		var speed_error = target.kmh / 3.6 - car.speed
		car.input = {
			"throttle": clampf(speed_error * .5 + .3, 0.0, 1.0),
			"brake": clampf(-speed_error * .3, 0.0, 1.0),
			"steer": clampf(wrapf(h_target - car.h, -PI, PI) * 2.5, -1.0, 1.0),
			"clutch": 0.0,
			"handbrake": 0.0
		}
		var before = Vector3(car.pos_x, car.pos_y, car.pos_z)
		car.step(DT, surface, true)
		wall_ticks += int(WallContact.step(car, walls) > 0)
		for wheel in car.wheels:
			if wheel.surf.id >= 2:
				offroad_ticks += 1
				break
		ticks += 1
		finite = finite_state(car)
		if not finite:
			break
		distance += before.distance_to(car.pos)
	var passed = finite and ticks == TICKS and distance > 0.0
	print(
		"SPA DRIVE RESULTS ",
		JSON.stringify(
			{
				"pass": passed,
				"car": "f296gt3",
				"grid_slot": 1,
				"seconds": ticks * DT,
				"ticks": ticks,
				"finite": finite,
				"distance_m": distance,
				"max_lateral_m": max_lateral,
				"wall_contact_ticks": wall_ticks,
				"offroad_ticks": offroad_ticks,
				"final_speed_kmh": car.speed * 3.6
			}
		)
	)
	quit(0 if passed else 1)
	return true


func bot_sample(path: Path3D, station: float) -> Dictionary:
	var keys = path.get_meta("timing_stations_m")
	var speeds = path.get_meta("target_speeds_kmh")
	station = fposmod(station, float(keys[keys.size() - 1]))
	var lo = 0
	var hi = keys.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if keys[mid] <= station:
			lo = mid
		else:
			hi = mid - 1
	var next = mini(lo + 1, keys.size() - 1)
	var fraction = clampf((station - keys[lo]) / maxf(keys[next] - keys[lo], 1e-6), 0.0, 1.0)
	var point = path.curve.get_point_position(lo).lerp(path.curve.get_point_position(next), fraction)
	return {"pos": path.transform * point, "kmh": float(speeds[lo])}


func finite_state(car) -> bool:
	for value in [
		car.pos_x, car.pos_y, car.pos_z, car.vel_x, car.vel_y, car.vel_z, car.engine_w, car.steer_angle
	]:
		if not is_finite(value):
			return false
	if not car.rot.is_finite() or not car.ang.is_finite():
		return false
	for wheel in car.wheels:
		for field in ["omega", "load", "comp", "phase", "fx", "fy"]:
			if not is_finite(wheel[field]):
				return false
	return true
