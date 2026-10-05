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
	var building = scenery.get_node("Michigan323")
	var exterior = building.mesh
	check(building.position.distance_to(Vector3(17.8, 8, -292.3)) < .01, "323 mapped fit")
	check(absf(building.rotation.y - (-PI / 2 + .021)) < .0001, "Michigan-facing frontage")
	check(exterior.get_surface_count() == 8, "Eight distinct physical materials")
	var bounds = exterior.get_aabb()
	check(absf(bounds.end.y - 14.5) < .02 and bounds.position.y >= -8.01, "Low-rise roof and foundation")
	var entry = first_hit(exterior, Vector3(.4, 2.4, 20), Vector3(.4, 2.4, 0))
	var jamb = first_hit(exterior, Vector3(1.5, 2.4, 20), Vector3(1.5, 2.4, 0))
	print("ENTRY ", entry, " JAMB ", jamb)
	check(
		entry != Vector3.INF and jamb != Vector3.INF and jamb.z - entry.z > 1,
		"Transparent entrance opens into recessed vestibule"
	)
	var retail = first_hit(exterior, Vector3(6, 2.4, 20), Vector3(6, 2.4, 0))
	check(retail != Vector3.INF and jamb.z - retail.z > 1, "Retail apertures remain open behind clear glass")
	var pane = first_hit(exterior, Vector3(10.85, 8.2, 20), Vector3(10.85, 8.2, 0))
	var pier = first_hit(exterior, Vector3(8.71, 8.2, 20), Vector3(8.71, 8.2, 0))
	print("OFFICE ", pane, " PIER ", pier)
	check(
		pane != Vector3.INF and pier != Vector3.INF and pier.z - pane.z > .3,
		"Tall upper glazing sits behind continuous piers"
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
	print("MICHIGAN323 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
