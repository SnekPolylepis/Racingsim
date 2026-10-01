extends RefCounted
## Traced kerbs for a generator (K-02): trackgen/data/<track>/kerbs.json (K-01/K-01b) as station ranges
## per side, in the generator's source stations (the same `s` its profile_at() receives).
##
## A kerbs.json is used only once reviewed ("status": "reviewed", set by the reviewer), so a coarse or
## unchecked trace can never replace a generator's own kerb rules. Low-confidence entries are skipped.
## Kerb kinds map to RoadSection kerbs: flat paint is a low RAMP, ribbed RIBBED, sausage SAUSAGE and
## unsure a RAMP. Section kerb types step at keys (RoadBuilder.section_at), so a generator adds marks()
## as section keys and each kerb starts and ends where its paint does.
const RoadSection = preload("res://scripts/track/road_section.gd")
## [RoadSection.Kerb, kerb_height m, rib_height m, rib_pitch m] per traced type.
const KINDS = {
	"flat": [RoadSection.Kerb.RAMP, 0.022, 0.0, 0.5],
	"ribbed": [RoadSection.Kerb.RIBBED, 0.048, 0.016, 0.38],
	"sausage": [RoadSection.Kerb.SAUSAGE, 0.080, 0.0, 0.5],
	"unsure": [RoadSection.Kerb.RAMP, 0.025, 0.0, 0.5],
}
## Tests set a map here (track id -> map) to exercise a generator without reviewed data on disk.
static var forced = {}
static var cache = {}


## The reviewed map for a track, or {} when there is none (no file, not reviewed, or no usable entries).
static func for_track(id: String, path: String) -> Dictionary:
	if forced.has(id):
		return forced[id]
	if not cache.has(id):
		cache[id] = load_reviewed(path)
	return cache[id]


static func load_reviewed(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("status", "") != "reviewed":
		return {}
	return from_entries(doc.get("kerbs", []))


## {"left": [entry...], "right": [...]} from kerbs.json entries; entry = {s0, s1, kind, width, height, rib_height, rib_pitch}.
static func from_entries(entries: Array) -> Dictionary:
	var map = {"left": [], "right": []}
	for e in entries:
		if not e is Dictionary or e.get("confidence", "medium") == "low":
			continue
		var side = str(e.get("side", ""))
		if not map.has(side):
			continue
		var kind = KINDS.get(str(e.get("type", "unsure")), KINDS.unsure)
		(
			map[side]
			. append(
				{
					"s0": float(e.s_start),
					"s1": float(e.s_end),
					"kind": kind[0],
					"height": kind[1],
					"rib_height": float(e.get("rib_height_m", kind[2])),
					"rib_pitch": float(e.get("rib_pitch_m", kind[3])),
					"width": clampf(float(e.get("width_m", 0.9)), 0.4, 2.0),
				}
			)
		)
	if map.left.is_empty() and map.right.is_empty():
		return {}
	return map


## The kerb covering station `s` on `side`, or {}. A range whose end is below its start wraps the line.
static func at(map: Dictionary, side: String, s: float, length: float) -> Dictionary:
	s = fposmod(s, length)
	for e in map.get(side, []):
		var s0 = fposmod(e.s0, length)
		var s1 = fposmod(e.s1, length)
		var inside = (s >= s0 and s < s1) if s0 <= s1 else (s >= s0 or s < s1)
		if inside:
			return e
	return {}


## Section-key stations where kerbs start and end.
static func marks(map: Dictionary, length: float) -> Array:
	var out = []
	for side in ["left", "right"]:
		for e in map.get(side, []):
			out.append(fposmod(e.s0, length))
			out.append(fposmod(e.s1, length))
	return out


## Replace a section's kerbs with the traced ones at `s`. Returns false (values untouched) with no map.
static func apply(map: Dictionary, values: Dictionary, s: float, length: float) -> bool:
	if map.is_empty():
		return false
	var width = 0.0
	var height = 0.0
	var rib_height = 0.0
	var rib_pitch = 0.0
	for side in ["left", "right"]:
		var e = at(map, side, s, length)
		if e.is_empty():
			values["kerb_" + side] = RoadSection.Kerb.NONE
		else:
			values["kerb_" + side] = e.kind
			width = maxf(width, e.width)
			height = maxf(height, e.height)
			if e.kind == RoadSection.Kerb.RIBBED:
				rib_height = maxf(rib_height, e.rib_height)
				rib_pitch = e.rib_pitch if rib_pitch == 0.0 else minf(rib_pitch, e.rib_pitch)
	if width > 0.0:
		values.kerb_width = width
		values.kerb_height = height
	if rib_height > 0.0:
		values.rib_height = rib_height
		values.rib_pitch = rib_pitch
	return true
