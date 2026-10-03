extends SceneTree
## Monaco closure/profile and open Swimming Pool regression. Physics queries run in the physics frame.
const Monaco = preload("res://trackgen/monaco.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
const Controls = preload("res://scripts/controls.gd")
const BotDriver = preload("res://scripts/vehicle/bot_driver.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
const WallContact = preload("res://scripts/vehicle/wall_contact.gd")
var asset
var ran = false
var frames = 0
var failures = []
var checks = 0
var results = {}


func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
	print("PASS " if ok else "FAIL ", label)


func _initialize():
	asset = Monaco.build_asset()
	asset.prepare()
	root.add_child(asset)


func _physics_process(_dt):
	frames += 1
	if frames < 3:
		return false
	if ran:
		quit(1)
		return true
	ran = true
	var curve = asset.get_node("Main").working_curve()
	var length = curve.get_baked_length()
	var max_grade = 0.0
	var max_curvature = 0.0
	var crest = 0.0
	var crest_curvature = 0.0
	for i in ceili(length):
		var p = curve.sample_baked(float(i), true)
		var a = curve.sample_baked(fposmod(i - 3.0, length), true)
		var b = curve.sample_baked(fposmod(i + 3.0, length), true)
		max_grade = maxf(max_grade, absf(b.y - a.y) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.1))
		max_curvature = maxf(max_curvature, absf(b.y - 2 * p.y + a.y) / 9.0)
		var kv = (b.y - 2 * p.y + a.y) / 9.0
		# The launch run below drives 45 m in and out without steering: the whole run must be straight in plan,
		# not just +-3 m (Casino Square's crest sits in a 57 degree bend, and the car left the road).
		var p0 = curve.sample_baked(fposmod(i - 45.0, length), true)
		var p1 = curve.sample_baked(fposmod(i + 45.0, length), true)
		var ta = Vector2(p.x - p0.x, p.z - p0.z).normalized()
		var tb = Vector2(p1.x - p.x, p1.z - p.z).normalized()
		if kv < crest_curvature and absf(ta.cross(tb)) < 0.05:
			crest_curvature = kv
			crest = float(i)
	results.max_grade = max_grade
	results.max_vertical_curvature = max_curvature
	results.crest_station = crest
	check(max_grade < 0.125, "road grade stays below 12.5 percent")
	check(max_curvature < 0.002, "vertical profile has no short launch ramps, including the lap seam")
	check(asset.version == 5, "changed track geometry has separate record identity")
	var hairpin_at = asset.get_meta("fairmont_apex")
	var cars = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var surf = asset.surface()
	var planter = asset.get_node("Scenery/FairmontPlanter")
	var nearest = curve.get_closest_point(planter.position)
	var clearance = Vector2(nearest.x - planter.position.x, nearest.z - planter.position.z).length()
	results.planter_centerline_clearance = clearance
	check(clearance > 8.0, "Fairmont planter stays inside the island, clear of the road and barrier")
	for key in ["f2004", "rb19"]:
		for simcade in [false, true]:
			for keyboard in [false, true]:
				var drive = _hairpin_input(cars[key], simcade, hairpin_at, surf, keyboard)
				var label = (
					key
					+ (" Simcade" if simcade else " Simulation")
					+ (" keyboard" if keyboard else " controller")
				)
				results[label] = drive
				check(
					drive.finished and drive.walls == 0 and drive.off == 0 and drive.minimum_kmh >= 24.5,
					label + " clears Fairmont through input events"
				)
	var space = asset.get_world_3d().direct_space_state
	var open = true
	var paved = true
	for at in [Vector2(43.73536, 7.42191), Vector2(43.73399, 7.42236)]:
		var anchor = Monaco.world_of(at.x, at.y) + Vector3.UP * 2.0
		var s = curve.get_closest_offset(anchor)
		var st = asset.station(s)
		var right = st.tangent.cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var ray = PhysicsRayQueryParameters3D.create(
				st.pos + Vector3.UP * 0.5, st.pos + Vector3.UP * 0.5 + right * side * 12.0, 2
			)
			open = open and space.intersect_ray(ray).is_empty()
			var hit = surf.contact(st.pos + right * side * 8.0 + Vector3.UP * 2, Vector3.DOWN, 4.0, -1)
			paved = paved and not hit.is_empty() and hit.get("surface", -1) == 4
	check(open, "both Swimming Pool chicanes have no roadside wall collision")
	var pool_gap: Vector2 = asset.get_meta("pool_gap")
	var gap_clear = true
	var gap_at = pool_gap.x + 4.0
	while gap_at < pool_gap.y - 4.0:
		var gap_station = asset.station(gap_at)
		var gap_right = gap_station.tangent.cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var ray = PhysicsRayQueryParameters3D.create(
				gap_station.pos + Vector3.UP * 0.5,
				gap_station.pos + Vector3.UP * 0.5 + gap_right * side * 12.0,
				2
			)
			gap_clear = gap_clear and space.intersect_ray(ray).is_empty()
		gap_at += 8.0
	check(gap_clear, "wall-free Swimming Pool span stays clear between chicane anchors")
	check(paved, "open chicane edges have collidable paved escape space")
	var approach = asset.station(
		curve.get_closest_offset(Monaco.world_of(43.7361, 7.42181) + Vector3.UP * 3.0)
	)
	var approach_right = approach.tangent.cross(Vector3.UP).normalized()
	var retained = true
	for side in [-1.0, 1.0]:
		var ray = PhysicsRayQueryParameters3D.create(
			approach.pos + Vector3.UP * 0.5, approach.pos + Vector3.UP * 0.5 + approach_right * side * 12.0, 2
		)
		retained = retained and not space.intersect_ray(ray).is_empty()
	check(retained, "barriers remain on the Tabac approach outside the Swimming Pool chicanes")
	var rascasse = asset.station(
		curve.get_closest_offset(Monaco.world_of(43.73245, 7.42275) + Vector3.UP * 3.0)
	)
	var rascasse_right = rascasse.tangent.cross(Vector3.UP).normalized()
	var rascasse_retained = true
	for side in [-1.0, 1.0]:
		var ray = PhysicsRayQueryParameters3D.create(
			rascasse.pos + Vector3.UP * 0.5, rascasse.pos + Vector3.UP * 0.5 + rascasse_right * side * 12.0, 2
		)
		rascasse_retained = rascasse_retained and not space.intersect_ray(ray).is_empty()
	check(rascasse_retained, "barriers remain at Rascasse after the Swimming Pool chicanes")
	check(
		(
			asset.get_node_or_null("Scenery/HarbourStand") == null
			and asset.get_node_or_null("Scenery/PoolStand") == null
		),
		"Swimming Pool chicanes have no stand walls or crowd panels"
	)
	var d = Monaco.data()
	var harbour = Monaco.world_of(43.735, 7.4245)
	var ix = roundi((harbour.x - d.ground.x0) / d.ground.cell)
	var iz = roundi((harbour.z - d.ground.z0) / d.ground.cell)
	check(d.ground.h[iz][ix] < Monaco.SEA_Y, "mapped harbour water is not filled by DEM ground")
	for key in ["roadster", "f296gt3", "rb19"]:
		for at in [0.0, crest]:
			var label = "seam" if at == 0.0 else "crest"
			var car = CarBody.new()
			car.configure(cars[key])
			var st = asset.station(fposmod(at - 45.0, length))
			var forward = st.tangent
			var right = forward.cross(Vector3.UP).normalized()
			var up = right.cross(forward).normalized()
			TrackDrive.place_on_grid(car, Transform3D(Basis(right, up, -forward), st.pos))
			for k in 240:
				car.input = {"throttle": 0.0, "brake": 1.0, "steer": 0.0, "clutch": 1.0, "handbrake": 0.0}
				car.step(1.0 / 240, surf, false)
			var speed = 60.0 if at == 0.0 else 45.0
			car.launch(speed)
			car.vel = st.tangent * speed
			var airborne = 0
			var longest = 0
			for k in 360:
				car.input.brake = 0.0
				car.step(1.0 / 240, surf, false)
				airborne = airborne + 1 if car.contacts == 0 else 0
				longest = maxi(longest, airborne)
			results[key + "_" + label + "_airborne_s"] = longest / 240.0
			check(
				longest <= 12 and car.pos.is_finite(),
				key + " crosses " + label + " at " + str(roundi(speed * 3.6)) + " km/h without a launch"
			)
	print("MONACO RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


## Automated driving reference passed through the player's keyboard ramps or controller mapping at 10 Hz.
## This exercises the input path; it does not substitute for a human playtest.
func _hairpin_input(preset, simcade, at, surf, keyboard) -> Dictionary:
	var car = CarBody.new()
	car.simcade_enabled = simcade
	car.configure(preset)
	var st = asset.station(at - 65.0)
	var right = st.tangent.cross(Vector3.UP).normalized()
	TrackDrive.place_on_grid(car, Transform3D(Basis(right, right.cross(st.tangent), -st.tangent), st.pos))
	car.launch(45.0 / 3.6)
	var bot = BotDriver.new(asset.get_node("BotLine"), car, surf)
	var controls = Controls.new()
	controls.poll_hardware = false
	var walls = WallQuery.new(asset, car.hull_half)
	var result = {"finished": false, "walls": 0, "off": 0, "minimum_kmh": INF}
	var input_ticks = 24
	for tick in 240 * 25:
		var command = bot.command(car)
		if keyboard and tick % input_ticks == 0:
			var keys = {
				KEY_W: command.throttle >= 0.99 or command.throttle > controls.raw.throttle,
				KEY_S: command.brake >= 0.99 or command.brake > controls.raw.brake,
				KEY_A: command.steer <= -0.99 or command.steer < controls.raw.steer - 0.002,
				KEY_D: command.steer >= 0.99 or command.steer > controls.raw.steer + 0.002
			}
			for key in keys:
				var event = InputEventKey.new()
				event.physical_keycode = key
				event.pressed = keys[key]
				controls.handle(event, true)
		elif not keyboard and tick % input_ticks == 0:
			for action in ["steer", "throttle", "brake"]:
				var event = InputEventJoypadMotion.new()
				event.device = 0
				event.axis = controls.pad[action].axis
				var value = float(command[action])
				event.axis_value = (
					(
						signf(value)
						* (controls.dead + (1.0 - controls.dead) * pow(absf(value), 1.0 / controls.linearity))
					)
					if action == "steer" and value != 0.0
					else value
				)
				controls.handle(event, true)
		car.input = controls.update(1.0 / 240.0, car.speed)
		car.step(1.0 / 240.0, surf, true)
		result.walls += WallContact.step(car, walls)
		for wheel in car.wheels:
			if wheel.load > 0 and wheel.surf.id >= 2:
				result.off += 1
		if absf(bot.s - at) < 35.0:
			result.minimum_kmh = minf(result.minimum_kmh, car.speed * 3.6)
		if bot.s > at + 65.0:
			result.finished = true
			break
	return result
