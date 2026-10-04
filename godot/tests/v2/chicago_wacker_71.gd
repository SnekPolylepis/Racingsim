extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
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
	var building = scenery.get_node("Wacker71")
	check(building.position.distance_to(Vector3(-964.95, 8, 423.4)) < .01, "Mapped 71 Wacker origin")
	check(absf(building.rotation.y - .019526) < .0001, "Mapped street alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 11, "Eleven authored materials")
	var bounds = exterior.get_aabb()
	print("WACKER71 BOUNDS ", bounds)
	check(bounds.position.x > -50.5 and bounds.end.x < 50.5, "Mapped east west envelope")
	check(bounds.position.z > -30.6 and bounds.end.z < 30.6, "Mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation meets ground under raised street")
	check(absf(bounds.end.y - 207.1) < .01, "Published architectural top")
	var lit = 0
	var transparent = 0
	var bowed_center = false
	var slim_tip = false
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if "curtain" in mat.resource_name:
			check(
				mat.metallic < .1 and mat.metallic_specular < .2 and mat.roughness >= .4,
				"Restrained dielectric highlights"
			)
			for vertex in exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				if vertex.y < 20:
					continue
				if absf(vertex.x) < 2 and absf(vertex.z) > 22:
					bowed_center = true
				if absf(vertex.x) > 43 and absf(vertex.z) < 7:
					slim_tip = true
		if mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= .15,
				"Clear lobby reveals actual interior"
			)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops emission: " + mat.resource_name)
	check(bowed_center and slim_tip, "Physical panes follow broad bowed center and narrow end tips")
	check(lit == 3, "Office, reception and ceiling night materials")
	check(transparent == 1, "Separate clear lobby enclosure")
	for side in [-1, 1]:
		var lobby = first_hit(exterior, Vector3(side * 60, 6, .7), Vector3(0, 6, .7))
		check(lobby != Vector3.INF and absf(lobby.x) < 31, "Open reception reaches inner granite core")
		var hall = first_hit(exterior, Vector3(side * 37, 1, 0), Vector3(side * 37, 17, 0))
		check(
			hall != Vector3.INF and absf(hall.y - 15.24) < .05, "Reception hall has published 50 foot height"
		)
		var tip = first_hit(exterior, Vector3(side * 70, 100, 1.95), Vector3(0, 100, 1.95))
		var slot = first_hit(exterior, Vector3(side * 70, 100, 0), Vector3(0, 100, 0))
		check(
			tip != Vector3.INF and slot != Vector3.INF and absf(tip.x) - absf(slot.x) > 1.8,
			"End spine is physically recessed between silver blades"
		)
	var ceiling = first_hit(exterior, Vector3(5, 1, -19), Vector3(5, 16, -19))
	check(
		ceiling != Vector3.INF and ceiling.y > 10.7 and ceiling.y < 11,
		"Curved main lobby has separate 36 foot ceiling"
	)
	asset.queue_free()
	await process_frame
	print("WACKER71 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
