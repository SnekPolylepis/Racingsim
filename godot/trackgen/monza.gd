extends SceneTree
## Autodromo Nazionale Monza (2020 layout). The circuit model is Tyler_Dave's CC BY Sketchfab
## "Autodromo Nazionale Monza Circuit 2020 layout" (THIRD-PARTY.md); its own asphalt, kerb, grass and sand
## meshes are the drivable surfaces and its walls/tyre stacks the barriers. The lap line is the OSM GP
## centreline (5.80 km) fitted to the model's asphalt by 2D ICP (trackgen/data/monza/lapline.json).

const TrackAsset = preload("res://scripts/track/track_asset.gd")
const MODEL = "res://assets/tracks/monza/monza.glb"
const LAPLINE = "res://trackgen/data/monza/lapline.json"
const BOTLINE = "res://trackgen/data/monza/botline.json"
const CACHE_REVISION = 10
## Inside the GLB (below its scene root) the model is Y-up with the ground ~200 m up: drop it to the origin.
const LIFT = -200.0
## Source material prefix -> SURF id (0 tarmac, 1 kerb, 2 grass, 3 gravel).
const SURFACES = {
	# Decal strips (groove, whiteline) float a few cm over the asphalt: visual only, never driven on.
	"apsh-shader": 0, "asph-pitlane": 0,
	"curb": 1, "grass-shader": 2, "sand": 3,
}
## "metals" is the armco (guardrails) and other steel: without it a car could leave the circuit through the rails.
const WALLS = {"walls": "concrete", "wall2": "concrete", "tyres": "tyre", "metals": "armco"}
## Everything else that is ground (terrain, paths, runoff) becomes fallback ground (grass grip) where it faces
## up, so running wide never drops the car through the world. Objects are excluded by material prefix.
const NOT_GROUND = [
	"glass", "box", "Bark", "grille", "metals", "Vehicles", "objects", "misc_alpha", "lights", "bushes",
	"gstand", "serraglio", "flag", "tree", "branch", "hedge", "fences", "antennas", "brd", "adv_add",
	"paddk", "top_", "misc_alphatest", "shadow", "physics", "groove", "whiteline", "bridges"
]


static func model_xform() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0, LIFT, 0))


