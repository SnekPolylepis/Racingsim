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
	var building = scenery.get_node("Wacker155")
	check(building.position.distance_to(Vector3(-987.7, 8, -3.15)) < .01, "Mapped 155 Wacker origin")
	check(absf(building.rotation.y - .0047) < .0001, "Mapped 155 Wacker alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 9, "Nine authored materials")
	var bounds = exterior.get_aabb()
	print("WACKER155 BOUNDS ", bounds)
	check(bounds.position.x > -34 and bounds.end.x < 34, "Mapped east/west envelope")
	check(bounds.position.z > -28 and bounds.end.z < 28, "Mapped north/south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation reaches ground beneath raised street")
	check(absf(bounds.end.y - 194.6) < .01, "Published architectural top")
	var lit = 0
	var transparent = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if "curtain" in mat.resource_name:
			check(
				mat.metallic < .1 and mat.metallic_specular < .2 and mat.roughness >= .3,
				"Restrained dielectric facade highlights"
			)
		if mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= .15,
				"Clear cable wall reveals lobby geometry"
			)
		if "ceiling strips" in mat.resource_name:
			var vertices = exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var strip_bounds = AABB(vertices[0], Vector3.ZERO)
			for vertex in vertices:
				strip_bounds = strip_bounds.expand(vertex)
			check(
				strip_bounds.end.y < 13.716 and strip_bounds.position.y > 13.6,
				"Luminous strips sit below the opaque arcade ceiling"
			)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops emission: " + mat.resource_name)
	check(lit == 3, "Office panes, lobby walls and arcade strips toggle separately")
	check(transparent == 1, "Separate clear lobby material")
	check(
		first_hit(exterior, Vector3(3, 6, 28), Vector3(3, 6, 19.4)) == Vector3.INF,
		"South arcade remains physically open to the recessed cable wall"
	)
	var soffit = first_hit(exterior, Vector3(3, 1, 23), Vector3(3, 20, 23))
	check(soffit != Vector3.INF and absf(soffit.y - 13.716) < .04, "Published 45 foot arcade ceiling")
	var recess = first_hit(exterior, Vector3(-40, 70, 0), Vector3(0, 70, 0))
	check(
		recess != Vector3.INF and recess.x > -23 and recess.x < -21,
		"H plan west facade has an actual deep recess"
	)
	var wing = first_hit(exterior, Vector3(-40, 70, 20), Vector3(0, 70, 20))
	check(wing != Vector3.INF and wing.x < -33, "H plan wing remains proud of the central bridge")
	asset.queue_free()
	await process_frame
	print("WACKER155 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
