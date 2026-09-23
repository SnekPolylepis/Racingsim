extends RefCounted
## A light knock-over trackside prop (REBUILD-PLAN.md P4-03, "props"): a traffic cone, bollard or marker
## board as a small rigid body on our own fixed-tick integrator (D6), like CarBody but far simpler.
## What a kind looks like is data (data/props.json): a frustum or a box, mass, centre of mass, inertia,
## restitution, friction and drag area. PropSet (prop_set.gd) owns the props, sleeps and wakes them and
## decides which cars can touch which prop.
##
## Frames: the rest pose (`xform()`, the TrackAsset marker) has its origin at the centre of the base on the
## ground, +Y up. Dynamics are about the centre of mass `cg` above that. World position and velocity are
## 64-bit scalars (5.1), angular velocity is body frame (as CarBody).
##
## One tick (step()): gravity, drag and spin, then contacts found at the pose the tick starts from and
## solved on the velocity before the prop moves, so friction holds a prop still on a slope:
##   car     each hull point swept, relative to the car's hull box, from last tick's poses to now. A point
##           that ends inside the box meets the face it entered through (the car moves up to 0.23 m a
##           tick at 200 km/h, so the nearest face could be the wrong one). The front and rear faces
##           push along a normal raked up by NOSE_RAKE, standing for the slope from bumper to bonnet a
##           box does not have, so a struck cone is thrown up as well as ahead instead of being batted
##           along the road; car-body friction is CAR_FRICTION (plastic on paint). A prop lower than the
##           sills passes under the car; one that gets under them and rises (a board tipping over under
##           the nose) is pinched between the floor and the road, and the car rides up on it.
##   ground  one surface ray below the centre of mass gives the local ground plane (a prop is well under
##           a metre across); every hull point below it, or near enough to reach it this tick, is a
##           contact (speculative: a gap may close this tick but not be crossed, so nothing tunnels).
##   walls   after the move, WallQuery with the kind's bounding box: swept, then contact points, as
##           WallContact does for the car.
## Each group pushes the prop out of its deepest penetration (car first, ground after), then sequential
## impulses with accumulated clamping solve all contacts together: restitution on the closing speed (no
## bounce under BOUNCE_SPEED), Coulomb friction up to mu times the normal impulse. A car contact is a
## two-body impulse: the car takes the opposite of what the prop takes, at the same point, with its full
## mass and world inverse inertia (CarBody.apply_impulse's arithmetic), so momentum is conserved.

const KINDS = "res://data/props.json"
const G = 9.81
const AIR_DENSITY = 1.22
## Hull points on a frustum's base ring, and on each ring up its side.
const RING = 8
const SIDE_RING = 6
## Closing speed below which a contact does not bounce, m/s.
const BOUNCE_SPEED = 1.0
## The car hull's front and rear faces push props along a normal raked up this far (radians): a real
## nose slopes back from the bumper to the bonnet, which the hull box does not.
const NOSE_RAKE = deg_to_rad(25.0)
## Friction between a prop and a car's body (plastic on paint).
const CAR_FRICTION = .35
## Sequential impulse passes over all of a prop's contacts.
const PASSES = 4
## Contacts are kept this far outside a surface too, so a resting prop keeps them from tick to tick.
const MARGIN = .002
## Asleep after SLEEP_TICKS slower than SLEEP_SPEED (m/s) and SLEEP_SPIN (rad/s) on the ground.
const SLEEP_TICKS = 120
const SLEEP_SPEED = .05
const SLEEP_SPIN = .2
## Spin is capped (rad/s) so one tick never turns a prop more than ~0.2 rad.
const MAX_SPIN = 50.0
## A prop this far below its rest pose has left the world; it stops for good.
const LOST_DROP = 200.0

static var kinds_cache = {}

var kind = ""
var spec = {}
var mass = 1.0
## Principal inertia about the centre of mass, body frame (kg m^2).
var inertia = Vector3.ONE
## Height of the centre of mass above the base, metres.
var cg = 0.0
## Hull points relative to the centre of mass, body frame.
var points = PackedVector3Array()
## Bounding box (relative to the centre of mass) and bounding sphere radius about it.
var box_center = Vector3.ZERO
var box_half = Vector3.ONE
var radius = 1.0
var restitution = .3
var friction = .6
var drag_area = .1

