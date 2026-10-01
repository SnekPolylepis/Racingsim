extends SceneTree


func _initialize():
	var city = preload("res://trackgen/chicago_city.gd")
	var route = {Vector2i.ZERO: [Vector3(0, 8, 0)]}
	var nearby = PackedVector2Array([Vector2(16, -4), Vector2(22, -4), Vector2(22, 4), Vector2(16, 4)])
	assert(not city._touches_route(route, nearby, 0.0), "Nearby centroid wrongly removes an intact building")
	var enclosing = PackedVector2Array(
		[Vector2(-40, -40), Vector2(40, -40), Vector2(40, 40), Vector2(-40, 40)]
	)
	assert(city._touches_route(route, enclosing, 0.0), "Route inside a large footprint must be detected")
	var edge = PackedVector2Array([Vector2(8, -4), Vector2(16, -4), Vector2(16, 4), Vector2(8, 4)])
	assert(city._touches_route(route, edge, 0.0), "Road clearance at the footprint edge must remain")
	print("Chicago clearance: nearby footprint preserved; interior and edge overlap detected")
	quit(0)
