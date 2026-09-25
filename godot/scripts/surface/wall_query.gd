extends RefCounted
## Car-vs-wall queries (REBUILD-PLAN.md P4-03) against a TrackAsset's Walls/ collision: physics-server
## shape queries on collision layer 2 only, so walls never answer suspension rays and the ground never
## answers wall queries. Like TrackSurface, it must be used inside a physics frame.
##
## The car's hull is a box. sweep() casts it along a tick's motion, so a car moving 0.35 m per tick
## (300 km/h) cannot step over a 0.15 m armco rail between ticks. contacts() returns the box's contact
## points with the walls at a pose, with the wall's outward normal and the penetration depth.

const WALL_LAYER = 2
## Contacts are gathered this far outside the hull too, so a car resting against a wall keeps its
## contact from tick to tick instead of flickering in and out.
const MARGIN = .02

var node
## The hull for sweeps, and the hull inflated by MARGIN for contacts: two shapes built once (resizing a
## shape per query rebuilds it in the physics server).
var box = BoxShape3D.new()
var wide = BoxShape3D.new()
var params = PhysicsShapeQueryParameters3D.new()
var near = PhysicsShapeQueryParameters3D.new()
var ray = PhysicsRayQueryParameters3D.new()
var warned = false


func _init(any_node_in_the_world: Node3D, half_extents: Vector3):
	node = any_node_in_the_world
	box.size = half_extents * 2
	wide.size = half_extents * 2 + Vector3.ONE * MARGIN * 2
	for q in [params, near]:
		q.collision_mask = 1 << (WALL_LAYER - 1)
		q.collide_with_bodies = true
		q.collide_with_areas = false
		q.margin = 0.0
	params.shape = box
	near.shape = wide
	ray.collision_mask = 1 << (WALL_LAYER - 1)
	ray.hit_back_faces = true
	ray.hit_from_inside = false


func space():
	if not Engine.is_in_physics_frame():
		if not warned:
			push_error("WallQuery used outside a physics frame; no wall contact is reported")
			warned = true
		return null
	return node.get_world_3d().direct_space_state


## Fraction of `motion` the hull can travel from `from` before touching a wall (1.0 when clear).
func sweep(from: Transform3D, motion: Vector3) -> float:
	var s = space()
	if s == null or motion.length_squared() < 1e-12:
		return 1.0
	params.transform = from
	params.motion = motion
	var fractions = s.cast_motion(params)
	return fractions[0] if fractions.size() > 0 else 1.0


## Contacts of the hull at `xform` (inflated by MARGIN) with the walls, deepest first:
## [{point (on the wall), normal (out of the wall, toward the car), depth (>= -MARGIN), kind}].
## Each contact carries its own wall's kind and that wall's face normal (F-P4-03-corners): in a corner
## the hull touches two walls at once, and one shared normal would push the car into the second wall.
func contacts(xform: Transform3D, max_results = 4) -> Array:
	var s = space()
	if s == null:
		return []
	near.transform = xform
	# intersect_shape is the cheap "anything here?" test and names the walls (1 µs); collide_shape gives
	# the points (40 µs), one call per wall body so every point knows which wall it is on. get_rest_info
	# would give a normal too, but costs 115 µs a call.
	var touching = s.intersect_shape(near, max_results)
	if touching.is_empty():
		return []
	var bodies = {}
	for hit in touching:
		if not bodies.has(hit.rid):
			bodies[hit.rid] = hit.collider
	var out = []
	for rid in bodies:
		var kind = "concrete"
		var body = bodies[rid]
		if body != null and body.has_meta("wall_kind"):
			kind = str(body.get_meta("wall_kind"))
		# With two or more walls touching, query one at a time (the others excluded).
		if bodies.size() > 1:
			var others = bodies.keys().filter(func(r): return r != rid)
			near.exclude = others
			ray.exclude = others
		var pairs = s.collide_shape(near, max_results)
		if pairs.size() < 2:
			continue
		# One face normal per wall, where it is deepest in the hull. A ray to every point would not do:
		# rays to points on a rail's top or end edge hit those faces, and a flat wall then pushes and
		# rubs the car along several directions at once.
		var deepest = 0
		var best = -INF
		for k in range(0, pairs.size() - 1, 2):
			var d = (pairs[k + 1] - pairs[k]).length()
			if d > best:
				best = d
				deepest = k
		var n = face_normal(s, xform.origin, pairs[deepest], pairs[deepest + 1])
		for k in range(0, pairs.size() - 1, 2):
			var on_car: Vector3 = pairs[k]
			var on_wall: Vector3 = pairs[k + 1]
			# Depth into the wall along its normal, measured on the unexpanded hull.
			var depth = (on_wall - on_car).dot(n) - MARGIN
			out.append({"point": on_wall, "normal": n, "depth": depth, "kind": kind})
	if bodies.size() > 1:
		near.exclude = []
		ray.exclude = []
	out.sort_custom(func(a, b): return a.depth > b.depth)
	return out


## The wall's face normal at a contact, pointing toward the car: a ray from the hull's centre to the
## wall point (4 µs). A pair's own direction is not the face normal for edge-on-edge contacts; it can
## point along the wall and brake the car against its direction of travel.
func face_normal(s, centre: Vector3, on_car: Vector3, on_wall: Vector3) -> Vector3:
	var dir = on_wall - centre
	ray.from = centre
	ray.to = on_wall + dir.normalized() * .25
	var face = s.intersect_ray(ray)
	var n: Vector3 = face.normal if not face.is_empty() else (on_wall - on_car).normalized()
	if n.dot(centre - on_wall) < 0:
		n = -n
	return n
