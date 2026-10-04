extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const Night = preload("res://scripts/track/chicago_night.gd")
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
	var building = scenery.get_node("LondonGuarantee")
	check(building.position.distance_to(Vector3(-57.85, 8, -351.3)) < .01, "Mapped London Guarantee origin")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 11, "Eleven authored materials")
	var bounds = exterior.get_aabb()
	print("LONDON BOUNDS ", bounds)
	check(
		bounds.position.x > -26.5 and bounds.end.x < 26.5,
		"Mapped east west envelope including projecting cafe canopies"
	)
	check(bounds.position.z > -25 and bounds.end.z < 25, "Historic mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Foundation reaches ground below raised street")
	check(absf(bounds.end.y - 102.9) < .01, "Published architectural tip height")
	var lit = 0
	var clear = 0
	var cupola_center = Vector3(-7.009, 90, -3.222)
	var opening = first_hit(exterior, cupola_center + Vector3(-8, 0, 0), cupola_center + Vector3(8, 0, 0))
	check(opening == Vector3.INF, "Cupola colonnade remains open between columns")
	var edge = Vector2(21.8, 29.7)
	var inward = Vector2(edge.y, -edge.x).normalized()
	var facade_point = Vector2(-24.75, -6.6) + edge * .25 + inward * 2.625
	var tangent = (edge + inward * 7.0).normalized()
	var normal = Vector3(-tangent.y, 0, -tangent.x)
	var pane_point = facade_point + tangent * .55
	var pier_point = facade_point - tangent * edge.length() / 20.0
	var pane_start = Vector3(pane_point.x, 43.2, -pane_point.y) + normal * 2
	var pier_start = Vector3(pier_point.x, 43.2, -pier_point.y) + normal * 2
	var pane_hit = first_hit(exterior, pane_start, pane_start - normal * 5)
	var pier_hit = first_hit(exterior, pier_start, pier_start - normal * 5)
	check(
		(
			pane_hit != Vector3.INF
			and pier_hit != Vector3.INF
			and pane_start.distance_to(pane_hit) > pier_start.distance_to(pier_hit) + .25
		),
		"Curved facade glazing is physically recessed behind limestone piers"
	)

	var entry_point = Vector2(-24.75, -6.6) + edge * .5 + inward * 3.7
	var entry_normal = Vector3(-edge.y, 0, -edge.x).normalized()
	var above_start = Vector3(entry_point.x, 12.0, -entry_point.y) + entry_normal * 1.5
	var opening_start = Vector3(entry_point.x, 7.2, -entry_point.y) + entry_normal * 1.5
	var above_hit = first_hit(exterior, above_start, above_start - entry_normal * 4)
	var opening_hit = first_hit(exterior, opening_start, opening_start - entry_normal * 4)
	check(
		(
			above_hit != Vector3.INF
			and opening_hit != Vector3.INF
			and above_start.distance_to(above_hit) < 1.6
			and opening_start.distance_to(opening_hit) > above_start.distance_to(above_hit) + .2
		),
		"Entrance has solid stone spandrel above recessed arched glazing"
	)
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if mat.resource_name.begins_with("Night"):
			lit += 1
			check(mat.has_meta("chicago_night") and not mat.emission_enabled, "Night material starts unlit")
		elif mat.resource_name.begins_with("Clear"):
			clear += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .2,
				"Clear cupola enclosure and setback screens"
			)
	check(lit == 2 and clear == 1, "Separate occupied glazing, cupola lights and clear screens")
	for on in [true, false]:
		Night.set_night(asset, on)
		var correct = true
		for surface in exterior.get_surface_count():
			var mat = exterior.surface_get_material(surface)
			if mat.has_meta("chicago_night"):
				correct = correct and mat.emission_enabled == on
		check(correct, "London night toggle " + str(on))
	asset.queue_free()
	await process_frame
	print("LONDON GUARANTEE RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
