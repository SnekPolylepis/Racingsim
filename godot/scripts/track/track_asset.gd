extends Node3D
## Root of an authored track scene (REBUILD-PLAN.md 5.3). Godot-native world space (+Y up, metres).
## The root stays at the origin; tracks keep coordinates within MAX_EXTENT (5.1 precision contract).
##
## Expected children:
##   Surfaces/   StaticBody3D per surface type: metadata "surface" = SURF index, collision layer 1.
##   Walls/      StaticBody3D barriers, metadata "wall_kind", collision layer 2. Optional here.
##   TimingLine  Path3D. Its baked curve, closed from last point back to first, is the lap line.
##               Metadata: start_offset_m (float), sector_offsets (Array, metres after the start),
##               checkpoint_offsets (Array, metres after the start). Missing metadata gets defaults.
##   Grid/       Marker3D slots in grid order (pole first); -Z of each marker points down the track.
##   Road/, Scenery/, Lights/, BotLine   presentation and bot data; not required by validate().
##
## Timing gates are vertical planes across the lap line at a station, bounded laterally and in
## height, so a car on another deck passing through the same plan position does not trigger them.

const SurfaceTable = preload("res://scripts/track3d.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
## 5.1: float32 query precision stays well under a millimetre within this distance of the origin.
const MAX_EXTENT = 5000.0
const SURFACE_LAYER = 1
const WALL_LAYER = 2
## Default checkpoint spacing, as the old track model used.
const CHECKPOINT_SPACING = 90.0
## Gates reach this far beyond the lap line to either side, and this far above and below it.
const GATE_HALF_WIDTH = 15.0
const GATE_HALF_HEIGHT = 3.0

@export var id = ""
@export var display_name = ""
## Bump whenever the drivable surface or timing changes; it is part of record identity.
@export var version = 1
@export var default_time_of_day = "day"
@export var lighting = {}

var line = PackedVector3Array()
## Cumulative distance at each line point; line_s[n] is the full lap length (closing segment).
var line_s = PackedFloat64Array()
var length = 0.0


## Record identity for best laps and ghosts: track id plus version. Car, setup and handling model
## are added by the caller, as today.
func record_key():
	return "%s@v%d" % [id, version]


## Bake the lap line from TimingLine. Call after the scene is instanced (validate() calls it).
func prepare():
	line = PackedVector3Array()
	line_s = PackedFloat64Array()
	length = 0.0
	var path = get_node_or_null("TimingLine")
	if not (path is Path3D) or path.curve == null:
		return
	var pts = path.curve.get_baked_points()
	var xf = path.transform
	for p in pts:
		line.append(xf * p)
	# A curve closed by repeating its first point would add a zero-length closing segment.
	if line.size() > 2 and line[0].distance_to(line[line.size() - 1]) < 1e-3:
		line.remove_at(line.size() - 1)
	var n = line.size()
	line_s.resize(n + 1)
	line_s[0] = 0.0
	for i in n:
		length += line[i].distance_to(line[(i + 1) % n])
		line_s[i + 1] = length


func timing_meta(key, fallback):
	var path = get_node_or_null("TimingLine")
	if path == null or not path.has_meta(key):
		return fallback
	return path.get_meta(key)


func start_offset():
	return fposmod(float(timing_meta("start_offset_m", 0.0)), maxf(length, 1e-9))


## Sector boundaries as metres after the start line (two boundaries make three sectors).
func sector_offsets():
	var meta = timing_meta("sector_offsets", [])
	if meta.is_empty():
		return [length / 3.0, length * 2.0 / 3.0]
	return meta


func checkpoint_offsets():
	var meta = timing_meta("checkpoint_offsets", [])
	if not meta.is_empty():
		return meta
	var out = []
	var d = CHECKPOINT_SPACING
	while d < length - CHECKPOINT_SPACING * .5:
		out.append(d)
		d += CHECKPOINT_SPACING
	return out


## Position and unit tangent on the lap line at absolute station s (wrapped).
func station(s):
	var n = line.size()
	s = fposmod(s, length)
	var lo = 0
	var hi = n - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if line_s[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	var a = line[lo]
	var b = line[(lo + 1) % n]
	var seg = line_s[lo + 1] - line_s[lo]
	var t = (s - line_s[lo]) / maxf(seg, 1e-9)
	return {"pos": a.lerp(b, t), "tangent": (b - a).normalized(), "idx": lo}


## Nearest point on the lap line in true 3D distance, so stacked decks resolve by height.
## With a hint (the idx from the previous call) only a window around it is searched.
func project(p: Vector3, hint = -1):
	var n = line.size()
	var from = 0
	var count = n
	if hint >= 0 and hint < n:
		from = hint - 40
		count = 81
	var best = INF
	var out = {}
	for k in count:
		var i = posmod(from + k, n)
		var a = line[i]
		var b = line[(i + 1) % n]
		var seg = b - a
		var t = clampf((p - a).dot(seg) / maxf(seg.length_squared(), 1e-12), 0, 1)
		var foot = a + seg * t
		var d = p.distance_squared_to(foot)
		if d < best:
			best = d
			var tangent = seg.normalized()
			var right = tangent.cross(Vector3.UP).normalized()
			out = {
				"s": line_s[i] + (line_s[i + 1] - line_s[i]) * t,
				"idx": i,
				"lateral": (p - foot).dot(right),
				"vertical": (p - foot).y,
				"distance": sqrt(d)
			}
	return out


## Lap-relative station (metres after the start line) of an absolute station.
func lap_distance(s):
	return fposmod(s - start_offset(), length)


func make_gate(kind, lap_offset):
	var st = station(start_offset() + lap_offset)
	var right = st.tangent.cross(Vector3.UP).normalized()
	return {"kind": kind, "offset": lap_offset, "origin": st.pos, "normal": st.tangent, "right": right}


## Start/finish, sector and checkpoint gates in the order a lap meets them: the start gate first,
## then every other gate sorted by its lap offset from the start line.
func gates():
	var rest = []
	for d in sector_offsets():
		rest.append(make_gate("sector", float(d)))
	for d in checkpoint_offsets():
		rest.append(make_gate("checkpoint", float(d)))
	rest.sort_custom(func(a, b): return a.offset < b.offset)
	return [make_gate("start", 0.0)] + rest


## True if the move p0 -> p1 crosses the gate forwards within its lateral and height bounds.
static func crossed(gate, p0: Vector3, p1: Vector3):
	var d0 = (p0 - gate.origin).dot(gate.normal)
	var d1 = (p1 - gate.origin).dot(gate.normal)
	if not (d0 < 0 and d1 >= 0):
		return false
	var q = p0 + (p1 - p0) * (d0 / (d0 - d1))
	var rel = q - gate.origin
	return absf(rel.dot(gate.right)) <= GATE_HALF_WIDTH and absf(rel.y) <= GATE_HALF_HEIGHT


func grid_slots():
	var out = []
	var grid = get_node_or_null("Grid")
	if grid == null:
		return out
	for m in grid.get_children():
		if m is Marker3D:
			out.append(m.transform)
	return out


## Plan-view (x, z) polyline of the lap line, `count` points evenly spaced by distance, for the
## minimap. Callers scale it to their widget.
func minimap(count = 512):
	var out = PackedVector2Array()
	for k in count:
		var p = station(length * k / count).pos
		out.append(Vector2(p.x, p.z))
	return out


func surface():
	return TrackSurface.new(self)


## Structural checks that need no physics frame. Returns a list of human-readable errors.
func validate():
	prepare()
	var errors = []
	if id.strip_edges() == "":
		errors.append("id is empty")
	if int(version) < 1:
		errors.append("version must be >= 1")
	if not transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("TrackAsset root must sit at the origin with no rotation or scale")
	var surfaces = get_node_or_null("Surfaces")
	var bodies = 0
	if surfaces == null:
		errors.append("missing Surfaces/")
	else:
		for b in surfaces.get_children():
			if not (b is StaticBody3D):
				continue
			bodies += 1
			var sid = b.get_meta("surface", -1)
			if typeof(sid) != TYPE_INT or sid < 0 or sid >= SurfaceTable.SURF.size():
				errors.append("Surfaces/%s: metadata 'surface' must be an int SURF index" % b.name)
			if not b.get_collision_layer_value(SURFACE_LAYER):
				errors.append("Surfaces/%s: must be on collision layer %d" % [b.name, SURFACE_LAYER])
			var shapes = b.get_children().filter(func(c): return c is CollisionShape3D and c.shape != null)
			if shapes.is_empty():
				errors.append("Surfaces/%s: no collision shape" % b.name)
		if bodies == 0:
			errors.append("Surfaces/ has no StaticBody3D")
	var path = get_node_or_null("TimingLine")
	if not (path is Path3D) or path.curve == null:
		errors.append("missing TimingLine (Path3D with a curve)")
	elif line.size() < 8:
		errors.append("TimingLine is too short (%d baked points)" % line.size())
	else:
		var gap = line[0].distance_to(line[line.size() - 1])
		if gap > 3 * length / line.size():
			errors.append("TimingLine is not closed: %.1f m from last point back to first" % gap)
		var so = float(timing_meta("start_offset_m", 0.0))
		if so < 0 or so >= length:
			errors.append("start_offset_m %.1f outside [0, %.1f)" % [so, length])
		for key in ["sector_offsets", "checkpoint_offsets"]:
			var prev = 0.0
			for d in timing_meta(key, []):
				if float(d) <= prev or float(d) >= length:
					errors.append("%s must increase strictly inside (0, lap length)" % key)
					break
				prev = float(d)
		for p in line:
			if absf(p.x) > MAX_EXTENT or absf(p.z) > MAX_EXTENT or absf(p.y) > MAX_EXTENT:
				errors.append("TimingLine leaves the ±%.0f m precision box (5.1)" % MAX_EXTENT)
				break
	var slots = grid_slots()
	if slots.is_empty():
		errors.append("Grid/ has no Marker3D slots")
	for xf in slots:
		if xf.origin.abs().x > MAX_EXTENT or xf.origin.abs().z > MAX_EXTENT:
			errors.append("a grid slot leaves the ±%.0f m precision box (5.1)" % MAX_EXTENT)
			break
	return errors
