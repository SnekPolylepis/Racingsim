extends SceneTree
## CHI-01 geometric acceptance: full-width surface coverage, lower/upper deck separation,
## ceiling clearance, slope, grid and landmark anchors. Driving is gated by laps.gd.
const Generator = preload("res://trackgen/chicago.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
var asset
var frames = 0
var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	asset = Generator.build_asset()
	root.add_child(asset)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if frames > 3:
		quit(1)
		return true
	check(asset.validate().is_empty(), "TrackAsset contract: %s" % [asset.validate()])
	var road = asset.get_node("Main")
	check(road.last_bake.warnings.is_empty(), "Bake without warnings")
	check(asset.length > 5000 and asset.length < 10000, "Closed lap length %.1f m" % asset.length)
	var surf = asset.surface()
	var misses = 0
	var max_error = 0.0
	var max_grade = 0.0
	var intrusions = 0
	var space = asset.get_world_3d().direct_space_state
	for st in road.last_bake.stations:
		max_grade = maxf(max_grade, absf(st.tangent.y) / Vector2(st.tangent.x, st.tangent.z).length())
		var right = st.tangent.cross(Vector3.UP).normalized()
		for lat in [-7.0, 0.0, 7.0]:
			var p = st.pos + right * lat + st.tangent * .35
			var hit = surf.contact(p + Vector3.UP * .5, Vector3.DOWN, 1.0, 0)
			if hit.get("surface", -1) != 0:
				misses += 1
				print("MISS ", st.s, " ", p, " ", hit)
			else:
				max_error = maxf(max_error, absf(hit.point.y - p.y))
		# 3 m vertical clear space for a car along the centre of the entire course, including ramps.
		var q = PhysicsRayQueryParameters3D.create(st.pos + Vector3.UP * .15, st.pos + Vector3.UP * 3.0, 2)
		if not space.intersect_ray(q).is_empty():
			intrusions += 1
	check(misses == 0, "Full lap tarmac width ±7 m: %d misses" % misses)
	check(max_error < .08, "Surface/line height error %.4f m" % max_error)
	check(max_grade < .10, "Maximum grade %.2f%%" % (max_grade * 100))
	check(intrusions == 0, "3 m headroom throughout lap: %d intrusions" % intrusions)
	for height in [0.0, 8.0]:
		var p = Generator.world([41.883, -87.6369, height])
		var hit = surf.contact(p + Vector3.UP * .5, Vector3.DOWN, 1.0, 0)
		check(
			hit.get("surface", -1) == 0 and absf(hit.get("point", Vector3.INF).y - height) < .05,
			"Wacker deck at %.0f m" % height
		)
		var projection = asset.project(p, -1)
		check(absf(projection.vertical) < .1, "Projection selects %.0f m deck" % height)
	var gates = asset.gates()
	var wrong_deck_triggers = 0
	for gate in gates:
		if gate.origin.y < .1:
			var p = gate.origin + Vector3.UP * 8
			if TrackAsset.crossed(gate, p - gate.normal * 2, p + gate.normal * 2):
				wrong_deck_triggers += 1
	check(wrong_deck_triggers == 0, "Upper road cannot trigger lower timing gates")
	for slot in asset.grid_slots():
		var hit = surf.contact(slot.origin + Vector3.UP * .5, Vector3.DOWN, 1.0, 0)
		check(hit.get("surface", -1) == 0, "Grid slot on tarmac")
	for title in Generator.data().landmarks:
		check(asset.get_node_or_null("Landmarks/" + title.replace(" ", "")) != null, "Landmark: " + title)
	check_cached_night_lighting()
	print(
		"CHICAGO RESULTS ",
		JSON.stringify(
			{"checks": checks, "failures": failures, "length_m": asset.length, "max_grade": max_grade}
		)
	)
	quit(0 if failures.is_empty() else 1)
	return true


func check_cached_night_lighting():
	var packed = PackedScene.new()
	check(packed.pack(asset) == OK, "Chicago scene packs for cache")
	var path = "user://native-tests/chicago-night-cache.scn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(ResourceSaver.save(packed, path) == OK, "Chicago lighting cache saves")
	var restored = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	var wheel = restored.get_node("Scenery/CentennialWheel").mesh.surface_get_material(0)
	var flood = restored.get_node("Scenery/PlazaFlood1")
	for night in [true, false, true, false]:
		preload("res://scripts/track/chicago_night.gd").set_night(restored, night)
		check(
			wheel.emission_enabled == night and flood.visible == night,
			"Cached lights follow Afterhours=%s" % night
		)
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
