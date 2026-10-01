extends SceneTree


func _initialize():
	var crowns = preload("res://trackgen/chicago_crowns.gd")
	var ring = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)])
	for winding in 2:
		for face in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var panel = crowns.photo_facade(
				ring, 28.0, 20.0, {"face": [face.x, face.y], "file": "rx_east.jpg"}
			)
			var arrays = panel.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var right = (-normals[0]).cross(Vector3.UP).normalized()
			assert(
				(vertices[1] - vertices[0]).normalized().dot(right) > .999,
				"Photo reads backwards from outside"
			)
			assert(uv[0].x == 0.0 and uv[1].x == 1.0)
			assert(vertices[0].y < vertices[2].y and uv[0].y > uv[2].y)
			panel.free()
		ring.reverse()
	var city = preload("res://trackgen/chicago_city.gd")
	var footprint = PackedVector2Array([Vector2(1, 1), Vector2(7, 1), Vector2(7, 7), Vector2(1, 7)])
	var raw = PackedByteArray()
	raw.resize(32)
	for i in 16:
		raw.encode_u16(i * 2, 990 if i == 5 else 200)
	var grid = [0, 0, 4, 4, 2, Marshalls.raw_to_base64(raw)]
	assert(city._photo_height(footprint, {"face": [1, 0]}, grid) == 20.0)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	city._lidar_building(surface, grid, 0, 0, Color.WHITE, footprint)
	var mesh = surface.commit()
	var measured_top = 0.0
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(vertex.x >= .999 and vertex.x <= 7.001)
		assert(vertex.z >= .999 and vertex.z <= 7.001)
		measured_top = maxf(measured_top, vertex.y)
	assert(measured_top > 99.0, "Clipping discarded a measured rear roof step")
	print("Photo wall clipping and measured frontage height: PASS")
	print("Chicago photo orientation: four sides, both footprint windings read left-to-right")
	quit(0)
