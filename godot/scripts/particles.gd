extends Node3D
## Car particle effects (Look-12), presentation only: nothing here feeds back into physics.
##   Tyre smoke    a tyre sliding past its grip peak on tarmac or a kerb (the skid-mark test)
##   Grass         clods and a little dust from wheels on grass
##   Gravel        stones flung up and a dust cloud from wheels in a gravel trap
##   Sparks        wall contacts (CarBody.wall_hits) and the body scraping the ground (scrape_hits)
##   Backfire      a short exhaust flame on a lift-off or a shift at high rpm
## One CPU pool of camera-facing quads in two MultiMeshes: "soft" (alpha: smoke, dust, grass, gravel)
## and "glow" (additive: sparks, flames), so the whole system costs two draw calls.
const POOL = 700
## Surface ids (scripts/surface/surface_table.gd).
const TARMAC = [0, 1, 4]
const GRASS = 2
const GRAVEL = 3

var soft: MultiMesh
var glow: MultiMesh
var rng = RandomNumberGenerator.new()
## Per particle: position, velocity, age, life, start size, end size, colour, gravity, drag, layer (0 soft, 1 glow).
var pos = PackedVector3Array()
var vel = PackedVector3Array()
var age = PackedFloat32Array()
var life = PackedFloat32Array()
var size0 = PackedFloat32Array()
var size1 = PackedFloat32Array()
var col = PackedColorArray()
var gravity = PackedFloat32Array()
var drag = PackedFloat32Array()
var layer = PackedByteArray()
var cursor = 0
## Emission carried between frames, per wheel and effect, so rates don't depend on frame rate.
var owed = {}
var last_throttle = 0.0
var last_gear = 1
var night = false


func _init():
	rng.seed = 90210
	for arr in [pos, vel]:
		arr.resize(POOL)
	for arr in [age, life, size0, size1, gravity, drag]:
		arr.resize(POOL)
	col.resize(POOL)
	layer.resize(POOL)
	for i in POOL:
		life[i] = 0.0
		age[i] = 1.0
	soft = _layer("SoftParticles", false)
	glow = _layer("GlowParticles", true)


func _layer(title: String, additive: bool) -> MultiMesh:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = POOL
	mm.visible_instance_count = 0
	var mat = StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _puff(additive)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = false
	mat.disable_receive_shadows = true
	quad.material = mat
	var inst = MultiMeshInstance3D.new()
	inst.name = title
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The pool follows the car around, so bounds never cull it wrongly.
	inst.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(inst)
	return mm


## A soft round puff (smoke and dust) or a hard bright dot (sparks and flames), 32 px.
static func _puff(hard: bool) -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d = Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 0.6) if hard else a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func emit(
	at: Vector3,
	v: Vector3,
	lifetime: float,
	s0: float,
	s1: float,
	c: Color,
	g: float,
	dr: float,
	glow_layer: bool
) -> void:
	var i = cursor
	cursor = (cursor + 1) % POOL
	pos[i] = at
	vel[i] = v
	age[i] = 0.0
	life[i] = lifetime
	size0[i] = s0
	size1[i] = s1
	col[i] = c
	gravity[i] = g
	drag[i] = dr
	layer[i] = 1 if glow_layer else 0


func live_count() -> int:
	var n = 0
	for i in POOL:
		if age[i] < life[i]:
			n += 1
	return n


## Integrate and write both MultiMeshes. Dead particles are packed out of the visible range.
func advance(dt: float) -> void:
	var ns = 0
	var ng = 0
	for i in POOL:
		if age[i] >= life[i]:
			continue
		age[i] += dt
		if age[i] >= life[i]:
			continue
		var v = vel[i]
		v.y -= gravity[i] * dt
		v *= maxf(0.0, 1.0 - drag[i] * dt)
		vel[i] = v
		pos[i] += v * dt
		var t = age[i] / life[i]
		var size = lerpf(size0[i], size1[i], t)
		var c = col[i]
		c.a *= (1.0 - t) * minf(1.0, t * 12.0 + 0.4)
		var xf = Transform3D(Basis.from_scale(Vector3(size, size, size)), pos[i])
		if layer[i] == 1:
			glow.set_instance_transform(ng, xf)
			glow.set_instance_color(ng, c)
			ng += 1
		else:
			soft.set_instance_transform(ns, xf)
			soft.set_instance_color(ns, c)
			ns += 1
	soft.visible_instance_count = ns
	glow.visible_instance_count = ng


