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
	var fixture = scenery.get_node("Block37")
	var exterior = fixture.mesh
	check(fixture.position.distance_to(Vector3(-357.2, 8, 104.25)) < .01, "Mapped compound origin")
	var bounds = exterior.get_aabb()
	print("BLOCK37 BOUNDS ", bounds)
	check(exterior.get_surface_count() == 7, "Seven physical exterior materials")
	check(bounds.position.x > -52 and bounds.end.x < 52, "Retained east west envelope")
	check(bounds.position.z > -61 and bounds.end.z < 61, "Retained north south envelope")
	check(absf(bounds.position.y + 8) < .01, "Retained buried foundation")
	check(absf(bounds.end.y - 130) < .02, "Provisional residential tower roof")
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "Original physical geometry: " + mat.resource_name)
		if mat.resource_name.begins_with("Night"):
			check(mat.has_meta("chicago_night"), "Occupied panes carry night flag")
			Night.set_night(holder, false)
			check(not mat.emission_enabled, "Day extinguishes occupied panes")
			Night.set_night(holder, true)
			check(mat.emission_enabled, "Night enables occupied panes")
	for probe in [[Vector3(0, 150, -44), 130.0], [Vector3(-10, 100, 40), 80.0], [Vector3(25, 40, 15), 26.0]]:
		var hit = first_hit(exterior, probe[0], probe[0] - Vector3.UP * 150)
		check(hit != Vector3.INF and absf(hit.y - probe[1]) < .02, "Separate roof tier " + str(probe[1]))
	check(not Clip._overhead("Scenery/Block37", 120, 3.4288), "Compound has no clipping exemption")
	var city = JSON.parse_string(FileAccess.get_file_as_string("res://trackgen/data/chicago/city.json"))
	for id in ["w124865494"]:
		var ring = PackedVector2Array()
		for entry in city.buildings:
			if entry.get("o", "") == id:
				for p in entry.f:
					ring.append(Vector2(p[0], p[1]))
		check(ring.size() == 14, "Mapped footprint available: " + id)
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
			print("BLOCK37 CLEARANCE ", id, " grid=", grid, " distance=", nearest)
			check(is_finite(nearest) and nearest > 8, "Both routes clear foundation: " + id + " " + str(grid))
	print("BLOCK37 RESULTS ", {"checks": checks, "failures": failures})
	holder.free()
	quit(0 if failures.is_empty() else 1)
