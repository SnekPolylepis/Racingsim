extends SceneTree
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
	var exterior = load("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/county_building.glb"
	)
	check(exterior.get_surface_count() == 6, "Six original physical materials")
	check(absf(exterior.get_aabb().end.y - 62.484) < .03, "HABS205ft coping height")
	var city_hall = load("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/city_hall.glb"
	)
	check(
		absf(exterior.get_aabb().end.y - city_hall.get_aabb().end.y) < .01,
		"Paired halves share coping height"
	)
	var pane = first_hit(exterior, Vector3(.7, 30.6, 80), Vector3(.7, 30.6, 0))
	var column = first_hit(exterior, Vector3(3.707, 30.6, 80), Vector3(3.707, 30.6, 0))
	print("COUNTY SOUTH HITS ", pane, " ", column)
	check(
		pane != Vector3.INF and column != Vector3.INF and column.z - pane.z > 1,
		"South triple sash glazing physically behind fluted column"
	)
	var court = first_hit(exterior, Vector3(-12, 80, -22), Vector3(-12, 0, -22))
	print("COUNTY COURT HIT ", court)
	check(court == Vector3.INF, "Mapped western courtyard notch remains open")
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("COUNTY RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