var pos_x = 0.0
var pos_y = 0.0
var pos_z = 0.0
var vel_x = 0.0
var vel_y = 0.0
var vel_z = 0.0
var pos: Vector3:
	get:
		return Vector3(pos_x, pos_y, pos_z)
	set(value):
		pos_x = value.x
		pos_y = value.y
		pos_z = value.z
var vel: Vector3:
	get:
		return Vector3(vel_x, vel_y, vel_z)
	set(value):
		vel_x = value.x
		vel_y = value.y
		vel_z = value.z
var rot = Quaternion.IDENTITY
var ang = Vector3.ZERO
## Pose at the start of the last step, for the car and wall sweeps.
var last_x = 0.0
var last_y = 0.0
var last_z = 0.0
var last_rot = Quaternion.IDENTITY
## Rest pose (base frame) it started from, for reset().
var home = Transform3D.IDENTITY
var asleep = true
var quiet = 0
var lost = false
## Touching the ground at the end of the last step.
var grounded = false
## Pose changed since the presentation node was last synced.
var moved = false
## Presentation node posed from xform() (optional).
var node = null
var hint = -1


static func kinds() -> Dictionary:
	if kinds_cache.is_empty():
		kinds_cache = JSON.parse_string(FileAccess.get_file_as_string(KINDS))
	return kinds_cache


func _init(kind_name: String, rest: Transform3D):
	configure(kind_name)
	place(rest)


## Shape, mass properties and contact coefficients from data/props.json.
func configure(kind_name: String):
	kind = kind_name
	spec = kinds()[kind_name]
	mass = float(spec.mass)
	restitution = float(spec.get("restitution", .3))
	friction = float(spec.get("friction", .6))
	drag_area = float(spec.get("drag_area", .1))
	var base = []
	var height = 0.0
	var solid = Vector3.ONE
	if spec.shape == "box":
		var s = Vector3(spec.size[0], spec.size[1], spec.size[2])
		height = s.y
		for fx in [-.5, 0.0, .5]:
			for fy in [0.0, .5, 1.0]:
				for fz in [-.5, 0.0, .5]:
					if fx != 0.0 or fy != .5 or fz != 0.0:
						base.append(Vector3(s.x * fx, s.y * fy, s.z * fz))
		solid = Vector3(s.y * s.y + s.z * s.z, s.x * s.x + s.z * s.z, s.x * s.x + s.y * s.y) * mass / 12
	else:
		height = float(spec.height)
		var r0 = float(spec.radius[0])
		var r1 = float(spec.radius[1])
		# Rings at the base and up the side (a car's sill is ~0.1 m up, so the side needs points low
		# down), and the tip.
		for f in [0.0, .15, .4, .7]:
			var r = lerpf(r0, r1, f)
			var n = RING if f == 0.0 else SIDE_RING
			for k in n:
				var a = TAU * (k + (0.0 if f == 0.0 else .5)) / n
				base.append(Vector3(cos(a) * r, height * f, sin(a) * r))
		if r1 < .05:
			base.append(Vector3(0, height, 0))
		else:
			for k in SIDE_RING:
				var a = TAU * k / SIDE_RING
				base.append(Vector3(cos(a) * r1, height, sin(a) * r1))
		# Uniform solid cylinder of the mean radius, when the data gives no inertia.
		var rm = (r0 + r1) * .5
		var ix = mass * (3 * rm * rm + height * height) / 12
		solid = Vector3(ix, mass * rm * rm * .5, ix)
	cg = float(spec.get("cg", height * .5))
	if spec.has("inertia"):
		inertia = Vector3(spec.inertia[0], spec.inertia[1], spec.inertia[2])
	else:
		# About the shape's middle, moved to the centre of mass.
		var d = height * .5 - cg
		inertia = solid + Vector3(mass * d * d, 0, mass * d * d)
	points.clear()
	var lo = Vector3.INF
	var hi = -Vector3.INF
	radius = 0.0
	for q in base:
		var p = q - Vector3(0, cg, 0)
		points.append(p)
		lo = lo.min(p)
		hi = hi.max(p)
		radius = maxf(radius, p.length())
	box_center = (lo + hi) * .5
	box_half = (hi - lo) * .5


