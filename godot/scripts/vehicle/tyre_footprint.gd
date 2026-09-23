extends RefCounted
## Tyre footprint contact (REBUILD-PLAN.md 5.2, P2-06). The tyre is not a point: a single ray per wheel
## puts the whole kerb height under the wheel the instant the kerb edge passes under the centre, and
## lets the car sit in a hole narrower than the tyre.
##
## The tyre is treated as a rigid curved surface: a circle of the wheel radius along the wheel's
## heading, and across it a flat tread with shoulders rounded to SHOULDER radius. At offset (x, y) from
## the bottom point the tyre sits drop(x, y) above it. A ground sample at ray distance d therefore
## holds the bottom point at d + drop, and the wheel rests on whichever sample holds it highest: the
## envelope of the ground under the tyre.
##
## Samples: the centre ray, one ahead and one behind it along the heading, and one at each tread edge.
## Where a sample disagrees with the centre about the ground plane under the tyre by more than
## EDGE_TOL, the gap holds an edge (a kerb face): it is located to BRACKET by bisection (extra rays
## only there), and the tyre rests on the edge's corner. So a kerb edge lifts the wheel progressively
## as the tyre's curve rolls onto it, and one met from the side meets the rounded shoulder first,
## rather than lifting the wheel by the whole kerb height in one tick.
##
## On ground that is smooth at the tyre's scale (radius of curvature larger than the wheel's, no edges)
## the centre sample holds the wheel highest and the result is exactly the single centre ray.
## Normals come from the ground (5.2): candidates within BLEND of the highest share the normal and
## contact point, so the contact moves continuously from one surface onto another.

## Fore-aft sample offset, ahead of and behind the centre ray, as a fraction of the wheel radius. The
## tread there sits 0.34 R above its bottom point, so an edge up to that height is caught before the
## tyre meets it; the edge is then located by bisection.
const FORE_AFT = .75
## Shoulder radius, metres: the tread is flat to SHOULDER inside each edge, then rounds off. A kerb
## edge at the tread edge meets the tyre SHOULDER above its bottom point.
const SHOULDER = .06
## Tread width when the car preset gives none, metres.
const DEFAULT_TREAD = .28
## Ground-height disagreement between neighbouring samples, beyond what the plane under the centre
## explains, that is treated as an edge.
const EDGE_TOL = .01
## An edge is bisected until its bracket is this long (8 rays fore-aft, 8 across), metres.
const BRACKET = .001
## Most extra (bisection) rays per wheel per tick: two edges.
const MAX_EXTRA = 16
## Surfaces steeper than 60 degrees to the tyre's up (kerb and wall faces) locate edges but never
## carry the tyre through an extra ray. The Karussell's 37 degree wall is well inside.
const FACE_COS = .5
## Candidates holding the wheel within this distance of the highest share the contact normal.
const BLEND = .005


## Height of the tyre above its bottom point at offset x along the heading and y across the tread
## (|y| up to half the tread width).
static func drop(x: float, y: float, radius: float, tread: float) -> float:
	var along = radius - sqrt(maxf(radius * radius - x * x, 0.0))
	var into = absf(y) - (tread * .5 - SHOULDER)
	if into <= 0:
		return along
	return along + SHOULDER - sqrt(maxf(SHOULDER * SHOULDER - into * into, 0.0))


