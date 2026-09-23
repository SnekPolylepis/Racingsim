extends RefCounted
## Bakes a road from a Curve3D and RoadSection keys (REBUILD-PLAN.md P3-02). Pure data in, data out,
## so it runs headless in tests and inside the editor from RoadPath's Bake button.
##
## Tessellation follows P3-00: stations every <= 1.5 m along the path, and at least w/8 across the road
## (more with `road_stations`, needed to resolve an inset ditch). Every station has the same lateral
## topology, so strips stitch without seams:
##   verge | runoff | kerb band (4 stations) | road (road_stations) | kerb band (4) | runoff | verge
## A side with no kerb keeps its kerb band as runoff/verge; a zero-width runoff keeps 5 cm of verge.
## RIBBED kerb bands are subdivided along the road (quarter rib pitch) to carry transverse ridges; the
## ridges vanish at both band edges, so the extra vertices lie on the neighbouring strips' edges.
##
## Frame at a station: tangent t along the road (it climbs with it), right0 = t x UP (level),
## up0 = right0 x t. Bank rotates that frame about t; positive bank raises the left edge.
##
## Optional elevation keys (s, y) replace the curve's own heights with an interpolating cubic spline
## over arc distance s, so an author can draw the plan flat and key the elevation by station.

const RoadSection = preload("res://scripts/track/road_section.gd")
const MAX_STEP = 1.5
const DEFAULT_ROAD_STATIONS = 9
const KERB_SURFACE = 1
## Kerb band stations outward from the road edge, as fractions of kerb width (the edge itself is the
## last road station).
const KERB_F = [.25, .5, .75, 1.0]
const MIN_BAND = .05
## Bank change per metre along the road above which bake() warns. A 2.65 m-wheelbase race car on a
## twist of 0.4 deg/m sees ~3 cm of warp across its axles, enough to lift a wheel on stiff springs
## (measured in P3-02); real circuits spread banking over tens of metres.
const TWIST_WARN_DEG_PER_M = .2
## A ditch needs road stations at least this fine across it to resolve its fillets and walls.
const DITCH_MAX_SPACING = .25
const EASED = [
	"width_left",
	"width_right",
	"bank_deg",
	"crown",
	"kerb_width",
	"kerb_height",
	"rib_height",
	"rib_pitch",
	"runoff_left",
	"runoff_right",
	"verge_left",
	"verge_right",
	"verge_slope_deg",
	"ditch",
	"ditch_offset",
	"ditch_floor",
	"ditch_wall",
	"ditch_angle_deg",
	"ditch_fillet"
]
const STEPPED = [
	"kerb_left",
	"kerb_right",
	"runoff_surface",
	"road_surface",
	"verge_surface",
	"verge_surface_left",
	"verge_surface_right"
]


