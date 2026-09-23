extends RefCounted
## Bakes a road from a Curve3D and RoadSection keys (REBUILD-PLAN.md P3-02). Pure data in, data out,
## so it runs headless in tests and inside the editor from RoadPath's Bake button.
##
## Tessellation follows P3-00: stations every <= 1.5 m along the path, and w/8 across the road.
## Every station has the same lateral topology, so strips stitch without seams:
##   verge outer | kerb band (3 stations) | road (9 stations) | kerb band (3) | verge outer
## A side with no kerb keeps its kerb band, but the band then continues the verge (verge surface,
## verge slope), so the mesh never needs degenerate triangles.
##
## Frame at a station: tangent t along the curve (it climbs with the road), right0 = t x UP (level),
## up0 = right0 x t. Bank rotates that frame about t; positive bank raises the left edge.

const RoadSection = preload("res://scripts/track/road_section.gd")
const MAX_STEP = 1.5
const ROAD_STATIONS = 9
const KERB_SURFACE = 1
## Bank change per metre along the road above which bake() warns. A 2.65 m-wheelbase race car on a
## twist of 0.4 deg/m sees ~3 cm of warp across its axles, enough to lift a wheel on stiff springs
## (measured in P3-02); real circuits spread banking over tens of metres.
const TWIST_WARN_DEG_PER_M = .2


## Stations along the curve: [{s, pos, tangent}], evenly spaced at <= step metres. For a closed road
## the last station stops one step short of the start (the strip wraps back to station 0).
static func stations(curve: Curve3D, closed: bool, step: float) -> Array:
	var length = curve.get_baked_length()
	# 1 % margin: cubic sampling can place stations a hair further apart than the arc step.
	var count = maxi(2, int(ceil(length / (minf(step, MAX_STEP) * .99))))
	var spacing = length / count
	var out = []
	var n = count if closed else count + 1
	for i in n:
		var s = i * spacing
		var eps = minf(.25, spacing * .5)
		var a = curve.sample_baked(maxf(0.0, s - eps), true)
		var b = curve.sample_baked(minf(length, s + eps), true)
		if closed and (s - eps < 0 or s + eps > length):
			a = curve.sample_baked(fposmod(s - eps, length), true)
			b = curve.sample_baked(fposmod(s + eps, length), true)
		out.append({"s": s, "pos": curve.sample_baked(s, true), "tangent": (b - a).normalized()})
	return out


## Numeric section values at distance s, eased between the bounding keys; types switch at keys.
## Keys are wrapped around for a closed road.
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
	for key in [
		"width_left",
		"width_right",
		"bank_deg",
		"crown",
		"kerb_width",
		"kerb_height",
		"verge_left",
		"verge_right",
		"verge_slope_deg"
	]:
		out[key] = lerpf(a[key], b[key], t)
	return out


static func values(k) -> Dictionary:
	return {
		"width_left": k.width_left,
		"width_right": k.width_right,
		"bank_deg": k.bank_deg,
		"crown": k.crown,
		"kerb_left": k.kerb_left,
		"kerb_right": k.kerb_right,
		"kerb_width": k.kerb_width,
		"kerb_height": k.kerb_height,
		"verge_left": k.verge_left,
		"verge_right": k.verge_right,
		"verge_slope_deg": k.verge_slope_deg,
		"road_surface": k.road_surface,
		"verge_surface": k.verge_surface
	}


## Banked frame at a station: [right, up].
static func frame(tangent: Vector3, bank_deg: float) -> Array:
	var right0 = tangent.cross(Vector3.UP).normalized()
	var up0 = right0.cross(tangent).normalized()
	var b = deg_to_rad(bank_deg)
	return [right0 * cos(b) - up0 * sin(b), up0 * cos(b) + right0 * sin(b)]


## Cross-section stations for one side, from the road edge outwards: [[lat, height, surface], ...]
## (kerb band: 3 stations, verge outer: 1). `sign` is -1 left, +1 right. The road edge itself is the
## first road station and is not repeated.
static func side(sec: Dictionary, sign: int) -> Array:
	var width = sec.width_left if sign < 0 else sec.width_right
	var kerb = sec.kerb_left if sign < 0 else sec.kerb_right
	var verge = sec.verge_left if sign < 0 else sec.verge_right
	var slope = tan(deg_to_rad(sec.verge_slope_deg))
	var kw = maxf(sec.kerb_width, .05)
	var out = []
	for f in [.5, 1.0]:
		var d = kw * f
		if kerb == RoadSection.Kerb.RAMP:
			out.append([sign * (width + d), sec.kerb_height * f, KERB_SURFACE])
		else:
			out.append([sign * (width + d), -slope * d, sec.verge_surface])
	var top = sec.kerb_height if kerb == RoadSection.Kerb.RAMP else -slope * kw
	out.append([sign * (width + kw + verge), top - slope * verge, sec.verge_surface])
	return out


