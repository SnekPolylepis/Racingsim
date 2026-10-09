extends SceneTree
## Millennium draft: physical glass/core visibility, opaque arcade and route clearance.
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
	var exterior = preload("res://scripts/track/prop_mesh.gd").mesh(
		"res://assets/chicago/landmarks/millennium_plaza.glb"
	)
	check(exterior.get_surface_count() == 8, "Millennium eight physical materials")
	check(absf(exterior.get_aabb().end.y - 121.9) < .02, "Millennium published tip envelope")
	var closed = true
	for i in 15:
		var x = -7.0 + i
		closed = closed and first_hit(exterior, Vector3(x, 2, 80), Vector3(x, 2, 0)) != Vector3.INF
	check(closed, "Millennium south arcade has no open rays at ground level")
	var corner = first_hit(
		exterior, Vector3(-7, 2, 80), Vector3(-7, 2, 0), "Millennium brown ribbed office panels"
	)
	check(corner != Vector3.INF, "Millennium opaque wall closes inset-core corner gap")
	for surface in exterior.get_surface_count():
		check(
			exterior.surface_get_material(surface).albedo_texture == null,
			"Millennium original physical material"
		)
	var visible_residential = first_hit(exterior, Vector3(1.7, 60, 80), Vector3(1.7, 60, 0))
	var residential_glass = first_hit(
		exterior, Vector3(1.7, 60, 80), Vector3(1.7, 60, 0), "Millennium recessed residential glass"
	)
	check(
		residential_glass != Vector3.INF and residential_glass.distance_to(visible_residential) < .01,
		"Residential glazing is ahead of opaque core"
	)
	# Offset from a radial rib: this ray checks glass visibility between the physical ribs.
	var dome_first = first_hit(exterior, Vector3(3.5, 140, 34), Vector3(3.5, 100, 34))
	var dome_glass = first_hit(
		exterior, Vector3(3.5, 140, 34), Vector3(3.5, 100, 34), "Millennium recessed residential glass"
	)
	check(
		dome_glass != Vector3.INF and dome_first.distance_to(dome_glass) < .01 and dome_glass.y > 119,
		"Pool dome has physical glass above the opaque roof"
	)
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w127107026"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 6, "Mapped footprint available: " + id)
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
			print("MILLENNIUM CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(
				is_finite(nearest) and nearest > 9.5, "Both routes clear foundation: " + id + " " + str(grid)
			)
	print("MILLENNIUM DRAFT RESULTS ", {"checks": checks, "failures": failures})
	quit(0 if failures.is_empty() else 1)