## Elevation through (s, y) keys: an interpolating cubic spline, natural at the ends of an open road
## and periodic on a closed one. It is C2, so the vertical curvature (and the load it puts through the
## suspension) never steps at a key. Keys sampled from a smooth profile reproduce it (an R 130 m crest
## keyed every 20 m comes back as R 130 m); keys that disagree with each other (a steep crest reached
## from a shallow approach) are honoured exactly, with the curvature redistributed between them.
## Returns [sorted keys, second derivatives].
static func elevation_spline(keys: PackedVector2Array, length: float, closed: bool) -> Array:
	var pts = Array(keys)
	pts.sort_custom(func(a, b): return a.x < b.x)
	var n = pts.size()
	var m = []
	m.resize(n)
	m.fill(0.0)
	if n < 3:
		return [pts, m]
	# Solve A m = r for the second derivatives (dense Gaussian elimination; key counts are small).
	var a = []
	var r = []
	for i in n:
		var row = []
		row.resize(n)
		row.fill(0.0)
		a.append(row)
		r.append(0.0)
	for i in n:
		var has_prev = i > 0 or closed
		var has_next = i < n - 1 or closed
		if not (has_prev and has_next):
			a[i][i] = 1.0  # natural end: zero curvature
			continue
		var ip = posmod(i - 1, n)
		var inx = (i + 1) % n
		var h0 = pts[i].x - pts[ip].x if i > 0 else pts[i].x + length - pts[ip].x
		var h1 = pts[inx].x - pts[i].x if i < n - 1 else pts[inx].x + length - pts[i].x
		a[i][ip] += h0 / 6.0
		a[i][i] += (h0 + h1) / 3.0
		a[i][inx] += h1 / 6.0
		r[i] = (pts[inx].y - pts[i].y) / h1 - (pts[i].y - pts[ip].y) / h0
	for c in n:
		var pivot = c
		for k in range(c + 1, n):
			if absf(a[k][c]) > absf(a[pivot][c]):
				pivot = k
		var tmp = a[c]
		a[c] = a[pivot]
		a[pivot] = tmp
		var tr = r[c]
		r[c] = r[pivot]
		r[pivot] = tr
		for k in range(c + 1, n):
			var factor = a[k][c] / a[c][c]
			for j in range(c, n):
				a[k][j] -= factor * a[c][j]
			r[k] -= factor * r[c]
	for c in range(n - 1, -1, -1):
		var acc = r[c]
		for j in range(c + 1, n):
			acc -= a[c][j] * m[j]
		m[c] = acc / a[c][c]
	return [pts, m]


## Evaluate the spline from elevation_spline() at arc distance s.
static func elevation_at(spline: Array, s: float, length: float, closed: bool) -> float:
	var pts = spline[0]
	var m = spline[1]
	var n = pts.size()
	if n == 0:
		return 0.0
	if n == 1:
		return pts[0].y
	if closed:
		s = fposmod(s, length)
	var i = -1
	for k in n:
		if pts[k].x <= s:
			i = k
	var a
	var b
	var ma
	var mb
	if i < 0 or i == n - 1:
		if not closed:
			return pts[0].y if i < 0 else pts[n - 1].y
		# Wrap-around span from the last key to the first.
		a = Vector2(pts[n - 1].x - (length if i < 0 else 0.0), pts[n - 1].y)
		b = Vector2(pts[0].x + (0.0 if i < 0 else length), pts[0].y)
		ma = m[n - 1]
		mb = m[0]
	else:
		a = pts[i]
		b = pts[i + 1]
		ma = m[i]
		mb = m[i + 1]
	var h = b.x - a.x
	var t = (s - a.x) / h
	var u = 1.0 - t
	return u * a.y + t * b.y + ((u * u * u - u) * ma + (t * t * t - t) * mb) * h * h / 6.0


## Centreline point at arc distance s (wrapped on a closed road, clamped on an open one), with the
## elevation spline applied when there is one.
static func point_at(curve: Curve3D, closed: bool, length: float, spline: Array, s: float) -> Vector3:
	var q = fposmod(s, length) if closed else clampf(s, 0.0, length)
	var p = curve.sample_baked(q, true)
	if not spline.is_empty():
		p.y = elevation_at(spline, q, length, closed)
	return p


## One station: {s, pos, tangent} at arc distance s.
static func station_at(curve: Curve3D, closed: bool, length: float, spline: Array, s: float, eps = .25):
	var tangent = (
		point_at(curve, closed, length, spline, s + eps) - point_at(curve, closed, length, spline, s - eps)
	)
	return {"s": s, "pos": point_at(curve, closed, length, spline, s), "tangent": tangent.normalized()}


## Stations along the curve: [{s, pos, tangent}], evenly spaced at <= step metres. For a closed road
## the last station stops one step short of the start (the strip wraps back to station 0).
static func stations(curve: Curve3D, closed: bool, step: float, elev = PackedVector2Array()) -> Array:
	var length = curve.get_baked_length()
	# 1 % margin: cubic sampling can place stations a hair further apart than the arc step.
	var count = maxi(2, int(ceil(length / (minf(step, MAX_STEP) * .99))))
	var spacing = length / count
	var spline = elevation_spline(elev, length, closed) if not elev.is_empty() else []
	var out = []
	var n = count if closed else count + 1
	for i in n:
		out.append(station_at(curve, closed, length, spline, i * spacing, minf(.25, spacing * .5)))
	return out


