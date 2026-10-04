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
	var building = scenery.get_node("Wacker125")
	check(building.position.distance_to(Vector3(-998.175, 8, 564.75)) < .01, "Mapped 125 Wacker origin")
	check(absf(building.rotation.y - .019009) < .0001, "Mapped street alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 10, "Ten authored materials")
	var bounds = exterior.get_aabb()
	print("WACKER125 BOUNDS ", bounds)
	check(bounds.position.x > -16.5 and bounds.end.x < 22, "Mapped tower and canopy east west envelope")
	check(bounds.position.z > -31 and bounds.end.z < 31, "Mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation meets ground under raised street")
	check(absf(bounds.end.y - 141.5) < .01, "Separate rear plant preserves measured roof-grid maximum")
	var lit = 0
	var transparent = 0
	var stone_front = INF
	var glass_front = INF
	var street_parapet = 0.0
	var vision_top = 0.0
	var clear_front = INF
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		var vertices = exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if "curtain" in mat.resource_name:
			check(
				mat.metallic < .1 and mat.metallic_specular < .2 and mat.roughness >= .45,
				"Restrained dielectric highlights"
			)
			for vertex in vertices:
				vision_top = maxf(vision_top, vertex.y)
				if vertex.y > 60 and vertex.y < 100:
					glass_front = minf(glass_front, vertex.x)
		if "granite" in mat.resource_name:
			check(mat.roughness > .8 and mat.metallic_specular < .2, "Rough granite avoids generic gloss")
			for vertex in vertices:
				if vertex.y > 6.3 and vertex.y < 126.6:
					stone_front = minf(stone_front, vertex.x)
				if vertex.x < -12:
					street_parapet = maxf(street_parapet, vertex.y)
		if mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= .15,
				"Clear arcade reveals lobby geometry"
			)
			for vertex in vertices:
				if vertex.y < 4:
					clear_front = minf(clear_front, vertex.x)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops emission: " + mat.resource_name)
	check(
		absf(street_parapet - 126.5) < .01, "Street-facing granite parapet has published architectural height"
	)
	check(
		vision_top < 124.3 and vision_top > 120,
		"Office glazing stops below architectural roof and rear plant"
	)
	check(
		stone_front < INF and glass_front < INF and glass_front - stone_front > .2,
		"Granite ribs physically project ahead of individual panes"
	)
	check(clear_front < INF and clear_front > -10, "Ground glazing remains recessed behind street piers")
	check(lit == 3, "Office, warm wood and exposed ceiling night materials")
	check(transparent == 1, "Separate clear arcade and canopy material")
	var west = first_hit(exterior, Vector3(-40, 4, 20), Vector3(15, 4, 20))
	check(west != Vector3.INF and west.x > -5, "West arcade genuinely opens to recessed lobby core")
	var south = first_hit(exterior, Vector3(1.4, 3, 60), Vector3(1.4, 3, 0))
	check(south != Vector3.INF and south.z < 25, "Adams arcade has actual setback below upper tower")
	asset.queue_free()
	await process_frame
	print("WACKER125 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
