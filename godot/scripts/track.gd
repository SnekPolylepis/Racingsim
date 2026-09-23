extends RefCounted
## Editable circuit document plus derived spline samples, checkpoints and spatial queries.
## Point bank is degrees; sampled bank is radians. Positive lateral distance is driver-right.
## Only data is serialized. Geometry/curb mutations require rebuild; paint/object edits do not.
# Source coordinates are retained: (x,y,height) maps to Godot (x,height,y).
const SURF = [
	{"id": 0, "grip": 1.0, "rr": 0.012, "drag": 0.0, "bump": 0.0},
	{"id": 1, "grip": 1.03, "rr": 0.016, "drag": 0.0, "bump": 0.55},
	{"id": 2, "grip": 0.55, "rr": 0.060, "drag": 0.006, "bump": 0.22},
	{"id": 3, "grip": 0.62, "rr": 0.220, "drag": 0.030, "bump": 0.30},
	# Tarmac runoff (paint 3): nearly road grip, but off the circuit for track-limit purposes.
	{"id": 4, "grip": 0.97, "rr": 0.013, "drag": 0.0, "bump": 0.03}
]
var data = {}
var samples = []
var length = 0.0
var checkpoints = []
var spatial = {}


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
	for o in data.objects:
		if o.type == "cone":
			o.ox = o.get("ox", o.x)
			o.oy = o.get("oy", o.y)
	for p in data.points:
		p.z = p.get("z", 0.0)
		p.bank = p.get("bank", 0.0)
	rebuild()