## A point `extra` metres beyond the outer edge of the road's verge on one side (sign -1 left, +1 right)
## at arc distance s, continuing the verge's fall. Returns {point, outward (horizontal, away from the
## road), up (banked frame), lat (signed distance from the centreline)}. Used to follow the road with
## walls and scenery.
static func beyond_edge(
	curve: Curve3D, keys: Array, closed: bool, spline: Array, s: float, sign: int, extra: float
) -> Dictionary:
	var length = curve.get_baked_length()
	var st = station_at(curve, closed, length, spline, s)
	var sec = section_at(keys, fposmod(s, length) if closed else s, length, closed)
	var fr = frame(st.tangent, sec.bank_deg)
	var outer = side(sec, sign)[-1]
	var slope = tan(deg_to_rad(sec.verge_slope_deg))
	var lat = outer[0] + sign * extra
	var point = st.pos + fr[0] * lat + fr[1] * (outer[1] - slope * extra)
	var outward = fr[0] * sign
	outward.y = 0.0
	return {"point": point, "outward": outward.normalized(), "up": fr[1], "lat": lat}


## Section values at distance s: numeric values eased between the bounding keys, types and surfaces
## taken from the key at or before s. Keys are wrapped around for a closed road.
static func section_at(keys: Array, s: float, length: float, closed: bool) -> Dictionary:
	if keys.is_empty():
		return values(RoadSection.new())
	var prev = null
	var next = null
	for k in keys:
		if k.at <= s:
			prev = k
		elif next == null:
			next = k
	var span_from = 0.0
	var span_to = 0.0
	if prev == null:
		prev = keys[-1] if closed else keys[0]
		span_from = prev.at - length if closed else prev.at
	else:
		span_from = prev.at
	if next == null:
		next = keys[0] if closed else keys[-1]
		span_to = next.at + length if closed else next.at
	else:
		span_to = next.at
	var a = values(prev)
	var b = values(next)
	var t = 0.0 if span_to <= span_from else smoothstep(span_from, span_to, s)
	var out = a.duplicate()
	for key in EASED:
		out[key] = lerpf(a[key], b[key], t)
	return out


static func values(k) -> Dictionary:
	var out = {}
	for key in EASED + STEPPED:
		out[key] = k.get(key)
	return out


## Banked frame at a station: [right, up].
static func frame(tangent: Vector3, bank_deg: float) -> Array:
	var right0 = tangent.cross(Vector3.UP).normalized()
	var up0 = right0.cross(tangent).normalized()
	var b = deg_to_rad(bank_deg)
	return [right0 * cos(b) - up0 * sin(b), up0 * cos(b) + right0 * sin(b)]


## Depth of the inset ditch below the road at distance `a` from its centre line (0 outside it). The
## same profile as TestSurface.ditch(): floor, smoothstep fillet, straight wall, smoothstep fillet, with
## the smoothstep integrals in closed form (integral of 3t^2 - 2t^3 is t^3 - t^4 / 2).
static func ditch_drop(sec: Dictionary, a: float) -> float:
	if sec.ditch <= 0:
		return 0.0
	var top = tan(deg_to_rad(sec.ditch_angle_deg))
	var fl = sec.ditch_floor
	var f = maxf(sec.ditch_fillet, 1e-6)
	var w = sec.ditch_wall
	var depth = top * (w + f)
	var rise = 0.0
	if a <= fl:
		rise = 0.0
	elif a <= fl + f:
		var t = (a - fl) / f
		rise = top * f * (t * t * t - t * t * t * t * .5)
	elif a <= fl + f + w:
		rise = top * f * .5 + top * (a - fl - f)
	elif a <= fl + 2 * f + w:
		var t = (a - fl - f - w) / f
		rise = top * f * .5 + top * w + top * f * (t - (t * t * t - t * t * t * t * .5))
	else:
		rise = depth
	return sec.ditch * (depth - rise)