static func build_asset() -> Node3D:
	var asset = TrackAsset.new()
	asset.name = "Monza"
	asset.id = "monza"
	asset.display_name = "Monza — Autodromo Nazionale"
	asset.version = 1
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	scenery.owner = asset
	var model: Node3D = load(MODEL).instantiate()
	model.name = "Circuit"
	model.transform = model_xform()
	scenery.add_child(model)
	model.owner = asset
	# Collision from the model's own surfaces, grouped by type.
	var faces = {}
	var wall_faces = {}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var xf = model.transform * _to(model, mi)
		for s in mi.mesh.get_surface_count():
			var mat = mi.mesh.surface_get_material(s)
			var name = mat.resource_name if mat else ""
			var sid = _match(SURFACES, name)
			var wall = _match(WALLS, name)
			var ground = sid == null and wall == null and _match_any(NOT_GROUND, name) == false
			if sid == null and wall == null and not ground:
				continue
			var tris = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = tris[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = tris[Mesh.ARRAY_INDEX] if tris[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var out = PackedVector3Array()
			if idx.is_empty():
				for p in v:
					out.append(xf * p)
			else:
				for i in idx:
					out.append(xf * v[i])
			if ground:
				faces[5] = faces.get(5, PackedVector3Array()) + _upward(out)
			elif sid != null:
				faces[sid] = faces.get(sid, PackedVector3Array()) + out
			else:
				wall_faces[wall] = wall_faces.get(wall, PackedVector3Array()) + out
	var surfaces = Node3D.new()
	surfaces.name = "Surfaces"
	asset.add_child(surfaces)
	surfaces.owner = asset
	# Asphalt: drop triangles standing > 0.5 m over their 4 m cell's median (raised props carrying the road
	# material, e.g. a 1.1 m block at the Parabolica).
	pass  # (raised-triangle filter removed: it cut real asphalt)
	# Fallback ground only where no real surface is: it must never cover the asphalt, kerbs or grass.
	if faces.has(5):
		faces[5] = _outside(faces[5], [faces.get(0, PackedVector3Array()), faces.get(1, PackedVector3Array()), faces.get(2, PackedVector3Array()), faces.get(3, PackedVector3Array())], 2.0)
	faces[6] = _safety_net(faces, curve_points(), 40.0, 4.0)
	for sid in faces:
		# Fallback ground (5) and the safety net (6) drive as grass.
		_body(asset, surfaces, "Surface%d" % sid, faces[sid], 1).set_meta("surface", 2 if sid >= 5 else sid)
	var walls = Node3D.new()
	walls.name = "Walls"
	asset.add_child(walls)
	walls.owner = asset
	for kind in wall_faces:
		_body(asset, walls, "Wall_" + kind, wall_faces[kind], 2).set_meta("wall_kind", kind)
	# Lap line, bot line and grid from the fitted centreline.
	var pts = JSON.parse_string(FileAccess.get_file_as_string(LAPLINE)).points
	var curve = Curve3D.new()
	for p in pts:
		curve.add_point(Vector3(p[0], p[1] + LIFT + 0.3, p[2]))
	curve.add_point(curve.get_point_position(0))
	var timing = Path3D.new()
	timing.name = "TimingLine"
	timing.curve = curve
	asset.add_child(timing)
	timing.owner = asset
	# The bot follows the model's own rubbered-in racing line (botline.json).
	var bot_curve = Curve3D.new()
	for p in JSON.parse_string(FileAccess.get_file_as_string(BOTLINE)).points:
		bot_curve.add_point(Vector3(p[0], p[1] + LIFT + 0.3, p[2]))
	bot_curve.add_point(bot_curve.get_point_position(0))
	var bot = Path3D.new()
	bot.name = "BotLine"
	bot.curve = bot_curve
	asset.add_child(bot)
	bot.owner = asset
	var length = curve.get_baked_length()
	asset.get_node("TimingLine").set_meta("sector_offsets", [length / 3.0, length * 2.0 / 3.0])
	var grid = Node3D.new()
	grid.name = "Grid"
	asset.add_child(grid)
	grid.owner = asset
	for i in 10:
		var s = length - 20.0 - i * 8.0
		var at = curve.sample_baked(s)
		var ahead = curve.sample_baked(s + 2.0)
		var side = (ahead - at).cross(Vector3.UP).normalized() * (2.0 if i % 2 == 0 else -2.0)
		var slot = Marker3D.new()
		slot.name = "Slot%d" % (i + 1)
		slot.transform = Transform3D(Basis.looking_at(ahead - at, Vector3.UP), at + side + Vector3(0, 0.5, 0))
		grid.add_child(slot)
		slot.owner = asset
	asset.set_meta("route_description", "Rettifilo / Variante del Rettifilo / Curva Grande / Roggia / Lesmo / Ascari / Parabolica")
	return asset


static func _body(asset: Node3D, parent: Node, title: String, tris: PackedVector3Array, layer: int) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = title
	body.collision_layer = 0
	body.set_collision_layer_value(layer, true)
	body.collision_mask = 0
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(tris)
	var cs = CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.owner = asset
	cs.owner = asset
	return body


static func _outside(tris: PackedVector3Array, primary: Array, cell: float) -> PackedVector3Array:
	var covered = {}
	for set in primary:
		for i in range(0, set.size() - 2, 3):
			var c = (set[i] + set[i + 1] + set[i + 2]) / 3.0
			covered[Vector2i(floori(c.x / cell), floori(c.z / cell))] = true
			for v in [set[i], set[i + 1], set[i + 2]]:
				covered[Vector2i(floori(v.x / cell), floori(v.z / cell))] = true
	var out = PackedVector3Array()
	for i in range(0, tris.size() - 2, 3):
		var c = (tris[i] + tris[i + 1] + tris[i + 2]) / 3.0
		if covered.has(Vector2i(floori(c.x / cell), floori(c.z / cell))):
			continue
		out.append(tris[i])
		out.append(tris[i + 1])
		out.append(tris[i + 2])
	return out


static func curve_points() -> Array:
	var out = []
	for p in JSON.parse_string(FileAccess.get_file_as_string(LAPLINE)).points:
		out.append(Vector2(p[0], p[2]))
	return out


## A 4 m grid skin 0.3 m under the lowest real surface nearby in each cell, within `reach` of the lap line, so cracks
## between the model's meshes never drop a car. Empty cells take their filled neighbours' height.
static func _safety_net(faces: Dictionary, lap: Array, reach: float, cell: float) -> PackedVector3Array:
	var low = {}
	for sid in faces:
		var tris: PackedVector3Array = faces[sid]
		for v in tris:
			var k = Vector2i(floori(v.x / cell), floori(v.z / cell))
			low[k] = minf(low.get(k, INF), v.y)
	var want = {}
	for i in lap.size():
		var a: Vector2 = lap[i]
		var b: Vector2 = lap[(i + 1) % lap.size()]
		var steps = maxi(1, int(a.distance_to(b) / cell))
		for t in steps + 1:
			var c = a.lerp(b, float(t) / steps)
			var r = int(reach / cell)
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					want[Vector2i(floori(c.x / cell) + dx, floori(c.y / cell) + dz)] = true
	for _pass in 6:
		for k in want:
			if low.has(k):
				continue
			var sum = 0.0
			var n = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if low.has(k + d):
					sum += low[k + d]
					n += 1
			if n > 0:
				low[k] = sum / n
	var out = PackedVector3Array()
	for k in want:
		if not low.has(k):
			continue
		# Lowest of the 3x3 neighbourhood, 0.3 m down: a cell's lowest vertex can sit above the middle of a
		# large road triangle, and the net must never surface through the road.
		var y = low[k]
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				y = minf(y, low.get(k + Vector2i(dx, dz), y))
		y -= 0.3
		var x0 = k.x * cell
		var z0 = k.y * cell
		for v in [Vector3(x0, y, z0), Vector3(x0 + cell, y, z0), Vector3(x0 + cell, y, z0 + cell), Vector3(x0, y, z0), Vector3(x0 + cell, y, z0 + cell), Vector3(x0, y, z0 + cell)]:
			out.append(v)
	return out


static func _match_any(prefixes: Array, name: String) -> bool:
	for prefix in prefixes:
		if name.begins_with(prefix):
			return true
	return false


static func _upward(tris: PackedVector3Array) -> PackedVector3Array:
	var out = PackedVector3Array()
	for i in range(0, tris.size() - 2, 3):
		var n = (tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i])
		if n.length_squared() > 1e-8 and absf(n.normalized().y) > 0.8:
			out.append(tris[i])
			out.append(tris[i + 1])
			out.append(tris[i + 2])
	return out


static func _drop_raised(tris: PackedVector3Array, cell: float, over: float) -> PackedVector3Array:
	var bins = {}
	for i in range(0, tris.size() - 2, 3):
		var c = (tris[i] + tris[i + 1] + tris[i + 2]) / 3.0
		var k = Vector2i(floori(c.x / cell), floori(c.z / cell))
		if not bins.has(k):
			bins[k] = []
		bins[k].append(c.y)
	var med = {}
	for k in bins:
		var a = bins[k]
		a.sort()
		med[k] = a[a.size() / 2]
	var out = PackedVector3Array()
	for i in range(0, tris.size() - 2, 3):
		var c = (tris[i] + tris[i + 1] + tris[i + 2]) / 3.0
		if c.y > med[Vector2i(floori(c.x / cell), floori(c.z / cell))] + over:
			continue
		out.append(tris[i])
		out.append(tris[i + 1])
		out.append(tris[i + 2])
	return out


static func _match(table: Dictionary, name: String):
	for prefix in table:
		if name.begins_with(prefix):
			return table[prefix]
	return null


static func _to(root: Node, node: Node) -> Transform3D:
	var t = Transform3D.IDENTITY
	var n = node
	while n != null and n != root:
		if n is Node3D:
			t = n.transform * t
		n = n.get_parent()
	return t


func _initialize() -> void:
	var asset = build_asset()
	var m = asset.get_node("Scenery/Circuit")
	print("MONZA model xf=", m.transform)
	var mi = m.find_children("*", "MeshInstance3D", true, false)[0]
	print("MONZA chain=", _to(m, mi), " mesh0 aabb=", mi.get_aabb())
	var f = asset.get_node("Surfaces").get_child(0).get_child(0).shape.get_faces()
	print("MONZA face0=", f[0])
	print("MONZA errors=", asset.validate())
	quit()
