extends RefCounted
## Analytic test surfaces with exact ground truth for the 6-DOF chassis (REBUILD-PLAN.md P2-02).
## Every shape is a heightfield y = height(x, z) in Godot world space (+Y up, metres).
## Implements the Surface contract (REBUILD-PLAN.md 5.2): contact(origin, direction, max_dist, hint).
##
## Shapes and their ground truth:
##   FLAT   y = 0.
##   PLANE  y = gx*x + gz*z: a uniform grade (ramp along x) or side slope (along z); exact normal.
##   CREST  along x: curvature exactly -1/R over the plateau, smoothstep-eased in and out, then grades.
##   BOWL   banked cone around the origin: bank angle exact everywhere, height 0 at bowl_radius.
##   DITCH  along x (Karussell-like trough across z): flat floor at -depth, walls at exactly the wall
##          angle over their straight part, smoothstep-filleted into floor and road, road at y = 0.
##   STEP   along x: a kerb-like rise of step_height at step_x, sharp or eased over step_width.
##   BLOCK  a flat-topped rectangular pad of block_height on flat ground (sharp edges), for jacking
##          one wheel: the warp / cross-weight test of the suspension (P2-03).
##   VOID   nothing to hit.
## CREST and DITCH share one symmetric profile table: slope is integrated from an analytic
## curvature (CREST) or slope (DITCH) function, and evaluated by cubic Hermite interpolation.

enum Shape { FLAT, CREST, BOWL, VOID, PLANE, DITCH, STEP, BLOCK }

const PROFILE_STEP = .05
## Ray-march samples before bisection in contact().
const MARCH_STEPS = 16

var shape = Shape.FLAT
## Surface index into the SURF table (0 tarmac).
var surface_id = 0
## Symmetric profile table for CREST (along x) and DITCH (across z): height and slope at
## u = i * PROFILE_STEP from the profile centre, for u >= 0. Beyond the table the last slope continues.
var profile_slope = PackedFloat64Array()
var profile_height = PackedFloat64Array()
var profile_offset = 0.0
## CREST: apex x, curvature radius, curvature plateau half-length and ease length.
var crest_x = 0.0
var crest_radius = 200.0
var crest_plateau = 20.0
var crest_ramp = 40.0
## BOWL: a banked cone around the origin; height is zero at bowl_radius and rises outwards.
var bowl_radius = 100.0
var bowl_bank = deg_to_rad(20.0)
## PLANE: height gradient (rise per metre along x and along z).
var plane_grad = Vector2.ZERO
## DITCH: trough centred on z = ditch_z, running along x. Floor half-width, wall angle, length of the
## straight part of each wall, and fillet (ease) length at both ends of the wall.
var ditch_z = 0.0
var ditch_floor = 1.5
var ditch_angle = deg_to_rad(37.0)
var ditch_wall = 1.1
var ditch_fillet = .5
## STEP: rise of step_height at x = step_x; step_width 0 is a sharp vertical face.
var step_x = 0.0
var step_height = .05
var step_width = 0.0
## BLOCK: centre, half extents in x and z, and height.
var block_center = Vector2.ZERO
var block_half = Vector2(.3, .3)
var block_height = .03


static func flat():
	return new()


static func block(cx, cz, half_x, half_z, rise):
	var s = new()
	s.shape = Shape.BLOCK
	s.block_center = Vector2(cx, cz)
	s.block_half = Vector2(half_x, half_z)
	s.block_height = rise
	return s


static func crest(apex_x, radius, plateau, ramp):
	var s = new()
	s.shape = Shape.CREST
	s.crest_x = apex_x
	s.crest_radius = radius
	s.crest_plateau = plateau
	s.crest_ramp = ramp
	s.build_profile()
	return s


static func bowl(radius, bank_deg):
	var s = new()
	s.shape = Shape.BOWL
	s.bowl_radius = radius
	s.bowl_bank = deg_to_rad(bank_deg)
	return s