## Footprint contact below `origin` along `down`. `fwd` and `side` are unit vectors perpendicular to
## `down` (the wheel's heading and its right). `centre` is the centre ray's hit, already cast by the
## caller from `origin` over `max_dist` ({} on a miss). Returns {} when nothing is under the tyre,
## otherwise the Surface contract's keys, with `distance` the centre-equivalent ray distance (where
## the tyre's bottom point would meet flat ground holding it at the same height), plus `rays`
## (queries made, the centre included) and `edge` (true when an edge corner carries the tyre).
static func contact(
	surface,
	origin: Vector3,
	down: Vector3,
	fwd: Vector3,
	side: Vector3,
	max_dist: float,
	hint: int,
	radius: float,
	tread: float,
	centre: Dictionary
) -> Dictionary:
	var up = -down
	# A sample past the tyre's reach can still hold its curved tread within reach.
	var reach = max_dist + radius
	var rays = 4
	# The caller's centre ray stops at max_dist; recast it as far as the other samples reach, so that a
	# miss means no ground there at all (an edge to a drop), not merely ground out of the wheel's reach.
	var middle = centre
	if centre.is_empty():
		middle = surface.contact(origin, down, reach, hint)
		rays += 1
	# Samples: [x, y, residual from the plane under the centre (INF on a miss), hit].
	var samples = [[0.0, 0.0, 0.0, middle]]
	for x in [-FORE_AFT * radius, FORE_AFT * radius]:
		samples.append([x, 0.0, 0.0, surface.contact(origin + fwd * x, down, reach, hint)])
	for y in [-tread * .5, tread * .5]:
		samples.append([0.0, y, 0.0, surface.contact(origin + side * y, down, reach, hint)])
	# Plane under the centre, as ray distance d(x, y) = ref + gf x + gs y, from the centre hit, or the
	# first other hit when the centre misses (a wheel beside a drop).
	var base = samples[0] if not centre.is_empty() else null
	for s in samples:
		if base == null and bearing(s[3], up):
			base = s
	if base == null:
		return {}
	var gf = 0.0
	var gs = 0.0
	var nu = base[3].normal.dot(up)
	if nu > .05:
		gf = base[3].normal.dot(fwd) / nu
		gs = base[3].normal.dot(side) / nu
	var ref = base[3].distance - gf * base[0] - gs * base[1]
	# Smooth ground under the whole tyre, the usual case: every sample agrees with the plane under the
	# centre and none comes near holding the tyre up, so the centre ray is the answer.
	var smooth = not centre.is_empty()
	for s in samples:
		s[2] = INF if s[3].is_empty() else s[3].distance - (ref + gf * s[0] + gs * s[1])
		if s[0] != 0.0 or s[1] != 0.0:
			smooth = (
				smooth
				and absf(s[2]) <= EDGE_TOL
				and s[3].distance + drop(s[0], s[1], radius, tread) >= centre.distance + BLEND
			)
	if smooth:
		centre.rays = rays + 1
		centre.edge = false
		return centre
	rays += 1
	# Edges between the centre and each other sample.
	var edges = []
	var extra = 0
	for k in range(1, 5):
		var a = samples[0]
		var b = samples[k]
		if is_inf(a[2]) and is_inf(b[2]):
			continue
		var levels = ceili(log(Vector2(b[0], b[1]).length() / BRACKET) / log(2.0))
		if absf(a[2] - b[2]) <= EDGE_TOL or extra + levels > MAX_EXTRA:
			continue
		var high = a if a[2] < b[2] else b
		var low = b if a[2] < b[2] else a
		# The nearest ray known to be on the high side's top surface. A slightly tilted ray close to the
		# edge can strike the kerb face part way up: it still narrows the bracket, but the tyre rests on
		# the top, so the edge takes its height from `top`.
		var top = high
		var mids = []
		for level in levels:
			var mid = sample(
				surface,
				origin,
				down,
				fwd,
				side,
				(high[0] + low[0]) * .5,
				(high[1] + low[1]) * .5,
				reach,
				hint,
				ref,
				gf,
				gs
			)
			extra += 1
			mids.append(mid)
			var split = top[2] + EDGE_TOL if is_inf(low[2]) else (top[2] + low[2]) * .5
			if mid[2] <= split:
				high = mid
				if absf(mid[2] - top[2]) <= EDGE_TOL * .5 and bearing(mid[3], up):
					top = mid
			else:
				low = mid
		if bearing(top[3], up) and (is_inf(low[2]) or low[2] - top[2] > EDGE_TOL):
			# An edge: its high side's corner, nearer the tyre than any bisection ray on that side, is
			# what the tyre meets, so those rays have done their job.
			edges.append([(high[0] + low[0]) * .5, (high[1] + low[1]) * .5, top])
		else:
			# No edge after all (a smooth hump or dip between the samples): its rays are ground samples.
			samples.append_array(mids)
	rays += extra
	# Candidates: [bottom-point distance, normal, point, surface, is edge].
	var cands = []
	for k in samples.size():
		var s = samples[k]
		# The caller's centre ray carries the wheel at any angle, exactly as the single-ray contact did
		# (a car rolled up a steep wall still rests on it); the extra rays must meet a bearing surface.
		var own = k == 0 and not centre.is_empty()
		if not (own or bearing(s[3], up)):
			continue
		cands.append(
			[s[3].distance + drop(s[0], s[1], radius, tread), s[3].normal, s[3].point, s[3].surface, false]
		)
	# The tyre on an edge's corner takes the high side's surface normal (5.2: normals from the ground).
	# The rigid tread's own normal there leans away from the edge, and its climb rate then reaches the
	# damper whole: with no tyre compliance or unsprung mass that gave 9-28x static load on a 5 cm step.
	for e in edges:
		var ground = ref + gf * e[0] + gs * e[1] + e[2][2]
		var point = origin + fwd * e[0] + side * e[1] + down * ground
		cands.append([ground + drop(e[0], e[1], radius, tread), e[2][3].normal, point, e[2][3].surface, true])
	if cands.is_empty():
		return {}
	var best = 0
	for k in cands.size():
		if cands[k][0] < cands[best][0]:
			best = k
	var lowest = cands[best][0]
	# Nothing holds the tyre within its reach.
	if lowest > max_dist:
		return {}
	var normal = Vector3.ZERO
	var point = Vector3.ZERO
	var total = 0.0
	var sharing = 0
	for c in cands:
		var gap = c[0] - lowest
		if gap >= BLEND:
			continue
		var w = (1.0 - gap / BLEND) * (1.0 - gap / BLEND)
		normal += c[1] * w
		point += c[2] * w
		total += w
		sharing += 1
	var chosen = cands[best]
	var out = {
		"distance": lowest,
		"surface": chosen[3],
		"hint": centre.hint if not centre.is_empty() else hint,
		"rays": rays,
		"edge": chosen[4]
	}
	if sharing == 1:
		# One candidate: pass its values through untouched (the single-ray result on smooth ground).
		out.normal = chosen[1]
		out.point = chosen[2]
	else:
		out.normal = normal.normalized()
		out.point = point / total
	return out


## True for a hit an extra footprint ray may carry the tyre on: not a kerb or wall face steeper than
## FACE_COS. Bisection concentrates rays at an edge, and with the chassis tilted some strike the face;
## a near-horizontal normal turns the wheel's forward speed into compression rate (car_body divides by
## the normal's up component): 500 kN wheel loads on a sharp kerb strip before this guard.
static func bearing(hit: Dictionary, up: Vector3) -> bool:
	return not hit.is_empty() and hit.normal.dot(up) >= FACE_COS


## One bisection ray at offset (x, y), with its residual from the plane under the centre.
static func sample(surface, origin, down, fwd, side, x, y, reach, hint, ref, gf, gs):
	var hit = surface.contact(origin + fwd * x + side * y, down, reach, hint)
	if hit.is_empty():
		return [x, y, INF, hit]
	return [x, y, hit.distance - (ref + gf * x + gs * y), hit]