## Emit this frame's effects from the car's state, then integrate. `dt` is the render frame time.
func update_car(car, dt: float) -> void:
	if car == null or dt <= 0.0:
		return
	var speed = car.speed
	for i in car.wheels.size():
		var hit = car.contact_hits[i] if i < car.contact_hits.size() else {}
		if hit.is_empty():
			continue
		var w = car.wheels[i]
		var at: Vector3 = hit.point + hit.normal * 0.05
		var sid = int(hit.get("surface", 0))
		var sliding = (
			w.skidding
			and (absf(w.slipAngle) > car.peak_slip_angle() or absf(w.slipRatio) > car.peak_slip_ratio())
		)
		if sid in TARMAC and sliding and speed > 2.0:
			var excess = maxf(
				absf(w.slipAngle) / car.peak_slip_angle(), absf(w.slipRatio) / car.peak_slip_ratio()
			)
			for k in _count(
				"smoke%d" % i, clampf(excess - 0.9, 0.0, 2.0) * 22.0 * minf(speed / 15.0, 1.5), dt
			):
				var drift = car.vel * 0.12 + Vector3(_r(0.6), 0.6 + rng.randf() * 0.6, _r(0.6))
				var grey = 0.55 if night else 0.82
				emit(
					at + Vector3(_r(0.15), 0.1, _r(0.15)),
					drift,
					1.6 + rng.randf(),
					0.35,
					2.8,
					Color(grey, grey, grey, 0.38),
					-0.25,
					0.9,
					false
				)
		elif sid == GRASS and speed > 6.0:
			for k in _count("grass%d" % i, minf(speed / 20.0, 2.0) * 30.0, dt):
				var kick = -car.vel * 0.25 + Vector3(_r(1.5), 1.8 + rng.randf() * 2.2, _r(1.5))
				var green = (
					Color(0.24, 0.36, 0.12, 0.95) if rng.randf() < 0.7 else Color(0.33, 0.26, 0.16, 0.95)
				)
				emit(at, kick, 0.8 + rng.randf() * 0.5, 0.16, 0.12, green, 9.8, 0.4, false)
			if sliding:
				for k in _count("gdust%d" % i, 6.0, dt):
					emit(
						at,
						car.vel * 0.1 + Vector3(_r(0.4), 0.5, _r(0.4)),
						1.4,
						0.4,
						2.0,
						Color(0.46, 0.43, 0.33, 0.28),
						-0.2,
						1.0,
						false
					)
		elif sid == GRAVEL and speed > 3.0:
			for k in _count("stones%d" % i, minf(speed / 15.0, 2.5) * 26.0, dt):
				var fling = -car.vel * 0.3 + Vector3(_r(2.0), 2.2 + rng.randf() * 3.0, _r(2.0))
				var shade = 0.35 + rng.randf() * 0.25
				emit(
					at,
					fling,
					0.8 + rng.randf() * 0.5,
					0.06,
					0.05,
					Color(shade, shade * 0.95, shade * 0.85, 1.0),
					9.8,
					0.2,
					false
				)
			for k in _count("dust%d" % i, minf(speed / 15.0, 2.0) * 8.0, dt):
				emit(
					at + Vector3(0, 0.2, 0),
					car.vel * 0.15 + Vector3(_r(0.8), 0.7 + rng.randf(), _r(0.8)),
					2.2,
					0.6,
					3.5,
					Color(0.62, 0.55, 0.42, 0.3),
					-0.15,
					0.7,
					false
				)
	# Sparks: walls and body scrapes.
	var hits = []
	for c in car.wall_hits:
		hits.append(c.point)
	for s in car.scrape_hits:
		if s[1] > 3.0:
			hits.append(s[0])
	if not hits.is_empty() and speed > 4.0:
		for k in _count("sparks", minf(speed / 10.0, 4.0) * 110.0, dt):
			var at2: Vector3 = hits[rng.randi() % hits.size()]
			var v = car.vel * (0.3 + rng.randf() * 0.5) + Vector3(_r(3.0), 1.0 + rng.randf() * 3.0, _r(3.0))
			var c = Color(1.0, 0.62 + rng.randf() * 0.3, 0.25, 1.0)
			emit(at2, v, 0.3 + rng.randf() * 0.35, 0.16, 0.06, c, 9.8, 0.3, true)
	_backfire(car, dt)
	last_throttle = car.input.get("throttle", 0.0)
	last_gear = car.gear
	advance(dt)


## Lift-off or a gear change above 70 % of the redline: a short flame from the exhaust.
func _backfire(car, dt: float) -> void:
	var throttle = car.input.get("throttle", 0.0)
	var high = car.rpm > car.p.redline * 0.7
	var lift = last_throttle > 0.8 and throttle < 0.2
	if not high or not (lift or car.gear != last_gear):
		return
	if rng.randf() > 0.7:
		return
	var b = car.basis()
	var back = -b.x
	var exhaust = car.pos + b * Vector3(-(car.p.b + 0.75), 0.35 - car.setup.cgHeight, 0.0)
	for k in 10:
		var v = car.vel + back * (3.0 + rng.randf() * 4.0) + Vector3(_r(0.6), _r(0.4), _r(0.6))
		emit(
			exhaust,
			v,
			0.07 + rng.randf() * 0.06,
			0.22,
			0.08,
			Color(1.0, 0.5 + rng.randf() * 0.3, 0.15, 1.0),
			0.0,
			2.0,
			true
		)


## Whole particles due this frame at `rate` per second; the fraction carries to the next frame.
func _count(key: String, rate: float, dt: float) -> int:
	var due = owed.get(key, 0.0) + rate * dt
	var n = int(due)
	owed[key] = due - n
	return mini(n, 40)


func _r(spread: float) -> float:
	return (rng.randf() * 2.0 - 1.0) * spread