func cat(a, b, c, d, t):
	return (
		0.5
		* (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
	)


## Recompute all spline-dependent caches after point, bank, width or curb changes.
func rebuild():
	samples.clear()
	checkpoints.clear()
	spatial.clear()
	length = 0.0
	var P = data.points
	var n = P.size()
	if n < 3:
		return
	for i in n:
		var a = P[posmod(i - 1, n)]
		var b = P[i]
		var c = P[(i + 1) % n]
		var d = P[(i + 2) % n]
		var steps = maxi(6, int(ceil(Vector2(c.x - b.x, c.y - b.y).length() / 1.5)))
		for k in steps:
			var t = float(k) / steps
			var sm = {
				"seg": i, "t": t, "s": 0.0, "len": 0.0, "curv": 0.0, "kv": 0.0, "grade": 0.0, "curb": false
			}
			for key in ["x", "y", "z"]:
				sm[key] = cat(a[key], b[key], c[key], d[key], t)
			sm.w = lerpf(b.w, c.w, t * t * (3 - 2 * t))
			sm.bank = deg_to_rad(lerpf(b.bank, c.bank, t * t * (3 - 2 * t)))
			samples.append(sm)
	var N = samples.size()
	for i in N:
		var cell = Vector2i(floori(samples[i].x / 40), floori(samples[i].y / 40))
		if not spatial.has(cell):
			spatial[cell] = []
		spatial[cell].append(i)
	for i in N:
		var a = samples[i]
		var b = samples[(i + 1) % N]
		a.s = length
		a.len = Vector2(b.x - a.x, b.y - a.y).length()
		length += a.len
	for i in N:
		var a = samples[posmod(i - 1, N)]
		var b = samples[i]
		var c = samples[(i + 1) % N]
		var tangent = Vector2(c.x - a.x, c.y - a.y).normalized()
		b.tx = tangent.x
		b.ty = tangent.y
		b.nx = -tangent.y
		b.ny = tangent.x
		b.grade = (c.z - a.z) / maxf(a.len + b.len, 0.000001)
	var raw = []
	for i in N:
		var a = samples[posmod(i - 2, N)]
		var b = samples[i]
		var c = samples[(i + 2) % N]
		var ds = maxf(a.len + samples[posmod(i - 1, N)].len + b.len + samples[(i + 1) % N].len, 0.000001)
		b.curv = wrapf(atan2(c.ty, c.tx) - atan2(a.ty, a.tx), -PI, PI) / ds
		raw.append((c.grade - a.grade) / ds)
	var curbs = []
	for i in n:
		var max_c = 0.0
		for sm in samples:
			if sm.seg == i:
				max_c = maxf(max_c, absf(sm.curv))
		var ov = data.curbOverride.get(str(i), "")
		curbs.append(ov == "on" or (ov != "off" and data.curbAuto and max_c > 1.0 / 30.0))
	for i in N:
		var total = 0.0
		for k in range(-3, 4):
			total += raw[posmod(i + k, N)]
		samples[i].kv = total / 7.0
		samples[i].curb = curbs[samples[i].seg]
	var count = clampi(roundi(length / 90.0), 3, 16)
	for k in range(1, count):
		checkpoints.append(
			fposmod(float(data.startS if data.startS != null else 0.0) + length * k / count, length)
		)


## Derived trackside barriers (not serialized). Built by build_barriers() on world rebuild when
## data.autoBarriers is true: armco along the whole lap, tire walls on the outside of slow corners,
## runoff scaled by estimated corner speed. Segments are indexed in a 40 m grid for collisions.
var barriers = []
var barrier_grid = {}


## Smoothed centreline curvature (1/m) around arc distance s; positive turns right.
func curvature_at(s, span = 30.0):
	var total = 0.0
	var n = 0
	for d in range(-int(span), int(span) + 1, 5):
		total += pos_at(s + d).curv
		n += 1
	return total / n


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
		for k in stations + 1:
			var s = k * step
			var p = pos_at(s)
			var c = curv[k]
			var outside = side * c < 0
			var runoff = runoffs[k]
			var off = side * (p.w / 2 + runoff)
			var pt = Vector2(p.x - sin(p.h) * off, p.y + cos(p.h) * off)
			var pr = project(pt.x, pt.y)
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


func nearest(x, y, hint = -1):
	var best = 0
	var bd = INF
	var N = samples.size()
	if hint >= 0:
		for k in range(-40, 41):
			var i = posmod(hint + k, N)
			var a = samples[i]
			var d = (a.x - x) * (a.x - x) + (a.y - y) * (a.y - y)
			if d < bd:
				bd = d
				best = i
		if bd < 400:
			return best
	var cx = floori(x / 40)
	var cy = floori(y / 40)
	for radius in [1, 3, 8]:
		for bx in range(cx - radius, cx + radius + 1):
			for by in range(cy - radius, cy + radius + 1):
				for i in spatial.get(Vector2i(bx, by), []):
					var a = samples[i]
					var d = (a.x - x) * (a.x - x) + (a.y - y) * (a.y - y)
					if d < bd:
						bd = d
						best = i
		var edge = minf(
			minf(x - (cx - radius) * 40, (cx + radius + 1) * 40 - x),
			minf(y - (cy - radius) * 40, (cy + radius + 1) * 40 - y)
		)
		if bd < edge * edge:
			return best
	for i in N:
		var a = samples[i]
		var d = (a.x - x) * (a.x - x) + (a.y - y) * (a.y - y)
		if d < bd:
			bd = d
			best = i
	return best


## Return centerline projection, signed rightward lateral offset and a sample search hint.
func project(x, y, hint = -1):
	if samples.is_empty():
		return {
			"idx": 0,
			"t": 0.0,
			"s": 0.0,
			"lat": 0.0,
			"width": 0.0,
			"curb": false,
			"px": x,
			"py": y,
			"tx": 1.0,
			"ty": 0.0
		}
	var i = nearest(x, y, hint)
	var N = samples.size()
	var bd = INF
	var result = {}
	for j in [posmod(i - 1, N), i]:
		var a = samples[j]
		var b = samples[(j + 1) % N]
		var dx = b.x - a.x
		var dy = b.y - a.y
		var l2 = maxf(dx * dx + dy * dy, 1e-9)
		var t = clampf(((x - a.x) * dx + (y - a.y) * dy) / l2, 0, 1)
		var px = a.x + dx * t
		var py = a.y + dy * t
		var d = (x - px) * (x - px) + (y - py) * (y - py)
		if d < bd:
			bd = d
			result = {
				"idx": j,
				"t": t,
				"s": a.s + a.len * t,
				"lat": ((x - px) * -dy + (y - py) * dx) / sqrt(l2),
				"width": lerpf(a.w, b.w, t),
				"curb": a.curb,
				"px": px,
				"py": py,
				"tx": dx / sqrt(l2),
				"ty": dy / sqrt(l2)
			}
	return result


## Query surface altitude/gradients with bank applied; returns flat defaults for empty drafts.
func elev_at(x, y, hint = -1):
	if samples.is_empty():
		return {"z": 0.0, "gx": 0.0, "gy": 0.0, "grade": 0.0, "bank": 0.0, "kv": 0.0}
	var pr = project(x, y, hint)
	var a = samples[pr.idx]
	var b = samples[(pr.idx + 1) % samples.size()]
	var t = pr.t
	var grade = lerpf(a.grade, b.grade, t)
	var bank = lerpf(a.bank, b.bank, t)
	var tb = tan(bank)
	return {
		"z": lerpf(a.z, b.z, t) - pr.lat * tb,
		"gx": grade * pr.tx + tb * pr.ty,
		"gy": grade * pr.ty - tb * pr.tx,
		"grade": grade,
		"bank": bank,
		"kv": lerpf(a.kv, b.kv, t)
	}


## Road and curb take priority over off-road paint; updates wheel.sIdx for the next query.
## Also writes w.roadZ: banked surface height plus the curb profile (ramp to 4.5 cm with 0.8 cm ridges).
func surface_at(x, y, w):
	var pr = project(x, y, w.sIdx)
	w.sIdx = pr.idx
	if samples.is_empty():
		w.roadZ = 0.0
		return SURF[0]
	var a = samples[pr.idx]
	var b = samples[(pr.idx + 1) % samples.size()]
	var road = lerpf(a.z, b.z, pr.t) - pr.lat * tan(lerpf(a.bank, b.bank, pr.t))
	w.roadZ = road
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


func pos_at(s):
	if samples.is_empty() or length <= 0:
		return {"x": 0.0, "y": 0.0, "z": 0.0, "h": 0.0, "w": 12.0, "bank": 0.0, "curv": 0.0}
	s = fposmod(s, length)
	var lo = 0
	var hi = samples.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) >> 1
		if samples[mid].s <= s:
			lo = mid
		else:
			hi = mid - 1
	var a = samples[lo]
	var b = samples[(lo + 1) % samples.size()]
	var t = (s - a.s) / maxf(a.len, 1e-9)
	return {
		"x": lerpf(a.x, b.x, t),
		"y": lerpf(a.y, b.y, t),
		"z": lerpf(a.z, b.z, t),
		"h": atan2(b.y - a.y, b.x - a.x),
		"w": lerpf(a.w, b.w, t),
		"bank": lerpf(a.bank, b.bank, t),
		"curv": a.curv
	}


