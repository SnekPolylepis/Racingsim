extends RefCounted
## The knock-over props of a track (REBUILD-PLAN.md P4-03, "props"): owns every PropBody, keeps the
## sleeping ones in a coarse grid so checking them against a car costs a few dictionary lookups per tick
## however many there are, and steps only the awake ones. Call after each car's step() and
## WallContact.step(), inside the physics frame:
##     props.step(dt, [car])      # returns the car-prop contact points this tick
## and props.sync_nodes() from the presentation side to pose the Props/ markers.
##
## A sleeping prop costs nothing unless a car's hull comes within its bounding sphere; then it wakes and
## is stepped until it has been still on the ground for PropBody.SLEEP_TICKS. Props do not collide with
## each other.

const PropBody = preload("res://scripts/props/prop_body.gd")
const WallQuery = preload("res://scripts/surface/wall_query.gd")
## Grid cell size for sleeping props, metres (a car hull's box spans one to four cells).
const CELL = 8.0
## Extra reach around a car's hull box when waking props, metres.
const WAKE_MARGIN = .05

var surface
## Any node in the physics world, for wall queries (null: no walls).
var wall_node = null
var queries = {}
var props = []
var awake = []
var grid = {}
## Largest prop bounding radius, for the grid lookups.
var reach = 0.0
## Whether every prop has been seated on the ground (done on the first step, inside the physics frame).
var seated = false
## Car-prop contact points in the last step.
var contacts = 0


func _init(ground, walls = null):
	surface = ground
	wall_node = walls


## Every node under the asset's Props/ with metadata "prop" (a kind in data/props.json) becomes a prop at
## the node's pose, and the node follows it (sync_nodes()).
static func from_asset(asset):
	var out = load("res://scripts/props/prop_set.gd").new(asset.surface(), asset)
	var root = asset.get_node_or_null("Props")
	if root != null:
		out.collect(root, asset)
	return out


## Props under `node`, posed in the asset's frame (the TrackAsset root sits at the origin, 5.3), so this
## works before the scene is in the tree.
func collect(node: Node, asset: Node3D):
	for child in node.get_children():
		if child is Node3D and child.has_meta("prop"):
			var rest = Transform3D.IDENTITY
			var n: Node = child
			while n != null and n != asset:
				if n is Node3D:
					rest = n.transform * rest
				n = n.get_parent()
			add(str(child.get_meta("prop")), rest, true, child)
		collect(child, asset)


## Add a prop of `kind` at rest pose `rest` (base frame). `seat`: snap it onto the ground under it on
## the first step (for authored placements); otherwise it starts awake where it is (a drop test).
func add(kind: String, rest: Transform3D, seat = true, node = null):
	var p = PropBody.new(kind, rest)
	p.node = node
	p.set_meta("seat", seat)
	props.append(p)
	reach = maxf(reach, p.radius)
	if wall_node != null and not queries.has(kind):
		queries[kind] = WallQuery.new(wall_node, p.box_half)
	if seated:
		settle(p)
	return p


## Everything back to its rest pose, asleep.
func reset():
	awake.clear()
	grid.clear()
	for p in props:
		p.place(p.home)
		p.set_meta("seat", true)
	seated = false


func cell(p) -> Vector2i:
	return Vector2i(floori(p.pos_x / CELL), floori(p.pos_z / CELL))


func sleep_in_grid(p):
	var key = cell(p)
	if not grid.has(key):
		grid[key] = []
	grid[key].append(p)


## First placement: seat on the ground (authored props) or wake (dropped props).
func settle(p):
	if p.get_meta("seat", true):
		seat(p)
		sleep_in_grid(p)
	else:
		p.wake()
		awake.append(p)


## Put a prop's base on the ground under it, upright on the local normal, keeping its heading.
func seat(p):
	var base = p.home.origin
	var hit = surface.contact(base + Vector3(0, 1.0, 0), Vector3.DOWN, 3.0, -1)
	if hit.is_empty():
		return
	var n: Vector3 = hit.normal
	var fwd: Vector3 = p.home.basis.x
	fwd = (fwd - n * fwd.dot(n)).normalized()
	var rest = Transform3D(Basis(fwd, n, fwd.cross(n)), hit.point)
	p.place(rest)


## One fixed tick: wake sleeping props a car's hull reaches, step the awake ones against the cars near
## them. Returns the number of car-prop contact points.
func step(dt: float, cars: Array) -> int:
	if not seated:
		seated = true
		for p in props:
			settle(p)
	contacts = 0
	if awake.is_empty() and grid.is_empty():
		return 0
	var boxes = []
	for car in cars:
		boxes.append(car_box(car))
	for i in cars.size():
		wake_near(cars[i], boxes[i])
	var still = []
	for p in awake:
		var near = []
		for i in cars.size():
			if sphere_in_box(p.pos, p.radius + WAKE_MARGIN, boxes[i]):
				near.append(cars[i])
		var hits = p.step(dt, surface, queries.get(p.kind), near)
		contacts += hits
		if p.asleep:
			if not p.lost:
				sleep_in_grid(p)
		else:
			still.append(p)
	awake = still
	if contacts > 0:
		for car in cars:
			car.sync_legacy()
	return contacts


## A car's swept hull as an axis-aligned box, [min, max]: the hull now, stretched back to where its
## centre was at the start of the tick (the tick's rotation moves a corner by millimetres).
func car_box(car) -> Array:
	var b: Basis = car.basis()
	var h: Vector3 = car.hull_half
	var off = b * car.hull_center
	var now = car.pos + off
	var then = Vector3(car.last_x, car.last_y, car.last_z) + off
	var e = b.x.abs() * h.x + b.y.abs() * h.y + b.z.abs() * h.z + Vector3.ONE * .01
	return [now.min(then) - e, now.max(then) + e]


static func sphere_in_box(c: Vector3, r: float, box: Array) -> bool:
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	return (
		c.x > lo.x - r
		and c.x < hi.x + r
		and c.y > lo.y - r
		and c.y < hi.y + r
		and c.z > lo.z - r
		and c.z < hi.z + r
	)


## Wake the sleeping props in the grid cells under a car's swept box whose bounding sphere it reaches.
func wake_near(car, box: Array):
	var pad = reach + WAKE_MARGIN
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	for gx in range(floori((lo.x - pad) / CELL), floori((hi.x + pad) / CELL) + 1):
		for gz in range(floori((lo.z - pad) / CELL), floori((hi.z + pad) / CELL) + 1):
			var key = Vector2i(gx, gz)
			if not grid.has(key):
				continue
			var list: Array = grid[key]
			for k in range(list.size() - 1, -1, -1):
				var p = list[k]
				if sphere_in_box(p.pos, p.radius + WAKE_MARGIN, box) and touches(car, p):
					list.remove_at(k)
					p.wake()
					awake.append(p)
			if list.is_empty():
				grid.erase(key)


## Whether the prop's bounding sphere reaches the car's hull box now (oriented).
static func touches(car, p) -> bool:
	var b = car.basis()
	var local = b.transposed() * (p.pos - (car.pos + b * car.hull_center))
	var h: Vector3 = car.hull_half
	var nearest = local.clamp(-h, h)
	return local.distance_to(nearest) < p.radius + WAKE_MARGIN


## Presentation: pose each moved prop's node (call from _process; the node's parent chain is identity
## below the TrackAsset root, which sits at the origin).
func sync_nodes():
	for p in props:
		if p.moved and p.node != null and p.node.is_inside_tree():
			p.node.global_transform = p.xform()
			p.moved = false


func awake_count() -> int:
	return awake.size()