## At rest in the pose `rest` (base frame), asleep.
func place(rest: Transform3D):
	home = rest
	var b = rest.basis.orthonormalized()
	rot = b.get_rotation_quaternion()
	pos = rest.origin + b.y * cg
	vel = Vector3.ZERO
	ang = Vector3.ZERO
	asleep = true
	lost = false
	quiet = 0
	grounded = true
	moved = true
	mark_pose()


func mark_pose():
	last_x = pos_x
	last_y = pos_y
	last_z = pos_z
	last_rot = rot


func basis() -> Basis:
	return Basis(rot)


## The rest-frame pose now (origin at the base centre), for presentation and markers.
func xform() -> Transform3D:
	var b = basis()
	return Transform3D(b, pos - b.y * cg)


func kinetic() -> float:
	return .5 * mass * vel.length_squared() + .5 * ang.dot(inertia * ang)


## Impulse `j` (N s, world) at world point `at`.
func apply_impulse(at: Vector3, j: Vector3):
	vel_x += j.x / mass
	vel_y += j.y / mass
	vel_z += j.z / mass
	var b = basis()
	ang += b.transposed() * (at - pos).cross(j) / inertia


func inverse_inertia_world(v: Vector3) -> Vector3:
	var b = basis()
	return b * ((b.transposed() * v) / inertia)


func velocity_at(at: Vector3) -> Vector3:
	return vel + (basis() * ang).cross(at - pos)


func wake():
	asleep = false
	quiet = 0


## One fixed tick for an awake prop. `walls` is a WallQuery for this kind (or null), `cars` the CarBodies
## the broad phase says may touch it. Returns the number of car contact points.
func step(dt: float, surface, walls, cars: Array) -> int:
	var prev = Vector3(last_x, last_y, last_z)
	var prev_rot = last_rot
	mark_pose()
	forces(dt)
	var b = basis()
	var cs = []
	var car_points = 0
	for car in cars:
		var found = car_contacts(car, b, prev, prev_rot)
		car_points += found.size()
		push_out(found)
		cs.append_array(found)
	var ground = ground_contacts(surface, b, dt)
	push_out(ground)
	cs.append_array(ground)
	grounded = false
	for c in ground:
		grounded = grounded or c.depth > -MARGIN
	solve(cs, b, dt)
	advance(dt)
	if walls != null:
		var found = wall_contacts(walls)
		if not found.is_empty():
			push_out(found)
			solve(found, basis(), dt)
	moved = true
	if grounded and vel.length() < SLEEP_SPEED and ang.length() < SLEEP_SPIN:
		quiet += 1
	else:
		quiet = 0
	if quiet >= SLEEP_TICKS:
		vel = Vector3.ZERO
		ang = Vector3.ZERO
		asleep = true
	if pos_y < home.origin.y - LOST_DROP:
		lost = true
		asleep = true
	return car_points


## Gravity and quadratic drag on the velocity, torque-free spin (RK4 as CarBody.gyro) on the rate.
func forces(dt: float):
	var speed = sqrt(vel_x * vel_x + vel_y * vel_y + vel_z * vel_z)
	var drag = .5 * AIR_DENSITY * drag_area * speed / mass * dt
	vel_x -= vel_x * drag
	vel_y -= vel_y * drag + G * dt
	vel_z -= vel_z * drag
	ang = gyro(ang, dt)
	var spin = ang.length()
	if spin > MAX_SPIN:
		ang *= MAX_SPIN / spin


## Move with the solved velocity and spin.
func advance(dt: float):
	pos_x += vel_x * dt
	pos_y += vel_y * dt
	pos_z += vel_z * dt
	var spin = ang.length()
	if spin > 1e-9:
		rot = (rot * Quaternion(ang / spin, spin * dt)).normalized()


func gyro(w0: Vector3, dt: float) -> Vector3:
	var k1 = -w0.cross(inertia * w0) / inertia
	var w1 = w0 + k1 * (dt * .5)
	var k2 = -w1.cross(inertia * w1) / inertia
	var w2 = w0 + k2 * (dt * .5)
	var k3 = -w2.cross(inertia * w2) / inertia
	var w3 = w0 + k3 * dt
	var k4 = -w3.cross(inertia * w3) / inertia
	return w0 + (k1 + 2 * k2 + 2 * k3 + k4) * (dt / 6)


