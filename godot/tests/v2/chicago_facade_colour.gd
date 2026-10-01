extends SceneTree


func _initialize():
	var city = preload("res://trackgen/chicago_city.gd")
	var tint = Color("7db9c4")
	var ring = PackedVector2Array([Vector2.ZERO, Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)])
	var walls = SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	city._building(walls, walls, ring, 12.0, .4, 0.0, 0.0, tint)
	check_colour(walls.commit().surface_get_arrays(0), tint)
	var raw = PackedByteArray([120, 0])
	var measured = SurfaceTool.new()
	measured.begin(Mesh.PRIMITIVE_TRIANGLES)
	city._lidar_building(measured, [0, 0, 1, 1, 2, Marshalls.raw_to_base64(raw)], .4, 0.0, tint)
	check_colour(measured.commit().surface_get_arrays(0), tint)
	print("Chicago facade colour: sourced RGB retained on footprint and measured walls")
	quit(0)


func check_colour(arrays: Array, tint: Color):
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var checked = 0
	for i in colours.size():
		if colours[i].b > .1 and colours[i].b < .5:
			assert(absf(uv2[i].x - tint.r) < .002)
			assert(absf(uv2[i].y - tint.g) < .002)
			assert(absf(colours[i].a - tint.b) <= 1.0 / 255.0)
			checked += 1
	assert(checked > 0, "Tagged wall colour missing")
