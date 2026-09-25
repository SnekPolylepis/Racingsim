extends SceneTree
## Look-12: car particle effects (scripts/particles.gd) against a stand-in car. Nothing emits while the
## tyres grip; sliding on tarmac smokes; grass and gravel throw debris that falls; wall and body contacts
## spark; a high-rpm lift backfires; the pool recycles without overflow. `-- --shots` (windowed) also
## captures each effect to user://particle-shots/.
const Particles = preload("res://scripts/particles.gd")
var checks = 0
var failures = []


class StubCar:
	extends RefCounted
	var speed = 30.0
	var vel = Vector3(30, 0, 0)
	var pos = Vector3(0, 0.5, 0)
	var wheels = []
	var contact_hits = []
	var wall_hits = []
	var scrape_hits = []
	var input = {"throttle": 1.0}
	var gear = 3
	var rpm = 3000.0
	var p = {"redline": 7000.0, "b": 1.2}
	var setup = {"cgHeight": 0.5}

	func _init(surface: int, sliding: bool):
		for i in 4:
			var slip = 0.3 if sliding else 0.02
			wheels.append({"skidding": sliding, "slipAngle": slip, "slipRatio": 0.0})
			var at = Vector3(1.2 if i < 2 else -1.2, 0.0, -0.75 if i % 2 == 0 else 0.75)
			contact_hits.append({"point": at, "normal": Vector3.UP, "surface": surface})

	func basis():
		return Basis.IDENTITY

	func peak_slip_angle():
		return 0.12

	func peak_slip_ratio():
		return 0.12


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func run(fx, car, seconds: float) -> void:
	for f in int(seconds * 60):
		fx.update_car(car, 1.0 / 60.0)


func fresh():
	var fx = Particles.new()
	root.add_child(fx)
	return fx


