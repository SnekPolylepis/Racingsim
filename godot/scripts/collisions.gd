extends RefCounted
## Planar contact solver applied after Car.step and before Race.update.
## Wall/tire segments and cones use simulation XY coordinates; height does not separate contacts.
## Mutates car velocities/contact flag and cone runtime position/velocity.


static func impulse(car, point, normal, bounce, friction):
	if car.simcade_enabled:
		var velocity = Vector2(car.vx, car.vy)
		var closing = velocity.dot(normal)
		if closing < 0:
			velocity -= normal * closing
			velocity *= car.simcade.contact_speed_retention
			car.vx = velocity.x
			car.vy = velocity.y
			car.r *= car.simcade.contact_yaw_retention
		return
	var offset = point - Vector2(car.x, car.y)
	var velocity = Vector2(car.vx - car.r * offset.y, car.vy + car.r * offset.x)
	var vn = velocity.dot(normal)
	if vn >= 0:
		return
	var rn = offset.cross(normal)
	var j = -(1 + bounce) * vn / (1 / car.p.mass + rn * rn / car.p.izz)
	car.vx += j * normal.x / car.p.mass
	car.vy += j * normal.y / car.p.mass
	car.r += j * rn / car.p.izz
	var tangent = Vector2(-normal.y, normal.x)
	var rt = offset.cross(tangent)
	velocity = Vector2(car.vx - car.r * offset.y, car.vy + car.r * offset.x)
	var jt = clampf(
		-velocity.dot(tangent) / (1 / car.p.mass + rt * rt / car.p.izz), -friction * j, friction * j
	)
	car.vx += jt * tangent.x / car.p.mass
	car.vy += jt * tangent.y / car.p.mass
	car.r += jt * rt / car.p.izz


static func step(car, track, dt):
	var hl = (car.p.a + car.p.b) / 2 + .35
	var hw = car.p.track / 2 + .12
	var center = Vector2(car.x, car.y) + Vector2(cos(car.h), sin(car.h)) * (car.p.a - car.p.b) / 2
	var points = []
	for v in [
		Vector2(hl, -hw),
		Vector2(hl, 0),
		Vector2(hl, hw),
		Vector2(0, hw),
		Vector2(-hl, hw),
		Vector2(-hl, 0),
		Vector2(-hl, -hw),
		Vector2(0, -hw)
	]:
		points.append(center + v.rotated(car.h))
	for o in track.data.objects:
		if o.type == "cone":
			var local = (Vector2(o.x, o.y) - center).rotated(-car.h)
			var closest = local.clamp(Vector2(-hl, -hw), Vector2(hl, hw))
			var delta = local - closest
			if delta.length() < .3:
				var n = (delta.normalized() if delta.length() > .0001 else Vector2(1, 0)).rotated(car.h)
				var vel = Vector2(car.vx, car.vy)
				var shove = n * (absf(vel.dot(n)) + 2) + vel * .5
				o.vx = o.get("vx", 0.0) + shove.x
				o.vy = o.get("vy", 0.0) + shove.y
				o.x += n.x * (.32 - delta.length())
				o.y += n.y * (.32 - delta.length())
				car.vx *= .999
				car.vy *= .999
			o.x += o.get("vx", 0.0) * dt
			o.y += o.get("vy", 0.0) * dt
			o.vx = o.get("vx", 0.0) * maxf(0, 1 - 4 * dt)
			o.vy = o.get("vy", 0.0) * maxf(0, 1 - 4 * dt)
			continue
		segment(car, o, points, center, hl, hw, true)
	# Derived trackside barriers: only the grid cells around the car; chained, so no endpoint test.
	for i in track.barriers_near(car.x, car.y):
		segment(car, track.barriers[i], points, center, hl, hw, false)


## Planar contact of the car's eight hull points (and optionally the segment endpoints) with one barrier.
static func segment(car, o, points, center, hl, hw, endpoints):
	if (
		car.x < minf(o.x1, o.x2) - 4
		or car.x > maxf(o.x1, o.x2) + 4
		or car.y < minf(o.y1, o.y2) - 4
		or car.y > maxf(o.y1, o.y2) + 4
	):
		return

		# Auto barriers know which side the track is on: contact is one-sided, so a fast car that
		# crosses the barrier centreline within one tick is still pushed back toward the track.
	var a = Vector2(o.x1, o.y1)
	var b = Vector2(o.x2, o.y2)
	var thickness = .6 if o.type == "tire" else .35
	var bounce = .08 if o.type == "tire" else .25
	var friction = .8 if o.type == "tire" else .6
	# Auto barriers know which side the track is on: contact is one-sided, so a fast car that
	# crosses the barrier centreline within one tick is still pushed back toward the track.
	var facing = Vector2.ZERO
	if o.has("side"):
		facing = -float(o.side) * Vector2(-(b - a).y, (b - a).x).normalized()
	for point in points:
		var closest = Geometry2D.get_closest_point_to_segment(point, a, b)
		var delta = point - closest
		var distance = delta.length()
		if facing != Vector2.ZERO:
			var signed = delta.dot(facing)
			if signed < thickness and signed > -2.5 and absf(delta.dot(Vector2(facing.y, -facing.x))) < .01:
				car.x += facing.x * (thickness - signed) * .6
				car.y += facing.y * (thickness - signed) * .6
				impulse(car, point, facing, bounce, friction)
				car.collided = true
			continue
		if distance < thickness:
			var n = delta.normalized() if distance > .0001 else Vector2(-(b - a).y, (b - a).x).normalized()
			if distance <= .0001 and (Vector2(car.x, car.y) - a).dot(n) < 0:
				n = -n
			car.x += n.x * (thickness - distance) * .6
			car.y += n.y * (thickness - distance) * .6
			impulse(car, point, n, bounce, friction)
			car.collided = true
	for endpoint in [a, b] if endpoints else []:
		var local = (endpoint - center).rotated(-car.h)
		if absf(local.x) < hl and absf(local.y) < hw:
			var px = hl - absf(local.x)
			var py = hw - absf(local.y)
			var n = Vector2(-1 if local.x > 0 else 1, 0) if px < py else Vector2(0, -1 if local.y > 0 else 1)
			n = n.rotated(car.h)
			var pen = minf(px, py)
			car.x += n.x * pen
			car.y += n.y * pen
			impulse(car, endpoint, n, bounce, friction)
			car.collided = true
