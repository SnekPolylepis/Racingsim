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
	var building = scenery.get_node("RelianceBuilding")
	check(building.position.distance_to(Vector3(-317.6, 8, 195.65)) < .01, "Historic footprint origin")
	check(absf(building.rotation.y - City.RELIANCE_YAW) < .0001, "Mapped north/east alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 8, "Eight authored materials")
	var bounds = exterior.get_aabb()
	print("RELIANCE BOUNDS ", bounds)
	check(bounds.position.x > -15 and bounds.end.x < 15, "Street-bay east/west envelope")
	check(bounds.position.z > -10.5 and bounds.end.z < 10.5, "Street-bay north/south envelope")
	check(absf(bounds.position.y) < .01, "Street base")
	check(absf(bounds.end.y - 60.96) < .05, "HABS architectural height")
	var north_bays = false
	var east_bay = false
	var diagonal_sash = false
	var lit = 0
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if "window glass" in mat.resource_name:
			var arrays = exterior.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				north_bays = north_bays or (vertex.z < -9.2 and absf(vertex.x) > 4)
				east_bay = east_bay or vertex.x > 13.6
			for normal in arrays[Mesh.ARRAY_NORMAL]:
				diagonal_sash = diagonal_sash or (absf(normal.x) > .2 and absf(normal.z) > .2)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Occupied panes light at night")
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Occupied panes stop emitting in daylight")
	check(north_bays and east_bay and diagonal_sash, "Projecting north/east bays include angled glass sash")
	check(lit == 1, "Selective occupancy material")
	var data = JSON.parse_string(FileAccess.get_file_as_string(City.DATA))
	var historic = false
	var neighbor = false
	for b in data.buildings:
		if b.get("o") == "w124865461":
			historic = b.k == "terracotta" and b.get("c") == "#ffffff"
		if b.get("o") == "w145625877":
			neighbor = b.k == "stone" and not b.has("c") and b.f.size() == 10
	check(historic and neighbor, "Corrected material attribution preserves larger neighboring footprint")
	asset.queue_free()
	await process_frame
	print("RELIANCE RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