## Road surface height (along the banked up axis) at lateral `lat`: crown minus any ditch.
static func road_height(sec: Dictionary, lat: float) -> float:
	var u = lat / maxf(sec.width_left if lat < 0 else sec.width_right, 1e-6)
	return sec.crown * (1 - u * u) - ditch_drop(sec, absf(lat - sec.ditch_offset))


## Kerb height profile at fraction f of the kerb width (0 at the road edge).
static func kerb_shape(kind, h, f):
	match kind:
		RoadSection.Kerb.RAMP:
			return h * f
		RoadSection.Kerb.SAUSAGE:
			return h * sin(PI * f)
		RoadSection.Kerb.RIBBED:
			return h * minf(1.0, f / .25)
	return 0.0


## One side's stations outward from the road edge: [[lat, height, surface of the band inside it]].
## `sign` is -1 left, +1 right.
static func side(sec: Dictionary, sign: int) -> Array:
	var left = sign < 0
	var width = sec.width_left if left else sec.width_right
	var kerb = sec.kerb_left if left else sec.kerb_right
	var runoff = sec.runoff_left if left else sec.runoff_right
	var verge = sec.verge_left if left else sec.verge_right
	var verge_sid = sec.verge_surface_left if left else sec.verge_surface_right
	if verge_sid < 0:
		verge_sid = sec.verge_surface
	var runoff_sid = sec.runoff_surface if runoff > 0 else verge_sid
	var slope = tan(deg_to_rad(sec.verge_slope_deg))
	var kw = maxf(sec.kerb_width, MIN_BAND)
	var out = []
	for f in KERB_F:
		var d = kw * f
		if kerb != RoadSection.Kerb.NONE:
			out.append([sign * (width + d), kerb_shape(kerb, sec.kerb_height, f), KERB_SURFACE])
		else:
			out.append([sign * (width + d), -slope * d, runoff_sid])
	var top = kerb_shape(kerb, sec.kerb_height, 1.0) if kerb != RoadSection.Kerb.NONE else -slope * kw
	var rw = maxf(runoff, MIN_BAND)
	out.append([sign * (width + kw + rw), top - slope * rw, runoff_sid])
	out.append([sign * (width + kw + rw + verge), top - slope * (rw + verge), verge_sid])
	return out


## Full cross-section, left outer to right outer: [[lat, height, surface of the band to its right]].
## Heights are along the banked up axis. `road_n` road stations span the road (odd, so the centre is
## a station).
static func profile(sec: Dictionary, road_n: int) -> Array:
	var left = side(sec, -1)
	left.reverse()
	var road = []
	for k in road_n:
		var u = -1.0 + 2.0 * k / (road_n - 1)
		var lat = u * (sec.width_left if u < 0 else sec.width_right)
		road.append([lat, road_height(sec, lat), sec.road_surface])
	var out = left + road + side(sec, 1)
	var n = out.size()
	var mid_first = left.size()
	var mid_last = mid_first + road_n - 1
	var rows = []
	for i in n:
		var band = -1
		if i < mid_first:
			band = out[i][2]  # left: the band from this station inwards carries this station's surface
		elif i < mid_last:
			band = sec.road_surface
		elif i < n - 1:
			band = out[i + 1][2]
		rows.append([out[i][0], out[i][1], band])
	return rows


