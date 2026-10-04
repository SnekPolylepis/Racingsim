extends SceneTree
const Chicago = preload("res://trackgen/chicago.gd")
const City = preload("res://trackgen/chicago_city.gd")
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


func run():
	var asset = Node3D.new()
	root.add_child(asset)
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	Chicago.add_loop_landmarks(asset, scenery)
	var building = scenery.get_node("MonadnockBuilding")
	check(building.position.distance_to(Vector3(-426.9, 8, 808.275)) < .01, "Historic block origin")
	check(absf(building.rotation.y - .0246) < .0001, "Mapped block alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 9, "Nine surfaces from eight authored materials")
	var bounds = exterior.get_aabb()
	print("MONADNOCK BOUNDS ", bounds)
	check(bounds.position.x > -12 and bounds.end.x < 12, "Narrow mapped block width")
	check(bounds.position.z > -63 and bounds.end.z < 63, "Full mapped block length")
	check(absf(bounds.position.y) < .01, "Street base")
	check(absf(bounds.end.y - 66.152) < .05, "HABS 215-foot masonry top plus modeled skylight")
	var north_bays = false
	var south_bays = false
	var angled_glass = false
	var lit = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if "office glass" in mat.resource_name:
			var arrays = exterior.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				north_bays = north_bays or (vertex.z < 0 and absf(vertex.x) > 10.3 and vertex.y > 10)
				south_bays = south_bays or (vertex.z > 0 and absf(vertex.x) > 10.3 and vertex.y > 10)
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				angled_glass = angled_glass or (absf(normal.x) > .2 and absf(normal.z) > .2)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Occupied windows light at night")
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops window emission")
	check(north_bays and south_bays and angled_glass, "Both building halves have projecting angled glazing")
	check(lit == 1, "Selective occupied-window material")
	asset.queue_free()
	await process_frame
	print("MONADNOCK RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