## Uniform grade along +x: positive degrees climb towards +x.
static func ramp(grade_deg):
	var s = new()
	s.shape = Shape.PLANE
	s.plane_grad = Vector2(tan(deg_to_rad(grade_deg)), 0)
	return s


## Uniform side slope across the x direction of travel: positive degrees climb towards +z (the right
## of a car heading along +x).
static func side_slope(angle_deg):
	var s = new()
	s.shape = Shape.PLANE
	s.plane_grad = Vector2(0, tan(deg_to_rad(angle_deg)))
	return s


static func ditch(floor_half_width, wall_deg, wall_length, fillet):
	var s = new()
	s.shape = Shape.DITCH
	s.ditch_floor = floor_half_width
	s.ditch_angle = deg_to_rad(wall_deg)
	s.ditch_wall = wall_length
	s.ditch_fillet = fillet
	s.build_profile()
	return s


static func step(x, rise, width = 0.0):
	var s = new()
	s.shape = Shape.STEP
	s.step_x = x
	s.step_height = rise
	s.step_width = width
	return s


## Nothing to hit anywhere: for free-flight tests.
static func void_space():
	var s = new()
	s.shape = Shape.VOID
	return s


## Signed crest curvature (1/m, negative = crest) at offset u from the apex.
func crest_curvature(u):
	var a = absf(u)
	if a <= crest_plateau:
		return -1.0 / crest_radius
	return -smoothstep(crest_plateau + crest_ramp, crest_plateau, a) / crest_radius


## Ditch wall slope (rise per metre outward) at distance u from the trough centre line.
func ditch_slope(u):
	var a = absf(u)
	var top = tan(ditch_angle)
	var wall_start = ditch_floor + ditch_fillet
	var wall_end = wall_start + ditch_wall
	if a <= ditch_floor:
		return 0.0
	if a < wall_start:
		return top * smoothstep(ditch_floor, wall_start, a)
	if a <= wall_end:
		return top
	return top * smoothstep(wall_end + ditch_fillet, wall_end, a)


## Depth of the ditch: the integral of its slope from the centre line to the road.
func ditch_depth():
	# Each smoothstep ease integrates to half its length at full slope.
	return tan(ditch_angle) * (ditch_wall + ditch_fillet)


## Build the symmetric profile table for CREST (integrating curvature twice) or DITCH (slope once).
func build_profile():
	var span = crest_plateau + crest_ramp
	if shape == Shape.DITCH:
		span = ditch_floor + 2 * ditch_fillet + ditch_wall
	var n = int(ceil(span / PROFILE_STEP)) + 1
	profile_slope.resize(n)
	profile_height.resize(n)
	profile_slope[0] = 0.0
	profile_height[0] = 0.0
	for i in range(1, n):
		if shape == Shape.DITCH:
			profile_slope[i] = ditch_slope(i * PROFILE_STEP)
		else:
			var k0 = crest_curvature((i - 1) * PROFILE_STEP)
			var k1 = crest_curvature(i * PROFILE_STEP)
			profile_slope[i] = profile_slope[i - 1] + (k0 + k1) * .5 * PROFILE_STEP
		profile_height[i] = (
			profile_height[i - 1] + (profile_slope[i - 1] + profile_slope[i]) * .5 * PROFILE_STEP
		)
	# The ditch table climbs from the floor; shift it so the road beyond the walls sits at y = 0.
	profile_offset = -profile_height[n - 1] if shape == Shape.DITCH else 0.0


## [height, slope d(height)/du] at offset u from the profile centre (cubic Hermite between nodes).
## Plain floats (64-bit) throughout: Godot's Vector2/Vector3 are 32-bit in standard builds, which
## is too coarse for ground truth.
func profile(u):
	var a = absf(u)
	var last = profile_slope.size() - 1
	var hgt
	var slope
	if a >= last * PROFILE_STEP:
		slope = profile_slope[last]
		hgt = profile_height[last] + (a - last * PROFILE_STEP) * slope
	else:
		var i = int(a / PROFILE_STEP)
		var t = a / PROFILE_STEP - i
		var h0 = profile_height[i]
		var h1 = profile_height[i + 1]
		var m0 = profile_slope[i] * PROFILE_STEP
		var m1 = profile_slope[i + 1] * PROFILE_STEP
		var t2 = t * t
		var t3 = t2 * t
		hgt = (2 * t3 - 3 * t2 + 1) * h0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * h1 + (t3 - t2) * m1
		slope = (
			(
				(6 * t2 - 6 * t) * h0
				+ (3 * t2 - 4 * t + 1) * m0
				+ (-6 * t2 + 6 * t) * h1
				+ (3 * t2 - 2 * t) * m1
			)
			/ PROFILE_STEP
		)
	return [hgt + profile_offset, slope * signf(u) if u != 0 else 0.0]


