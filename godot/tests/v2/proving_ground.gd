extends SceneTree
## P5-03 measured gates on the generated proving ground. All contacts run inside a physics frame.
const Generator = preload("res://trackgen/proving_ground.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const DT = 1.0 / 240.0
var asset
var road
var surf
var presets
var checks = 0
var failures = []
var results = {}
var frames = 0
var ran = false
var kerb_curve
var kerb_spline
var kerb_sections


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures.append(label)


func _initialize() -> void:
	asset = Generator.build_asset()
	road = asset.get_node("Main")
	root.add_child(asset)
	presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var errors = asset.validate()
	check(errors.is_empty(), "generated TrackAsset validates: %s" % [errors])
	check(road.last_bake.warnings.is_empty(), "road bake has zero warnings: %s" % [road.last_bake.warnings])
	check(
		asset.length > 2450.0 and asset.length < 2550.0,
		"3D lap length %.3f m (plan %.3f m)" % [asset.length, Generator.plan_length()]
	)
	check(
		asset.get_node_or_null("BotLine") != null and asset.get_node_or_null("DitchChallengeLine") != null,
		"BotLine and ditch challenge line are authored"
	)
	check(
		(
			asset.get_node("Lights").get_child_count() == 18
			and asset.get_node("Scenery/Trees").multimesh.instance_count >= 180
		),
		"18 night lamps and deterministic roadside trees are baked"
	)
	surf = asset.surface()
	kerb_curve = road.working_curve()
	kerb_spline = RoadBuilder.elevation_spline(road.elevation_keys, road.last_bake.length, true)
	kerb_sections = road.sections.duplicate()
	kerb_sections.sort_custom(func(a, b): return a.at < b.at)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	if ran:
		print("PROVING GROUND RESULTS aborted by script error (see stderr)")
		quit(1)
		return true
	ran = true
	grid_and_geometry()
	kerbs()
	driven_kerbs()
	crest()
	crest_landing()
	bowl()
	compression()
	ditch_challenge()
	bot_lap(false)
	bot_lap(true)
	print(
		"PROVING GROUND RESULTS ",
		JSON.stringify({"checks": checks, "failures": failures, "results": results})
	)
	quit(0 if failures.is_empty() else 1)
	return true


func hit_at(p: Vector3) -> Dictionary:
	return surf.contact(p + Vector3.UP * 5.0, Vector3.DOWN, 10.0, -1)


func car_at(s: float, kmh: float, lateral = 0.0, simcade = false) -> CarBody:
	var st = asset.station(s)
	var right = st.tangent.cross(Vector3.UP).normalized()
	var hit = hit_at(st.pos + right * lateral)
	var c = CarBody.new()
	c.simcade_enabled = simcade
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	c.place(hit.point, atan2(st.tangent.z, st.tangent.x), hit.point.y)
	var up = hit.normal
	var fwd = (st.tangent - up * st.tangent.dot(up)).normalized()
	c.rot = Basis(fwd, up, fwd.cross(up)).orthonormalized().get_rotation_quaternion()
	c.pos = hit.point + up * c.setup.cgHeight
	c.launch(kmh / 3.6)
	return c


func driver(c: CarBody, target: Vector3, kmh: float) -> void:
	var h_target = atan2(target.z - c.pos.z, target.x - c.pos.x)
	var steer = clampf(wrapf(h_target - c.h, -PI, PI) * 2.5, -1.0, 1.0)
	var e = kmh / 3.6 - c.speed
	c.input = {
		"throttle": clampf(e * .5 + .3, 0.0, 1.0),
		"brake": clampf(-e * .3, 0.0, 1.0),
		"steer": steer,
		"clutch": 0.0,
		"handbrake": 0.0
	}


## Interpolate an authored line by timing station, not by its slightly different 3D arc length.
func line_point(path: Path3D, s: float) -> Vector3:
	var keys = path.get_meta("timing_stations_m")
	s = fposmod(s, road.last_bake.length)
	var lo = 0
	var hi = keys.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if keys[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	var next = mini(lo + 1, keys.size() - 1)
	var t = clampf((s - keys[lo]) / maxf(keys[next] - keys[lo], 1e-6), 0.0, 1.0)
	return path.curve.get_point_position(lo).lerp(path.curve.get_point_position(next), t)


func line_speed(path: Path3D, s: float) -> float:
	var keys = path.get_meta("timing_stations_m")
	var speeds = path.get_meta("target_speeds_kmh")
	s = fposmod(s, road.last_bake.length)
	var lo = 0
	var hi = keys.size() - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if keys[mid] <= s:
			lo = mid
		else:
			hi = mid - 1
	return speeds[lo]


## Road frame for a driven kerb crossing; right is positive, matching the road tool.
func driven_kerb_point(s: float, lateral: float) -> Dictionary:
	var length = road.last_bake.length
	var st = RoadBuilder.station_at(kerb_curve, true, length, kerb_spline, s)
	var sec = RoadBuilder.section_at(kerb_sections, s, length, true)
	var frame = RoadBuilder.frame(st.tangent, sec.bank_deg)
	return {"pos": st.pos + frame[0] * lateral, "tangent": st.tangent, "sec": sec}


## Drive the 296 from the lane centre over one kerb at approximately 11 degrees.
## The load and compression measurements are probes until P2-06 is accepted.
func drive_kerb(name: String, station: float, side: int, kmh: int) -> void:
	var start = driven_kerb_point(station - 45.0, 0.0)
	var hit = surf.contact(start.pos + Vector3.UP * 3.0, Vector3.DOWN, 6.0, -1)
	if hit.is_empty():
		check(false, "%s %d km/h: no starting road contact" % [name, kmh])
		return
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	c.place(hit.point, atan2(start.tangent.z, start.tangent.x), hit.point.y)
	var up = hit.normal
	var fwd = (start.tangent - up * start.tangent.dot(up)).normalized()
	c.rot = Basis(fwd, up, fwd.cross(up)).orthonormalized().get_rotation_quaternion()
	c.pos = hit.point + up * c.setup.cgHeight
	c.launch(kmh / 3.6)
	var sec = driven_kerb_point(station, 0.0).sec
	var width = sec.width_left if side < 0 else sec.width_right
	var beyond = side * (width + sec.kerb_width + 1.5)
	var static_load = c.p.mass * 9.81 / 4.0
	var peak = 0.0
	var jump = 0.0
	var roll = 0.0
	var yaw = 0.0
	var min_contacts = 4
	var min_up = 1.0
	var kerb_ticks = 0
	var cross_angle = 0.0
	var crossing_measured = false
	var prev = [0.0, 0.0, 0.0, 0.0]
	var travelled = 0.0
	var finite = true
	var ticks = 0
	var loose_since = -1.0
	var longest_recovery = 0.0
	var last_kerb_tick = -1
	while travelled < 120.0 and ticks < 240 * 10:
		var s_car = station - 45.0 + travelled
		var ramp = clampf((s_car - (station - 40.0)) / 35.0, 0.0, 1.0)
		var target = driven_kerb_point(s_car + 15.0, beyond * smoothstep(0.0, 1.0, ramp)).pos
		driver(c, target, float(kmh))
		c.step(DT, surf, true)
		travelled += c.speed * DT
		ticks += 1
		finite = finite and is_finite(c.pos_x + c.pos_y + c.pos_z)
		finite = finite and is_finite(c.vel.length()) and is_finite(c.ang.length())
		if not finite:
			break
		var on_kerb = false
		for k in 4:
			var w = c.wheels[k]
			peak = maxf(peak, w.load / static_load)
			if ticks > 1:
				jump = maxf(jump, absf(w.comp - prev[k]))
			prev[k] = w.comp
			if w.surf.id == 1 and w.load > 0.0:
				kerb_ticks += 1
				on_kerb = true
		if on_kerb:
			last_kerb_tick = ticks
		if on_kerb and not crossing_measured:
			var tangent = driven_kerb_point(s_car, 0.0).tangent
			cross_angle = absf(rad_to_deg(wrapf(c.h - atan2(tangent.z, tangent.x), -PI, PI)))
			crossing_measured = true
		roll = maxf(roll, absf(c.ang.x))
		yaw = maxf(yaw, absf(c.ang.y))
		min_contacts = mini(min_contacts, c.contacts)
		min_up = minf(min_up, c.basis().y.dot(Vector3.UP))
		if kerb_ticks > 0:
			if c.contacts < 4 and loose_since < 0.0:
				loose_since = ticks * DT
			elif c.contacts == 4 and loose_since >= 0.0:
				longest_recovery = maxf(longest_recovery, ticks * DT - loose_since)
				loose_since = -1.0
		# Stop after the crossing and a quarter-second of stable four-wheel contact. Continuing onto
		# the verge tests a different route and can reach the next terrain feature.
		if (
			last_kerb_tick >= 0
			and c.contacts == 4
			and loose_since < 0.0
			and (ticks - last_kerb_tick) * DT >= .25
		):
			break
		if loose_since >= 0.0 and ticks * DT - loose_since >= 2.0:
			break
	var recovered = (
		last_kerb_tick >= 0
		and loose_since < 0.0
		and c.contacts == 4
		and longest_recovery <= 2.0
		and (ticks - last_kerb_tick) * DT >= .25
	)
	var key = "%s_%d" % [name, kmh]
	results["driven_kerb_" + key] = {
		"peak_load_static": peak,
		"compression_jump_mm": jump * 1000.0,
		"roll_rate_rad_s": roll,
		"yaw_rate_rad_s": yaw,
		"min_wheels_down": min_contacts,
		"kerb_wheel_ticks": kerb_ticks,
		"cross_angle_deg": cross_angle,
		"longest_recovery_s": longest_recovery,
		"up_dot_min": min_up,
		"back_on_four": recovered
	}
	print(
		(
			"PROBE %s %d km/h: peak %.2fx static, jump %.1f mm, roll %.2f rad/s, yaw %.2f rad/s, min wheels %d, kerb wheel-ticks %d, crossing %.1f deg, recovery %.2f s"
			% [
				name,
				kmh,
				peak,
				jump * 1000.0,
				roll,
				yaw,
				min_contacts,
				kerb_ticks,
				cross_angle,
				longest_recovery
			]
		)
	)
	check(
		finite and kerb_ticks > 0 and min_up > 0.0 and recovered,
		(
			"%s %d km/h kerb drive: finite, never inverted, back on four wheels within 2 s (up dot %.2f, four %s)"
			% [name, kmh, min_up, recovered]
		)
	)


func driven_kerbs() -> void:
	for kerb in [["bevel", 990.0, -1], ["ribbed", 1750.0, 1], ["sausage", 2150.0, -1]]:
		for kmh in [60, 120]:
			drive_kerb(kerb[0], kerb[1], kerb[2], kmh)


func grid_and_geometry() -> void:
	var slots = asset.grid_slots()
	var all_tarmac = slots.size() == 4
	for xf in slots:
		var hit = hit_at(xf.origin)
		all_tarmac = all_tarmac and not hit.is_empty() and hit.surface == 0
	check(all_tarmac, "four level-grid slots rest on tarmac")
	var elev = road.elevation_keys
	var spline = RoadBuilder.elevation_spline(elev, road.last_bake.length, true)
	var apex = Generator.actual_station(road.working_curve(), 1115.0, road.last_bake.length)
	var h = 1.0
	var y0 = RoadBuilder.elevation_at(spline, apex - h, road.last_bake.length, true)
	var y1 = RoadBuilder.elevation_at(spline, apex, road.last_bake.length, true)
	var y2 = RoadBuilder.elevation_at(spline, apex + h, road.last_bake.length, true)
	var radius = -h * h / (y0 - 2.0 * y1 + y2)
	results["crest_radius_m"] = radius
	check(radius > 115.0 and radius < 145.0, "re-keyed crest apex radius %.1f m (target ~130)" % radius)
	var ditch_keys = road.sections
	var a = RoadBuilder.section_at(ditch_keys, 1380.0, road.last_bake.length, true).ditch
	var b = RoadBuilder.section_at(ditch_keys, 1395.0, road.last_bake.length, true).ditch
	var d = RoadBuilder.section_at(ditch_keys, 1410.0, road.last_bake.length, true).ditch
	check(
		a < .03 and b > .35 and b < .65 and d > .97,
		"ditch entry eases over 30 m (factor %.2f / %.2f / %.2f)" % [a, b, d]
	)


func kerb_probe(s: float, sign: int, fraction: float) -> Dictionary:
	var length = road.last_bake.length
	var curve = road.working_curve()
	var spline = RoadBuilder.elevation_spline(road.elevation_keys, length, true)
	var st = RoadBuilder.station_at(curve, true, length, spline, s)
	var keys = road.sections.duplicate()
	keys.sort_custom(func(a, b): return a.at < b.at)
	var sec = RoadBuilder.section_at(keys, s, length, true)
	var fr = RoadBuilder.frame(st.tangent, sec.bank_deg)
	var width = sec.width_left if sign < 0 else sec.width_right
	var lat = sign * (width + sec.kerb_width * fraction)
	var base = st.pos + fr[0] * lat
	var hit = surf.contact(base + fr[1] * 2.0, -fr[1], 4.0, -1)
	return {
		"surface": hit.get("surface", -1),
		"height": (hit.point - base).dot(fr[1]) if not hit.is_empty() else -999.0
	}


func kerbs() -> void:
	var paint = kerb_probe(30.0, 1, .5)
	var paint_edge = kerb_probe(30.0, 1, 0.0)
	var low = kerb_probe(980.0, -1, .5)
	var low_edge = kerb_probe(980.0, -1, 0.0)
	var sausage = kerb_probe(2150.0, -1, .5)
	var sausage_edge = kerb_probe(2150.0, -1, 0.0)
	var paint_rise = paint.height - paint_edge.height
	var low_rise = low.height - low_edge.height
	var sausage_rise = sausage.height - sausage_edge.height
	var rib_min = INF
	var rib_max = -INF
	var rib_sid = true
	for k in 41:
		var rib = kerb_probe(1700.0 + .05 * k, 1, .5)
		rib_min = minf(rib_min, rib.height)
		rib_max = maxf(rib_max, rib.height)
		rib_sid = rib_sid and rib.surface == 1
	results["kerb_rises_m"] = {
		"paint": paint_rise,
		"bevel": low_rise,
		"rib_min": rib_min,
		"rib_max": rib_max,
		"sausage": sausage_rise
	}
	check(
		paint.surface == 1 and absf(paint_rise) < .005,
		"paint control: kerb surface 1, zero rise (%.3f m)" % paint_rise
	)
	check(
		low.surface == 1 and absf(low_rise - .02) < .01,
		"low bevel: kerb surface 1, half-width rise %.3f m" % low_rise
	)
	check(
		rib_sid and rib_min > .035 and rib_max > rib_min + .005,
		"ribbed kerb: base %.3f m, ridge %.3f m" % [rib_min, rib_max - rib_min]
	)
	check(
		sausage.surface == 1 and absf(sausage_rise - .09) < .012,
		"high sausage: kerb surface 1, mid-width rise %.3f m" % sausage_rise
	)


func crest_trial(kmh: float) -> Dictionary:
	var c = car_at(1020.0, kmh)
	var hint = -1
	var off = false
	var off_run = 0
	var max_off_run = 0
	var first_off_kmh = 0.0
	var first_off_s = 0.0
	var run_start_s = 0.0
	var run_start_kmh = 0.0
	var apex_kmh = 0.0
	var min_contacts = 4
	for i in 240 * 7:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		if pr.s > 1170.0:
			break
		driver(c, asset.station(pr.s + 20.0).pos, kmh)
		c.step(DT, surf, true)
		if pr.s > 1040.0 and pr.s < 1165.0:
			min_contacts = mini(min_contacts, c.contacts)
			if absf(pr.s - 1115.0) < .3:
				apex_kmh = c.speed * 3.6
			if c.contacts == 0:
				off_run += 1
				max_off_run = maxi(max_off_run, off_run)
				if off_run == 1:
					run_start_s = pr.s
					run_start_kmh = c.speed * 3.6
				if off_run >= 24 and not off:
					off = true
					first_off_s = run_start_s
					first_off_kmh = run_start_kmh
			else:
				off_run = 0
	return {
		"off": off,
		"first_off_kmh": first_off_kmh,
		"first_off_s": first_off_s,
		"apex_kmh": apex_kmh,
		"min_contacts": min_contacts,
		"max_off_s": max_off_run * DT
	}


func crest() -> void:
	var low = 110.0
	var high = 180.0
	var low_trial = crest_trial(low)
	var high_trial = crest_trial(high)
	for i in 8:
		var mid = (low + high) * .5
		var trial = crest_trial(mid)
		if trial.off:
			high = mid
			high_trial = trial
		else:
			low = mid
			low_trial = trial
	var threshold = high_trial.first_off_kmh
	results["crest_takeoff_kmh"] = threshold
	results["crest_first_off_s"] = high_trial.first_off_s
	results["crest_bracket_input_kmh"] = [low, high]
	check(
		not low_trial.off and high_trial.off and high - low < .3 and threshold > 135.0 and threshold < 160.0,
		(
			"crest takeoff bisection: input %.1f..%.1f km/h, observed first unload %.1f km/h at s %.1f"
			% [low, high, threshold, high_trial.first_off_s]
		)
	)


func crest_landing() -> void:
	# A few km/h over the take-off threshold the bisection found (crest() runs first), so the flight
	# check follows the chassis: compliance (P2-comp) moved take-off from 148 to 152.5 km/h input.
	var bracket = results.get("crest_bracket_input_kmh", [147.0, 147.0])
	var kmh = bracket[1] + 3.0
	var c = car_at(1020.0, kmh)
	var hint = -1
	var off_run = 0
	var run_start_s = -1.0
	var airborne = false
	var first_off_s = -1.0
	var land_s = -1.0
	var peak_clearance = 0.0
	for i in 240 * 14:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		if pr.s > 1390.0:
			break
		driver(c, asset.station(pr.s + 20.0).pos, kmh)
		c.step(DT, surf, true)
		if pr.s > 1040.0 and c.contacts == 0:
			off_run += 1
			if off_run == 1:
				run_start_s = pr.s
			if off_run >= 24 and not airborne:
				airborne = true
				first_off_s = run_start_s
			if airborne:
				var ground = hit_at(c.pos)
				if not ground.is_empty():
					peak_clearance = maxf(peak_clearance, c.pos.y - c.setup.cgHeight - ground.point.y)
		else:
			off_run = 0
			if airborne and land_s < 0.0:
				land_s = pr.s
				break
	results["crest_flight_kmh"] = kmh
	results["crest_flight_takeoff_s"] = first_off_s
	results["crest_flight_landing_s"] = land_s
	results["crest_flight_peak_clearance_m"] = peak_clearance
	check(
		airborne and first_off_s >= 1040.0 and land_s > first_off_s and land_s < 1380.0,
		(
			"%.1f km/h crest flight: takeoff s %.1f, landing s %.1f before T3, peak clearance %.2f m"
			% [kmh, first_off_s, land_s, peak_clearance]
		)
	)


func bowl() -> void:
	var design = sqrt(9.81 * 130.0 * tan(deg_to_rad(16.0))) * 3.6
	var c = car_at(215.0, design)
	var hint = -1
	var lat_sum = 0.0
	var speed_sum = 0.0
	var samples = 0
	var max_error = 0.0
	for i in 240 * 12:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		if pr.s > 330.0:
			break
		driver(c, asset.station(pr.s + 9.0 + c.speed * .4).pos, design)
		c.step(DT, surf, true)
		if pr.s > 240.0 and pr.s < 285.0:
			speed_sum += c.speed * 3.6
			for w in c.wheels:
				lat_sum += absf(w.fy)
			max_error = maxf(max_error, absf(pr.lateral))
			samples += 1
	var share = lat_sum / maxf(samples * c.p.mass * 9.81, 1.0)
	var observed = speed_sum / maxf(samples, 1)
	results["bowl_design_kmh"] = design
	results["bowl_observed_kmh"] = observed
	results["bowl_lateral_share"] = share
	results["bowl_max_lateral_error_m"] = max_error
	check(
		(
			samples > 300
			and absf(observed - design) < 8.0
			and is_finite(share)
			and share < .35
			and max_error < 5.0
		),
		(
			"bowl at %.1f km/h (target %.1f): |Fy| sum %.1f%% of mg, max path error %.2f m"
			% [observed, design, share * 100.0, max_error]
		)
	)


func compression() -> void:
	var c = car_at(1885.0, 100.0)
	var hint = -1
	var peak = 0.0
	var speed_sum = 0.0
	var bottom = 0
	var samples = 0
	for i in 240 * 12:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		if pr.s > 2030.0:
			break
		driver(c, asset.station(pr.s + 18.0).pos, 100.0)
		c.step(DT, surf, true)
		if pr.s > 1940.0 and pr.s < 2000.0:
			speed_sum += c.speed * 3.6
			var load = 0.0
			for w in c.wheels:
				load += w.load
			peak = maxf(peak, load / (c.p.mass * 9.81))
			bottom += int(c.body_contacts > 0)
			samples += 1
	var observed = speed_sum / maxf(samples, 1)
	results["compression_observed_kmh"] = observed
	results["compression_peak_mg"] = peak
	results["compression_body_contact_ticks"] = bottom
	check(
		samples > 300 and absf(observed - 100.0) < 10.0 and peak > 1.2 and peak < 4.0,
		(
			"compression at %.1f km/h (target 100): peak %.2f x mg, body-contact ticks %d"
			% [observed, peak, bottom]
		)
	)


func ditch_challenge() -> void:
	var path = asset.get_node("DitchChallengeLine")
	var spline = RoadBuilder.elevation_spline(road.elevation_keys, road.last_bake.length, true)
	var c = car_at(1365.0, 50.0)
	var hint = -1
	var min_drop = INF
	var speed_sum = 0.0
	var light_ticks = 0
	var off_tarmac = 0
	var samples = 0
	for i in 240 * 35:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		if pr.s > 1610.0:
			break
		driver(c, line_point(path, pr.s + 9.0), 50.0)
		c.step(DT, surf, true)
		if pr.s > 1420.0 and pr.s < 1560.0:
			speed_sum += c.speed * 3.6
			min_drop = minf(
				min_drop,
				(
					c.pos.y
					- c.setup.cgHeight
					- RoadBuilder.elevation_at(spline, pr.s, road.last_bake.length, true)
				)
			)
			light_ticks += int(c.contacts < 4)
			for w in c.wheels:
				off_tarmac += int(w.surf.id != 0)
			samples += 1
	var observed = speed_sum / maxf(samples, 1)
	results["ditch_observed_kmh"] = observed
	results["ditch_min_ride_vs_center_m"] = min_drop
	results["ditch_light_s"] = light_ticks * DT
	results["ditch_off_tarmac_wheel_ticks"] = off_tarmac
	check(
		(
			samples > 600
			and absf(observed - 50.0) < 8.0
			and min_drop < -.4
			and min_drop > -2.0
			and off_tarmac == 0
		),
		(
			"ditch challenge at %.1f km/h (target 50): ride %.2f m below centre, light %.2f s, off-tarmac wheel ticks %d"
			% [observed, min_drop, light_ticks * DT, off_tarmac]
		)
	)


func bot_lap(simcade: bool) -> void:
	var path = asset.get_node("BotLine")
	var pole = asset.grid_slots()[0]
	var fwd = -pole.basis.z
	var c = CarBody.new()
	c.simcade_enabled = simcade
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	c.launch(60.0 / 3.6)
	var wall_lines = []
	for wall in asset.get_node("Walls").get_children():
		wall_lines.append(wall.get_meta("wall_line"))
	var gates = asset.gates()
	var next_gate = 0
	var started = -1.0
	var lap_time = -1.0
	var hint = -1
	var off_steps = 0
	var max_error = 0.0
	var min_wall = INF
	var prev = c.pos
	var time = 0.0
	for i in 240 * 230:
		var pr = asset.project(c.pos, hint)
		hint = pr.idx
		var lookahead = 9.0 + c.speed * .5
		driver(c, line_point(path, pr.s + lookahead), line_speed(path, pr.s + lookahead))
		c.step(DT, surf, true)
		time += DT
		for w in c.wheels:
			if w.surf.id >= 2:
				off_steps += 1
		max_error = maxf(max_error, absf(pr.lateral))
		if i % 48 == 0:
			var xz = Vector2(c.pos.x, c.pos.z)
			for line in wall_lines:
				for k in line.size():
					var a = Vector2(line[k].x, line[k].z)
					var b = Vector2(line[(k + 1) % line.size()].x, line[(k + 1) % line.size()].z)
					var ab = b - a
					var u = clampf((xz - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
					min_wall = minf(min_wall, xz.distance_to(a + ab * u))
		if TrackAsset.crossed(gates[next_gate], prev, c.pos):
			if next_gate == 0:
				if started >= 0.0:
					lap_time = time - started
					break
				started = time
				next_gate = 1
			else:
				next_gate = (next_gate + 1) % gates.size()
		prev = c.pos
		if not is_finite(c.pos.length()) or pr.distance > 40.0:
			break
	var key = "simcade" if simcade else "simulation"
	results[key + "_bot_lap_s"] = lap_time
	results[key + "_off_wheel_ticks"] = off_steps
	results[key + "_max_lateral_m"] = max_error
	results[key + "_min_wall_m"] = min_wall
	check(
		lap_time > 0.0 and off_steps == 0 and max_error < 6.0 and min_wall > 3.0,
		(
			"%s 296 BotLine lap %.2f s, off-wheel ticks %d, max lateral %.2f m, min wall %.2f m"
			% [key, lap_time, off_steps, max_error, min_wall]
		)
	)
