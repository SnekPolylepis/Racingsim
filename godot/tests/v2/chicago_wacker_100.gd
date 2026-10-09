extends SceneTree
## Wacker100 working exterior geometry, fixture and retained footprint clearance.
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
	var fixture = scenery.get_node("Wacker100")
	var exterior = fixture.mesh
	check(
		fixture.position.distance_to(Vector3(-1084.45, 8, 500)) < .01, "Wacker100 mapped production fixture"
	)
	var bounds = exterior.get_aabb()
	check(exterior.get_surface_count() == 6, "Wacker100 six original physical materials")
	check(absf(bounds.position.y + 8) < .01, "Wacker100 buried foundation")
	check(absf(bounds.end.y - 74.4) < .02, "Wacker100 CVU architectural height")
	check(bounds.position.x > -31 and bounds.end.x < 31, "Wacker100 retained east west bounds")
	check(bounds.position.z > -25 and bounds.end.z < 25, "Wacker100 retained north south bounds")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Wacker100 original geometry: " + mat.resource_name)
	var pane = first_hit(
		exterior, Vector3(40, 18, 3.5), Vector3(20, 18, 3.5), "Wacker100 recessed green grey panes"
	)
	check(pane != Vector3.INF, "Wacker100 east facade physical recessed glass")
	var visible = first_hit(exterior, Vector3(40, 18, 3.5), Vector3(20, 18, 3.5))
	check(
		pane != Vector3.INF and visible.distance_to(pane) < .01,
		"Wacker100 recessed glass exposed through coffer opening"
	)
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w124865451"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 4, "Mapped footprint available: " + id)
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
			print("WACKER100 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(is_finite(nearest) and nearest > 8, "Both routes clear foundation: " + id + " " + str(grid))
	holder.free()
	print("WACKER100 DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
