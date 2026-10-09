extends SceneTree
## Sharp working exterior geometry, fixture and retained footprint clearance.
const Chicago = preload("res://trackgen/chicago.gd")
var checks = 0
var failures = []


func check(ok: bool, label: String):
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)


func _initialize():
	call_deferred("run")


func first_hit(exterior: Mesh, start: Vector3, end: Vector3, material_name: String = "") -> Vector3:
	var nearest = INF
	var result = Vector3.INF
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if material_name != "" and mat.resource_name != material_name:
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
	var holder = Node3D.new()
	root.add_child(holder)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	holder.add_child(scenery)
	Chicago.add_loop_landmarks(holder, scenery)
	var fixture = scenery.get_node("SharpBuilding")
	var exterior = fixture.mesh
	check(fixture.position.distance_to(Vector3(-105, 8, 423)) < .01, "Sharp mapped production fixture")
	var bounds = exterior.get_aabb()
	check(exterior.get_surface_count() == 6, "Sharp six original physical materials")
	check(absf(bounds.position.y + 8) < .01, "Sharp buried foundation")
	check(absf(bounds.end.y - 61.3) < .02, "Sharp CVU architectural height")
	check(bounds.position.x > -27 and bounds.end.x < 28, "Sharp retained east west bounds")
	check(bounds.position.z > -13 and bounds.end.z < 13, "Sharp retained north south bounds")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Sharp original geometry: " + mat.resource_name)
	var pane = first_hit(exterior, Vector3(-35, 18, 3), Vector3(-20, 18, 3), "Sharp recessed blue grey panes")
	check(pane != Vector3.INF, "Sharp west facade physical recessed pane")
	var arch_top = first_hit(
		exterior,
		Vector3(-35, 60.7, -.1203125),
		Vector3(-20, 60.7, -.1203125),
		"Sharp pale terracotta surrounds"
	)
	check(arch_top != Vector3.INF, "Sharp upper parapet arch has physical terracotta ring")
	var opening = first_hit(
		exterior,
		Vector3(-35, 60.5, -.1203125),
		Vector3(-20, 60.5, -.1203125),
		"Sharp dark recessed interior and roof"
	)
	check(opening != Vector3.INF and opening.x > -26.0, "Sharp upper parapet opening physically recessed")
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w147478374"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 9, "Mapped footprint available: " + id)
		for grid in [false, true]:
			var curve: Curve3D = Chicago.route_curve(grid)
			var nearest = INF
			for station in range(0, ceili(curve.get_baked_length())):
				var p = curve.sample_baked(station, true)
				var pos = Vector2(p.x, p.z)
				if Geometry2D.is_point_in_polygon(pos, ring):
					nearest = 0
				for i in ring.size():
					nearest = minf(
						nearest,
						pos.distance_to(
							Geometry2D.get_closest_point_to_segment(pos, ring[i], ring[(i + 1) % ring.size()])
						)
					)
			print("SHARP CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(is_finite(nearest) and nearest > 8, "Both routes clear foundation: " + id + " " + str(grid))
	var door = first_hit(
		exterior, Vector3(-35, 1.5, -8.4875), Vector3(-20, 1.5, -8.4875), "Sharp recessed blue grey panes"
	)
	check(door != Vector3.INF and door.x > -25.8, "Sharp paired northern entry door physically recessed")
	var lower_glass = first_hit(
		exterior, Vector3(-35, .5, -8.4875), Vector3(-20, .5, -8.4875), "Sharp recessed blue grey panes"
	)
	var lower_visible = first_hit(exterior, Vector3(-35, .5, -8.4875), Vector3(-20, .5, -8.4875))
	check(
		lower_glass != Vector3.INF and lower_visible.distance_to(lower_glass) < .01,
		"Sharp entrance lower leaf exposed without masonry spandrel"
	)
	holder.free()
	print("SHARP DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
