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
	check(exterior.get_surface_count() == 11, "Physical materials including court masonry")
	var coping = first_hit(exterior, Vector3(-22.8, 80, .25), Vector3(-22.8, 0, .25))
	check(absf(coping.y - 62.484) < .03, "HABS205ft coping height")
	var equipment = first_hit(exterior, Vector3(-1, 80, 0), Vector3(-1, 0, 0))
	check(equipment.y > 68, "Raised central rooftop equipment")
	var planting = first_hit(exterior, Vector3(-18, 80, 40), Vector3(-18, 0, 40))
	check(planting.y > 61.8 and planting.y < 62.5, "Low planted roof bed")
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
	var court_middle = Vector3(9.15, 29, 28.45)
	var court_along = Vector3(-24.9, 0, .5).normalized()
	var court_out = Vector3(court_along.z, 0, -court_along.x) * -1
	var court_pane = first_hit(exterior, court_middle + court_out * 5, court_middle - court_out * 2)
	var pier_center = court_middle + court_along * (24.90502 / 14)
	var court_pier = first_hit(exterior, pier_center + court_out * 5, pier_center - court_out * 2)
	print("COURT PANE/PIER HITS ", court_pane, " ", court_pier)
	check(
		(
			court_pane != Vector3.INF
			and court_pier != Vector3.INF
			and (court_pier - court_pane).dot(court_out) > .20
		),
		"Court sash physically recessed behind masonry pier"
	)
	var middle = Vector3(-22.8, 0, .25)
	var along = Vector3(1.6, 0, 112).normalized()
	var outward = Vector3(-along.z, 0, along.x)
	for panel in [-1.5, -.5, .5, 1.5]:
		var center = middle + along * panel * 112.01143 / 18.0
		center.y = 4.12
		var torso = first_hit(exterior, center + outward * 8, center - outward * 2)
		var field_center = center + Vector3.DOWN * 2.30
		var field = first_hit(exterior, field_center + outward * 8, field_center - outward * 2)
		check(
			torso != Vector3.INF and field != Vector3.INF and (torso - field).dot(outward) > .15,
			"City sculpted figure projects beyond stone field at panel %s" % panel
		)
	for surface in exterior.get_surface_count():
		check(exterior.surface_get_material(surface).albedo_texture == null, "No photographic facade")
	print("CITY HALL RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
