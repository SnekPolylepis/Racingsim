extends SceneTree
## Free Roam acceptance: the street layer answers suspension rays off the race route, mapped buildings answer
## hull queries, and nothing blocks the route itself.
const Generator = preload("res://trackgen/chicago_free.gd")
const ChicagoCity = preload("res://trackgen/chicago_city.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
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
	check(asset.id == "chicago_free", "Distinct track identity")
	check(asset.validate().is_empty(), "TrackAsset contract: %s" % [asset.validate()])
	check(not asset.get_meta("city").has("ground_faces"), "Ground faces are not baked into metadata")
	var surf = asset.surface()
	var walls = WallQuery.new(asset, Vector3(1.0, 0.6, 2.2))
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	var street_hits = 0
	var street_tried = 0
	var wall_hits = 0
	var wall_tried = 0
	for road in doc.roads:
		if road.c != "secondary" or road.b != 0 or road.p.size() < 2:
			continue
		var p = road.p[road.p.size() / 2]
		if absf(p[0]) > 600 or absf(p[1]) > 600:
			continue
		street_tried += 1
		var hit = surf.contact(Vector3(p[0], 10.0, p[1]), Vector3.DOWN, 6.0)
		if not hit.is_empty() and absf(hit.point.y - 8.0) < .1:
			street_hits += 1
		if hit.is_empty() or absf(hit.point.y - 8.0) >= .1:
			print("miss ", p, " ", hit.get("point"))
		if street_tried >= 60:
			break
	var lower = Generator._lower()
	var low_hits = 0
	for ramp in lower.ramps:
		var mid = ramp[0].lerp(ramp[1], 0.5)
		var hit = surf.contact(Vector3(mid.x, 12.0, mid.y), Vector3.DOWN, 12.0)
		var y = ChicagoCity.LOW_ROAD_Y + (ChicagoCity.STREET_Y - ChicagoCity.LOW_ROAD_Y) * 0.5
		low_hits += int(not hit.is_empty() and absf(hit.point.y - y) < 0.6)
	check(
		not lower.ramps.is_empty() and low_hits == lower.ramps.size(),
		"Ramp midpoints are open: %d of %d" % [low_hits, lower.ramps.size()]
	)
	check(street_hits > street_tried * 0.8, "Street ray hits ground: %d of %d" % [street_hits, street_tried])
	for b in doc.buildings:
		if b.h < 30.0 or absf(b.f[0][0]) > 600 or absf(b.f[0][1]) > 600:
			continue
		wall_tried += 1
		var a: Array = b.f[0]
		var c: Array = b.f[1]
		var mid = Vector3((a[0] + c[0]) * .5, 9.5, (a[1] + c[1]) * .5)
		if not walls.contacts(Transform3D(Basis.IDENTITY, mid)).is_empty():
			wall_hits += 1
		if wall_tried >= 80:
			break
	check(
		wall_hits > wall_tried * 0.6, "Building edge answers hull query: %d of %d" % [wall_hits, wall_tried]
	)
	var blocked = 0
	var line = asset.line
	for i in range(0, line.size(), 40):
		var p = line[i] + Vector3(0, 0.8, 0)
		if not walls.contacts(Transform3D(Basis.IDENTITY, p)).is_empty():
			blocked += 1
	check(blocked == 0, "No building wall on the race route (%d samples blocked)" % blocked)
	print("RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
	return true
