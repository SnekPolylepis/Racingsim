extends SceneTree
## CHI-01 geometric acceptance: full-width surface coverage, lower/upper deck separation,
## ceiling clearance, slope, grid and landmark anchors. Driving is gated by laps.gd.
const Generator = preload("res://trackgen/chicago.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
var asset
var loop_grid = false
var frames = 0
var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	loop_grid = "--track=chicago_grid" in OS.get_cmdline_user_args()
	asset = Generator.build_asset(loop_grid)
	root.add_child(asset)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if frames > 3:
		quit(1)
		return true
	check(asset.id == ("chicago_grid" if loop_grid else "chicago"), "Distinct track identity")
	check(asset.validate().is_empty(), "TrackAsset contract: %s" % [asset.validate()])
	var road = asset.get_node("Main")
	check(road.last_bake.warnings.is_empty(), "Bake without warnings")
	check(asset.length > 5000 and asset.length < 10000, "Closed lap length %.1f m" % asset.length)
	for level in [Generator.ChicagoCity.LOW_ROAD_Y, 8.0]:
		var target = Vector3(-61.3, level, -381.5)
		var approach_s = road.curve.get_closest_offset(target)
		check(
			road.curve.sample_baked(approach_s).distance_to(target) < 1.0,
			"Mapped Michigan/Wacker bend at level %.2f" % level
		)
		var approach_section = RoadBuilder.section_at(road.sections, approach_s, asset.length, road.closed)
		check(
			absf(approach_section.width_left - 5.1) < .01 and absf(approach_section.width_right - 5.1) < .01,
			"Mapped Wacker driving corridor at level %.2f" % level
		)
	var surf = asset.surface()
	var misses = 0
	var max_error = 0.0
	var max_grade = 0.0
	var intrusions = 0
	var ceiling_checks = 0
	var ceiling_error = 0.0
	var space = asset.get_world_3d().direct_space_state
	for st in road.last_bake.stations:
		max_grade = maxf(max_grade, absf(st.tangent.y) / Vector2(st.tangent.x, st.tangent.z).length())
		var right = st.tangent.cross(Vector3.UP).normalized()
		var section = RoadBuilder.section_at(road.sections, st.s, road.last_bake.length, road.closed)
		for lat in [-section.width_left + .2, 0.0, section.width_right - .2]:
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
		if Generator.covered_wacker(st.pos) and st.pos.x < -1000 and st.pos.z > 0 and st.pos.z < 600:
			var ceiling = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(st.pos + Vector3.UP * .15, st.pos + Vector3.UP * 6.0, 2)
			)
			ceiling_checks += 1
			ceiling_error = maxf(
				ceiling_error, absf(ceiling.position.y - st.pos.y - 4.191) if not ceiling.is_empty() else INF
			)
	check(misses == 0, "Full lap authored tarmac widths: %d misses" % misses)
	check(max_error < .08, "Surface/line height error %.4f m" % max_error)
	check(max_grade < .10, "Maximum grade %.2f%%" % (max_grade * 100))
	check(intrusions == 0, "3 m headroom throughout lap: %d intrusions" % intrusions)
	check(
		ceiling_checks > 0 and ceiling_error < .03,
		"N–S 13 ft 9 in ceiling clearance: %d probes, error %.4f m" % [ceiling_checks, ceiling_error]
	)
	for height in [Generator.ChicagoCity.LOW_ROAD_Y, 8.0]:
		var latitude = 41.8800 if loop_grid and height == 8.0 else 41.883
		var longitude = -87.636999 if loop_grid and height == 8.0 else -87.6369
		var p = Generator.world([latitude, longitude, height])
		var hit = surf.contact(p + Vector3.UP * .5, Vector3.DOWN, 1.0, 0)
		check(
			hit.get("surface", -1) == 0 and absf(hit.get("point", Vector3.INF).y - height) < .05,
			"Wacker deck at %.4f m" % height
		)
		var projection = asset.project(p, -1)
		check(absf(projection.vertical) < .1, "Projection selects %.4f m deck" % height)
	var gates = asset.gates()
	var wrong_deck_triggers = 0
	for gate in gates:
		if gate.origin.y < Generator.ChicagoCity.LOW_ROAD_Y + .1:
			var p = gate.origin + Vector3.UP * (8 - Generator.ChicagoCity.LOW_ROAD_Y)
			if TrackAsset.crossed(gate, p - gate.normal * 2, p + gate.normal * 2):
				wrong_deck_triggers += 1
	check(wrong_deck_triggers == 0, "Upper road cannot trigger lower timing gates")
	for slot in asset.grid_slots():
		var hit = surf.contact(slot.origin + Vector3.UP * .5, Vector3.DOWN, 1.0, 0)
		check(hit.get("surface", -1) == 0, "Grid slot on tarmac")
	for title in Generator.data().landmarks:
		check(asset.get_node_or_null("Landmarks/" + title.replace(" ", "")) != null, "Landmark: " + title)
	var wheel_cabins = 0
	var lowest_cabin = INF
	for node in asset.get_node("Scenery").get_children():
		if node is MeshInstance3D and String(node.name).begins_with("WheelCabin"):
			wheel_cabins += 1
			var bounds = node.mesh.get_aabb()
			lowest_cabin = minf(lowest_cabin, node.position.y + bounds.position.y)
	check(
		wheel_cabins == 42 and lowest_cabin > Generator.ChicagoCity.LAKE_Y + .8,
		"42 enclosed wheel gondolas clear the pier deck: lowest %.2f m" % lowest_cabin
	)
	var plaza_wall_hits = 0
	var plaza_camera = Generator.world([41.8912, -87.6059, 12])
	var plaza_ray = (Generator.world([41.8917, -87.6059, 38]) - plaza_camera).normalized()
	var pier_cell = asset.get_node("Scenery/City/Low_2_-2")
	for surface in pier_cell.mesh.get_surface_count():
		var arrays = pier_cell.mesh.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		for i in range(0, vertices.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(
				plaza_camera, plaza_ray, vertices[i], vertices[i + 1], vertices[i + 2]
			)
			if hit == null:
				hit = Geometry3D.ray_intersects_triangle(
					plaza_camera, plaza_ray, vertices[i + 2], vertices[i + 1], vertices[i]
				)
			if hit != null and plaza_camera.distance_to(hit) < 50.0:
				plaza_wall_hits += 1
	check(plaza_wall_hits == 0, "Mapped pier halls leave wheel/loading plaza approach clear")
	check(
		(
			asset.get_node_or_null("Scenery/PierRoofLight0") == null
			and is_equal_approx(asset.get_node("Scenery/PierRoofLight1").position.y, 21.9)
		),
		"Pier roof lights follow the raised halls and leave the wheel plaza open"
	)
	var bridge_steel = asset.get_node("Scenery/ChicagoBridgeSteel").multimesh
	var rail_top = -INF
	for i in bridge_steel.instance_count:
		var tr = bridge_steel.get_instance_transform(i)
		rail_top = maxf(rail_top, tr.origin.y + tr.basis.y.length() * .5)
	check(rail_top < Generator.ChicagoCity.STREET_Y + 4.0, "Closed bascule bridge rails keep skyline open")
	var park_path_surfaces = 0
	for node in asset.get_node("Scenery/City").get_children():
		if not node is MeshInstance3D:
			continue
		for i in node.mesh.get_surface_count():
			if node.mesh.surface_get_material(i) == Generator.ChicagoCity.material("path"):
				park_path_surfaces += 1
	check(park_path_surfaces > 0, "Mapped park footpaths included in committed city meshes")
	var furniture = Generator.ChicagoFurniture
	var poles_clear = true
	for i in furniture.find_crossings(road.last_bake.stations):
		var at = road.last_bake.stations[i]
		var flat = Vector3(at.tangent.x, 0, at.tangent.z).normalized()
		for side in [-1, 1]:
			var foot = furniture.pole_foot(
				road.last_bake.stations, at, side * 9.0, flat.cross(Vector3.UP) * side, 10.4
			)
			for station in road.last_bake.stations:
				if (
					absf(station.pos.y - foot.y) < 8.0
					and Vector2(station.pos.x - foot.x, station.pos.z - foot.z).length() < 9.9
				):
					poles_clear = false
	check(poles_clear, "Traffic signal supports clear both decks and curved driving corridor")
	var roof_probe = Node3D.new()
	var footprint = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)])
	var roof_stats = Generator.ChicagoKit.roof_clutter(roof_probe, roof_probe, [[footprint, 30.0, 1, false]])
	check(roof_stats.roof_props == 0, "Measured stepped roofs never receive unsupported generic roof props")
	roof_probe.free()
	var trestle_clear = true
	var trestle_bases = 0
	var checked_bases = {}
	var trestle = asset.get_node("Scenery/City/ElevatedL").mesh
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	for si in trestle.get_surface_count():
		for vertex in trestle.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.y - 8.0) > .01:
				continue
			if checked_bases.has(vertex):
				continue
			checked_bases[vertex] = true
			trestle_bases += 1
			for height in [0.0, 2.6, 5.2]:
				var projection = asset.project(vertex + Vector3.UP * height, -1)
				var sec = road.RoadBuilder.section_at(keys, projection.s, asset.length, road.closed)
				var width = sec.width_left if projection.lateral < 0.0 else sec.width_right
				if (
					projection.vertical >= -.01
					and projection.vertical <= 3.01
					and absf(projection.lateral) < width + .5
				):
					trestle_clear = false
	check(trestle_bases > 0 and trestle_clear, "Actual elevated L supports stay outside authored road widths")
	var bean = Generator.world(Generator.data().landmarks.Bean)
	var city_trees = asset.get_node("Scenery/City/RealTrees").multimesh
	var plaza_clear = true
	for i in city_trees.instance_count:
		var tr = city_trees.get_instance_transform(i)
		var crown = tr.basis.x.length() * .71
		var in_plaza = absf(tr.origin.x - bean.x) < 35.0 + crown and absf(tr.origin.z - bean.z) < 30.0 + crown
		var in_approach = (
			tr.origin.x > 12.0 - crown
			and tr.origin.x < bean.x - 35.0 + crown
			and absf(tr.origin.z - bean.z) < 6.0 + crown
		)
		if in_plaza or in_approach:
			plaza_clear = false
	check(plaza_clear, "Tree crowns keep Cloud Gate's plaza and west approach clear")
	var box_probe = Node3D.new()
	var box_size = Vector3(2, 3, 7)
	var box_basis = Basis(Vector3.UP, PI * .5)
	Generator.multimesh_boxes(
		box_probe, box_probe, "Probe", Generator.material(Color.WHITE), [[Vector3.ZERO, box_size, box_basis]]
	)
	var box_mm = box_probe.get_node("Probe").multimesh
	var box_tr = box_mm.get_instance_transform(0)
	if DisplayServer.get_name() == "headless":
		# Godot Dummy renderer discards MultiMesh buffers: verify axes in the windowed run.
		check(box_mm.mesh.size.is_equal_approx(Vector3.ONE), "Batched boxes use an authored unit mesh")
	else:
		check(
			(
				box_mm.mesh.size.is_equal_approx(Vector3.ONE)
				and (
					Vector3(box_tr.basis.x.length(), box_tr.basis.y.length(), box_tr.basis.z.length())
					. is_equal_approx(box_size)
				)
				and box_tr.basis.x.normalized().is_equal_approx(box_basis.x)
				and box_tr.basis.y.normalized().is_equal_approx(box_basis.y)
				and box_tr.basis.z.normalized().is_equal_approx(box_basis.z)
			),
			"Batched boxes preserve authored dimensions and rotated local axes"
		)
	box_probe.free()
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
