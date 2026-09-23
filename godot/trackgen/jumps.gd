extends SceneTree
## Restores the Nordschleife's jumps, which the elevation pipeline smoothed away. Usage:
##   godot --headless --path . --script trackgen/jumps.gd -- <in.json> <out.json>
##
## build.py limits vertical curvature to an effective radius of about 800 m. That is right for DEM
## noise and wrong for the short, sharp crests the circuit is famous for: in the smoothed data
## Flugplatz needs 322 km/h to leave the ground and Pflanzgarten 225 km/h.
##
## For each named jump this tool finds the existing crest near the label, adds a local Gaussian
## rise, measures the resulting vertical curvature through the real ribbon model, and rescales the
## rise until a car without downforce would take off at the target speed. Takeoff happens when
## g + v^2 * kv < 0, so the target curvature is -g / v^2. Downforce raises the real threshold.
##
## Targets are modelled, not surveyed. They are chosen so a light road car flies at plausible
## speeds and a downforce car needs more; tune them here, not in the circuit file.
const Track3D = preload("res://scripts/track3d.gd")
const G = 9.81

const JUMPS = [
	{"name": "Flugplatz", "takeoff_kmh": 160.0, "sigma": 18.0},
	{"name": "Sprunghügel", "takeoff_kmh": 150.0, "sigma": 16.0},
	{"name": "Pflanzgarten", "takeoff_kmh": 150.0, "sigma": 16.0},
]


func load_track(doc):
	var t = Track3D.new()
	t.load_data(doc)
	return t


## Most negative vertical curvature within `span` metres of station `s0`, and where it is.
func sharpest(t, s0, span):
	var best = 0.0
	var at = s0
	for d in range(-int(span), int(span) + 1, 1):
		var k = t.pose_at(s0 + d).kv
		if k < best:
			best = k
			at = s0 + d
	return [best, fposmod(at, t.length)]


func _initialize():
	var args = OS.get_cmdline_user_args()
	var doc = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var t = load_track(doc)
	var labels = doc.get("presentation", {}).get("labels", [])
	# Station of every control point, measured once on the unmodified circuit so every rise is
	# placed against the same parameterisation.
	var stations = []
	for p in doc.points:
		stations.append(t.project(Vector3(float(p.x), float(p.y), float(p.get("z", 0.0)))).s)
	var base_z = []
	for p in doc.points:
		base_z.append(float(p.get("z", 0.0)))
	var specs = []
	for spec in JUMPS:
		var anchor = null
		for l in labels:
			if l.get("name", "") == spec.name:
				anchor = Vector3(float(l.x), float(l.y), t.probe_height(-1))
		if anchor == null:
			push_error("Label not found: " + spec.name)
			quit(1)
			return
		var centre = t.project(anchor).s
		var found = sharpest(t, centre, 150.0)
		var v = spec.takeoff_kmh / 3.6
		specs.append(
			{
				"name": spec.name,
				"sigma": spec.sigma,
				"crest_s": found[1],
				"before": found[0],
				"target": -G / (v * v),
				"amp": maxf(0.05, (found[0] + G / (v * v)) * spec.sigma * spec.sigma),
			}
		)
	# Rescale each rise until the measured crest curvature hits its target. Rises are summed onto
	# the survey heights each pass, so neighbouring jumps cannot compound.
	for rep in 6:
		for i in doc.points.size():
			var z = base_z[i]
			for sp in specs:
				var d = wrapf(stations[i] - sp.crest_s, -t.length / 2, t.length / 2)
				z += sp.amp * exp(-d * d / (2 * sp.sigma * sp.sigma))
			doc.points[i].z = snappedf(z, .001)
		var m = load_track(doc)
		var done = true
		for sp in specs:
			var got = sharpest(m, sp.crest_s, 3 * sp.sigma)[0]
			var need_extra = sp.target - sp.before
			var got_extra = got - sp.before
			if absf(got - sp.target) > absf(sp.target) * .03:
				done = false
			if absf(got_extra) > 1e-6:
				sp.amp = clampf(sp.amp * need_extra / got_extra, 0.02, 6.0)
		if done:
			break
	var final = load_track(doc)
	var worst_compression = 0.0
	for sm in final.samples:
		worst_compression = maxf(worst_compression, sm.kv)
	for sp in specs:
		var got = sharpest(final, sp.crest_s, 3 * sp.sigma)[0]
		print(
			(
				"%-13s rise %.2f m over sigma %.0f m: crest %.5f -> %.5f 1/m, takeoff %.0f -> %.0f km/h"
				% [
					sp.name,
					sp.amp,
					sp.sigma,
					sp.before,
					got,
					sqrt(G / maxf(-sp.before, 1e-6)) * 3.6,
					sqrt(G / maxf(-got, 1e-6)) * 3.6
				]
			)
		)
	print("worst compression curvature on the lap: %.5f 1/m" % worst_compression)
	var f = FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	print("JUMPS written")
	quit()
