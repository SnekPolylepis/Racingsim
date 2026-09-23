extends RefCounted
## Tyre footprint contact (REBUILD-PLAN.md 5.2, P2-06). The tyre is not a point: a single ray per wheel
## puts the whole kerb height under the wheel the instant the kerb edge passes under the centre, and
## lets the car sit in a hole narrower than the tyre.
##
## The tyre is treated as a rigid curved surface: a circle of the wheel radius along the wheel's
## heading, and across it a slightly crowned tread with rounded shoulders. At offset (x, y) from
## the bottom point the tyre sits drop(x, y) above it. A ground sample at ray distance d therefore
## holds the bottom point at d + drop, and the wheel rests on whichever sample holds it highest: the
## envelope of the ground under the tyre.
##
## Samples: the centre ray, four more along the heading and four across the tread (ALONG, ACROSS).
## Where two neighbouring samples disagree about the ground plane under the tyre by more than
## EDGE_TOL, the gap holds an edge (a kerb face): it is located to BRACKET by bisection (extra rays
## only there), and the tyre rests on the edge's corner. So a kerb edge lifts the wheel progressively
## as the tyre's curve rolls onto it, and one met from the side meets the rounded shoulder first,
## rather than lifting the wheel by the whole kerb height in one tick.
##
## On ground that is smooth at the tyre's scale (radius of curvature larger than the wheel's, no edges)
## the centre sample holds the wheel highest and the result is exactly the single centre ray.
## Normals come from the ground (5.2): candidates within BLEND of the highest share the normal and
## contact point, so the contact moves continuously from one surface onto another.

## Sample offsets along the heading, as fractions of the wheel radius (the tread sits 0.34 R above its
## bottom point at 0.75 R, so an edge up to that height is caught before the tyre meets it), and across
## the tread, as fractions of the tread width. Dense enough that a kerb hump (a 9 cm sausage over 0.6 m
## has a 0.4 m radius at its crown) is followed by the fixed samples alone, to within ~2 mm.
const ALONG = [-.75, -.375, .375, .75]
const ACROSS = [-.5, -.25, .25, .5]
## Neighbouring samples (indices: 0 centre, 1-4 ALONG, 5-8 ACROSS), in order along each line.
const PAIRS = [[1, 2], [2, 0], [0, 3], [3, 4], [5, 6], [6, 0], [0, 7], [7, 8]]
## The outer ring of samples, cast first, and the inner ones, cast only when the outer ring finds
## something other than smooth ground.
const OUTER = [1, 4, 5, 8]
const INNER = [2, 3, 6, 7]
## Tread crown radius, metres, inside the shoulders. The wheel here is rigid with the chassis (no
## camber gain, no tyre compliance), so a slightly round tread stands in for both: it keeps a few
## degrees of body roll relative to the ground from shifting the contact to the tread's edge.
const CROWN = .4
## Shoulder radius, metres: past the crown the tread rounds off over its last SHOULDER each side. A
## kerb edge at the tread edge meets the tyre SHOULDER (plus the crown's drop) above its bottom point.
const SHOULDER = .06
## Tread width when the car preset gives none, metres.
const DEFAULT_TREAD = .28
## Ground-height disagreement between neighbouring samples, beyond what the plane under the centre
## explains, that is treated as an edge.
const EDGE_TOL = .01
## Largest disagreement with that plane that still counts as smooth ground, so the inner samples are
## skipped. Well under a kerb rib (8 mm): a ribbed kerb always gets the full footprint, instead of
## switching between the two every few ticks (10 mm compression jumps at 60 km/h when it was EDGE_TOL).
## A crest of 200 m radius departs from the plane by 0.2 mm at the outer samples.
const SMOOTH_TOL = .002
## An edge is bisected until its bracket is this long (7 rays along, 7 across), metres.
const BRACKET = .001
## Most extra (bisection) rays per wheel per tick: two edges, the largest first.
const MAX_EXTRA = 16
## Surfaces steeper than 60 degrees to the tyre's up (kerb and wall faces) locate edges but never
## carry the tyre through an extra ray. The Karussell's 37 degree wall is well inside.
const FACE_COS = .5
## Candidates holding the wheel within this distance of the highest share the contact normal.
const BLEND = .002


