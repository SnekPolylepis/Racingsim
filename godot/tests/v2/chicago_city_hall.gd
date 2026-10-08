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
		"res://assets/chicago/landmarks/city_hall.glb"
	)
	check(exterior.get_surface_count() == 7, "Seven original physical materials including bronze entrance")
	check(absf(exterior.get_aabb().end.y - 62.484) < .03, "HABS205ft coping height")
	var pane = first_hit(exterior, Vector3(.5, 30.6, 80), Vector3(.5, 30.6, 0))
	var column = first_hit(exterior, Vector3(3.143, 30.6, 80), Vector3(3.143, 30.6, 0))
	print("CITY HALL SOUTH HITS ", pane, " ", column)
	check(
		pane != Vector3.INF and column != Vector3.INF and column.z - pane.z > 1,
		"South triple sash glazing physically behind fluted column"
	)
	var door = first_hit(exterior, Vector3(-60, 1.65, 1), Vector3(0, 1.65, 1))
	var transom = first_hit(exterior, Vector3(-60, 4.6, 1), Vector3(0, 4.6, 1))
	var lintel = first_hit(exterior, Vector3(-60, 6.74, 1), Vector3(0, 6.74, 1))
	print("CITY HALL ENTRY HITS ", door, " ", transom, " ", lintel)
	check(
		(
			door != Vector3.INF
			and transom != Vector3.INF
			and lintel != Vector3.INF
			and door.x - lintel.x > 1.5
			and transom.x - lintel.x > 1.5
		),
		"LaSalle doors and transoms physically recessed behind portal lintel"
	)
	var court = first_hit(exterior, Vector3(12, 80, -22), Vector3(12, 0, -22))
	print("CITY HALL COURT HIT ", court)
	check(court == Vector3.INF, "Mapped eastern courtyard notch remains open")
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("CITY HALL RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
