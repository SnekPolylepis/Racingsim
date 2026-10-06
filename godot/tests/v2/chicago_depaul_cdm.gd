extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


func first_hit(exterior, start, end):
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
	var building = scenery.get_node("DePaulCDM")
	var exterior = building.mesh
	check(building.position.distance_to(Vector3(-99.85, 8, 702.45)) < .01, "DePaul mapped fit")
	check(absf(building.rotation.y - (.022)) < .0001, "South and west frontage")
	check(exterior.get_surface_count() == 8, "Eight distinct physical materials")
	var bounds = exterior.get_aabb()
	check(absf(bounds.end.y - 39.0) < .02 and bounds.position.y >= -8.01, "Roof and foundation")
	var entry = first_hit(exterior, Vector3(-40, 2.4, 11), Vector3(0, 2.4, 11))
	var jamb = first_hit(exterior, Vector3(-40, 2.4, 8.43), Vector3(0, 2.4, 8.43))
	print("ENTRY ", entry, " JAMB ", jamb)
	check(
		entry != Vector3.INF and jamb != Vector3.INF and entry.x - jamb.x > 1,
		"Transparent entrance opens into recessed vestibule"
	)
	var retail = first_hit(exterior, Vector3(4, 2.4, 30), Vector3(4, 2.4, 0))
	check(retail != Vector3.INF and retail.z < 13.5, "Retail apertures remain open behind clear glass")
	var pane = first_hit(exterior, Vector3(.3, 16.4, 30), Vector3(.3, 16.4, 0))
	var pier = first_hit(exterior, Vector3(2.9, 16.4, 30), Vector3(2.9, 16.4, 0))
	print("OFFICE ", pane, " PIER ", pier)
	check(
		pane != Vector3.INF and pier != Vector3.INF and pier.z - pane.z > .3,
		"Upper glazing sits behind terracotta piers"
	)
	var clear = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if mat.resource_name.begins_with("Clear"):
			clear += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .2,
				"Entry and storefront glass stay transparent"
			)
	check(clear == 1, "One clear glazing material")
	asset.queue_free()
	await process_frame
	print("DEPAULCDM RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