func height(x, z):
	match shape:
		Shape.CREST:
			return profile(x - crest_x)[0]
		Shape.BOWL:
			return (sqrt(x * x + z * z) - bowl_radius) * tan(bowl_bank)
		Shape.PLANE:
			return plane_grad.x * x + plane_grad.y * z
		Shape.DITCH:
			return profile(z - ditch_z)[0]
		Shape.STEP:
			if step_width <= 0:
				return step_height if x >= step_x else 0.0
			return step_height * smoothstep(step_x, step_x + step_width, x)
		Shape.BLOCK:
			var inside = absf(x - block_center.x) <= block_half.x and absf(z - block_center.y) <= block_half.y
			return block_height if inside else 0.0
		Shape.VOID:
			return -1e6
	return 0.0


## Unit surface normal from the analytic gradient. A sharp STEP reports the flat normal on both
## sides; its vertical face has no heightfield normal.
func normal(x, z):
	var gx = 0.0
	var gz = 0.0
	match shape:
		Shape.CREST:
			gx = profile(x - crest_x)[1]
		Shape.BOWL:
			var rho = maxf(sqrt(x * x + z * z), 1e-6)
			gx = tan(bowl_bank) * x / rho
			gz = tan(bowl_bank) * z / rho
		Shape.PLANE:
			gx = plane_grad.x
			gz = plane_grad.y
		Shape.DITCH:
			gz = profile(z - ditch_z)[1]
		Shape.STEP:
			if step_width > 0 and x > step_x and x < step_x + step_width:
				var u = (x - step_x) / step_width
				gx = step_height * 6 * u * (1 - u) / step_width
	return Vector3(-gx, 1.0, -gz).normalized()


## Cast a ray against the heightfield. Returns {} on no hit, otherwise
## {point, normal, distance, surface, hint}. A ray that starts below the surface hits at distance 0.
func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
	if shape == Shape.VOID:
		return {}
	var t = 0.0
	if origin.y - height(origin.x, origin.z) > 0:
		if shape == Shape.FLAT or shape == Shape.PLANE:
			# Closed form: signed height above the plane is linear along the ray.
			var above = origin.y - plane_grad.x * origin.x - plane_grad.y * origin.z
			var closing = -(direction.y - plane_grad.x * direction.x - plane_grad.y * direction.z)
			if closing <= 0 or above > closing * max_dist:
				return {}
			t = above / closing
		else:
			# A tilted ray can pass over a hump with both ends above it, so march for the FIRST sample
			# below the surface rather than trusting the endpoints, then bisect inside that segment.
			# A crossing narrower than one march step (max_dist / MARCH_STEPS) can still be missed.
			var lo = 0.0
			var hi = -1.0
			for i in range(1, MARCH_STEPS + 1):
				var d = max_dist * i / MARCH_STEPS
				var q = origin + direction * d
				if q.y - height(q.x, q.z) <= 0:
					hi = d
					break
				lo = d
			if hi < 0:
				return {}
			# 32 halvings of one march step is sub-micron.
			for i in 32:
				var mid = (lo + hi) * .5
				var q = origin + direction * mid
				if q.y - height(q.x, q.z) > 0:
					lo = mid
				else:
					hi = mid
			t = (lo + hi) * .5
	var point = origin + direction * t
	return {
		"point": point, "normal": normal(point.x, point.z), "distance": t, "surface": surface_id, "hint": hint
	}
