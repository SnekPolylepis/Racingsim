extends SceneTree
## Geometry regression for the 3-space ribbon model in scripts/track3d.gd.
##
## The load-bearing case is the overpass: a circuit that crosses over itself in plan view. The
## plan-view model in track.gd cannot represent it at all, because its surface is a height function
## over the ground plane and its sample index is a 2-D grid. These checks assert that the ribbon
## model keeps the two decks distinct, both for a cold query and for a car tracking along one deck
## through the crossing.

const Track3D = preload("res://scripts/track3d.gd")

var checks = 0
var failures = []


func check(ok, label):
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures.append(label)
		print("FAIL  ", label)


func near(a, b, tol):
	return absf(a - b) <= tol


## Closed circle of radius r in the ground plane, optionally banked and raised.
func circle_doc(r, count, bank = 0.0, width = 12.0):
	var points = []
	for i in count:
		var th = TAU * i / count
		points.append({"x": r * cos(th), "y": r * sin(th), "z": 0.0, "w": width, "bank": bank})
	return {"schema": 1, "name": "Circle", "points": points, "startS": 0.0}


## Lemniscate of Gerono: crosses itself at the origin at th = PI/2 and th = 3*PI/2. Height follows
## sin(th), so the two passes through the crossing sit at +h and -h. This is a genuine overpass:
## the same plan position carries two road surfaces with different tangents.
func overpass_doc(a, h, count):
	var points = []
	for i in count:
		var th = TAU * i / count
		points.append(
			{"x": a * cos(th), "y": a * sin(th) * cos(th), "z": h * sin(th), "w": 12.0, "bank": 0.0}
		)
	return {"schema": 1, "name": "Overpass", "points": points, "startS": 0.0}