## Bake. Returns {"faces": {surface: PackedVector3Array}, "center": PackedVector3Array, "stations",
## "length", "max_along", "max_across_road", "max_twist_deg_per_m", "max_twist_at_m", "warnings"}.
## max_along is the largest spacing between consecutive stations on the path; max_across_road the
## largest road strip width.
static func bake(
	curve: Curve3D,
	keys: Array,
	closed: bool,
	step = MAX_STEP,
	road_n = DEFAULT_ROAD_STATIONS,
	elev = PackedVector2Array()
) -> Dictionary:
	road_n = maxi(3, road_n | 1)
	var sorted = keys.duplicate()
	sorted.sort_custom(func(a, b): return a.at < b.at)
	var length = curve.get_baked_length()
	var st = stations(curve, closed, step, elev)
	var first_road = KERB_F.size() + 2
	var rows = []
	var lat_rows = []
	var bands = []
	var ups = []
	var secs = []
	var center = PackedVector3Array()
	var max_across = 0.0
	var ditch_spacing = 0.0
	for station in st:
		var sec = section_at(sorted, station.s, length, closed)
		secs.append(sec)
		var fr = frame(station.tangent, sec.bank_deg)
		ups.append(fr[1])
		var row = PackedVector3Array()
		var lats = PackedFloat64Array()
		var band = []
		for p in profile(sec, road_n):
			row.append(station.pos + fr[0] * p[0] + fr[1] * p[1])
			lats.append(p[0])
			band.append(p[2])
		rows.append(row)
		lat_rows.append(lats)
		bands.append(band)
		center.append(row[first_road + (road_n - 1) / 2])
		for k in range(first_road, first_road + road_n - 1):
			max_across = maxf(max_across, row[k].distance_to(row[k + 1]))
		if sec.ditch > 0:
			# Lateral station spacing (on a 37 degree wall the 3D edge is 1/cos 37 longer).
			ditch_spacing = maxf(ditch_spacing, maxf(sec.width_left, sec.width_right) * 2.0 / (road_n - 1))
	# Kerb band vertex indices, inner (road edge) to outer, with their width fractions.
	var left_kerb = [first_road, first_road - 1, first_road - 2, first_road - 3, first_road - 4]
	var right_edge = first_road + road_n - 1
	var right_kerb = [right_edge, right_edge + 1, right_edge + 2, right_edge + 3, right_edge + 4]
	var faces = {}
	var uvs = {}
	var max_along = 0.0
	var max_twist = 0.0
	var twist_at = 0.0
	var count = rows.size() if closed else rows.size() - 1
	for i in count:
		var j = (i + 1) % rows.size()
		var r0 = rows[i]
		var r1 = rows[j]
		var l0 = lat_rows[i]
		var l1 = lat_rows[j]
		# UVs in metres: U across the section, V along the road; the closing strip unwraps to `length`.
		var s0 = st[i].s
		var s1 = length if closed and j == 0 else st[j].s
		# Station spacing along the path itself (the chord between curve points; <= the arc step).
		var gap = st[i].pos.distance_to(st[j].pos)
		max_along = maxf(max_along, gap)
		var twist = absf(secs[j].bank_deg - secs[i].bank_deg) / maxf(gap, 1e-6)
		if twist > max_twist:
			max_twist = twist
			twist_at = st[i].s
		var ribbed = {}
		if secs[i].kerb_left == RoadSection.Kerb.RIBBED:
			for k in range(first_road - 4, first_road):
				ribbed[k] = left_kerb
		if secs[i].kerb_right == RoadSection.Kerb.RIBBED:
			for k in range(right_edge, right_edge + 4):
				ribbed[k] = right_kerb
		for k in r0.size() - 1:
			var sid = bands[i][k]
			if not faces.has(sid):
				faces[sid] = PackedVector3Array()
				uvs[sid] = PackedVector2Array()
			if ribbed.has(k):
				var strip = ribbed_strip(r0, r1, l0, l1, ups[i], ups[j], k, ribbed[k], s0, s1, gap, secs[i])
				faces[sid].append_array(strip[0])
				uvs[sid].append_array(strip[1])
				continue
			# Winding as ribbon.gd: (a, c, b), (b, c, d) with a/b on this station and c/d on the next.
			faces[sid].append_array(
				PackedVector3Array([r0[k], r1[k], r0[k + 1], r0[k + 1], r1[k], r1[k + 1]])
			)
			var a = Vector2(l0[k], s0)
			var b = Vector2(l0[k + 1], s0)
			var c = Vector2(l1[k], s1)
			var d = Vector2(l1[k + 1], s1)
			uvs[sid].append_array(PackedVector2Array([a, c, b, b, c, d]))
	var warnings = []
	if max_twist > TWIST_WARN_DEG_PER_M:
		(
			warnings
			. append(
				(
					"bank changes %.2f deg/m at %.0f m (over %.2f). Stiff cars will lift a wheel; spread the bank change over more distance."
					% [max_twist, twist_at, TWIST_WARN_DEG_PER_M]
				)
			)
		)
	if ditch_spacing > DITCH_MAX_SPACING + 1e-3:
		(
			warnings
			. append(
				(
					"the ditch is sampled every %.2f m across (over %.2f); raise road_stations so its fillets and walls are resolved."
					% [ditch_spacing, DITCH_MAX_SPACING]
				)
			)
		)
	return {
		"faces": faces,
		"uvs": uvs,
		"center": center,
		"stations": st,
		"length": length,
		"max_along": max_along,
		"max_across_road": max_across,
		"max_twist_deg_per_m": max_twist,
		"max_twist_at_m": twist_at,
		"warnings": warnings
	}


