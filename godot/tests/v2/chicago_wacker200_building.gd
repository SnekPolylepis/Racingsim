extends SceneTree
## Physical exterior and retained foundation clearance on both driving layouts.
const Chicago = preload("res://trackgen/chicago.gd")
const Clip = preload("res://tests/visual/clip_scan.gd")
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
	var fixture = scenery.get_node("Wacker200")
	var exterior = fixture.mesh
	check(fixture.position.distance_to(Vector3(-1076.05, 8, 641.75)) < .01, "Mapped 200 South Wacker origin")
	var bounds = exterior.get_aabb()
	print("WACKER200 BOUNDS ", bounds)
	check(exterior.get_surface_count() == 7, "Seven authored materials")
	check(bounds.position.x > -26 and bounds.end.x < 26, "Mapped east west envelope")
	check(bounds.position.z > -27 and bounds.end.z < 27, "Mapped north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Mapped foundation below street")
	check(absf(bounds.end.y - 154.3) < .02, "Provisional mapped coping height")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if "angled lobby glazing" in mat.resource_name:
			check(
				(
					mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
					and absf(mat.albedo_color.a - .18) < .001
				),
				"Lobby glazing exposes modeled interior"
			)
		check(mat.albedo_texture == null, "Physical 200 South Wacker without photo: " + mat.resource_name)
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		if mat.resource_name.begins_with("Night"):
			check(mat.has_meta("chicago_night"), "Integrated fixture carries night flag")
			Night.set_night(holder, false)
			check(not mat.emission_enabled, "Day extinguishes 200 South Wacker fixtures")
			Night.set_night(holder, true)
			check(mat.emission_enabled, "Night enables recessed 200 South Wacker fixtures")
	var roof = first_hit(exterior, Vector3(20, 160, 20), Vector3(20, 120, 20))
	check(roof != Vector3.INF and absf(roof.y - 122) < .02, "Lower triangular roof remains below taller mass")
	var canopy = first_hit(exterior, Vector3(25.3, 6, -20), Vector3(25.3, 3, -20))
	check(
		canopy != Vector3.INF and canopy.y > 4.1 and canopy.y < 4.4,
		"Suspended entrance canopy is physical geometry"
	)
	check(
		Clip._overhead("Scenery/RightBarrierFence5789/Posts", 8.4, 3.4288),
		"Upper street guardrail is deliberate overhead geometry"
	)
	check(
		not Clip._overhead("Scenery/RightBarrierFence5789/Posts", 2.5, 3.4288),
		"Low guardrail still fails clearance scan"
	)
	check(
		not Clip._overhead("Scenery/RightBarrierFence5789/Posts", 8.4, 8), "Street level guardrail not exempt"
	)
	check(not Clip._overhead("Scenery/Wacker200", 120, 3.4288), "200 South Wacker never exempt from clipping")
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w64888042"]:
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
				if p.x < -1100 or p.x > -700 or p.z < 550 or p.z > 950:
					continue
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
			print("WACKER200 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(is_finite(nearest) and nearest > 8, "Both routes clear foundation: " + id + " " + str(grid))
	print("WACKER200 RESULTS ", {"checks": checks, "failures": failures})
	holder.free()
	quit(0 if failures.is_empty() else 1)
