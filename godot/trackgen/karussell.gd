extends SceneTree
## Paints cross-section profiles onto the two Karussells of the Nordschleife, then writes the
## circuit back. Usage:
##   godot --headless --path . --script trackgen/karussell.gd -- <in.json> <out.json>
##
## Both Karussells are banked concrete ditches on the inside of a hairpin, not flat road with a
## cross-slope. The ribbon model carries a per-control-point cross section as [u, drop] pairs,
## where u is the fraction of half width (negative to the driver's left) and drop is metres below
## the banked plane. This tool locates each corner from the circuit's own labels, works out which
## side is the inside from the sign of the curvature there, and writes a mirrored profile.
##
## Depths are modelled, not surveyed. The Caracciola-Karussell concrete runs at roughly 30 degrees
## across a band about a third of the road wide; Kleines Karussell is shallower and shorter.
const Track3D = preload("res://scripts/track3d.gd")

## [fraction of half width measured from the inside edge, metres below the banked plane].
## The inside edge sits slightly higher than the trough, which is the concrete lip.
const CARACCIOLA = [[0.00, 1.15], [0.11, 1.28], [0.24, 0.86], [0.33, 0.22], [0.37, 0.0], [1.0, 0.0]]
const KLEINES = [[0.00, 0.62], [0.12, 0.70], [0.26, 0.44], [0.34, 0.12], [0.39, 0.0], [1.0, 0.0]]


func _initialize():
	var args = OS.get_cmdline_user_args()
	var doc = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var t = Track3D.new()
	t.load_data(doc)
	var labels = doc.get("presentation", {}).get("labels", [])
	var painted = 0
	for spec in [
		{"name": "Caracciola-Karussell", "shape": CARACCIOLA, "reach": 95.0},
		{"name": "Kleines Karussell", "shape": KLEINES, "reach": 58.0}
	]:
		var anchor = null
		for l in labels:
			if l.get("name", "") == spec.name:
				anchor = Vector3(float(l.x), float(l.y), 0.0)
		if anchor == null:
			push_error("Label not found: " + spec.name)
			quit(1)
			return
		# Resolve the label to an arc station, then take the inside from the curvature there.
		var pr = t.project(Vector3(anchor.x, anchor.y, t.probe_height(-1)))
		var centre_s = pr.s
		var curv = t.curvature_at(centre_s, 40.0)
		var inside = 1.0 if curv > 0 else -1.0
		print(
			"%s at s=%.0f m, curvature %.4f 1/m, inside is %s"
			% [spec.name, centre_s, curv, "right" if inside > 0 else "left"]
		)
		# Write the profile onto every control point whose station falls inside the corner, fading
		# it in and out over the last quarter at each end so the ditch does not start as a step.
		for i in doc.points.size():
			var p = doc.points[i]
			var ppr = t.project(Vector3(float(p.x), float(p.y), float(p.get("z", 0.0))))
			var offset = wrapf(ppr.s - centre_s, -t.length / 2, t.length / 2)
			var away = absf(offset)
			if away > spec.reach:
				continue
			var fade = clampf((spec.reach - away) / (spec.reach * .45), 0.0, 1.0)
			fade = fade * fade * (3 - 2 * fade)
			var pairs = []
			for pair in spec.shape:
				# Map "fraction from the inside edge" onto signed u, mirroring for a left-hand ditch.
				pairs.append([inside * (1.0 - float(pair[0]) * 2.0), float(pair[1]) * fade])
			p["profile"] = pairs
			painted += 1
	doc.schema = 1
	var f = FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("KARUSSELL painted %d control points" % painted)
	quit()
