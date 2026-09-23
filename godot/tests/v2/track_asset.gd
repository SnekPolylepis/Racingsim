extends SceneTree
## P3-01: TrackAsset format, loader, timing and TrackSurface (REBUILD-PLAN.md P3-01, 5.3).
## Fixture: a figure-eight whose second pass crosses 8 m above the first (x = A sin t,
## z = B sin t cos t, y = H (1 - cos t) / 2), built in code with scripts/track/ribbon.gd, saved as a
## packed scene under user:// and loaded back through the loader. Checks validation (and that broken
## assets are rejected with the right message), timing geometry, deck-aware projection, 3D gates,
## TrackSurface hits, grid slots, and finally a CarBody lap timed through the gates.
## Surface queries run in _physics_process, as they must (P3-00).
## Run: tools/Godot.exe --headless --path . --script tests/v2/track_asset.gd
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackLoader = preload("res://scripts/track/track_loader.gd")
const Ribbon = preload("res://scripts/track/ribbon.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const A = 240.0
const B = 120.0
const H = 8.0
const HALF = 5.0
const VERGE = 6.0
const DIR = "user://native-tests/v2/tracks3d"
const DT = 1.0 / 240
var asset
var failures = []
var checks = 0
var frames = 0
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func curve_point(t):
	return Vector3(A * sin(t), H * (1 - cos(t)) * .5, B * sin(t) * cos(t))


## Arc length of the analytic figure-eight by fine summation.
func analytic_length():
	var total = 0.0
	var prev = curve_point(0.0)
	for k in range(1, 200001):
		var p = curve_point(TAU * k / 200000.0)
		total += prev.distance_to(p)
		prev = p
	return total


## Give every descendant (not the root itself) the root as owner, so PackedScene.pack keeps them.
func own(node, owner_node):
	for c in node.get_children():
		c.owner = owner_node
		own(c, owner_node)


func surface_body(name, sid, faces):
	var body = StaticBody3D.new()
	body.name = name
	body.set_meta("surface", sid)
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body


func build_fixture():
	var root_node = Node3D.new()
	root_node.set_script(TrackAsset)
	root_node.name = "Figure8"
	root_node.id = "figure8"
	root_node.display_name = "Figure-eight overpass (test fixture)"
	root_node.version = 1
	var center = PackedVector3Array()
	for k in 900:
		center.append(curve_point(TAU * k / 900.0))
	var faces = Ribbon.bake(center, HALF, VERGE)
	var road = MeshInstance3D.new()
	road.name = "Road"
	road.mesh = Ribbon.mesh(faces.road)
	root_node.add_child(road)
	var surfaces = Node3D.new()
	surfaces.name = "Surfaces"
	surfaces.add_child(surface_body("Tarmac", 0, faces.road))
	surfaces.add_child(surface_body("Grass", 2, faces.verge))
	root_node.add_child(surfaces)
	var path = Path3D.new()
	path.name = "TimingLine"
	var curve = Curve3D.new()
	curve.bake_interval = 1.0
	for p in center:
		curve.add_point(p)
	path.curve = curve
	root_node.add_child(path)
	var grid = Node3D.new()
	grid.name = "Grid"
	root_node.add_child(grid)
	own(root_node, root_node)
	root_node.prepare()
	var lap = root_node.length
	# Start on the lower deck at the crossing; the first sector boundary is the upper-deck crossing.
	path.set_meta("start_offset_m", 0.0)
	path.set_meta("sector_offsets", [lap * .5, lap * .75])
	for k in 4:
		var st = root_node.station(lap - 12.0 - 9.0 * k)
		var right = st.tangent.cross(Vector3.UP).normalized()
		var m = Marker3D.new()
		m.name = "Slot%d" % (k + 1)
		m.transform = Transform3D(
			Basis(right, Vector3.UP, -st.tangent), st.pos + right * (2.0 if k % 2 else -2.0)
		)
		grid.add_child(m)
		m.owner = root_node
	return root_node


func expect_error(label, node, fragment):
	var errors = node.validate()
	var hit = errors.any(func(e): return fragment in e)
	check(hit, 'rejects %s ("%s")' % [label, errors[0] if not errors.is_empty() else "no error"])
	node.free()


func validation_cases():
	var ok = build_fixture()
	var errors = ok.validate()
	check(errors.is_empty(), "fixture validates cleanly %s" % [errors])
	ok.free()
	var n = build_fixture()
	n.get_node("Grid").free()
	expect_error("a missing grid", n, "Grid/")
	n = build_fixture()
	n.get_node("Surfaces/Grass").set_meta("surface", "grass")
	expect_error("a non-integer surface id", n, "'surface'")
	n = build_fixture()
	n.get_node("Surfaces/Tarmac").set_collision_layer_value(1, false)
	expect_error("a surface off layer 1", n, "collision layer")
	n = build_fixture()
	var c = n.get_node("TimingLine").curve
	for k in 100:
		c.remove_point(c.point_count - 1)
	expect_error("an open timing line", n, "not closed")
	n = build_fixture()
	n.position = Vector3(10, 0, 0)
	expect_error("a moved root", n, "origin")
	n = build_fixture()
	n.get_node("TimingLine").position = Vector3(6000, 0, 0)
	expect_error("a line beyond 5 km", n, "precision box")
	n = build_fixture()
	n.get_node("TimingLine").set_meta("sector_offsets", [900.0, 100.0])
	expect_error("decreasing sector offsets", n, "sector_offsets")
	n = build_fixture()
	n.id = ""
	expect_error("an empty id", n, "id is empty")


func _initialize():
	validation_cases()
	var built = build_fixture()
	var folder = DIR + "/figure8"
	DirAccess.make_dir_recursive_absolute(folder)
	var packed = PackedScene.new()
	var pack_err = packed.pack(built)
	var save_err = ResourceSaver.save(packed, folder + "/figure8.scn")
	var built_len = built.length
	built.free()
	check(pack_err == OK and save_err == OK, "fixture packs and saves to %s/figure8.scn" % folder)
	var listed = TrackLoader.list(DIR)
	check(
		listed.size() == 1 and listed[0].id == "figure8",
		"loader lists exactly the saved track (%s)" % [listed.map(func(e): return e.id)]
	)
	var loaded = TrackLoader.load_asset(folder + "/figure8.scn")
	asset = loaded.asset
	check(
		asset != null and loaded.errors.is_empty() and asset.record_key() == "figure8@v1",
		"loaded asset validates, record key %s" % (asset.record_key() if asset else "none")
	)
	check(absf(asset.length - built_len) < 1e-6, "lap length survives the save/load round trip")
	root.add_child(asset)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	timing()
	surface_queries()
	lap()
	print(
		"TRACK ASSET RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true


func timing():
	var want = analytic_length()
	var lap_len = asset.length
	results["lap_m"] = lap_len
	check(
		absf(lap_len / want - 1) < .002,
		(
			"lap line %.2f m vs analytic figure-eight %.2f m (%+.3f%%)"
			% [lap_len, want, (lap_len / want - 1) * 100]
		)
	)
	var low = asset.project(Vector3(0, .5, 0))
	var high = asset.project(Vector3(0, H + .5, 0))
	check(
		minf(low.s, lap_len - low.s) < 2.0 and absf(high.s - lap_len * .5) < 2.0,
		(
			"projection resolves the crossing by deck: lower deck s = %.1f (0 / %.1f), upper deck s = %.1f (%.1f)"
			% [low.s, lap_len, high.s, lap_len * .5]
		)
	)
	# Drive the analytic curve finely for one lap from just before the start and count gate triggers.
	var gates = asset.gates()
	var hits = []
	hits.resize(gates.size())
	hits.fill(0)
	var order = []
	var prev = curve_point(-.002)
	for k in range(1, 20001):
		var p = curve_point(-.002 + TAU * k / 20000.0)
		for g in gates.size():
			if TrackAsset.crossed(gates[g], prev, p):
				hits[g] += 1
				order.append(g)
		prev = p
	var once = hits.all(func(h): return h == 1)
	var in_order = order == range(gates.size())
	var offsets_sorted = true
	for g in range(1, gates.size()):
		offsets_sorted = offsets_sorted and gates[g].offset > gates[g - 1].offset
	check(
		once and in_order and offsets_sorted,
		(
			"one lap crosses each of %d gates exactly once, in list order, and the list is sorted by lap offset (%s)"
			% [gates.size(), ", ".join(gates.map(func(g): return "%s %.0f" % [g.kind, g.offset]))]
		)
	)
	var start = gates[0]
	var upper_pass = TrackAsset.crossed(start, curve_point(PI - .01), curve_point(PI + .01))
	var sector = gates[1]
	var lower_pass = TrackAsset.crossed(sector, curve_point(-.01), curve_point(.01))
	check(
		not upper_pass and not lower_pass,
		"the start gate ignores the upper-deck pass 8 m above it, and the upper-deck sector gate ignores the lower pass"
	)
	var mm = asset.minimap(512)
	var ext = Vector2.ZERO
	for p in mm:
		ext = Vector2(maxf(ext.x, absf(p.x)), maxf(ext.y, absf(p.y)))
	check(
		mm.size() == 512 and absf(ext.x - A) < 1.0 and absf(ext.y - B * .5) < 1.0,
		"minimap: 512 points spanning ±%.1f by ±%.1f m (analytic ±%.0f by ±%.0f)" % [ext.x, ext.y, A, B * .5]
	)


func surface_queries():
	var surf = asset.surface()
	var worst = 0.0
	var ids_ok = true
	for k in 60:
		var st = asset.station(asset.length * k / 60.0)
		var right = st.tangent.cross(Vector3.UP).normalized()
		var on_road = surf.contact(st.pos + Vector3.UP * .6, Vector3.DOWN, 1.2)
		var on_grass = surf.contact(st.pos + right * (HALF + 3) + Vector3.UP * .6, Vector3.DOWN, 1.2)
		if on_road.is_empty() or on_grass.is_empty():
			ids_ok = false
			continue
		ids_ok = ids_ok and on_road.surface == 0 and on_grass.surface == 2 and on_road.normal.y > .99
		worst = maxf(worst, absf(on_road.distance - .6))
	check(
		ids_ok and worst < .05,
		(
			"TrackSurface: road hits are tarmac (0), verge hits grass (2), normals face up; road height within %.3f m of the line"
			% worst
		)
	)
	var upper = surf.contact(Vector3(0, H + .6, 0), Vector3.DOWN, 1.2)
	var lower = surf.contact(Vector3(0, .6, 0), Vector3.DOWN, 1.2)
	check(
		(
			not upper.is_empty()
			and absf(upper.point.y - H) < .05
			and not lower.is_empty()
			and absf(lower.point.y) < .05
		),
		(
			"at the crossing a wheel on each deck finds its own deck (upper y %.2f, lower y %.2f)"
			% [upper.get("point", Vector3.ZERO).y, lower.get("point", Vector3.ZERO).y]
		)
	)
	var slots_ok = true
	for xf in asset.grid_slots():
		var hit = surf.contact(xf.origin + Vector3.UP, Vector3.DOWN, 2.0)
		slots_ok = (
			slots_ok and not hit.is_empty() and hit.surface == 0 and absf(hit.point.y - xf.origin.y) < .05
		)
	check(slots_ok and asset.grid_slots().size() == 4, "all 4 grid slots sit on tarmac")


## A CarBody (296 GT3) from pole, steered along the lap line at 70 km/h on TrackSurface. Gates are
## taken in order like race timing: the lap counts when the start gate is crossed after every
## sector and checkpoint gate.
func lap():
	var surf = asset.surface()
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	var pole = asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var gates = asset.gates()
	var next = 0
	var started = -1.0
	var lap_time = -1.0
	var hint = -1
	var off_tarmac = 0
	var min_contacts = 4
	var t = 0.0
	var prev = c.pos
	var step_us = 0
	var ticks = 0
	while t < 150 and lap_time < 0:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		var target = asset.station(pr.s + 10 + c.speed * .5).pos
		var want = atan2(target.z - c.pos.z, target.x - c.pos.x)
		var st = clampf(wrapf(want - c.h, -PI, PI) * 2.5, -1, 1)
		var e = 70 / 3.6 - c.speed
		c.input = {
			"throttle": clampf(e * .5 + .3, 0, 1),
			"brake": clampf(-e * .3, 0, 1),
			"steer": st,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		var t0 = Time.get_ticks_usec()
		c.step(DT, surf, true)
		step_us += Time.get_ticks_usec() - t0
		ticks += 1
		t += DT
		min_contacts = mini(min_contacts, c.contacts)
		for w in c.wheels:
			if w.surf.id != 0:
				off_tarmac += 1
		if TrackAsset.crossed(gates[next], prev, c.pos):
			if next == 0:
				if started >= 0:
					lap_time = t - started
				else:
					started = t
				next = 1
			else:
				next = (next + 1) % gates.size()
		prev = c.pos
	results["lap_s"] = lap_time
	results["car_step_us"] = float(step_us) / ticks
	# One lap at the held speed, with slack for the standing start before the line: a count that
	# spans two laps (as an unsorted gate list once produced) lands far outside this.
	var nominal = asset.length / (70 / 3.6)
	check(
		lap_time > nominal * .98 and lap_time < nominal * 1.15 and min_contacts == 4 and off_tarmac == 0,
		(
			"296 GT3 laps the figure-eight on TrackSurface through all %d gates in order: %.2f s (one lap at 70 km/h ≈ %.1f s), min contacts %d, wheel-ticks off tarmac %d"
			% [gates.size(), lap_time, nominal, min_contacts, off_tarmac]
		)
	)
	check(
		results.car_step_us < 150,
		"car step with 4 physics-server rays: %.1f µs per tick (P3-00 budget ~150 µs)" % results.car_step_us
	)
