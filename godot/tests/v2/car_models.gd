extends SceneTree
## Dedicated car builders keep the simulation pose contract and a bounded raster budget.
const Visuals = preload("res://scripts/visuals.gd")
var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS  " if ok else "FAIL  ") + label)


func _initialize():
	call_deferred("run")


func count_meshes(node):
	var tris = 0
	var draws = 0
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mesh = part.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			draws += 1
			var arrays = mesh.surface_get_arrays(i)
			var index_count = 0 if arrays[Mesh.ARRAY_INDEX] == null else arrays[Mesh.ARRAY_INDEX].size()
			tris += (index_count if index_count > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return {"tris": tris, "draws": draws}


func run():
	var cars = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	for key in ["roadster", "gt", "f296gt3"]:
		var v = Visuals.new()
		var model = v.make_car(cars[key])
		check(
			model.has("root") and model.has("body") and model.has("brakes") and model.has("wheel_r"),
			key + " model contract"
		)
		check(model.pivots.size() == 4 and model.spins.size() == 4, key + " animated wheels")
		check(is_equal_approx(model.wheel_r, cars[key].wheelR), key + " preset radius")
		for i in 4:
			check(
				is_equal_approx(model.pivots[i].position.x, cars[key].a if i < 2 else -cars[key].b),
				key + " axle " + str(i)
			)
			check(
				is_equal_approx(absf(model.pivots[i].position.z), cars[key].track * .5),
				key + " track " + str(i)
			)
		var budget = count_meshes(model.root)
		print("CAR MODEL ", key, " ", JSON.stringify(budget))
		check(budget.tris < 18000 and budget.draws < 200, key + " raster budget")
		check(
			model.root.find_children("TyreSidewallAndRim", "MeshInstance3D", true, false).size() == 4,
			key + " complete rims and sidewalls"
		)
		var lamps = []
		for ref in v.headlights:
			var lamp = ref.get_ref()
			if lamp is MeshInstance3D:
				lamps.append(lamp)
		check(lamps.size() >= 2, key + " night lamp clusters")
		v.set_time(true)
		check(lamps.all(func(lamp): return lamp.visible), key + " lamps light at night")
		v.set_time(false)
		check(lamps.all(func(lamp): return not lamp.visible), key + " lamps dim by day")
		var ghost = v.make_car(cars[key], true)
		check(ghost.root != null and ghost.pivots.size() == 4, key + " ghost contract")
		model.root.free()
		ghost.root.free()
	print("CAR_MODELS RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
