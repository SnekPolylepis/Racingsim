extends SceneTree
## Runtime optimization equivalence and repeatable microbenchmarks; no user saves or track bakes.
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackLights = preload("res://scripts/track/track_lights.gd")
const Instruments = preload("res://scripts/instruments.gd")
const NightGlow = preload("res://scripts/track/night_glow.gd")
var checks = 0
var failures = []
var timings = {}


func check(ok, label):
	checks += 1
	if not ok:
		failures.append(label)
	print("PASS " if ok else "FAIL ", label)


func _initialize():
	run.call_deferred()


func run():
	var asset = TrackAsset.new()
	for i in 1200:
		var angle = TAU * i / 1200.0
		asset.line.append(Vector3(200 * cos(angle), 8 * sin(angle * 2), 200 * sin(angle)))
		asset.line_s.append(asset.length)
		var next = TAU * (i + 1) / 1200.0
		asset.length += asset.line[-1].distance_to(
			Vector3(200 * cos(next), 8 * sin(next * 2), 200 * sin(next))
		)
	asset.line_s.append(asset.length)
	for hint in [-1, 0, 600, 1199]:
		for point in [Vector3(205, 2, 0), Vector3(-200, -3, 0), Vector3(0, 10, 195)]:
			var actual = asset.project(point, hint)
			var from = hint - 40 if hint >= 0 else 0
			var count = 81 if hint >= 0 else asset.line.size()
			var best = INF
			var index = -1
			for k in count:
				var i = posmod(from + k, asset.line.size())
				var foot = Geometry3D.get_closest_point_to_segment(
					point, asset.line[i], asset.line[(i + 1) % asset.line.size()]
				)
				var distance = point.distance_squared_to(foot)
				if distance < best:
					best = distance
					index = i
			check(
				actual.idx == index and absf(actual.distance - sqrt(best)) < 0.0001,
				"projection matches segment geometry, hint %d" % hint
			)
	var start = Time.get_ticks_usec()
	for i in 12000:
		asset.project(Vector3(205, 2, 0), 0)
	timings.projection_us = float(Time.get_ticks_usec() - start) / 12000
	var hud = Instruments.new()
	hud.app = {"track": null}
	var car = {"speed": 0.0, "input": {"throttle": 0.2, "brake": 0.3, "steer": -0.4}}
	start = Time.get_ticks_usec()
	for i in 12000:
		car.speed = float(i)
		hud.sample(car, 1.0 / 60)
	timings.telemetry_us = float(Time.get_ticks_usec() - start) / 12000
	var head = hud.get("sample_head")
	if head == null:
		head = 0
	check(hud.samples.size() == 600, "telemetry stays bounded to 600 samples")
	check(
		hud.samples[head][0] == 11400 and hud.samples[(head + 599) % 600][0] == 11999,
		"telemetry retains chronological endpoints after wrapping"
	)
	hud.reset()
	check(hud.samples.is_empty(), "telemetry reset clears history")
	hud.free()
	var lights = Node3D.new()
	lights.name = "Lights"
	asset.add_child(lights)
	root.add_child(asset)
	var heads = PackedVector3Array()
	for i in 1000:
		heads.append(Vector3(i * 2.0, 9, sin(i) * 20))
	lights.set_meta("lamp_heads", heads)
	var pool = TrackLights.make_pool(asset)
	for eye in [Vector3.ZERO, Vector3(800, 0, 0), Vector3(1998, 0, 0)]:
		TrackLights.update_pool(pool, asset, eye, true)
		var order = []
		for i in heads.size():
			order.append([heads[i].distance_squared_to(eye), i])
		order.sort_custom(func(a, b): return a[0] < b[0])
		var cutoff = sqrt(order[pool.size()][0])
		var matches = true
		for k in pool.size():
			var d = sqrt(order[k][0])
			var fade = clampf((cutoff - d) / 15.0, 0, 1) * (1.0 - smoothstep(90.0, 140.0, d))
			matches = (
				matches
				and pool[k].global_position == heads[order[k][1]]
				and is_equal_approx(pool[k].light_energy, 3.2 * fade)
			)
		check(matches, "lamp pool matches full nearest-distance sort at x=%d" % eye.x)
	start = Time.get_ticks_usec()
	for i in 500:
		TrackLights.update_pool(pool, asset, Vector3(1998, 0, 0), true)
	timings.lamp_pool_us = float(Time.get_ticks_usec() - start) / 500
	TrackLights.update_pool(pool, asset, Vector3.ZERO, false)
	check(pool.all(func(light): return not light.visible), "daytime hides every pooled lamp")
	var scenery = Node3D.new()
	scenery.name = "Scenery"
	asset.add_child(scenery)
	var shader = Shader.new()
	shader.code = "shader_type spatial; uniform bool afterhours = false; void fragment() { ALBEDO = vec3(afterhours ? 1.0 : 0.0); }"
	var materials = []
	for i in 2:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		materials.append(mat)
		var mesh = BoxMesh.new()
		mesh.material = mat
		for k in 5:
			var node = MeshInstance3D.new()
			node.mesh = mesh
			scenery.add_child(node)
		var multi = MultiMeshInstance3D.new()
		multi.multimesh = MultiMesh.new()
		multi.multimesh.mesh = mesh
		scenery.add_child(multi)
	NightGlow.set_night(asset, true)
	check(
		materials.all(func(mat): return mat.get_shader_parameter("afterhours") == true),
		"shared facade shaders toggle distinct materials and MultiMeshes on"
	)
	NightGlow.set_night(asset, false)
	check(
		materials.all(func(mat): return mat.get_shader_parameter("afterhours") == false),
		"facade deduplication resets between night toggles"
	)
	asset.free()
	print(
		"OPTIMIZATION RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "timings": timings})
	)
	quit(0 if failures.is_empty() else 1)
