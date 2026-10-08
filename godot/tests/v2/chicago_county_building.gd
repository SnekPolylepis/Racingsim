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
	check(exterior.get_surface_count() == 8, "Physical materials including court masonry")
	check(absf(exterior.get_aabb().end.y - 62.484) < .03, "HABS205ft coping height")
	var city_hall = load("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/city_hall.glb"
	)
	var city_coping = first_hit(city_hall, Vector3(-22.8, 80, .25), Vector3(-22.8, 0, .25))
	check(absf(exterior.get_aabb().end.y - city_coping.y) < .01, "Paired halves share coping height")
	var pane = first_hit(exterior, Vector3(.7, 30.6, 80), Vector3(.7, 30.6, 0))
	var column = first_hit(exterior, Vector3(3.707, 30.6, 80), Vector3(3.707, 30.6, 0))
	print("COUNTY SOUTH HITS ", pane, " ", column)
	check(
		pane != Vector3.INF and column != Vector3.INF and column.z - pane.z > 1,
		"South triple sash glazing physically behind fluted column"
	)
	var door = first_hit(exterior, Vector3(60, 1.65, -.5), Vector3(0, 1.65, -.5))
	var transom = first_hit(exterior, Vector3(60, 4.6, -.5), Vector3(0, 4.6, -.5))
	var lintel = first_hit(exterior, Vector3(60, 6.74, -.5), Vector3(0, 6.74, -.5))
	print("COUNTY ENTRY HITS ", door, " ", transom, " ", lintel)
	check(
		(
			door != Vector3.INF
			and transom != Vector3.INF
			and lintel != Vector3.INF
			and lintel.x - door.x > 1.5
			and lintel.x - transom.x > 1.5
		),
		"Clark doors and transoms physically recessed behind portal lintel"
	)
	var court = first_hit(exterior, Vector3(-12, 80, -22), Vector3(-12, 0, -22))
	print("COUNTY COURT HIT ", court)
	check(court == Vector3.INF, "Mapped western courtyard notch remains open")
	# Cast at both outer seals using the mapped Clark face, independent of mesh names.
	var court_middle = Vector3(-8.45, 29, -29.75)
	var court_along = Vector3(28, 0, -.3).normalized()
	var court_out = Vector3(-court_along.z, 0, court_along.x)
	var pane_center = court_middle + court_along * (28.00161 / 16)
	var court_pane = first_hit(exterior, pane_center + court_out * 5, pane_center - court_out * 2)
	var court_pier = first_hit(exterior, court_middle + court_out * 5, court_middle - court_out * 2)
	print("COURT PANE/PIER HITS ", court_pane, " ", court_pier)
	check(
		(
			court_pane != Vector3.INF
			and court_pier != Vector3.INF
			and (court_pier - court_pane).dot(court_out) > .20
		),
		"County court sash physically recessed behind masonry pier"
	)
	var middle = Vector3(24.05, 0, -1.25)
	var along = Vector3(-1.4, 0, -112.1).normalized()
	var outward = Vector3(-along.z, 0, along.x)
	for sign in [-1, 1]:
		var center = middle + along * sign * 112.10874 / 18.0 * 1.5
		center.y = 3.82
		var seal = first_hit(exterior, center + outward * 8, center - outward * 2)
		var field_center = center + Vector3.UP * 1.58
		var field = first_hit(exterior, field_center + outward * 8, field_center - outward * 2)
		print("COUNTY RELIEF HITS ", seal, " ", field)
		check(
			seal != Vector3.INF and field != Vector3.INF and (seal - field).dot(outward) > .12,
			"County outer oval seal projects physically beyond recessed relief field %s" % sign
		)
	for panel in [-.5, .5]:
		var center = middle + along * panel * 112.10874 / 18.0
		center.y = 4.12
		var torso = first_hit(exterior, center + outward * 8, center - outward * 2)
		var field_center = center + Vector3.DOWN * 2.30
		var field = first_hit(exterior, field_center + outward * 8, field_center - outward * 2)
		check(
			torso != Vector3.INF and field != Vector3.INF and (torso - field).dot(outward) > .15,
			"County inner seated figure projects beyond backing %s" % panel
		)
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("COUNTY RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