## Height of the tyre above its bottom point at offset x along the heading and y across the tread
## (|y| up to half the tread width).
static func drop(x: float, y: float, radius: float, tread: float) -> float:
	var along = radius - sqrt(maxf(radius * radius - x * x, 0.0))
	var flat = tread * .5 - SHOULDER
	var inner = minf(absf(y), flat)
	var across = CROWN - sqrt(CROWN * CROWN - inner * inner)
	var into = absf(y) - flat
	if into <= 0:
		return along + across
	return along + across + SHOULDER - sqrt(maxf(SHOULDER * SHOULDER - into * into, 0.0))


## Footprint contact below `origin` along `down`. `fwd` and `side` are unit vectors perpendicular to
## `down` (the wheel's heading and its right). `centre` is the centre ray's hit, already cast by the
## caller from `origin` over `max_dist` ({} on a miss). Returns {} when nothing is under the tyre,
## otherwise the Surface contract's keys, with `distance` the centre-equivalent ray distance (where
## the tyre's bottom point would meet flat ground holding it at the same height), plus `rays`
## (queries made, the centre included), `edge` (true when an edge corner carries the tyre) and `at`
## (where on the tyre it is carried: offset along the heading and across the tread, metres).
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
	var rays = 1
	# The caller's centre ray stops at max_dist; recast it as far as the other samples reach, so that a
	# miss means no ground there at all (an edge to a drop), not merely ground out of the wheel's reach.
	var middle = centre
	if centre.is_empty():
		middle = surface.contact(origin, down, reach, hint)
		rays += 1
	# Samples: [x, y, residual from the plane under the centre (INF on a miss), hit]. Index 0 is the
	# centre, 1-4 the ALONG samples, 5-8 the ACROSS samples.
	var samples = [[0.0, 0.0, 0.0, middle]]
	for f in ALONG:
		samples.append([f * radius, 0.0, 0.0, {}])
	for f in ACROSS:
		samples.append([0.0, f * tread, 0.0, {}])
	# The outer ring first. Anything under the tyre from outside it (a kerb, an edge, a drop) reaches
	# the outer samples before the inner ones, so on smooth ground the inner ones are not needed.
	for k in OUTER:
		samples[k][3] = surface.contact(
			origin + fwd * samples[k][0] + side * samples[k][1], down, reach, hint
		)
		rays += 1
	# Plane under the centre, as ray distance d(x, y) = ref + gf x + gs y, from the centre hit, or the
	# first other hit when the centre misses (a wheel beside a drop).
	var base = samples[0] if not centre.is_empty() else null
	for k in OUTER:
		if base == null and bearing(samples[k][3], up):
			base = samples[k]
	if base == null:
		return {}
	var gf = 0.0
	var gs = 0.0
	var nu = base[3].normal.dot(up)
	if nu > .05:
		gf = base[3].normal.dot(fwd) / nu
		gs = base[3].normal.dot(side) / nu
	var ref = base[3].distance - gf * base[0] - gs * base[1]
	samples[0][2] = residual(samples[0], ref, gf, gs)
	# Smooth ground under the whole tyre, the usual case: every sample agrees with the plane under the
	# centre and none comes near holding the tyre up, so the centre ray is the answer.
	if smooth(samples, OUTER, centre, ref, gf, gs, radius, tread):
		centre.rays = rays
		centre.edge = false
		centre.at = Vector2.ZERO
		return centre
	for k in INNER:
		samples[k][3] = surface.contact(
			origin + fwd * samples[k][0] + side * samples[k][1], down, reach, hint
		)
		samples[k][2] = residual(samples[k], ref, gf, gs)
		rays += 1
	# Edges between neighbouring samples on each line, largest disagreement first, so the bisection
	# budget always goes to the same edges while the tyre moves across them.
	var gaps = []
	for pair in PAIRS:
		var ra = samples[pair[0]][2]
		var rb = samples[pair[1]][2]
		if is_inf(ra) and is_inf(rb):
			continue
		var gap = INF if is_inf(ra) or is_inf(rb) else absf(ra - rb)
		if gap > EDGE_TOL:
			gaps.append([gap, pair])
	gaps.sort_custom(func(p, q): return p[0] > q[0])
	var edges = []
	var extra = 0
	for g in gaps:
		var a = samples[g[1][0]]
		var b = samples[g[1][1]]
		var levels = ceili(log(Vector2(b[0] - a[0], b[1] - a[1]).length() / BRACKET) / log(2.0))
		if extra + levels > MAX_EXTRA:
			continue
		var high = a if a[2] < b[2] else b
		var low = b if a[2] < b[2] else a
		# The nearest high-side ray on a bearing surface. A slightly tilted ray close to the edge can strike
		# the kerb face part way up: it still narrows the bracket, but the tyre rests on the top, so the
		# edge takes its height from `top`. On a smooth slope `top` ends 1 mm from the low side and no
		# edge is found (comparing against the first high sample, 3.5 cm up a sausage kerb's 25 degree
		# side, made a false edge that came and went, jumping the wheel 3 cm).
		var top = high
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
			var split = top[2] + EDGE_TOL if is_inf(low[2]) else (top[2] + low[2]) * .5
			if mid[2] <= split:
				high = mid
				if bearing(mid[3], up):
					top = mid
			else:
				low = mid
		# An edge: its high side's corner, nearer the tyre than any bisection ray on that side, is what the
		# tyre meets. Otherwise (a smooth hump or dip) the bisection rays are dropped: a candidate that
		# exists on some ticks and not others makes the wheel flicker, and the fixed samples are dense
		# enough to follow a kerb's shape.
		if bearing(top[3], up) and (is_inf(low[2]) or low[2] - top[2] > EDGE_TOL):
			edges.append([(high[0] + low[0]) * .5, (high[1] + low[1]) * .5, top])
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
			[
				s[3].distance + drop(s[0], s[1], radius, tread),
				s[3].normal,
				s[3].point,
				s[3].surface,
				false,
				Vector2(s[0], s[1])
			]
		)
	# The tyre on an edge's corner takes the high side's surface normal (5.2: normals from the ground).
	# The rigid tread's own normal there leans away from the edge, and its climb rate then reaches the
	# damper whole: with no tyre compliance or unsprung mass that gave 9-28x static load on a 5 cm step.
	for e in edges:
		var ground = ref + gf * e[0] + gs * e[1] + e[2][2]
		var point = origin + fwd * e[0] + side * e[1] + down * ground
		cands.append(
			[
				ground + drop(e[0], e[1], radius, tread),
				e[2][3].normal,
				point,
				e[2][3].surface,
				true,
				Vector2(e[0], e[1])
			]
		)
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
		"edge": chosen[4],
		"at": chosen[5]
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


## A sample's ground distance less the plane under the centre's there (INF on a miss).
static func residual(s, ref, gf, gs):
	return INF if s[3].is_empty() else s[3].distance - (ref + gf * s[0] + gs * s[1])


## Sets the residual of samples `ks` and returns true if they agree with the plane under a hit centre
## and none comes within BLEND of holding the tyre up (samples not in `ks` were checked before).
static func smooth(samples, ks, centre, ref, gf, gs, radius, tread):
	var ok = not centre.is_empty()
	for k in ks:
		var s = samples[k]
		s[2] = residual(s, ref, gf, gs)
		ok = (
			ok
			and absf(s[2]) <= SMOOTH_TOL
			and s[3].distance + drop(s[0], s[1], radius, tread) >= centre.distance + BLEND
		)
	return ok


## One bisection ray at offset (x, y), with its residual from the plane under the centre.
static func sample(surface, origin, down, fwd, side, x, y, reach, hint, ref, gf, gs):
	var hit = surface.contact(origin + fwd * x + side * y, down, reach, hint)
	if hit.is_empty():
		return [x, y, INF, hit]
	return [x, y, hit.distance - (ref + gf * x + gs * y), hit]
