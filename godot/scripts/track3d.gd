extends RefCounted
## Circuit geometry as a ribbon in 3-space: a centreline curve carrying an orthonormal frame.
##
## This is the replacement for the plan-view model in track.gd, where the road was a height
## function z = f(x, y) over the ground plane. That representation cannot express an overpass,
## because f is single valued, and it degrades banking into a linear cross-slope applied to a
## horizontal width. Here every sample stores a position and a (tangent, right, up) frame; bank is
## a rotation about the tangent, and every query resolves in 3-space, so two decks stacked at the
## same plan position remain distinct.
##
## Coordinates follow the rest of the project. Simulation space is (x, y, z): x and y lie on the
## ground plane with positive y "down" in the top-down view, and z is altitude. Rendering maps
## (x, y, z) to Godot (x, z, y), and that conversion stays in circuit_world.gd. Lateral offsets are
## positive to the driver's right, matching track.gd's `lat`.
##
## The control-point document is unchanged. Schema 1 already permits two points to share a plan
## position at different heights, so existing circuits load here without migration and overpasses
## become expressible immediately.

const UP = Vector3(0, 0, 1)
## Spatial-hash cell, metres. The index is keyed on the ground plane, as track.gd's is: a plan cell
## holds the samples of every deck above it, and the candidates inside it are then compared by true
## 3-space distance. Indexing in three dimensions instead would force cubic shell searches, which
## measured far slower on cold lookups without resolving decks any better.
const CELL = 40.0
## Below this the tangent is too close to vertical for the world-up reference frame, and the frame
## is carried forward from the previous sample by parallel transport instead.
const FRAME_EPS = 1e-3
## Cross-section profiles are resampled onto this many stations across the full width before being
## interpolated between control points, so profiles of differing detail blend without special cases.
const PROFILE_N = 33
## Surface classification, shared with track.gd so consumers read the same ids and grip values.
const SURF = [
	{"id": 0, "grip": 1.0, "rr": 0.012, "drag": 0.0, "bump": 0.0},
	{"id": 1, "grip": 1.03, "rr": 0.016, "drag": 0.0, "bump": 0.55},
	{"id": 2, "grip": 0.55, "rr": 0.060, "drag": 0.006, "bump": 0.22},
	{"id": 3, "grip": 0.62, "rr": 0.220, "drag": 0.030, "bump": 0.30},
	{"id": 4, "grip": 0.97, "rr": 0.013, "drag": 0.0, "bump": 0.03}
]

var data = {}
var samples = []
var length = 0.0
var spatial = {}
var checkpoints = []


## Deep-copy a structurally validated document, apply legacy defaults and rebuild derived data.
func load_data(d):
	data = d.duplicate(true)
	for key in ["paint", "curbOverride"]:
		if not data.has(key):
			data[key] = {}
	if not data.has("objects"):
		data.objects = []
	if not data.has("curbAuto"):
		data.curbAuto = true
	if not data.has("autoBarriers"):
		data.autoBarriers = true
	if not data.has("name"):
		data.name = "Untitled"
	if not data.has("startS"):
		data.startS = null
	if not data.has("gridS"):
		data.gridS = null
	for p in data.points:
		p.z = p.get("z", 0.0)
		p.bank = p.get("bank", 0.0)
		p.profile = p.get("profile", [])
	rebuild()