func grid_pose():
	var s = data.get("gridS")
	return pos_at(float(s) if s != null else float(data.startS if data.startS != null else 0.0) - 10.0)


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
	# Coarse strict intersection test, ignoring shared endpoints and collinear spans.
	# Spatial candidate filtering preserves the test while avoiding O(n^2) Spa loading stalls.
	var points = []
	for i in range(0, samples.size(), 6):
		points.append(Vector2(samples[i].x, samples[i].y))
	var intersects = false
	var cells = {}
	for i in points.size():
		if intersects:
			break
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		var low = a.min(b) / 40.0
		var high = a.max(b) / 40.0
		var visited = {}
		for cy in range(floori(low.y), floori(high.y) + 1):
			for cx in range(floori(low.x), floori(high.x) + 1):
				var key = Vector2i(cx, cy)
				if not cells.has(key):
					cells[key] = []
				for j in cells[key]:
					if visited.has(j) or i - j <= 1 or (j == 0 and i == points.size() - 1):
						continue
					visited[j] = true
					var c = points[j]
					var d = points[(j + 1) % points.size()]
					if (
						(b - a).cross(c - a) * (b - a).cross(d - a) < -.000001
						and (d - c).cross(a - c) * (d - c).cross(b - c) < -.000001
					):
						intersects = true
						break
				cells[key].append(i)
	if intersects:
		warnings.append("Track crosses itself; separate overlapping sections.")
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