## Contacts with a car's hull box: each hull point swept, relative to the box, from last tick's poses
## (prop at `prev`, car at the start of its step) to now.
func car_contacts(car, b: Basis, prev: Vector3, prev_rot: Quaternion) -> Array:
	var out = []
	var cb = car.basis()
	var cb0 = Basis(car.last_rot)
	var c_now = car.pos + cb * car.hull_center
	var c_then = Vector3(car.last_x, car.last_y, car.last_z) + cb0 * car.hull_center
	var ci = cb.transposed()
	var ci0 = cb0.transposed()
	var pb0 = Basis(prev_rot)
	var here = pos
	var h: Vector3 = car.hull_half
	for q in points:
		var w_now = here + b * q
		var e = ci * (w_now - c_now)
		if absf(e.x) > h.x + MARGIN or absf(e.y) > h.y + MARGIN or absf(e.z) > h.z + MARGIN:
			continue
		var a = ci0 * (prev + pb0 * q - c_then)
		var axis = -1
		var side = 1.0
		var t_best = -INF
		for i in 3:
			var t = -INF
			var s = 1.0
			if a[i] > h[i]:
				t = (a[i] - h[i]) / maxf(a[i] - e[i], 1e-9)
			elif a[i] < -h[i]:
				t = (-h[i] - a[i]) / maxf(e[i] - a[i], 1e-9)
				s = -1.0
			else:
				continue
			if t > t_best:
				t_best = t
				axis = i
				side = s
		if axis < 0:
			# It started inside too (a resting contact): the nearest face.
			var least = INF
			for i in 3:
				var d = h[i] - absf(e[i])
				if d < least:
					least = d
					axis = i
					side = 1.0 if e[i] >= 0 else -1.0
		var c = Contact.new()
		c.point = w_now
		c.face = cb[axis] * side
		c.normal = c.face
		if axis == 0:
			c.normal = (c.face * cos(NOSE_RAKE) + cb.y * sin(NOSE_RAKE)).normalized()
		c.depth = h[axis] - e[axis] * side
		c.car = car
		# Under the floor the road holds the prop: no push-out into it, the impulses lift the car.
		c.pinned = axis == 1 and side < 0
		out.append(c)
	return out


func wall_contacts(walls) -> Array:
	var b = basis()
	var now = pos + b * box_center
	var start = Vector3(last_x, last_y, last_z) + Basis(last_rot) * box_center
	var motion = now - start
	var fraction = walls.sweep(Transform3D(b, start), motion)
	if fraction < 1.0:
		var back = motion * (1.0 - maxf(0.0, fraction - .002 / maxf(motion.length(), 1e-6)))
		pos_x -= back.x
		pos_y -= back.y
		pos_z -= back.z
	var out = []
	for w in walls.contacts(Transform3D(b, pos + b * box_center)):
		var c = Contact.new()
		c.point = w.point
		c.normal = w.normal
		c.face = w.normal
		c.depth = w.depth
		out.append(c)
	return out


## The ground under the centre of mass as a plane. Every hull point below it, or close enough above it
## to reach it this tick, is a contact (a gap it may close but not cross: speculative).
func ground_contacts(surface, b: Basis, dt: float) -> Array:
	var out = []
	var look: float = MARGIN + (vel.length() + ang.length() * radius) * dt
	var here: Vector3 = pos
	var hit: Dictionary = surface.contact(
		here + Vector3(0, radius + .1, 0), Vector3.DOWN, 2 * radius + look + .2, hint
	)
	if hit.is_empty():
		return out
	hint = hit.get("hint", -1)
	var n: Vector3 = hit.normal
	var rel: Vector3 = hit.point - here
	var top: float = rel.dot(n)
	if top + radius < -look:
		return out
	# The deepest point in each quadrant around the centre of mass (in the ground plane): four well
	# spread supports hold a resting prop as well as all of them, and cost half as much to solve.
	var t1: Vector3 = n.cross(Vector3.RIGHT if absf(n.x) < .9 else Vector3.FORWARD).normalized()
	var t2: Vector3 = n.cross(t1)
	# In the body frame, so each point costs three dot products.
	var bt: Basis = b.transposed()
	var nl: Vector3 = bt * n
	var t1l: Vector3 = bt * t1
	var t2l: Vector3 = bt * t2
	var depth = PackedFloat64Array([-INF, -INF, -INF, -INF])
	var which = PackedInt32Array([-1, -1, -1, -1])
	for i in points.size():
		var q: Vector3 = points[i]
		var d: float = top - q.dot(nl)
		if d <= -look:
			continue
		var k: int = (1 if q.dot(t1l) >= 0 else 0) + (2 if q.dot(t2l) >= 0 else 0)
		if d > depth[k]:
			depth[k] = d
			which[k] = i
	for k in 4:
		if which[k] >= 0:
			var c = Contact.new()
			c.point = here + b * points[which[k]]
			c.normal = n
			c.face = n
			c.depth = depth[k]
			out.append(c)
	return out