## Uniform Catmull-Rom, evaluated on Vector3 control positions rather than per axis.
func cat3(a, b, c, d, t):
	return (
		0.5
		* (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
	)


## Recompute samples, frames, arc length, curvature, curbs and the spatial hash.
func rebuild():
	samples.clear()
	spatial.clear()
	length = 0.0
	var P = data.points
	var n = P.size()
	if n < 3:
		return
	for i in n:
		var pa = control_pos(P[posmod(i - 1, n)])
		var pb = control_pos(P[i])
		var pc = control_pos(P[(i + 1) % n])
		var pd = control_pos(P[(i + 2) % n])
		# Step count follows the 3-space chord, so a steep climb is sampled as finely as a flat run.
		var steps = maxi(6, int(ceil(pb.distance_to(pc) / 1.5)))
		var b = P[i]
		var c = P[(i + 1) % n]
		for k in steps:
			var t = float(k) / steps
			var ease = t * t * (3 - 2 * t)
			samples.append(
				{
					"seg": i,
					"t": t,
					"s": 0.0,
					"len": 0.0,
					"pos": cat3(pa, pb, pc, pd, t),
					"w": lerpf(b.w, c.w, ease),
					"bank": deg_to_rad(lerpf(b.bank, c.bank, ease)),
					"curb": false,
					"curv": 0.0,
					"kv": 0.0,
					"grade": 0.0
				}
			)
	var N = samples.size()
	for i in N:
		var a = samples[i]
		a.s = length
		a.len = a.pos.distance_to(samples[(i + 1) % N].pos)
		length += a.len
	build_frames()
	build_curvature()
	build_curbs()
	build_profiles()
	build_spatial()
	build_checkpoints()


static func control_pos(p):
	return Vector3(p.x, p.y, p.z)


## Tangent by central difference, then an orthonormal frame. The reference frame uses world up, so
## a level road has right exactly horizontal and bank means what a surveyor means by it. Where the
## tangent approaches vertical that reference degenerates, and the frame is parallel-transported
## from the previous sample instead (double reflection), which keeps loops and walls well defined.
func build_frames():
	var N = samples.size()
	var carried = Vector3.ZERO
	for i in N:
		var a = samples[posmod(i - 1, N)]
		var b = samples[i]
		var c = samples[(i + 1) % N]
		var tan_v = c.pos - a.pos
		if tan_v.length_squared() < 1e-12:
			tan_v = c.pos - b.pos
		tan_v = tan_v.normalized()
		var right = UP.cross(tan_v)
		if right.length() < FRAME_EPS:
			right = transport(carried, samples[posmod(i - 1, N)].get("tan", tan_v), tan_v)
		right = right.normalized()
		var up = tan_v.cross(right).normalized()
		carried = right
		# Bank is a rotation of the frame about the tangent, not a height offset applied to a
		# horizontal width. Road width is therefore measured across the banked surface, which is
		# what "12 m wide" means on a banked circuit.
		var cb = cos(b.bank)
		var sb = sin(b.bank)
		b.tan = tan_v
		b.right = (right * cb - up * sb).normalized()
		b.up = tan_v.cross(b.right).normalized()
		b.grade = tan_v.z
		# Plan-view aliases. Consumers written against track.gd read x/y/z and the ground-plane
		# tangent and normal directly off a sample; keeping them means the ribbon can be dropped in
		# without touching rendering, the editor or the barrier builder.
		b.x = b.pos.x
		b.y = b.pos.y
		b.z = b.pos.z
		var plan = Vector2(tan_v.x, tan_v.y)
		plan = plan.normalized() if plan.length() > 1e-9 else Vector2(1, 0)
		b.tx = plan.x
		b.ty = plan.y
		b.nx = -plan.y
		b.ny = plan.x


## Double-reflection parallel transport of `vec` from tangent `t0` to tangent `t1`.
static func transport(vec, t0, t1):
	if vec.length_squared() < 1e-12:
		return Vector3(1, 0, 0)
	var v1 = t1 - t0
	var c1 = v1.length_squared()
	if c1 < 1e-12:
		return vec
	var reflected = vec - v1 * (2.0 * v1.dot(vec) / c1)
	return reflected


## Curvature vector k = dT/ds, split into the frame. `curv` is the component about up: positive
## turns right, matching track.gd. `kv` is the component about right: negative over a crest, which
## is what the effective-gravity term expects.
func build_curvature():
	var N = samples.size()
	for i in N:
		var a = samples[posmod(i - 1, N)]
		var b = samples[i]
		var c = samples[(i + 1) % N]
		var ds = maxf(a.len + b.len, 1e-6)
		var k = (c.tan - a.tan) / ds
		b.curv = k.dot(b.right)
		b.kv = k.dot(b.up)


## Curbs are decided per control segment, as in track.gd: a segment is curbed when its peak lateral
## curvature is tight enough, unless the document overrides it.
func build_curbs():
	var n = data.points.size()
	var peak = []
	peak.resize(n)
	peak.fill(0.0)
	for sm in samples:
		peak[sm.seg] = maxf(peak[sm.seg], absf(sm.curv))
	var curbs = []
	for i in n:
		var ov = data.curbOverride.get(str(i), "")
		curbs.append(ov == "on" or (ov != "off" and data.curbAuto and peak[i] > 1.0 / 30.0))
	for sm in samples:
		sm.curb = curbs[sm.seg]


func cell_of(p):
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func build_spatial():
	for i in samples.size():
		var key = cell_of(samples[i].pos)
		if not spatial.has(key):
			spatial[key] = []
		spatial[key].append(i)


## Surface position at arc station `sm`, `lat` metres to the right across the banked plane, with
## the cross-section profile applied. A flat cross-section reduces to the banked plane exactly.
static func surface_point(sm, lat):
	var u = lat / maxf(sm.w * .5, 1e-6)
	return sm.pos + sm.right * lat - sm.up * profile_drop(sm, u)


## Nearest sample index to a point in 3-space. `hint` is the previous result for this querier; the
## local window around it is searched first, which is what keeps a car on its own deck where two
## sections of circuit overlap in plan view.
func nearest(p, hint = -1):
	var N = samples.size()
	var best = 0
	var bd = INF
	if hint >= 0 and N > 0:
		for k in range(-40, 41):
			var i = posmod(hint + k, N)
			var d = samples[i].pos.distance_squared_to(p)
			if d < bd:
				bd = d
				best = i
		# 20 m: far beyond a step's travel, and far tighter than the vertical separation any real
		# overpass uses, so the window cannot cross to the other deck.
		if bd < 400:
			return best
	var base = cell_of(p)
	for radius in [1, 3, 8]:
		for bx in range(base.x - radius, base.x + radius + 1):
			for by in range(base.y - radius, base.y + radius + 1):
				for i in spatial.get(Vector2i(bx, by), []):
					# Candidates come from a plan cell, but the comparison is 3-space, so stacked
					# decks in the same cell resolve to whichever is genuinely nearer.
					var d = samples[i].pos.distance_squared_to(p)
					if d < bd:
						bd = d
						best = i
		# Accept only once the found sample is nearer than the unsearched shell, otherwise a closer
		# sample could still sit just outside the cells examined so far.
		var edge = minf(
			minf(p.x - (base.x - radius) * CELL, (base.x + radius + 1) * CELL - p.x),
			minf(p.y - (base.y - radius) * CELL, (base.y + radius + 1) * CELL - p.y)
		)
		if bd < edge * edge:
			return best
	if bd < INF:
		return best
	for i in N:
		var d = samples[i].pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Project onto the ribbon. Two call forms are accepted:
##   project(point: Vector3, hint) — the real query; overlapping decks resolve by 3-space distance.
##   project(x, y, hint)           — plan-only compatibility with track.gd. A plan position cannot
##                                   name a deck on its own, so it probes at the hint's height.
## The second form exists so the ribbon can be dropped in beneath callers written against the old
## model. Phase 3 gives those callers real 3-space positions and it goes away.
func project(a, b = -1, c = -1):
	if a is Vector3:
		return project_at(a, int(b))
	var hint = int(c)
	return project_at(Vector3(float(a), float(b), probe_height(hint)), hint)


## Returns the arc station, the signed lateral offset across the banked surface, the signed height
## above that surface, and a hint for the next call. Genuinely three dimensional: `vert` is a
## measured quantity, not a byproduct of a height lookup.
## Frames are interpolated with a normalized lerp rather than slerp. Adjacent samples are about
## 1.5 m apart, so the angle between their frames is a fraction of a degree and the two agree to
## far better than the solver cares about; slerp's acos and sin ran five times per physics tick.
func project_at(p, hint = -1):
	if samples.is_empty():
		return {
			"idx": 0,
			"t": 0.0,
			"s": 0.0,
			"lat": 0.0,
			"vert": 0.0,
			"width": 0.0,
			"curb": false,
			"pos": p,
			"tan": Vector3(1, 0, 0),
			"right": Vector3(0, 1, 0),
			"up": UP
		}
	var i = nearest(p, hint)
	var N = samples.size()
	var bd = INF
	var result = {}
	for j in [posmod(i - 1, N), i]:
		var a = samples[j]
		var b = samples[(j + 1) % N]
		var seg = b.pos - a.pos
		var l2 = maxf(seg.length_squared(), 1e-9)
		var t = clampf((p - a.pos).dot(seg) / l2, 0, 1)
		var foot = a.pos + seg * t
		var d = p.distance_squared_to(foot)
		if d < bd:
			bd = d
			var right = a.right.lerp(b.right, t).normalized()
			var up = a.up.lerp(b.up, t).normalized()
			var delta = p - foot
			var tan_v = a.tan.lerp(b.tan, t).normalized()
			var plan = Vector2(tan_v.x, tan_v.y)
			plan = plan.normalized() if plan.length() > 1e-9 else Vector2(1, 0)
			result = {
				"idx": j,
				"t": t,
				"s": a.s + a.len * t,
				"lat": delta.dot(right),
				"vert": delta.dot(up),
				"width": lerpf(a.w, b.w, t),
				"curb": a.curb,
				"pos": foot,
				"tan": tan_v,
				"right": right,
				"up": up,
				# Plan-view aliases matching track.gd's projection result, so consumers written
				# against the old model read the same keys from the same call.
				"px": foot.x,
				"py": foot.y,
				"tx": plan.x,
				"ty": plan.y
			}
	return result


## Centreline pose at arc distance `s`, wrapped. Mirrors track.gd's pos_at for callers that walk
## the circuit by distance rather than by position.
func pose_at(s):
	var N = samples.size()
	if N == 0:
		return {"pos": Vector3.ZERO, "tan": Vector3(1, 0, 0), "right": Vector3(0, 1, 0), "up": UP, "w": 0.0}
	var d = fposmod(s, length)
	var lo = 0
	var hi = N - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if samples[mid].s <= d:
			lo = mid
		else:
			hi = mid - 1
	var a = samples[lo]
	var b = samples[(lo + 1) % N]
	var t = clampf((d - a.s) / maxf(a.len, 1e-6), 0, 1)
	return {
		"pos": a.pos.lerp(b.pos, t),
		"tan": a.tan.lerp(b.tan, t).normalized(),
		"right": a.right.lerp(b.right, t).normalized(),
		"up": a.up.lerp(b.up, t).normalized(),
		"w": lerpf(a.w, b.w, t),
		"curb": a.curb,
		"curv": lerpf(a.curv, b.curv, t),
		"kv": lerpf(a.kv, b.kv, t)
	}


## Resample a control point's [u, drop] pairs onto the fixed PROFILE_N grid across u in [-1, 1],
## where u is the fraction of half width and drop is metres below the banked plane. Returns null
## for a flat cross-section so the common case costs nothing.
static func profile_grid(pairs):
	if not pairs is Array or pairs.is_empty():
		return null
	var pts = []
	for pair in pairs:
		if pair is Array and pair.size() >= 2:
			pts.append(Vector2(clampf(float(pair[0]), -1.0, 1.0), float(pair[1])))
	if pts.is_empty():
		return null
	pts.sort_custom(func(a, b): return a.x < b.x)
	var grid = PackedFloat32Array()
	grid.resize(PROFILE_N)
	var flat = true
	for i in PROFILE_N:
		var u = -1.0 + 2.0 * i / (PROFILE_N - 1)
		var v = pts[0].y
		if u >= pts[-1].x:
			v = pts[-1].y
		elif u > pts[0].x:
			for k in range(1, pts.size()):
				if u <= pts[k].x:
					var span = maxf(pts[k].x - pts[k - 1].x, 1e-6)
					v = lerpf(pts[k - 1].y, pts[k].y, (u - pts[k - 1].x) / span)
					break
		grid[i] = v
		flat = flat and absf(v) < 1e-4
	return null if flat else grid


## Per-sample cross-section, blended between the two bounding control points with the same easing
## used for width and bank. Samples on a flat stretch keep a null profile.
func build_profiles():
	var P = data.points
	var n = P.size()
	var grids = []
	var any = false
	for i in n:
		var g = profile_grid(P[i].get("profile", []))
		grids.append(g)
		any = any or g != null
	for sm in samples:
		sm.profile = null
	if not any:
		return
	for sm in samples:
		var ga = grids[sm.seg]
		var gb = grids[(sm.seg + 1) % n]
		if ga == null and gb == null:
			continue
		var ease = sm.t * sm.t * (3 - 2 * sm.t)
		var out = PackedFloat32Array()
		out.resize(PROFILE_N)
		for i in PROFILE_N:
			out[i] = lerpf(0.0 if ga == null else ga[i], 0.0 if gb == null else gb[i], ease)
		sm.profile = out


## d(drop)/du at lateral fraction `u`, by central difference on the resampled grid. Needed for the
## surface normal: inside a ditch the road tilts, and a normal taken from the frame alone would
## leave the car flat on a Karussell.
static func profile_slope(sm, u):
	var grid = sm.get("profile")
	if grid == null:
		return 0.0
	var step = 2.0 / (PROFILE_N - 1)
	return (profile_drop(sm, minf(u + step, 1.0)) - profile_drop(sm, maxf(u - step, -1.0))) / (2.0 * step)


## Outward surface normal at lateral fraction `u`. The surface is S(lat) = pos + right*lat -
## up*drop(u); differentiating and crossing with the tangent gives up + right * d(drop)/d(lat).
static func surface_normal(sm, u):
	var slope = profile_slope(sm, u) / maxf(sm.w * .5, 1e-6)
	return (sm.up + sm.right * slope).normalized()


## Metres the surface drops below the banked plane at lateral fraction `u` in [-1, 1].
static func profile_drop(sm, u):
	var grid = sm.get("profile")
	if grid == null:
		return 0.0
	var f = clampf((u + 1.0) * .5, 0.0, 1.0) * (PROFILE_N - 1)
	var i = clampi(int(f), 0, PROFILE_N - 2)
	return lerpf(grid[i], grid[i + 1], f - i)


## Checkpoints every ~90 m of lap, matching track.gd so lap validation is unchanged.
func build_checkpoints():
	checkpoints.clear()
	if samples.is_empty() or length <= 0:
		return
	var count = clampi(roundi(length / 90.0), 3, 16)
	var start = float(data.startS if data.startS != null else 0.0)
	for k in range(1, count):
		checkpoints.append(fposmod(start + length * k / count, length))


## Centreline pose at arc distance `s`, in the shape track.gd's pos_at returns, plus the 3-space
## frame. Existing callers read x/y/z/h/w/bank/curv; new code can use pos/tan/right/up.
func pos_at(s):
	if samples.is_empty() or length <= 0:
		return {
			"x": 0.0,
			"y": 0.0,
			"z": 0.0,
			"h": 0.0,
			"w": 12.0,
			"bank": 0.0,
			"curv": 0.0,
			"kv": 0.0,
			"pos": Vector3.ZERO,
			"tan": Vector3(1, 0, 0),
			"right": Vector3(0, 1, 0),
			"up": UP
		}
	var pose = pose_at(s)
	return {
		"x": pose.pos.x,
		"y": pose.pos.y,
		"z": pose.pos.z,
		"h": atan2(pose.tan.y, pose.tan.x),
		"w": pose.w,
		"bank": bank_of(pose),
		"curv": pose.curv,
		"kv": pose.kv,
		"pos": pose.pos,
		"tan": pose.tan,
		"right": pose.right,
		"up": pose.up
	}


## Lateral curvature at arc distance `s`: exactly pos_at(s).curv (same search, same interpolation),
## without building the pose. The showcase driver samples it 34 times per tick for its speed plan.
func curv_at(s):
	var N = samples.size()
	if N == 0 or length <= 0:
		return 0.0
	var d = fposmod(s, length)
	var lo = 0
	var hi = N - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if samples[mid].s <= d:
			lo = mid
		else:
			hi = mid - 1
	var a = samples[lo]
	var b = samples[(lo + 1) % N]
	var t = clampf((d - a.s) / maxf(a.len, 1e-6), 0, 1)
	return lerpf(a.curv, b.curv, t)


## Bank recovered from a frame: the roll of `right` out of the ground plane. Signed so that a
## positive value raises the left edge, matching the control-point convention.
static func bank_of(pose):
	return asin(clampf(-pose.right.z, -1.0, 1.0))


## Smoothed lateral curvature around arc distance `s`, matching track.gd's span and stride.
func curvature_at(s, span = 30.0):
	var total = 0.0
	var n = 0
	for d in range(-int(span), int(span) + 1, 5):
		total += pose_at(s + d).curv
		n += 1
	return total / maxi(n, 1)


## Grid pose, from gridS when present, otherwise 10 m before the start line.
func grid_pose():
	var s = data.get("gridS")
	return pos_at(float(s) if s != null else float(data.startS if data.startS != null else 0.0) - 10.0)


## Surface altitude and gradients beneath a plan position, in track.gd's elev_at shape. `normal`
## and `up` are the genuine 3-space surface orientation, which the plan-view model could not give:
## there gx/gy were reconstructed from a scalar grade and a cross-slope.
func elev_at(x, y, hint = -1):
	if samples.is_empty():
		return {"z": 0.0, "gx": 0.0, "gy": 0.0, "grade": 0.0, "bank": 0.0, "kv": 0.0, "up": UP}
	var pr = project(Vector3(x, y, probe_height(hint)), hint)
	var sm = samples[pr.idx]
	var u = pr.lat / maxf(pr.width * .5, 1e-6)
	var surface = pr.pos + pr.right * pr.lat - pr.up * profile_drop(sm, u)
	# Surface gradient in the ground plane from the outward normal: for a plane with unit normal n,
	# dz/dx = -n.x / n.z and dz/dy = -n.y / n.z.
	var normal = surface_normal(sm, u)
	var nz = normal.z
	if absf(nz) < 1e-4:
		nz = 1e-4 if nz >= 0 else -1e-4
	return {
		"z": surface.z,
		"gx": -normal.x / nz,
		"gy": -normal.y / nz,
		"grade": pr.tan.z,
		"bank": asin(clampf(-pr.right.z, -1.0, 1.0)),
		"kv": lerpf(sm.kv, samples[(pr.idx + 1) % samples.size()].kv, pr.t),
		"up": normal
	}


## Classify the surface beneath a wheel and write its road height, as track.gd's surface_at does.
## Road and curb take priority over painted runoff; `w.sIdx` carries the projection hint forward.
func surface_at(x, y, w):
	var hint = int(w.get("sIdx", -1))
	var pr = project(Vector3(x, y, probe_height(hint)), hint)
	w.sIdx = pr.idx
	if samples.is_empty():
		w.roadZ = 0.0
		return SURF[0]
	var sm = samples[pr.idx]
	var u = pr.lat / maxf(pr.width * .5, 1e-6)
	var road = (pr.pos + pr.right * pr.lat - pr.up * profile_drop(sm, u)).z
	w.roadZ = road
	w.surfUp = surface_normal(sm, u)
	if absf(pr.lat) <= pr.width / 2:
		return SURF[0]
	if pr.curb and absf(pr.lat) <= pr.width / 2 + 1.4:
		var out = absf(pr.lat) - pr.width / 2
		w.roadZ = (
			road + .045 * smoothstep(0, .6, out) + (.008 * absf(sin(PI * pr.s / 1.1)) if out > .15 else 0.0)
		)
		return SURF[1]
	var paint = int(data.paint.get(str(floori(x / 2)) + "," + str(floori(y / 2)), 0))
	return SURF[3] if paint == 2 else (SURF[4] if paint == 3 else SURF[2])


## Height to probe at when a caller supplies only a plan position. Compatibility shim for the
## track.gd API, whose queries predate the car carrying a real 3-space position: the last resolved
## sample stands in for "which deck am I on". Callers that know their height should project()
## directly, and phase 3 replaces these plan-only entry points outright.
func probe_height(hint):
	if hint >= 0 and hint < samples.size():
		return samples[hint].pos.z
	return 0.0


## Derived trackside barriers, never serialized. Ported from track.gd with one change: the runoff
## probe resolves at the station's own height, so on an overpass a barrier belongs to the deck that
## spawned it instead of to whichever road happens to be nearer in plan. Barrier segments are still
## planar; giving them a vertical extent is phase 3.
var barriers = []
var barrier_grid = {}


func build_barriers():
	barriers = []
	barrier_grid = {}
	if samples.is_empty() or not data.get("autoBarriers", true):
		return
	var step = 6.0
	var stations = int(length / step)
	var user = []
	for o in data.objects:
		if o.type != "cone":
			user.append([Vector2(o.x1, o.y1), Vector2(o.x2, o.y2)])
	var curv = []
	for k in stations + 1:
		curv.append(curvature_at(k * step))
	for side in [-1, 1]:
		# Runoff per station, then widened ahead of/after corners, smoothed and slew-limited so the
		# barrier line flows (at most ~1.2 m sideways per 6 m) instead of zigzagging.
		var raw = []
		for k in stations + 1:
			var c = curv[k]
			var outside = side * c < 0
			var v = minf(sqrt(11.0 / maxf(absf(c), .0001)), 90.0)
			raw.append(
				clampf(6 + v * .32, 8, 32) if outside and absf(c) > 1.0 / 400 else clampf(6 + v * .08, 7, 14)
			)
		var wide = []
		for k in raw.size():
			var m = 0.0
			for j in range(-8, 9):
				m = maxf(m, raw[posmod(k + j, raw.size())])
			wide.append(m)
		var runoffs = []
		for k in wide.size():
			var total = 0.0
			for j in range(-5, 6):
				total += wide[posmod(k + j, wide.size())]
			runoffs.append(total / 11.0)
		for sweep in 2:
			for k in range(1, runoffs.size()):
				runoffs[k] = clampf(runoffs[k], runoffs[k - 1] - 1.2, runoffs[k - 1] + 1.2)
			for k in range(runoffs.size() - 2, -1, -1):
				runoffs[k] = clampf(runoffs[k], runoffs[k + 1] - 1.2, runoffs[k + 1] + 1.2)
		var prev = null
		var hint = -1
		for k in stations + 1:
			var s = k * step
			var p = pos_at(s)
			var c = curv[k]
			var outside = side * c < 0
			var runoff = runoffs[k]
			var off = side * (p.w / 2 + runoff)
			var pt = Vector2(p.x - sin(p.h) * off, p.y + cos(p.h) * off)
			var pr = project(Vector3(pt.x, pt.y, p.z), hint)
			hint = pr.idx
			var ok = (
				absf(pr.lat) >= pr.width / 2 + 5
				and absf(wrapf(pr.s - s, -length / 2, length / 2)) < runoff + 20
			)
			for seg in user:
				if ok and Geometry2D.get_closest_point_to_segment(pt, seg[0], seg[1]).distance_to(pt) < 12:
					ok = false
			var kind = "tire" if outside and absf(c) > 1.0 / 45 else "wall"
			if ok and prev != null and k > 0:
				barriers.append(
					{
						"type": kind,
						"x1": prev[0].x,
						"y1": prev[0].y,
						"x2": pt.x,
						"y2": pt.y,
						"auto": true,
						"side": side
					}
				)
			prev = [pt, kind] if ok else null
	for i in barriers.size():
		var o = barriers[i]
		for cx in range(floori(minf(o.x1, o.x2) / 40), floori(maxf(o.x1, o.x2) / 40) + 1):
			for cy in range(floori(minf(o.y1, o.y2) / 40), floori(maxf(o.y1, o.y2) / 40) + 1):
				var cell = Vector2i(cx, cy)
				if not barrier_grid.has(cell):
					barrier_grid[cell] = []
				barrier_grid[cell].append(i)


## Auto barrier indices whose 40 m cells touch the 3x3 neighbourhood of (x, y).
func barriers_near(x, y):
	var found = {}
	var cx = floori(x / 40)
	var cy = floori(y / 40)
	for bx in range(cx - 1, cx + 2):
		for by in range(cy - 1, cy + 2):
			for i in barrier_grid.get(Vector2i(bx, by), []):
				found[i] = true
	return found.keys()


## Geometry validation. Unlike track.gd this does not object to a circuit crossing itself in plan
## view: that is how an overpass looks from above, and the ribbon resolves the two decks correctly.
## A crossing is only reported when the two sections are close enough in height to actually meet.
func validate():
	var errors = []
	var warnings = []
	if data.points.size() < 3 or length < 5:
		errors.append("Place at least three distinct points.")
	if data.startS == null:
		errors.append("Place a start / finish line.")
	var max_grade = 0.0
	for sm in samples:
		max_grade = maxf(max_grade, absf(sm.grade))
	if max_grade > .25:
		warnings.append("Very steep grade: %.0f%%." % (max_grade * 100))
	var conflict = false
	var stride = 6
	var cells = {}
	for i in range(0, samples.size(), stride):
		var a = samples[i]
		var key = Vector2i(floori(a.x / 40), floori(a.y / 40))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(i)
	for i in range(0, samples.size(), stride):
		if conflict:
			break
		var a = samples[i]
		for bx in range(floori(a.x / 40) - 1, floori(a.x / 40) + 2):
			for by in range(floori(a.y / 40) - 1, floori(a.y / 40) + 2):
				for j in cells.get(Vector2i(bx, by), []):
					# Ignore neighbours along the lap; only a genuinely separate section counts.
					if absf(wrapf(samples[j].s - a.s, -length / 2, length / 2)) < maxf(a.w, 30.0):
						continue
					var gap = Vector2(samples[j].x - a.x, samples[j].y - a.y).length()
					if gap < (a.w + samples[j].w) * .5 and absf(samples[j].pos.z - a.pos.z) < 3.0:
						conflict = true
	if conflict:
		warnings.append("Two sections overlap at the same height; separate them or raise one.")
	return {"errors": errors, "warnings": warnings}


## Serialize a copy, restoring cone rest positions and stripping transient collision fields.
func to_json():
	var result = data.duplicate(true)
	result.schema = 1
	result.savedAt = Time.get_datetime_string_from_system(true) + "Z"
	for o in result.objects:
		for field in ["vx", "vy", "hit"]:
			o.erase(field)
		if o.type == "cone":
			o.x = o.ox
			o.y = o.oy
	return result
