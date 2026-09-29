extends SceneTree
## Monaco closure/profile and open Swimming Pool regression. Physics queries run in the physics frame.
const Monaco = preload("res://trackgen/monaco.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
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
		max_grade = maxf(
			max_grade, absf(b.y - a.y) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.1)
		)
		max_curvature = maxf(max_curvature, absf(b.y - 2 * p.y + a.y) / 9.0)
		var kv = (b.y - 2 * p.y + a.y) / 9.0
		var ta = Vector2(p.x - a.x, p.z - a.z).normalized()
		var tb = Vector2(b.x - p.x, b.z - p.z).normalized()
		if kv < crest_curvature and absf(ta.cross(tb)) < 0.006:
			crest_curvature = kv
			crest = float(i)
	results.max_grade = max_grade
	results.max_vertical_curvature = max_curvature
	results.crest_station = crest
	check(max_grade < 0.125, "road grade stays below 12.5 percent")
	check(
		max_curvature < 0.002, "vertical profile has no short launch ramps, including the lap seam"
	)
	check(asset.version == 2, "changed track geometry has separate record identity")
	var gap: Vector2 = asset.get_meta("pool_gap")
	var surf = asset.surface()
	var space = asset.get_world_3d().direct_space_state
	var open = true
	var paved = true
	for i in 12:
		var s = lerpf(gap.x + 30, gap.y - 30, i / 11.0)
		var st = asset.station(s)
		var right = st.tangent.cross(Vector3.UP).normalized()
		for side in [-1.0, 1.0]:
			var ray = PhysicsRayQueryParameters3D.create(
				st.pos + Vector3.UP * 0.5, st.pos + Vector3.UP * 0.5 + right * side * 12.0, 2
			)
			open = open and space.intersect_ray(ray).is_empty()
			var hit = surf.contact(
				st.pos + right * side * 8.0 + Vector3.UP * 2, Vector3.DOWN, 4.0, -1
			)
			paved = paved and not hit.is_empty() and hit.get("surface", -1) == 4
	check(open, "both Swimming Pool chicanes have no roadside wall collision")
	check(paved, "open chicane edges have collidable paved escape space")
	var cars = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
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
				car.input = {
					"throttle": 0.0, "brake": 1.0, "steer": 0.0, "clutch": 1.0, "handbrake": 0.0
				}
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
				(
					key
					+ " crosses "
					+ label
					+ " at "
					+ str(roundi(speed * 3.6))
					+ " km/h without a launch"
				)
			)
	print(
		"MONACO RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true
