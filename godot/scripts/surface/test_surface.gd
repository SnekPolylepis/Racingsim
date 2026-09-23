extends RefCounted
## Analytic test surfaces with exact ground truth for the 6-DOF chassis (REBUILD-PLAN.md P2).
## Every shape is a heightfield y = height(x, z) in Godot world space (+Y up, metres).
## Implements the Surface contract (REBUILD-PLAN.md 5.2): contact(origin, direction, max_dist, hint).

enum Shape { FLAT, CREST, BOWL, VOID }

const CREST_STEP = .05

var shape = Shape.FLAT
## Surface index into the SURF table (0 tarmac).
var surface_id = 0
## CREST: a crest along +X whose curvature is exactly 1/crest_radius over |x - crest_x| <= plateau,
## eased in and out over `ramp` metres with a smoothstep so the suspension sees no curvature step.
## Beyond the ramps the profile is straight grades. Height/slope are integrated into a fine table.
var crest_x = 0.0
var crest_radius = 200.0
var crest_plateau = 20.0
var crest_ramp = 40.0
var crest_slope = PackedFloat64Array()
var crest_height = PackedFloat64Array()
## BOWL: a banked cone around the origin; height is zero at bowl_radius and rises outwards.
var bowl_radius = 100.0
var bowl_bank = deg_to_rad(20.0)


static func flat():
	return new()


static func crest(apex_x, radius, plateau, ramp):
	var s = new()
	s.shape = Shape.CREST
	s.crest_x = apex_x
	s.crest_radius = radius
	s.crest_plateau = plateau
	s.crest_ramp = ramp
	s.build_crest()
	return s


static func bowl(radius, bank_deg):
	var s = new()
	s.shape = Shape.BOWL
	s.bowl_radius = radius
	s.bowl_bank = deg_to_rad(bank_deg)
	return s


## Nothing to hit anywhere: for free-flight tests.
static func void_space():
	var s = new()
	s.shape = Shape.VOID
	return s


## Signed curvature (1/m, negative = crest) at offset u from the apex.
func crest_curvature(u):
	var a = absf(u)
	if a <= crest_plateau:
		return -1.0 / crest_radius
	return -smoothstep(crest_plateau + crest_ramp, crest_plateau, a) / crest_radius


## Integrate curvature to slope and slope to height for u >= 0 (the profile is symmetric).
func build_crest():
	var n = int(ceil((crest_plateau + crest_ramp) / CREST_STEP)) + 1
	crest_slope.resize(n)
	crest_height.resize(n)
	crest_slope[0] = 0.0
	crest_height[0] = 0.0
	for i in range(1, n):
		var k0 = crest_curvature((i - 1) * CREST_STEP)
		var k1 = crest_curvature(i * CREST_STEP)
		crest_slope[i] = crest_slope[i - 1] + (k0 + k1) * .5 * CREST_STEP
		crest_height[i] = crest_height[i - 1] + (crest_slope[i - 1] + crest_slope[i]) * .5 * CREST_STEP


## Height and slope d(height)/du at offset u from the apex (cubic Hermite between table nodes).
func crest_profile(u):
	var a = absf(u)
	var last = crest_slope.size() - 1
	var hgt
	var slope
	if a >= last * CREST_STEP:
		slope = crest_slope[last]
		hgt = crest_height[last] + (a - last * CREST_STEP) * slope
	else:
		var i = int(a / CREST_STEP)
		var t = a / CREST_STEP - i
		var h0 = crest_height[i]
		var h1 = crest_height[i + 1]
		var m0 = crest_slope[i] * CREST_STEP
		var m1 = crest_slope[i + 1] * CREST_STEP
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
			/ CREST_STEP
		)
	return Vector2(hgt, slope * signf(u) if u != 0 else 0.0)


func height(x, z):
	match shape:
		Shape.CREST:
			return crest_profile(x - crest_x).x
		Shape.BOWL:
			return (Vector2(x, z).length() - bowl_radius) * tan(bowl_bank)
		Shape.VOID:
			return -1e6
	return 0.0


## Unit surface normal from the analytic gradient.
func normal(x, z):
	var gx = 0.0
	var gz = 0.0
	match shape:
		Shape.CREST:
			gx = crest_profile(x - crest_x).y
		Shape.BOWL:
			var rho = maxf(Vector2(x, z).length(), 1e-6)
			gx = tan(bowl_bank) * x / rho
			gz = tan(bowl_bank) * z / rho
	return Vector3(-gx, 1.0, -gz).normalized()


## Cast a ray against the heightfield. Returns {} on no hit, otherwise
## {point, normal, distance, surface, hint}. A ray that starts below the surface hits at distance 0.
func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int = -1) -> Dictionary:
	if shape == Shape.VOID:
		return {}
	var t = 0.0
	if origin.y - height(origin.x, origin.z) > 0:
		var end = origin + direction * max_dist
		if end.y - height(end.x, end.z) > 0:
			return {}
		if shape == Shape.FLAT:
			t = origin.y / -direction.y
		else:
			# Bisection on the signed height above the surface along the ray; 40 halvings is sub-micron.
			var lo = 0.0
			var hi = max_dist
			for i in 40:
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