func _initialize():
	var atlas = load("res://assets/particles/particle_atlas.png")
	check(atlas is Texture2D, "the Kenney particle atlas loads")
	var mapped = {}
	for effect in Particles.EFFECT_FRAMES:
		var frame = Particles.EFFECT_FRAMES[effect]
		mapped[frame] = true
		check(frame >= 0 and frame < 8, "%s maps to a valid atlas frame" % effect)
	check(mapped.size() == 8, "each particle effect uses a distinct atlas frame")
	var fx = fresh()
	run(fx, StubCar.new(0, false), 1.0)
	check(fx.live_count() == 0, "gripping tyres on tarmac emit nothing")
	run(fx, StubCar.new(0, true), 1.0)
	var smoke = fx.live_count()
	check(
		smoke > 30 and fx.glow.visible_instance_count == 0,
		"sliding tyres smoke (%d puffs, soft layer)" % smoke
	)
	check(fx.frame[fx.cursor - 1] == Particles.EFFECT_FRAMES.smoke, "tyre smoke selects its atlas frame")
	fx.queue_free()

	fx = fresh()
	var grass = StubCar.new(2, false)
	run(fx, grass, 0.2)
	var n = fx.live_count()
	check(n > 5, "grass at speed throws clods (%d)" % n)
	check(fx.frame[fx.cursor - 1] == Particles.EFFECT_FRAMES.grass, "grass selects its atlas frame")
	fx.queue_free()

	fx = fresh()
	var gravel = StubCar.new(3, false)
	run(fx, gravel, 0.3)
	var peak = -INF
	var dust_frames = 0
	for i in fx.POOL:
		if fx.age[i] < fx.life[i] and fx.gravity[i] > 1.0:
			peak = maxf(peak, fx.vel[i].y)
		if fx.age[i] < fx.life[i] and fx.frame[i] == Particles.EFFECT_FRAMES.dust:
			dust_frames += 1
	gravel.speed = 0.0
	gravel.vel = Vector3.ZERO
	run(fx, gravel, 0.6)
	var falling = 0
	for i in fx.POOL:
		if fx.age[i] < fx.life[i] and fx.gravity[i] > 1.0 and fx.vel[i].y < 0.0:
			falling += 1
	check(peak > 1.0 and falling > 0, "gravel stones fly up and fall back (%d falling)" % falling)
	check(dust_frames > 0, "gravel dust selects its atlas frame")
	fx.queue_free()

	fx = fresh()
	var wall = StubCar.new(0, false)
	wall.wall_hits = [
		{"point": Vector3(0, 0.4, 1.0), "normal": Vector3(0, 0, -1), "kind": "armco", "depth": 0.01}
	]
	run(fx, wall, 0.2)
	check(fx.glow.visible_instance_count > 5, "wall contact sparks (%d)" % fx.glow.visible_instance_count)
	check(fx.frame[fx.cursor - 1] == Particles.EFFECT_FRAMES.sparks, "wall sparks select their atlas frame")
	fx.queue_free()

	fx = fresh()
	var scrape = StubCar.new(0, false)
	scrape.scrape_hits = [[Vector3(0, 0, 0), 12.0]]
	run(fx, scrape, 0.2)
	check(fx.glow.visible_instance_count > 5, "body scrape sparks")
	var scrape_sparks = false
	var scrape_flash = false
	for i in fx.POOL:
		if fx.age[i] >= fx.life[i]:
			continue
		scrape_sparks = scrape_sparks or fx.frame[i] == Particles.EFFECT_FRAMES.scrape
		scrape_flash = scrape_flash or fx.frame[i] == Particles.EFFECT_FRAMES.scorch
	check(scrape_sparks and scrape_flash, "body scrape sparks and flash select their atlas frames")
	fx.queue_free()

	fx = fresh()
	var lift = StubCar.new(0, false)
	lift.rpm = 6500.0
	var flames = 0
	for k in 8:
		lift.input = {"throttle": 1.0}
		fx.update_car(lift, 1.0 / 60.0)
		lift.input = {"throttle": 0.0}
		fx.update_car(lift, 1.0 / 60.0)
		flames = maxi(flames, fx.glow.visible_instance_count)
	check(flames > 0, "a high-rpm lift backfires")
	fx.queue_free()

	fx = fresh()
	for k in 3 * fx.POOL:
		fx.emit(Vector3.ZERO, Vector3.UP, 5.0, 0.1, 0.1, Color.WHITE, 0.0, 0.0, k % 2 == 0, k % 8)
	fx.advance(0.016)
	check(
		(
			fx.live_count() == fx.POOL
			and fx.soft.visible_instance_count + fx.glow.visible_instance_count == fx.POOL
		),
		"the pool recycles without overflow"
	)
	fx.advance(10.0)
	check(fx.live_count() == 0 and fx.soft.visible_instance_count == 0, "particles expire")
	fx.queue_free()

	if "--shots" in OS.get_cmdline_user_args():
		await shots()
	print("PARTICLES RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


## Windowed: each effect in a small lit scene, saved as PNGs.
func shots():
	DirAccess.make_dir_recursive_absolute("user://particle-shots")
	var scene = Node3D.new()
	root.add_child(scene)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	ground.material_override = mat
	scene.add_child(ground)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	scene.add_child(sun)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.8)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	scene.add_child(env)
	var cam = Camera3D.new()
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(-6, 2.0, 4.5), Vector3(0, 0.6, 0))
	cam.make_current()
	for case in [["smoke", 0, true], ["grass", 2, false], ["gravel", 3, true], ["sparks", 0, false]]:
		var fx = Particles.new()
		scene.add_child(fx)
		var car = StubCar.new(case[1], case[2])
		car.vel = Vector3(-25, 0, 0)
		if case[0] == "sparks":
			car.wall_hits = [
				{"point": Vector3(0, 0.4, 1.0), "normal": Vector3(0, 0, -1), "kind": "armco", "depth": 0.01}
			]
		for f in 60:
			fx.update_car(car, 1.0 / 60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://particle-shots/%s.png" % case[0])
		fx.queue_free()
		await process_frame
	scene.queue_free()