## Move the prop out of the deepest of `cs` along its face normal; the points move with it.
func push_out(cs: Array):
	var deepest = 0.0
	var n = Vector3.ZERO
	for c in cs:
		if c.depth > deepest and not c.pinned:
			deepest = c.depth
			n = c.face
	if deepest <= 0.0:
		return
	var shift = n * deepest
	pos_x += shift.x
	pos_y += shift.y
	pos_z += shift.z
	for c in cs:
		c.point += shift
		c.depth -= deepest * c.face.dot(n)


## Sequential impulses over all contacts with accumulated clamping: the normal impulse (>= 0) reaches
## the contact's target closing speed, friction stays within mu times it. Car contacts are two-body:
## the car takes the opposite impulse at the same point (CarBody.apply_impulse's arithmetic, with its
## basis and world inverse inertia computed once). Each contact's response matrix K (closing velocity
## per unit impulse, both bodies) is built once, so a pass costs a few matrix products per contact.
func solve(cs: Array, b: Basis, dt: float):
	if cs.is_empty():
		return
	var im: float = 1.0 / mass
	var iw: Basis = b * Basis.from_scale(Vector3.ONE / inertia) * b.transposed()
	var v: Vector3 = vel
	var w: Vector3 = b * ang
	var here: Vector3 = pos
	var cars = []
	var cv = []
	var cw = []
	var cim = []
	var ciw = []
	var cj = []
	var total = Vector3.ZERO
	for c: Contact in cs:
		c.r = c.point - here
		c.m = response(c.r, im, iw)
		if c.car != null:
			var k = cars.find(c.car)
			if k < 0:
				k = cars.size()
				var car = c.car
				var cb: Basis = car.basis()
				cars.append(car)
				cv.append(car.vel)
				cw.append(cb * car.ang)
				cim.append(1.0 / car.p.mass)
				ciw.append(cb * Basis.from_scale(Vector3.ONE / car.inertia) * cb.transposed())
				cj.append(Vector3.ZERO)
			c.ci = k
			c.rc = c.point - c.car.pos
			var mc: Basis = response(c.rc, cim[k], ciw[k])
			c.m = Basis(c.m.x + mc.x, c.m.y + mc.y, c.m.z + mc.z)
		var n: Vector3 = c.normal
		var vr: Vector3 = v + w.cross(c.r)
		if c.ci >= 0:
			vr -= cv[c.ci] + cw[c.ci].cross(c.rc)
		var vn: float = vr.dot(n)
		c.k = n.dot(c.m * n)
		var fast: bool = -vn > BOUNCE_SPEED
		if c.depth < -MARGIN:
			# A gap: close it this tick at most, or bounce if it closes fast within the tick.
			var gap: float = -c.depth
			c.target = restitution * -vn if fast and -vn * dt > gap else -gap / dt
		else:
			c.target = restitution * -vn if fast else 0.0
	for pass_i in PASSES:
		for c: Contact in cs:
			var n: Vector3 = c.normal
			var vr: Vector3 = v + w.cross(c.r)
			if c.ci >= 0:
				vr -= cv[c.ci] + cw[c.ci].cross(c.rc)
			var jn: float = maxf(0.0, c.jn + (c.target - vr.dot(n)) / c.k)
			var j: Vector3 = n * (jn - c.jn)
			c.jn = jn
			if jn <= 0.0 and j == Vector3.ZERO:
				continue
			# Friction on the velocity after this normal impulse.
			vr += c.m * j
			var vt: Vector3 = vr - n * vr.dot(n)
			var slide: float = vt.length()
			if slide > 1e-9 and jn > 0.0:
				var t: Vector3 = vt / slide
				var jt: Vector3 = c.jt - t * (slide / t.dot(c.m * t))
				var cap: float = (friction if c.ci < 0 else CAR_FRICTION) * jn
				if jt.length_squared() > cap * cap:
					jt = jt.normalized() * cap
				j += jt - c.jt
				c.jt = jt
			v += j * im
			w += iw * c.r.cross(j)
			total += j
			if c.ci >= 0:
				cv[c.ci] -= j * cim[c.ci]
				cw[c.ci] -= ciw[c.ci] * c.rc.cross(j)
				cj[c.ci] += j
	# Linear velocities from the summed impulses in 64 bits, so what one body gains the other loses.
	vel_x += total.x * im
	vel_y += total.y * im
	vel_z += total.z * im
	ang = b.transposed() * w
	for k in cars.size():
		var car = cars[k]
		car.vel_x -= cj[k].x * cim[k]
		car.vel_y -= cj[k].y * cim[k]
		car.vel_z -= cj[k].z * cim[k]
		car.ang = car.basis().transposed() * cw[k]


