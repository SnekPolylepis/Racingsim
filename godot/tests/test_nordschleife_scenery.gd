extends SceneTree
## Validates Nürburgring Nordschleife landmarks and scenery.

const Track3D = preload("res://scripts/track3d.gd")
const CircuitWorld = preload("res://scripts/circuit_world.gd")
const Visuals = preload("res://scripts/visuals.gd")

var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures.append(label)
		print("FAIL  ", label)


func _init():
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Nurburgring-Nordschleife.json"))
	check(doc != null, "loaded Nordschleife document")
	var t = Track3D.new()
	t.load_data(doc)
	check(t.length > 20000.0, "track ribbon length exceeds 20 km")

	var landmarks = doc.get("presentation", {}).get("landmarks", [])
	check(landmarks.size() >= 20, "document defines at least 20 landmarks (got %d)" % landmarks.size())

	var cw = CircuitWorld.new()
	cw.track = t
	var world_node = Node3D.new()
	cw.build(world_node, t)
	check(world_node.get_child_count() > 0, "world built nodes successfully")

	# Verify landmark placement constraints
	var karussell_outside_ok = true
	var no_road_clipping = true

	for lm in landmarks:
		var kind = lm.get("kind", "")
		var anchor = lm.get("anchor")
		var s = -1.0
		for l in doc.presentation.labels:
			if l.name == anchor:
				s = t.project(float(l.x), float(l.y)).s
				break
		if s < 0.0 and anchor is Dictionary:
			s = t.project(float(anchor.x), float(anchor.y)).s
		if s < 0.0:
			continue
		if lm.has("s_offset"):
			s = wrapf(s + float(lm.s_offset), 0.0, t.length)

		var p = t.pos_at(s)
		var side_str = str(lm.get("side", "outside")).to_lower()
		var curv = t.curvature_at(s, 20.0)
		var side_sign = 1.0
		if side_str == "left":
			side_sign = -1.0
		elif side_str == "right":
			side_sign = 1.0
		elif side_str == "outside":
			side_sign = -1.0 if curv > 0.0 else 1.0
		elif side_str == "inside":
			side_sign = 1.0 if curv > 0.0 else -1.0

		var offset = float(lm.get("offset", 12.0))
		var off = side_sign * (p.w / 2.0 + offset)
		var x = p.x - sin(p.h) * off
		var y = p.y + cos(p.h) * off
		var pr = t.project(x, y)

		# Check non-bridge objects do not sit on road or runoff
		if kind != "bridge" and kind != "footbridge":
			if absf(pr.lat) <= pr.width / 2.0 + 2.0:
				no_road_clipping = false
				print("Landmark clips road/runoff: ", lm.name, " lat: ", pr.lat, " road width: ", pr.width)

		# Check Karussell is on outside (lat > 0), clear of the inner concrete ditch (lat < 0)
		if anchor == "Caracciola-Karussell":
			if pr.lat < 0.0 or absf(pr.lat) < 10.0:
				karussell_outside_ok = false
				print("Karussell landmark on inside ditch: ", lm.name, " lat: ", pr.lat)

	check(no_road_clipping, "all ground landmarks maintain safe margin outside road and runoff")
	check(karussell_outside_ok, "Caracciola-Karussell landmarks sit on outside, away from inner ditch")

	# Test visuals scenery builder with clearings
	var vis = Visuals.new()
	var vis_root = Node3D.new()
	vis.world = cw
	vis.build_scenery(vis_root, t)
	check(vis_root.get_child_count() > 0, "scenery with clearings built successfully")

	# Clean up allocated node trees
	world_node.free()
	vis_root.free()

	print("NORDSCHLEIFE SCENERY TEST: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
