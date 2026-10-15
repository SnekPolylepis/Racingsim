extends SceneTree
## Free Roam variant: the Loop Grid route plus collision for the rest of the city. The street layer is the
## land tiles the visual city already clips against water (surface 4, tarmac runoff), and every mapped
## building footprint the city kept becomes a layer-2 wall, so you can drive anywhere and hit what you see.
const Chicago = preload("res://trackgen/chicago.gd")
const ChicagoCity = preload("res://trackgen/chicago_city.gd")
const WALL_HEIGHT = 4.0
## Reasons the city drops a footprint without drawing something else in its place.
const NOT_DRAWN = ["authored route clearance", "invalid footprint"]


static func build_asset() -> Node3D:
	return Chicago.build_asset(true, true)


static func add_collision(asset: Node3D, city: Dictionary) -> void:
	var ground = StaticBody3D.new()
	ground.name = "FreeRoamGround"
	ground.set_meta("surface", 4)
	ground.collision_layer = 1
	ground.collision_mask = 0
	_shape(ground, city.ground_faces)
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
		if skip.has(i) or ring.size() < 3:
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


static func _shape(body: StaticBody3D, faces: PackedVector3Array) -> void:
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var col = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