## [triangles, UVs] for one band (lateral vertices k, k+1) of a RIBBED kerb between two stations,
## subdivided every quarter rib pitch along the road. Ridge height rib_height * (1 - cos(2 pi s / pitch)) / 2,
## shaped across the band by sin(pi f) so it is zero on the road edge and the kerb's outer edge.
static func ribbed_strip(r0, r1, l0, l1, up0, up1, k, kerb_idx, s0, s1, gap, sec) -> Array:
	var f_of = {kerb_idx[0]: 0.0, kerb_idx[1]: .25, kerb_idx[2]: .5, kerb_idx[3]: .75, kerb_idx[4]: 1.0}
	var pitch = maxf(sec.rib_pitch, .05)
	var m = maxi(1, int(ceil(gap / (pitch * .25))))
	var out = PackedVector3Array()
	var out_uv = PackedVector2Array()
	var prev = []
	var prev_uv = []
	for q in m + 1:
		var t = float(q) / m
		var up = up0.lerp(up1, t).normalized()
		var wave = .5 - .5 * cos(TAU * (s0 + t * gap) / pitch)
		var row = []
		var row_uv = []
		for v in [k, k + 1]:
			var bump = sec.rib_height * wave * sin(PI * f_of[v])
			row.append(r0[v].lerp(r1[v], t) + up * bump)
			row_uv.append(Vector2(lerpf(l0[v], l1[v], t), lerpf(s0, s1, t)))
		if q > 0:
			out.append_array(PackedVector3Array([prev[0], row[0], prev[1], prev[1], row[0], row[1]]))
			out_uv.append_array(
				PackedVector2Array([prev_uv[0], row_uv[0], prev_uv[1], prev_uv[1], row_uv[0], row_uv[1]])
			)
		prev = row
		prev_uv = row_uv
	return [out, out_uv]


## Render mesh: one surface per surface type, UVs in metres (u across, v along) for tiling textures.
static func mesh(faces: Dictionary, uvs: Dictionary) -> ArrayMesh:
	var out = ArrayMesh.new()
	var colors = {
		0: Color(.22, .22, .24),
		1: Color(.75, .15, .12),
		2: Color(.25, .45, .2),
		3: Color(.6, .55, .42),
		4: Color(.35, .35, .37)
	}
	for sid in faces:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in faces[sid].size():
			st.set_uv(uvs[sid][i])
			st.add_vertex(faces[sid][i])
		st.generate_normals()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = colors.get(sid, Color.MAGENTA)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(mat)
		st.commit(out)
	return out
