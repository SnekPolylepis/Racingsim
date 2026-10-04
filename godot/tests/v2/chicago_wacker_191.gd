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
	var building = scenery.get_node("Wacker191")
	check(building.position.distance_to(Vector3(-1001.2, 8, -63.55)) < .01, "Mapped 191 Wacker origin")
	check(absf(building.rotation.y - .0202) < .0001, "Mapped Wacker alignment")
	var exterior = building.mesh
	check(exterior.get_surface_count() == 10, "Ten authored materials")
	var bounds = exterior.get_aabb()
	print("WACKER191 BOUNDS ", bounds)
	check(bounds.position.x > -23 and bounds.end.x < 23, "Tower and entrance envelope")
	check(bounds.position.z > -28 and bounds.end.z < 28, "Mapped north/south envelope")
	check(absf(bounds.position.y) < .01, "Street base")
	check(absf(bounds.end.y - 157.4) < .08, "Published architectural top")
	var lit = 0
	var transparent = 0
	var inner_bounds = AABB()
	var outer_bounds = AABB()
	var mullions = false
	for surface in exterior.get_surface_count():
		var mat = exterior.surface_get_material(surface)
		check(mat.albedo_texture == null, "No facade photograph: " + mat.resource_name)
		if "curtain glass" in mat.resource_name or "spandrels" in mat.resource_name:
			check(mat.metallic_specular < .2 and mat.roughness >= .3 and mat.metallic < .1,
				"Restrained dielectric glass highlights")
		var arrays = exterior.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var surface_bounds = AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			surface_bounds = surface_bounds.expand(vertex)
		if "solid inner" in mat.resource_name:
			inner_bounds = surface_bounds
		if "lantern sleeve" in mat.resource_name:
			outer_bounds = surface_bounds
		if "mullions" in mat.resource_name:
			mullions = vertices.size() > 1000 and surface_bounds.end.y > 157
		if mat.resource_name.begins_with("Clear"):
			transparent += 1
			check(
				mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a < .4,
				"Clear glazing preserves modeled parts behind it"
			)
		if mat.has_meta("chicago_night"):
			lit += 1
			Night.set_night(asset, true)
			check(mat.emission_enabled, "Night emission: " + mat.resource_name)
			Night.set_night(asset, false)
			check(not mat.emission_enabled, "Daylight stops emission: " + mat.resource_name)
	check(lit == 2, "Office occupancy and lantern toggle separately")
	check(transparent == 2, "Separate clear lantern and lobby materials")
	check(
		outer_bounds.encloses(inner_bounds) and outer_bounds.size.z > inner_bounds.size.z + 2,
		"Transparent lantern sleeve encloses a distinct solid volume"
	)
	check(mullions, "Physical tower mullions and lantern frame")
	asset.queue_free()
	await process_frame
	print("WACKER191 RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
