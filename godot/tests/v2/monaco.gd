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
		max_grade = maxf(max_grade, absf(b.y - a.y) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.1))
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
	check(max_curvature < 0.002, "vertical profile has no short launch ramps, including the lap seam")
	check(asset.version == 4, "changed track geometry has separate record identity")
	var hairpin_at = asset.get_meta("corners")["Grand Hotel Hairpin"]
	var pa = curve.sample_baked(hairpin_at - 2.0, true)
	var pb = curve.sample_baked(hairpin_at, true)
	var pc = curve.sample_baked(hairpin_at + 2.0, true)
	var a2 = Vector2(pa.x, pa.z)
	var b2 = Vector2(pb.x, pb.z)
	var c2 = Vector2(pc.x, pc.z)
	var hairpin_radius = (
		a2.distance_to(b2) * b2.distance_to(c2) * c2.distance_to(a2)
		/ (2.0 * absf((b2 - a2).cross(c2 - a2)))
	)
	var cars = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	for key in ["f2004", "rb19"]:
		var formula = CarBody.new()
		formula.configure(cars[key])
		var speed = 45.0 / 3.6
		var available_lock = deg_to_rad(formula.setup.maxSteer) / (1.0 + speed / formula.steer_falloff)
		var required_lock = atan((formula.p.a + formula.p.b) / hairpin_radius)
		check(
			available_lock >= required_lock,
			key + " has enough front-wheel lock for the Fairmont centreline at 45 km/h"
		)
	var surf = asset.surface()
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
			rascasse.pos + Vector3.UP * 0.5,
			rascasse.pos + Vector3.UP * 0.5 + rascasse_right * side * 12.0,
			2
		)
		rascasse_retained = rascasse_retained and not space.intersect_ray(ray).is_empty()
	check(rascasse_retained, "barriers remain at Rascasse after the Swimming Pool chicanes")
	check(
		asset.get_node_or_null("Scenery/HarbourStand") == null
			and asset.get_node_or_null("Scenery/PoolStand") == null,
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
