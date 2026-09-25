extends SceneTree
## K-02: traced kerb maps (trackgen/kerb_map.gd). Station lookup with wrap-around, section marks, the
## RoadSection values a map writes, low-confidence skipping, the reviewed-only rule on the shipped files,
## and a Spa build with a forced map: the kerb starts and ends at the traced stations.
const KerbMap = preload("res://trackgen/kerb_map.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const Spa = preload("res://trackgen/spa.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
var checks = 0
var failures = []


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func _initialize():
	var entries = [
		{
			"side": "left",
			"s_start": 100,
			"s_end": 130,
			"type": "sausage",
			"width_m": 0.8,
			"confidence": "high"
		},
		{
			"side": "right",
			"s_start": 400,
			"s_end": 420,
			"type": "ribbed",
			"width_m": 1.2,
			"confidence": "medium"
		},
		{"side": "right", "s_start": 4990, "s_end": 10, "type": "flat", "confidence": "medium"},
		{"side": "left", "s_start": 700, "s_end": 760, "type": "flat", "confidence": "low"},
	]
	var map = KerbMap.from_entries(entries)
	check(map.left.size() == 1 and map.right.size() == 2, "low-confidence entries are skipped")
	check(KerbMap.at(map, "left", 115.0, 5000.0).kind == RoadSection.Kerb.SAUSAGE, "inside a range")
	check(KerbMap.at(map, "left", 130.0, 5000.0).is_empty(), "range end is exclusive")
	check(KerbMap.at(map, "left", 99.9, 5000.0).is_empty(), "before a range")
	check(not KerbMap.at(map, "right", 4995.0, 5000.0).is_empty(), "wrapping range before the line")
	check(not KerbMap.at(map, "right", 5.0, 5000.0).is_empty(), "wrapping range after the line")
	check(KerbMap.marks(map, 5000.0).size() == 6, "two marks per kerb")
	var values = {"kerb_left": RoadSection.Kerb.RIBBED, "kerb_right": RoadSection.Kerb.RAMP}
	var used = KerbMap.apply(map, values, 410.0, 5000.0)
	check(
		(
			used
			and values.kerb_left == RoadSection.Kerb.NONE
			and values.kerb_right == RoadSection.Kerb.RIBBED
			and is_equal_approx(values.kerb_width, 1.2)
		),
		"apply replaces both sides' kerbs"
	)
	var untouched = {"kerb_left": RoadSection.Kerb.RIBBED}
	check(
		not KerbMap.apply({}, untouched, 0.0, 10.0) and untouched.kerb_left == RoadSection.Kerb.RIBBED,
		"no map, no change"
	)
	# Shipped files: only a reviewed kerbs.json drives a generator.
	for path in ["res://trackgen/data/spa/kerbs.json", "res://trackgen/data/nordschleife/kerbs.json"]:
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
		var reviewed = doc is Dictionary and doc.get("status", "") == "reviewed"
		var drives = not KerbMap.load_reviewed(path).is_empty()
		check(reviewed == drives, path.get_file() + " used only if reviewed")
	# Spa with a forced map: section kerbs switch exactly at the traced stations.
	KerbMap.forced["spa"] = KerbMap.from_entries(
		[{"side": "right", "s_start": 1500, "s_end": 1540, "type": "sausage", "confidence": "high"}]
	)
	var data = JSON.parse_string(FileAccess.get_file_as_string(Spa.DATA + "centreline.json"))
	var length = Spa.source_length(data)
	var corners = Spa.corner_specs(data)
	var keys = Spa.sections(data, length, corners)
	var sorted = keys.duplicate()
	sorted.sort_custom(func(a, b): return a.at < b.at)
	var inside = RoadBuilder.section_at(sorted, 1520.0, length, true)
	var before = RoadBuilder.section_at(sorted, 1499.0, length, true)
	var after = RoadBuilder.section_at(sorted, 1541.0, length, true)
	check(
		(
			inside.kerb_right == RoadSection.Kerb.SAUSAGE
			and before.kerb_right != RoadSection.Kerb.SAUSAGE
			and after.kerb_right != RoadSection.Kerb.SAUSAGE
		),
		"Spa sections: forced kerb 1500-1540 m on the right, off at 1499 and 1541"
	)
	KerbMap.forced.clear()
	print("KERB_MAP RESULTS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
