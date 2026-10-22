extends SceneTree
## Free Roam variant: the Loop Grid route plus collision for the rest of the city. The street layer is the
## land tiles the visual city already clips against water (surface 4, tarmac runoff), and every mapped
## building footprint the city kept becomes a layer-2 wall, so you can drive anywhere and hit what you see.
const Chicago = preload("res://trackgen/chicago.gd")
const ChicagoCity = preload("res://trackgen/chicago_city.gd")
const WALL_HEIGHT = 4.0
## Reasons the city drops a footprint without drawing something else in its place.
const Lower = preload("res://trackgen/chicago_lower_data.gd")
const LOW_WIDTH = 12.0
## Ramp grade cap: STREET_Y - LOW_ROAD_Y = 4.57 m takes 76.2 m, and the city's 20 m ground tiles are cut to match.
const MAX_GRADE = 0.06
const NOT_DRAWN = ["authored route clearance", "invalid footprint"]


static func build_asset() -> Node3D:
	return Chicago.build_asset(true, true)


static func add_collision(asset: Node3D, city: Dictionary) -> void:
	var ground = StaticBody3D.new()
	ground.name = "FreeRoamGround"
	ground.set_meta("surface", 4)
	ground.collision_layer = 1
	ground.collision_mask = 0
	var low = _lower()
	_shape(ground, _without(city.ground_faces, low.ramps, LOW_WIDTH * 0.5 + 10.0))
	asset.get_node("Surfaces").add_child(ground)
	var skip = {}
	for row in city.excluded:
		if row.reason in NOT_DRAWN:
			skip[row.city_index] = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(ChicagoCity.DATA))
	var faces = PackedVector3Array()
	var floor_y = ChicagoCity.STREET_Y
	for i in doc.buildings.size():
		var ring: Array = doc.buildings[i].f
		if skip.has(i) or ring.size() < 3 or _near(ring, low.ramps, LOW_WIDTH * 0.5 + 2.0):
			continue
		for k in ring.size():
			var a: Array = ring[k]
			var b: Array = ring[(k + 1) % ring.size()]
			var a0 = Vector3(a[0], floor_y, a[1])
			var b0 = Vector3(b[0], floor_y, b[1])
			var up = Vector3(0, WALL_HEIGHT, 0)
			faces.append_array([a0, b0, b0 + up, a0, b0 + up, a0 + up])
	var walls = StaticBody3D.new()
	walls.name = "FreeRoamBuildings"
	walls.collision_layer = 2
	walls.collision_mask = 0
	walls.set_meta("wall_kind", "concrete")
	_shape(walls, faces)
	asset.get_node("Walls").add_child(walls)
	var lower = StaticBody3D.new()
	lower.name = "FreeRoamLower"
	lower.set_meta("surface", 0)
	lower.collision_layer = 1
	lower.collision_mask = 0
	_shape(lower, low.faces)
	asset.get_node("Surfaces").add_child(lower)
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = low.faces
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.1, 0.11)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var node = MeshInstance3D.new()
	node.name = "FreeRoamLowerMesh"
	node.mesh = mesh
	asset.add_child(node)


## Lower Wacker / Michigan / Randolph as flat strips at LOW_ROAD_Y. Each end that meets no other lower road
## gets a ramp climbing outward to the street slab at MAX_GRADE. Returns {faces, ramps: [[from, to], ...]}.
static func _lower() -> Dictionary:
	var faces = PackedVector3Array()
	var ramps = []
	var y0 = ChicagoCity.LOW_ROAD_Y
	var roads = Lower.ROADS
	var run = ceili((ChicagoCity.STREET_Y - y0) / MAX_GRADE / 4.0) * 4
	for r in roads.size():
		var pts: Array = roads[r]
		for k in pts.size() - 1:
			_strip(faces, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), y0, y0)
		for end in [0, pts.size() - 1]:
			var e = Vector2(pts[end][0], pts[end][1])
			var inner = pts[1] if end == 0 else pts[pts.size() - 2]
			var joined = false
			for o in roads.size():
				for q in roads[o]:
					joined = joined or (o != r and e.distance_to(Vector2(q[0], q[1])) < 12.0)
			if joined:
				continue
			var tip = e + (e - Vector2(inner[0], inner[1])).normalized() * run
			ramps.append([e, tip])
			var steps = 8
			for k in steps:
				var a = e.lerp(tip, float(k) / steps)
				var b = e.lerp(tip, float(k + 1) / steps)
				_strip(
					faces,
					a,
					b,
					lerpf(y0, ChicagoCity.STREET_Y - 0.04, float(k) / steps),
					lerpf(y0, ChicagoCity.STREET_Y - 0.04, float(k + 1) / steps)
				)
	return {"faces": faces, "ramps": ramps}


static func _strip(faces: PackedVector3Array, a: Vector2, b: Vector2, ya: float, yb: float) -> void:
	var side = (b - a).normalized().orthogonal() * LOW_WIDTH * 0.5
	var a0 = Vector3(a.x - side.x, ya, a.y - side.y)
	var a1 = Vector3(a.x + side.x, ya, a.y + side.y)
	var b0 = Vector3(b.x - side.x, yb, b.y - side.y)
	var b1 = Vector3(b.x + side.x, yb, b.y + side.y)
	faces.append_array([a0, a1, b1, a0, b1, b0])


static func _near(ring: Array, ramps: Array, dist: float) -> bool:
	for p in ring:
		var v = Vector2(p[0], p[1])
		for ramp in ramps:
			if Geometry2D.get_closest_point_to_segment(v, ramp[0], ramp[1]).distance_to(v) < dist:
				return true
	return false


## Drops street-slab triangles whose centre lies within dist of a ramp, which opens the slab above it.
static func _without(faces: PackedVector3Array, ramps: Array, dist: float) -> PackedVector3Array:
	var kept = PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var c = (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		if not _near([[c.x, c.z]], ramps, dist):
			kept.append_array([faces[i], faces[i + 1], faces[i + 2]])
	return kept


static func _shape(body: StaticBody3D, faces: PackedVector3Array) -> void:
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var col = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
