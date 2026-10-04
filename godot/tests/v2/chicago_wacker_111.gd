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
	var building = scenery.get_node("Wacker111")
	check(building.position.distance_to(Vector3(-987.45, 8, 502.0)) < .01, "Mapped 111 Wacker origin")
	check(absf(building.rotation.y - .0201) < .0001, "Mapped 111 Wacker alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 9, "Nine authored materials")
	var bounds = exterior.get_aabb()
	print("WACKER111 BOUNDS ", bounds)
	check(bounds.position.x > -25.3 and bounds.end.x < 25.3, "Mapped east/west envelope")
	check(bounds.position.z > -29 and bounds.end.z < 29, "Mapped north/south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation reaches ground beneath raised street")
	check(absf(bounds.end.y - 207.6) < .01, "Published architectural top")
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
		if mat.resource_name.begins_with("Clear"):
			var vertices = exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var circular = 0
			for vertex in vertices:
				if absf(Vector2(vertex.x, vertex.z).length() - 23.7) < .035:
					circular += 1
			check(circular > vertices.size() * .8, "Lobby panes form a physical curved enclosure")
		if "spiral ceiling" in mat.resource_name:
			var vertices = exterior.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var strip_bounds = AABB(vertices[0], Vector3.ZERO)
			for vertex in vertices:
				strip_bounds = strip_bounds.expand(vertex)
			check(
				strip_bounds.position.y > 9 and strip_bounds.end.y < 13.8,
				"Spiral lighting remains exposed below the upper tower"
			)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops emission: " + mat.resource_name)
	check(lit == 3, "Office panes, lobby walls and spiral lights toggle separately")
	check(transparent == 1, "Separate clear lobby material")
	var lobby = first_hit(exterior, Vector3(-40, 6, -.7), Vector3(0, 6, -.7))
	check(lobby != Vector3.INF and lobby.x > -3, "Open west lobby reaches compact marble core")
	var low = first_hit(exterior, Vector3(15, 1, -1), Vector3(15, 14, -1))
	var high = first_hit(exterior, Vector3(-15, 1, -1), Vector3(-15, 14, -1))
	check(low != Vector3.INF and low.y > 9 and low.y < 9.5, "Lower turn of modeled ramp underside")
	check(high != Vector3.INF and high.y > 10.9 and high.y < 11.3, "Opposite turn of modeled ramp underside")
	check(
		low != Vector3.INF and high != Vector3.INF and high.y - low.y > 1.5,
		"Lobby ceiling is a true rising spiral"
	)
	var shoulder = first_hit(exterior, Vector3(-40, 80, 26), Vector3(0, 80, 26))
	var center = first_hit(exterior, Vector3(-40, 80, 0), Vector3(0, 80, 0))
	check(
		shoulder != Vector3.INF and center != Vector3.INF and shoulder.x - center.x > 8,
		"Mapped west projection has actual recessed shoulders"
	)
	asset.queue_free()
	await process_frame
	print("WACKER111 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
