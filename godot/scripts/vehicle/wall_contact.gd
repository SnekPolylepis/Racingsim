extends RefCounted
## Car-vs-wall contact for the 6-DOF CarBody (REBUILD-PLAN.md P4-03), applied after CarBody.step() with
## a WallQuery (scripts/surface/wall_query.gd) inside the physics frame. The 3D successor of the planar
## scripts/collisions.gd, whose per-kind response it keeps:
##   1. Sweep: the hull box travels from the pose at the start of the tick to the pose now; if a wall
##      is in the way, the car stops at the first touch. 300 km/h is 0.35 m per tick, more than a
##      0.15 m armco rail, so a pose-only test could step through it.
##   2. Push-out: any remaining penetration (from rotation during the tick) is removed along the wall
##      normal.
##   3. Impulses at each contact point, with the car's full 3D inertia: restitution on the closing
##      speed, and sliding friction up to mu times the normal impulse. A few sequential passes so
##      several points of the hull share the load.
##   Simcade, as in collisions.gd: the closing speed is removed without bounce, then the car keeps
##   `contact_speed_retention` of its speed and `contact_yaw_retention` of its yaw rate per tick in
##   contact.
## Walls are layer 2 only (TrackAsset contract), so suspension rays never see them.

## [restitution, friction] per wall kind, as collisions.gd (tyre walls absorb, concrete and armco bounce).
const RESPONSE = {"tyre": [.08, .8], "armco": [.25, .6], "concrete": [.25, .6]}
const PASSES = 4
## Closing speed below which a contact does not bounce, m/s.
const BOUNCE_SPEED = .5
## Stop this far short of the first touch along the swept motion, metres.
const SKIN = .002


## Resolve the car against the walls; returns the number of contact points (0 = clear).
static func step(car, query) -> int:
	var b = car.basis()
	var now = car.pos + b * car.hull_center
	var start_b = Basis(car.last_rot)
	var start = Vector3(car.last_x, car.last_y, car.last_z) + start_b * car.hull_center
	var motion = now - start
	var travel = motion.length()
	var fraction = query.sweep(Transform3D(b, start), motion)
	if fraction < 1.0:
		# Back the car up to where the hull first touched (less a skin), keeping its 64-bit position.
		var keep = maxf(0.0, fraction - SKIN / maxf(travel, 1e-6))
		var back = motion * (1.0 - keep)
		car.pos_x -= back.x
		car.pos_y -= back.y
		car.pos_z -= back.z
	var cs = query.contacts(Transform3D(b, car.pos + b * car.hull_center))
	if cs.is_empty():
		return 0
	# Push out of the deepest penetration along its normal.
	var deepest = cs[0]
	if deepest.depth > 0:
		var n0: Vector3 = deepest.normal
		car.pos_x += n0.x * deepest.depth
		car.pos_y += n0.y * deepest.depth
		car.pos_z += n0.z * deepest.depth
	var resp = RESPONSE.get(deepest.kind, RESPONSE.concrete)
	if car.simcade_enabled:
		arcade(car, cs)
	else:
		for pass_i in PASSES:
			for c in cs:
				hit(car, c.point, c.normal, resp[0], resp[1])
	car.collided = true
	car.sync_legacy()
	return cs.size()


## One contact impulse at world point `at`, wall normal `n` (toward the car).
static func hit(car, at: Vector3, n: Vector3, bounce: float, friction: float):
	var r = at - car.pos
	var w = car.basis() * car.ang
	var v = car.vel + w.cross(r)
	var vn = v.dot(n)
	if vn >= 0:
		return
	var k = 1.0 / car.p.mass + n.dot(car.inverse_inertia_world(r.cross(n)).cross(r))
	# No bounce for a slow touch: a car leaning on a wall would otherwise buzz off it every tick.
	var e = bounce if -vn > BOUNCE_SPEED else 0.0
	var j = -(1.0 + e) * vn / k
	car.apply_impulse(at, n * j)
	# Sliding friction against the wall, up to mu j, never reversing the slide.
	w = car.basis() * car.ang
	v = car.vel + w.cross(r)
	var vt = v - n * v.dot(n)
	var slide = vt.length()
	if slide < 1e-6:
		return
	var t = vt / slide
	var kt = 1.0 / car.p.mass + t.dot(car.inverse_inertia_world(r.cross(t)).cross(r))
	var jt = minf(slide / kt, friction * j)
	car.apply_impulse(at, -t * jt)


## Simcade's arcade contact: no bounce, closing speed removed, speed and yaw rate bled per tick.
static func arcade(car, cs):
	var n: Vector3 = cs[0].normal
	var closing = car.vel.dot(n)
	if closing < 0:
		car.vel = car.vel - n * closing
		car.vel = car.vel * car.simcade.contact_speed_retention
		car.ang.y *= car.simcade.contact_yaw_retention
