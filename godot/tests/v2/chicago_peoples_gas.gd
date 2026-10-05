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
	var building = scenery.get_node("PeoplesGas")
	var exterior = building.mesh
	print("PEOPLES NATIVE BOUNDS ", exterior.get_aabb())
	check(building.position.distance_to(Vector3(-45.2, 8, 544.15)) < .01, "Mapped Peoples Gas origin")
	check(absf(building.rotation.y - .022) < .0001, "Mapped Peoples Gas facade alignment")
	check(exterior.get_surface_count() == 10, "Ten imported authored surfaces")
	var bounds = exterior.get_aabb()
	check(bounds.position.y >= -8.01 and absf(bounds.end.y - 92) < .02, "Foundation and parapet height")
	# Includes physical Ionic capitals and carved roof masks outside the wall plane.
	check(bounds.size.x < 52.5 and bounds.size.z < 61.8, "Overhangs remain close to mapped envelope")
	var pane = first_hit(exterior, Vector3(40, 16.8, -.877), Vector3(20, 16.8, -.877))
	var pier = first_hit(exterior, Vector3(40, 16.8, 0), Vector3(20, 16.8, 0))
	check(
		pane != Vector3.INF and pier != Vector3.INF and pier.x - pane.x > .25,
		"Individual office glazing recessed behind stone piers"
	)
	var vestibule = first_hit(exterior, Vector3(40, 2.4, .6), Vector3(20, 2.4, .6))
	var jamb = first_hit(exterior, Vector3(40, 2.4, 1.5), Vector3(20, 2.4, 1.5))
	check(
		vestibule != Vector3.INF and jamb != Vector3.INF and jamb.x - vestibule.x > 1,
		"Clear entrance leads into actual recessed vestibule"
	)
	var court = first_hit(exterior, Vector3(0, 120, 0), Vector3(0, 0, 0))
	var roof = first_hit(exterior, Vector3(20, 120, 0), Vector3(20, 0, 0))
	check(
		court != Vector3.INF and roof != Vector3.INF and roof.y - court.y > 60, "Central light court is open"
	)
	var north = first_hit(exterior, Vector3(0, 120, -28), Vector3(0, 0, -28))
	check(north != Vector3.INF and roof.y - north.y > 60, "Smaller shared north light court is open")
	var names = {}
	var lit = 0
	var clear = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		names[mat.resource_name] = true
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if mat.resource_name.begins_with("Night"):
			lit += 1
			check(mat.has_meta("chicago_night") and not mat.emission_enabled, "Occupied panes start unlit")
		elif mat.resource_name.begins_with("Clear"):
			clear += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .2,
				"Entrance glazing remains transparent"
			)
	check(names.size() == 10 and lit == 1 and clear == 1, "Ten distinct authored materials")
	var column = first_hit(exterior, Vector3(40, 80, 2.3077), Vector3(20, 80, 2.3077))
	var wall = first_hit(exterior, Vector3(40, 80, 2.0), Vector3(20, 80, 2.0))
	check(
		column != Vector3.INF and wall != Vector3.INF and column.x - wall.x > .15,
		"Upper engaged column projects from wall"
	)
	var lion = first_hit(exterior, Vector3(40, 90.75, 2.3077), Vector3(20, 90.75, 2.3077))
	var frieze = first_hit(exterior, Vector3(40, 90.75, 0), Vector3(20, 90.75, 0))
	check(
		lion != Vector3.INF and frieze != Vector3.INF and lion.x - frieze.x > .3,
		"Carved roof mask projects from solid frieze"
	)
	for on in [true, false]:
		Night.set_night(asset, on)
		var correct = true
		for surface in exterior.get_surface_count():
			var mat = exterior.surface_get_material(surface)
			if mat.has_meta("chicago_night"):
				correct = correct and mat.emission_enabled == on
		check(correct, "Peoples Gas occupied-window night toggle " + str(on))
	asset.queue_free()
	await process_frame
	print("PEOPLES RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
