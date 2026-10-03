extends SceneTree
const Windows = preload("res://trackgen/chicago_windows.gd")
const City = preload("res://trackgen/chicago_city.gd")


func _initialize():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(.4, .5, .25, .3))
	st.set_uv2(Vector2(.2, .4))
	# Five adjacent measured cells must become a single wall run.
	for i in 5:
		City._lidar_wall(st, Vector3(i * 2, 0, 0), Vector3(i * 2 + 2, 0, 0), Vector3.BACK, 0, 24 + i * .1)
	var arrays = st.commit_to_arrays()
	var walls = {}
	Windows.collect(arrays, {Vector2i(0, 0): [Vector3(5, 8, 15)]}, walls)
	assert(walls.size() == 1)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var colours = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert(absf(colours[0].b - .75) < .005, "Physical marker must survive packed vertex colours")
	assert(absf(colours[0].a - .3) < .005, "Sourced blue tint must survive")
	var asset = Node3D.new()
	root.add_child(asset)
	var count = Windows.build(asset, asset, walls)
	assert(count > 15, "Frames cover multiple cells and all storeys")
	var highest = 0.0
	var lowest = INF
	for node in asset.get_children():
		assert(node.multimesh.mesh.get_surface_count() == 2, "Only frames and glass; no masonry cover panels")
		assert(node.multimesh.use_custom_data)
		for i in node.multimesh.instance_count:
			var xf = node.multimesh.get_instance_transform(i)
			var bounds = xf * node.multimesh.mesh.get_aabb()
			assert(bounds.position.x >= -.01 and bounds.end.x <= 10.01)
			assert(bounds.position.y >= 8.0 and bounds.end.y <= 32.01)
			highest = maxf(highest, bounds.end.y)
			lowest = minf(lowest, bounds.position.y)
	assert(highest > 27, "Upper floors receive real geometry")
	assert(lowest < 9.0, "Street-floor frames survive removal of the source kickboard")
	asset.free()
	var angled = SurfaceTool.new()
	angled.begin(Mesh.PRIMITIVE_TRIANGLES)
	angled.set_color(Color(.4, .5, 0))
	var normal = Vector3(.6, 0, .8)
	var along = Vector3(.8, 0, -.6)
	var origin = Vector3(20, 0, 20)
	City._lidar_wall(angled, origin, origin + along * 10, normal, 0, 24)
	var angled_walls = {}
	Windows.collect(angled.commit_to_arrays(), {Vector2i(0, 0): [origin + normal * 15]}, angled_walls)
	var rotated_asset = Node3D.new()
	root.add_child(rotated_asset)
	assert(Windows.build(rotated_asset, rotated_asset, angled_walls) > 15)
	for node in rotated_asset.get_children():
		for i in node.multimesh.instance_count:
			var xf = node.multimesh.get_instance_transform(i)
			assert(xf.basis.z.is_equal_approx(normal), "Angled footprint normals are retained")
			assert(absf(normal.dot(xf.origin - origin) - .13) < .002, "Frames follow the measured plane")
	rotated_asset.free()
	# A measured roof must follow its diagonal mapped walls, with roof steps retained.
	var footprint = PackedVector2Array([Vector2(4, 0), Vector2(8, 4), Vector2(4, 8), Vector2(0, 4)])
	var raw = PackedByteArray()
	raw.resize(32)
	for i in 16:
		raw.encode_u16(i * 2, 300 if i == 5 else 240)
	var mapped = SurfaceTool.new()
	mapped.begin(Mesh.PRIMITIVE_TRIANGLES)
	City._lidar_building(
		mapped, [0, 0, 4, 4, 2, Marshalls.raw_to_base64(raw)], .4, 4, Color(0, 0, 0, 0), footprint
	)
	var mapped_arrays = mapped.commit_to_arrays()
	var contained = true
	var diagonal_wall = false
	var roof_height = 0.0
	for i in mapped_arrays[Mesh.ARRAY_VERTEX].size():
		var v: Vector3 = mapped_arrays[Mesh.ARRAY_VERTEX][i]
		var point = Vector2(v.x, v.z)
		var on_edge = false
		for edge in footprint.size():
			on_edge = (
				on_edge
				or (
					point.distance_to(
						Geometry2D.get_closest_point_to_segment(
							point, footprint[edge], footprint[(edge + 1) % footprint.size()]
						)
					)
					< .01
				)
			)
		contained = contained and (on_edge or Geometry2D.is_point_in_polygon(point, footprint))
		var n: Vector3 = mapped_arrays[Mesh.ARRAY_NORMAL][i]
		diagonal_wall = diagonal_wall or (absf(n.x) > .5 and absf(n.z) > .5)
		roof_height = maxf(roof_height, v.y)
	assert(contained, "Measured geometry stays inside the mapped footprint")
	assert(diagonal_wall, "Mapped diagonal walls replace square raster stairs")
	assert(is_equal_approx(roof_height, City.STREET_Y + 30), "Measured taller roof cells survive clipping")
	print("CHICAGO WINDOWS RESULTS ", JSON.stringify({"checks": 15, "failures": []}))
	quit()