func _initialize():
	var t = Track3D.new()

	# ---- frames on a flat circle ----
	t.load_data(circle_doc(200.0, 64))
	check(
		near(t.length, TAU * 200.0, 4.0),
		"flat circle arc length %.1f m (expected %.1f)" % [t.length, TAU * 200.0]
	)
	var orthonormal = true
	var horizontal_right = true
	for sm in t.samples:
		orthonormal = (
			orthonormal
			and near(sm.tan.length(), 1.0, 1e-4)
			and near(sm.right.length(), 1.0, 1e-4)
			and near(sm.up.length(), 1.0, 1e-4)
			and near(sm.tan.dot(sm.right), 0.0, 1e-4)
			and near(sm.tan.dot(sm.up), 0.0, 1e-4)
			and near(sm.right.dot(sm.up), 0.0, 1e-4)
		)
		horizontal_right = horizontal_right and near(sm.right.z, 0.0, 1e-4)
	check(orthonormal, "frames are orthonormal at every sample")
	check(horizontal_right, "unbanked road has a horizontal right vector")
	var up_ok = true
	for sm in t.samples:
		up_ok = up_ok and sm.up.z > .999
	check(up_ok, "unbanked road has up along world up")

	# Lateral sign must match track.gd, whose sample normal is (-ty, tx). Asserting the vector
	# directly pins the convention, rather than reasoning about which way a given circle is wound.
	var lateral_ok = true
	for sm in t.samples:
		lateral_ok = (lateral_ok and near(sm.right.x, -sm.tan.y, 1e-4) and near(sm.right.y, sm.tan.x, 1e-4))
	check(lateral_ok, "right vector matches track.gd's (-ty, tx) normal convention")

	# ---- banking is a rotation, not a cross-slope ----
	var b = Track3D.new()
	var bank_deg = 30.0
	b.load_data(circle_doc(200.0, 64, bank_deg))
	var bs = b.samples[0]
	var edge = Track3D.surface_point(bs, -6.0)
	check(
		near(edge.distance_to(bs.pos), 6.0, 1e-3),
		"banked road keeps its width across the surface (%.3f m)" % edge.distance_to(bs.pos)
	)
	check(
		near(edge.z - bs.pos.z, 6.0 * sin(deg_to_rad(bank_deg)), 1e-3),
		"positive bank raises the left edge by width * sin(bank)"
	)
	check(near(bs.right.z, -sin(deg_to_rad(bank_deg)), 1e-3), "right vector tilts by the bank angle")

	# A cross-slope model would place the edge at 6*tan(bank) and stretch the surface; assert the
	# ribbon differs from it, so this cannot silently regress to the old behaviour.
	check(
		absf((edge.z - bs.pos.z) - 6.0 * tan(deg_to_rad(bank_deg))) > .1,
		"banked geometry is a rotation, not the old linear cross-slope"
	)

	# ---- curvature decomposition ----
	var c = Track3D.new()
	c.load_data(circle_doc(150.0, 96))
	var curv_ok = true
	for sm in c.samples:
		curv_ok = curv_ok and near(absf(sm.curv), 1.0 / 150.0, 2e-4) and near(sm.kv, 0.0, 2e-4)
	check(curv_ok, "circle curvature resolves to 1/r laterally and zero vertically")

	# ---- the overpass ----
	var o = Track3D.new()
	var height = 6.0
	o.load_data(overpass_doc(200.0, height, 96))
	# Stations nearest each pass through the origin.
	var upper = -1
	var lower = -1
	for i in o.samples.size():
		var sm = o.samples[i]
		if Vector2(sm.pos.x, sm.pos.y).length() < 4.0:
			if sm.pos.z > 0 and (upper < 0 or sm.pos.z > o.samples[upper].pos.z):
				upper = i
			if sm.pos.z < 0 and (lower < 0 or sm.pos.z < o.samples[lower].pos.z):
				lower = i
	check(upper >= 0 and lower >= 0, "overpass has two decks at the crossing")
	var sep = o.samples[upper].pos.z - o.samples[lower].pos.z
	check(near(sep, 2 * height, .6), "decks are %.1f m apart vertically" % sep)

	# A cold query just above each deck must return that deck, not the other one. This is the case
	# the plan-view model cannot answer: both points share a plan position.
	var probe_up = o.samples[upper].pos + Vector3(0, 0, .5)
	var probe_down = o.samples[lower].pos + Vector3(0, 0, .5)
	var pr_up = o.project(probe_up)
	var pr_down = o.project(probe_down)
	check(
		absf(pr_up.pos.z - o.samples[upper].pos.z) < 1.0,
		"cold query above the upper deck resolves to the upper deck"
	)
	check(
		absf(pr_down.pos.z - o.samples[lower].pos.z) < 1.0,
		"cold query above the lower deck resolves to the lower deck"
	)
	check(
		absf(wrapf(pr_up.s - pr_down.s, -o.length / 2, o.length / 2)) > o.length * .2,
		"the two decks report arc stations half a lap apart"
	)
	check(
		near(pr_up.vert, .5, .15) and near(pr_down.vert, .5, .15), "height above surface is measured directly"
	)

	# Continuity: walk a point along the lower deck through the crossing, carrying the hint the way
	# a wheel does. It must never snap to the upper deck even while passing directly beneath it.
	var hint = -1
	var jumped = false
	var start_s = o.samples[lower].s - 120.0
	for step in 240:
		var s = start_s + step
		var pose = o.pose_at(s)
		var probe = pose.pos + pose.up * .3
		var pr = o.project(probe, hint)
		hint = pr.idx
		if absf(wrapf(pr.s - fposmod(s, o.length), -o.length / 2, o.length / 2)) > 8.0:
			jumped = true
	check(not jumped, "a tracked point stays on its own deck through the crossing")

	# ---- existing circuits still load ----
	for name in ["Monza", "Spa-Francorchamps", "Nurburgring-Nordschleife"]:
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/%s.json" % name))
		var real = Track3D.new()
		real.load_data(doc)
		var finite = true
		for sm in real.samples:
			finite = (
				finite
				and is_finite(sm.pos.x + sm.pos.y + sm.pos.z)
				and is_finite(sm.curv + sm.kv)
				and near(sm.right.length(), 1.0, 1e-3)
			)
		check(
			real.samples.size() > 100 and real.length > 1000 and finite,
			"%s loads as a ribbon: %d samples, %.0f m" % [name, real.samples.size(), real.length]
		)

	# ---- cross-section profiles ----
	var pf = Track3D.new()
	var pdoc = circle_doc(200.0, 64)
	# A 0.8 m ditch across the left third, flat elsewhere.
	for pt in pdoc.points:
		pt["profile"] = [[-1.0, .8], [-.7, .9], [-.4, .5], [-.25, 0.0], [1.0, 0.0]]
	pf.load_data(pdoc)
	var psm = pf.samples[0]
	var half = psm.w * .5
	check(psm.get("profile") != null, "profile survives resampling onto the sample grid")
	check(near(Track3D.profile_drop(psm, 1.0), 0.0, 1e-3), "flat side of the profile stays flat")
	check(near(Track3D.profile_drop(psm, -.7), .9, .02), "ditch reaches its authored depth")
	var flat_pt = Track3D.surface_point(psm, half)
	var ditch_pt = Track3D.surface_point(psm, -.7 * half)
	check(
		near(flat_pt.z - ditch_pt.z, .9, .03),
		"surface point drops into the ditch by %.2f m" % (flat_pt.z - ditch_pt.z)
	)
	# The normal must tilt on the ditch wall; a frame-only normal would leave the car flat. Scan
	# the cross-section rather than guessing where the wall is steepest.
	var wall_tilt = 0.0
	for k in 65:
		var u = -1.0 + 2.0 * k / 64.0
		wall_tilt = maxf(wall_tilt, rad_to_deg(acos(clampf(Track3D.surface_normal(psm, u).z, -1, 1))))
	var flat_tilt = rad_to_deg(acos(clampf(Track3D.surface_normal(psm, .5).z, -1, 1)))
	check(wall_tilt > 20.0, "ditch wall tilts the surface normal (%.1f deg)" % wall_tilt)
	check(flat_tilt < 2.0, "flat road keeps an upright normal (%.1f deg)" % flat_tilt)

	# A track with no profile anywhere must cost nothing and behave exactly as before.
	var noprof = true
	for sm in t.samples:
		noprof = noprof and sm.get("profile") == null and near(Track3D.profile_drop(sm, -.5), 0.0, 1e-9)
	check(noprof, "unprofiled circuits carry no cross-section data")

	# ---- the Karussell ----
	var nord = Track3D.new()
	nord.load_data(
		JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Nurburgring-Nordschleife.json"))
	)
	for spec in [["Caracciola-Karussell", 0.9, 25.0], ["Kleines Karussell", 0.45, 15.0]]:
		var anchor = null
		for l in nord.data.presentation.labels:
			if l.name == spec[0]:
				anchor = Vector3(float(l.x), float(l.y), nord.probe_height(-1))
		var ksm = nord.samples[nord.project(anchor).idx]
		var deepest = 0.0
		var steepest = 0.0
		for k in 65:
			var u = -1.0 + 2.0 * k / 64.0
			deepest = maxf(deepest, Track3D.profile_drop(ksm, u))
			steepest = maxf(steepest, rad_to_deg(acos(clampf(Track3D.surface_normal(ksm, u).z, -1, 1))))
		check(deepest > spec[1], "%s is a ditch %.2f m deep" % [spec[0], deepest])
		check(steepest > spec[2], "%s banks to %.0f deg across the concrete" % [spec[0], steepest])
	var straight = nord.samples[nord.project(Vector3(-219.4, 2304.7, nord.probe_height(-1))).idx]
	check(straight.get("profile") == null, "Antoniusbuche straight is left unprofiled")

	# ---- drop-in parity with the plan-view model ----
	# Where no profile is present the ribbon must agree with track.gd, or swapping the model under
	# the car would silently move every circuit. Spa has real elevation and no cross-sections.
	var legacy = load("res://scripts/track.gd").new()
	var spa_doc = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Spa-Francorchamps.json"))
	legacy.load_data(spa_doc)
	var ribbon = Track3D.new()
	ribbon.load_data(spa_doc)
	# Compare the curves in space, not at equal arc distance: the two models parameterise the lap
	# differently, so equal s is not the same place on the circuit.
	check(ribbon.samples.size() == legacy.samples.size(), "sample counts match (%d)" % ribbon.samples.size())
	var worst_pos = 0.0
	for sm in legacy.samples:
		var q = Vector3(sm.x, sm.y, sm.z)
		worst_pos = maxf(worst_pos, ribbon.project(q).pos.distance_to(q))
	check(worst_pos < .01, "centreline is the same curve in space (worst %.4f m)" % worst_pos)
	check(
		ribbon.checkpoints.size() == legacy.checkpoints.size(),
		"checkpoint count matches (%d)" % ribbon.checkpoints.size()
	)
	# track.gd sums segment lengths in plan view only (a.len drops the z term), so it under-measures
	# every climb. The ribbon sums true 3-space distance and is therefore slightly longer. Assert the
	# direction and the scale, so a regression to 2-D arc length would be caught.
	var gain = ribbon.length - legacy.length
	check(
		gain > 0 and gain / legacy.length < .005,
		(
			"3-space lap is %.2f m longer than the plan-view lap (%.3f%%), as elevation requires"
			% [gain, 100.0 * gain / legacy.length]
		)
	)
	var surf_match = 0
	var surf_total = 0
	for k in 300:
		var s = ribbon.length * k / 300.0
		var pose = ribbon.pos_at(s)
		for lat in [-3.0, 0.0, 3.0]:
			var wx = pose.x - sin(pose.h) * lat
			var wy = pose.y + cos(pose.h) * lat
			var wa = {"sIdx": -1}
			var wb = {"sIdx": -1}
			surf_total += 1
			if ribbon.surface_at(wx, wy, wa).id == legacy.surface_at(wx, wy, wb).id:
				surf_match += 1
	check(
		surf_match >= surf_total - 2,
		"surface classification agrees on %d of %d probes" % [surf_match, surf_total]
	)

	print(
		(
			"TRACK3D %s  %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
