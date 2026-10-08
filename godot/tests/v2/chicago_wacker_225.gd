extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const Clip = preload("res://tests/visual/clip_scan.gd")
const Night = preload("res://scripts/track/chicago_night.gd")
var checks = 0
var failures = []


func check(ok: bool, label: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


# Imported triangles, ignoring transparent panes, establish real openings.
func first_hit(exterior: Mesh, start: Vector3, end: Vector3) -> Vector3:
	var nearest = INF
	var result = Vector3.INF
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var arrays = exterior.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var hit = Geometry3D.segment_intersects_triangle(
				start, end, vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]
			)
			if hit != null and start.distance_squared_to(hit) < nearest:
				nearest = start.distance_squared_to(hit)
				result = hit
	return result


func run():
	var asset = Node3D.new()
	root.add_child(asset)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	Chicago.add_loop_landmarks(asset, scenery)
	var building = scenery.get_node("Wacker225")
	check(building.position.distance_to(Vector3(-886, 8, -164.75)) < .01, "Mapped 225 Wacker origin")
	var exterior = building.mesh
	var bounds = exterior.get_aabb()
	print("WACKER225 BOUNDS ", bounds)
	check(exterior.get_surface_count() == 8, "Eight authored materials")
	check(bounds.position.x > -18 and bounds.end.x < 18, "Mapped east west envelope")
	check(bounds.position.z > -50 and bounds.end.z < 50, "Mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation below raised street")
	check(absf(bounds.end.y - 126.5) < .01, "Provisional mapped finial height")
	var upward_vault = false
	var lit = 0
	var transparent = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if mat.resource_name.begins_with("Grey"):
			var arrays = exterior.surface_get_arrays(surface)
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var vertex = arrays[Mesh.ARRAY_VERTEX][i]
				if absf(vertex.x) < .1 and absf(vertex.y - 116) < .1 and arrays[Mesh.ARRAY_NORMAL][i].y > .9:
					upward_vault = true
		check(mat.albedo_texture == null, "Physical facade without photograph: " + mat.resource_name)
		if mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= .15,
				"Lobby panes reveal interior"
			)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night lights enable: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Day stops emission: " + mat.resource_name)
	check(lit == 3 and transparent == 1, "Three night materials and clear lobby")
	check(upward_vault, "Barrel roof normals face the sky")
	var vault = first_hit(exterior, Vector3(0, 130, 0), Vector3(0, 100, 0))
	check(vault != Vector3.INF and vault.y > 115.9 and vault.y < 116.1, "Actual curved central barrel roof")
	var shoulder = first_hit(exterior, Vector3(4, 130, 0), Vector3(4, 100, 0))
	check(shoulder != Vector3.INF and shoulder.y < vault.y - 1, "Barrel falls toward sides")
	var turret = first_hit(exterior, Vector3(10.5, 130, 40), Vector3(10.5, 110, 40))
	check(turret != Vector3.INF and turret.y > 126.4, "Separate stepped corner finial")
	var channel = first_hit(exterior, Vector3(-30, 61.8, -23.7), Vector3(0, 61.8, -23.7))
	check(
		channel != Vector3.INF and absf(channel.x + 16.16) < .08,
		"Recessed channel glass stays ahead of opaque backing"
	)
	var entrance = first_hit(exterior, Vector3(1, 4, -60), Vector3(1, 4, 0))
	check(entrance != Vector3.INF and entrance.z > -48, "North entrance has real recessed interior")
	for name in ["Wacker225", "Wacker125", "Wacker191"]:
		check(
			not Clip._overhead("Scenery/" + name, 120, 3.4288),
			"Building is not exempt as a Wacker deck: " + name
		)
	check(
		Clip._overhead("Scenery/WackerDeckAndColumns", 4.5, 3.4288), "Actual Upper Wacker deck stays overhead"
	)
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	var footprint = PackedVector2Array()
	for entry in city.buildings:
		if entry.get("o", "") == "w64391366":
			for point in entry.f:
				footprint.append(Vector2(point[0], point[1]))
	check(footprint.size() == 7, "Retained mapped foundation available for clearance checks")
	for grid in [false, true]:
		var curve = Chicago.route_curve(grid)
		var nearest = INF
		for station in range(0, ceili(curve.get_baked_length())):
			var point = curve.sample_baked(station, true)
			var horizontal = Vector2(point.x, point.z)
			if horizontal.distance_to(Vector2(-886, -164.75)) > 150:
				continue
			if Geometry2D.is_point_in_polygon(horizontal, footprint):
				nearest = 0
			for i in footprint.size():
				nearest = minf(
					nearest,
					horizontal.distance_to(
						Geometry2D.get_closest_point_to_segment(
							horizontal, footprint[i], footprint[(i + 1) % footprint.size()]
						)
					)
				)
		print("WACKER225 ROUTE CLEARANCE ", "grid" if grid else "original", " ", nearest)
		check(
			nearest > 10,
			"Sampled carriageway clears retained foundation: " + ("grid" if grid else "original")
		)
	asset.queue_free()
	await process_frame
	print("WACKER225 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