## Velocity change at arm `r` per unit impulse there, for a body of inverse mass `im` and world inverse
## inertia `iw`: im I - [r]x iw [r]x, as a matrix (columns).
static func response(r: Vector3, im: float, iw: Basis) -> Basis:
	return Basis(
		Vector3(im, 0, 0) + (iw * r.cross(Vector3.RIGHT)).cross(r),
		Vector3(0, im, 0) + (iw * r.cross(Vector3.UP)).cross(r),
		Vector3(0, 0, im) + (iw * r.cross(Vector3.BACK)).cross(r)
	)


class Contact:
	var point: Vector3 = Vector3.ZERO
	## Impulse direction, out of what the prop touches.
	var normal: Vector3 = Vector3.ZERO
	## Push-out direction: the touched face's normal.
	var face: Vector3 = Vector3.ZERO
	## Not pushed out (under a car's floor).
	var pinned: bool = false
	## Penetration along `face` (negative: a gap).
	var depth: float = 0.0
	var car = null
	var ci: int = -1
	var r: Vector3 = Vector3.ZERO
	var rc: Vector3 = Vector3.ZERO
	## Response matrix: closing velocity per unit impulse, both bodies.
	var m: Basis = Basis()
	var k: float = 1.0
	var target: float = 0.0
	var jn: float = 0.0
	var jt: Vector3 = Vector3.ZERO


## Presentation: a MeshInstance3D for `kind_name` in its rest frame (base on the ground). Meshes and
## materials are shared per kind, so a track full of cones stores one mesh.
static var meshes = {}


static func visual(kind_name: String) -> MeshInstance3D:
	if not meshes.has(kind_name):
		var s = kinds()[kind_name]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(str(s.get("color", "#ff5a14")))
		mat.roughness = .7
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if s.shape == "box":
			var m = BoxMesh.new()
			m.size = Vector3(s.size[0], s.size[1], s.size[2])
			st.append_from(m, 0, Transform3D(Basis(), Vector3(0, s.size[1] * .5, 0)))
		else:
			var m = CylinderMesh.new()
			m.bottom_radius = float(s.radius[0]) * .8
			m.top_radius = float(s.radius[1])
			m.height = float(s.height)
			m.radial_segments = 16
			m.rings = 1
			st.append_from(m, 0, Transform3D(Basis(), Vector3(0, float(s.height) * .5, 0)))
			var plate = BoxMesh.new()
			var w = float(s.radius[0]) * 2
			plate.size = Vector3(w, .03, w)
			st.append_from(plate, 0, Transform3D(Basis(), Vector3(0, .015, 0)))
		var mesh = st.commit()
		mesh.surface_set_material(0, mat)
		meshes[kind_name] = mesh
	var mi = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = meshes[kind_name]
	return mi