## Full cross-section, left outer to right outer: [[lat, height, surface_of_band_to_the_right], ...].
## Heights are along the banked up axis; the road carries the parabolic crown.
static func profile(sec: Dictionary) -> Array:
	var left = side(sec, -1)
	left.reverse()
	var road = []
	for k in ROAD_STATIONS:
		var u = -1.0 + 2.0 * k / (ROAD_STATIONS - 1)
		var lat = u * (sec.width_left if u < 0 else sec.width_right)
		road.append([lat, sec.crown * (1 - u * u), sec.road_surface])
	var out = left + road + side(sec, 1)
	# A band's surface is that of its outer station on the verge side and its inner (road) side on the
	# road. Store, per station, the surface of the band from it to the next station on the right.
	var n = out.size()
	var mid_first = left.size()
	var mid_last = mid_first + ROAD_STATIONS - 1
	var bands = []
	for i in n - 1:
		if i < mid_first:
			bands.append(out[i][2])  # left side: the outer station's own surface covers the band
		elif i < mid_last:
			bands.append(sec.road_surface)
		else:
			bands.append(out[i + 1][2])
	var rows = []
	for i in n:
		rows.append([out[i][0], out[i][1], bands[i] if i < n - 1 else -1])
	return rows


## Bake. Returns {"faces": {surface: PackedVector3Array}, "center": PackedVector3Array,
## "stations": Array, "length": float, "max_along": float, "max_across_road": float}. max_along is the
## largest spacing between consecutive stations on the path; max_across_road the largest road strip width;
## max_twist_deg_per_m the steepest bank change along the road (and where).
static func bake(curve: Curve3D, keys: Array, closed: bool, step = MAX_STEP) -> Dictionary:
	var sorted = keys.duplicate()
	sorted.sort_custom(func(a, b): return a.at < b.at)
	var length = curve.get_baked_length()
	var st = stations(curve, closed, step)
	var rows = []
	var uv_rows = []
	var bands = []
	var center = PackedVector3Array()
	var max_across = 0.0
	var banks = []
	for station in st:
		var sec = section_at(sorted, station.s, length, closed)
		banks.append(sec.bank_deg)
		var fr = frame(station.tangent, sec.bank_deg)
		var prof = profile(sec)
		var row = PackedVector3Array()
		var uv_row = PackedVector2Array()
		var band = []
		for p in prof:
			row.append(station.pos + fr[0] * p[0] + fr[1] * p[1])
			uv_row.append(Vector2(p[0], station.s))
			band.append(p[2])
		rows.append(row)
		uv_rows.append(uv_row)
		bands.append(band)
		var first_road = 3
		center.append(row[first_road + (ROAD_STATIONS - 1) / 2])
		for k in range(first_road, first_road + ROAD_STATIONS - 1):
			max_across = maxf(max_across, row[k].distance_to(row[k + 1]))
	var faces = {}
	var uvs = {}
	var max_along = 0.0
	var max_twist = 0.0
	var twist_at = 0.0
	var count = rows.size() if closed else rows.size() - 1
	for i in count:
		var r0 = rows[i]
		var r1 = rows[(i + 1) % rows.size()]
		var uv0 = uv_rows[i]
		var uv1 = uv_rows[(i + 1) % uv_rows.size()]
		var next_s = length if closed and i == count - 1 else st[i + 1].s
		# Station spacing along the path itself (the chord between curve points; <= the arc step).
		var gap = st[i].pos.distance_to(st[(i + 1) % st.size()].pos)
		max_along = maxf(max_along, gap)
		var twist = absf(banks[(i + 1) % banks.size()] - banks[i]) / maxf(gap, 1e-6)
		if twist > max_twist:
			max_twist = twist
			twist_at = st[i].s
		for k in r0.size() - 1:
			var sid = bands[i][k]
			if not faces.has(sid):
				faces[sid] = PackedVector3Array()
				uvs[sid] = PackedVector2Array()
			# Winding as ribbon.gd: (a, c, b), (b, c, d) with a/b on this station and c/d on the next.
			faces[sid].append_array(
				PackedVector3Array([r0[k], r1[k], r0[k + 1], r0[k + 1], r1[k], r1[k + 1]])
			)
			# U is across the section and V follows the road in metres; unwrap the closing strip.
			uvs[sid].append_array(
				PackedVector2Array(
					[
						uv0[k],
						Vector2(uv1[k].x, next_s),
						uv0[k + 1],
						uv0[k + 1],
						Vector2(uv1[k].x, next_s),
						Vector2(uv1[k + 1].x, next_s)
					]
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
		"max_twist_at_m": twist_at
	}


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
