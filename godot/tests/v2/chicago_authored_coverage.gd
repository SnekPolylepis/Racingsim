extends SceneTree
const City = preload("res://trackgen/chicago_city.gd")
const Crowns = preload("res://trackgen/chicago_crowns.gd")
const PropMesh = preload("res://scripts/track/prop_mesh.gd")


func _initialize():
	var checks = 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(City.DATA))
	for building in data.buildings:
		if not building.has("ph"):
			continue
		assert(
			City.AUTHORED_BUILDINGS.has(building.o),
			"Photo-tagged building requires an authored exterior: " + building.o
		)
		checks += 1
		var exterior = PropMesh.mesh(
			"res://assets/chicago/buildings/chicago_theatre/%s.glb" % City.AUTHORED_BUILDINGS[building.o][1]
		)
		var physical = exterior.get_surface_count() > 1
		for surface in exterior.get_surface_count():
			var material = exterior.surface_get_material(surface)
			if material is StandardMaterial3D and material.albedo_texture:
				physical = physical and not "facade-photos" in material.albedo_texture.resource_path
		assert(physical, "Authored building must not retain a full-building photograph")
		checks += 1
	# All four wall orientations and both winding orders place model +X to the
	# viewer's right, with model +Z pointing out from the actual mapped wall.
	var ring = PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 20), Vector2(0, 20)])
	for winding in 2:
		for face in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var wall = Crowns.exterior_wall(ring, {"face": [face.x, face.y]})
			var along = (wall[1] - wall[0]).normalized()
			var normal = Vector3(wall[2].x, 0, wall[2].y)
			var right = (-normal).cross(Vector3.UP).normalized()
			assert(
				(
					Vector3(along.x, 0, along.y).dot(right) > .999
					and Vector2(normal.x, normal.z).dot(face) > .999
				),
				"Mapped exterior orientation"
			)
			checks += 1
		ring.reverse()
	# Keep the measured footprint/rear-step check from the retired panel suite.
	var footprint = PackedVector2Array([Vector2(1, 1), Vector2(7, 1), Vector2(7, 7), Vector2(1, 7)])
	var raw = PackedByteArray()
	raw.resize(32)
	for i in 16:
		raw.encode_u16(i * 2, 990 if i == 5 else 200)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	City._lidar_building(surface, [0, 0, 4, 4, 2, Marshalls.raw_to_base64(raw)], 0, 0, Color.WHITE, footprint)
	var measured_top = 0.0
	for vertex in surface.commit_to_arrays()[Mesh.ARRAY_VERTEX]:
		assert(
			vertex.x >= .999 and vertex.x <= 7.001 and vertex.z >= .999 and vertex.z <= 7.001,
			"Measured footprint envelope"
		)
		measured_top = maxf(measured_top, vertex.y)
	assert(measured_top > 99.0, "Measured rear roof step is preserved")
	checks += 1
	print("AUTHORED COVERAGE RESULTS ", JSON.stringify({"checks": checks, "failures": []}))
	quit()
