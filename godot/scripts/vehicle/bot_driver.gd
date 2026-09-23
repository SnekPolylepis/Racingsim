extends RefCounted
## A bot for the 6-DOF CarBody on an authored TrackAsset (REBUILD-PLAN.md P4-07): follows the track's
## BotLine (§5.3) at a set fraction of *this car's* grip, so the same line serves every car. The legacy
## scripts/showcase_driver.gd drives the planar CarModel on JSON tracks and is untouched (P7 removes it).
##
## Speed plan, per metre of line: the banked-turn cornering limit from the line's plan-view curvature,
## the road's bank under it (sampled from the surface; off-camber lowers it), and the car's tyre grip
## with downforce and the tyre model's load sensitivity; a crest limit so the wheels stay loaded
## (v^2 <= 0.85 g R over convex vertical curves); a top-speed cap; then a backward pass for the braking
## zones. The BotLine's own target speeds are ignored unless `use_line_targets` (the proving ground's
## are a conservative 60-75 km/h).
## Steering: pure pursuit to a point ahead on the line plus a small capped cross-track term, turned into
## the car's steering input range at its current speed. Throttle and brake: proportional on the planned
## speed just ahead, easing off when more than 1 m off the line.

## Cross-track steering gain (1/s): radians of steer per metre off the line at 1 m/s.
const CROSS_GAIN = .5
## Most steering the cross-track term adds, radians (3 degrees).
const CROSS_MAX = .052
## Fraction of the grip limit the plan uses (cornering and braking). 0.88 put the aid-free roadster on
## the edge in the proving ground's narrow ditch bypass; a validation bot needs margin more than pace.
var pace = .85
var use_line_targets = false
## Plan-view points of the line (asset space), cumulative distance, and planned speed (m/s) per point.
var points = PackedVector3Array()
var dist = PackedFloat64Array()
var plan = PackedFloat64Array()
var length = 0.0
var hint = -1
## Last projection: distance along the line and lateral offset (right positive).
var s = 0.0
var lateral = 0.0
var off_line = 0.0


## `surface` (optional, §5.2) gives the road's bank under the line; a TrackSurface must then be passed
## from inside a physics frame. Without it the road is taken as level.
func _init(bot_line: Path3D, car, surface = null, pace_fraction = .85, line_targets = false):
	pace = pace_fraction
	use_line_targets = line_targets
	var pts = bot_line.curve.get_baked_points()
	var xf = bot_line.transform
	for p in pts:
		points.append(xf * p)
	# The curve closes by repeating its first point; drop it so the loop wraps cleanly.
	if points.size() > 2 and points[0].distance_to(points[points.size() - 1]) < .5:
		points.remove_at(points.size() - 1)
	var n = points.size()
	dist.resize(n + 1)
	dist[0] = 0.0
	for i in n:
		dist[i + 1] = dist[i] + points[i].distance_to(points[(i + 1) % n])
	length = dist[n]
	build_plan(bot_line, car, surface)


## Road bank under line point i, radians, positive when the road's right side is lower.
func bank_right(surface, i: int) -> float:
	if surface == null:
		return 0.0
	var n = points.size()
	var hit = surface.contact(points[i] + Vector3.UP * 3.0, Vector3.DOWN, 6.0, -1)
	if hit.is_empty():
		return 0.0
	var t = (points[(i + 1) % n] - points[(i - 1 + n) % n]).normalized()
	var right = t.cross(Vector3.UP).normalized()
	return asin(clampf(hit.normal.dot(right), -1.0, 1.0))


func build_plan(bot_line: Path3D, car, surface):
	var n = points.size()
	var g = car.G
	var down = car.RHO * (car.setup.clAF + car.setup.clAR) / (2.0 * car.p.mass)
	# Load sensitivity as the tyre model has it (tyre.gd): grip per unit load falls as downforce loads
	# the tyres, so downforce is worth less than its raw load.
	var sens = car.setup.loadSens * (car.simcade.load_sensitivity_scale if car.simcade_enabled else 1.0)
	var mu0 = car.setup.tireMu * pace
	var brake = .75 * mu0 * g
	var top = 90.0
	plan.resize(n)
	# Cornering grip each point needs at its planned speed is taken from braking (friction circle).
	var lat_use = PackedFloat64Array()
	lat_use.resize(n)
	var k = 6
	var bank = 0.0
	for i in n:
		var a = points[(i - k + n) % n]
		var b = points[i]
		var c = points[(i + k) % n]
		var ab = Vector2(b.x - a.x, b.z - a.z)
		var bc = Vector2(c.x - b.x, c.z - b.z)
		var curv = plan_curvature(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
		if i % 4 == 0:
			bank = bank_right(surface, i)
		# Bank into the turn helps, away from it (off-camber) hurts: right turns want the right side low.
		var theta = bank if ab.cross(bc) >= 0 else -bank
		var v = top
		if curv > 1e-6:
			# Banked-turn capacity with downforce, solved for v by a few fixed-point steps.
			v = sqrt(mu0 * g / curv)
			for it in 6:
				var extra = down * v * v / g
				var mu = mu0 * clampf(1.0 - sens * extra, .5, 1.3)
				var den = cos(theta) - mu * sin(theta)
				var cap = (g * sin(theta) + mu * (g * cos(theta) + down * v * v)) / maxf(den, .05)
				v = minf(top, sqrt(maxf(cap, .1) / curv))
		# Crest: vertical curvature from the heights either side (negative = convex).
		var ds = dist[i] - dist[(i - k + n) % n] if i >= k else dist[i] + length - dist[i - k + n]
		ds = maxf(absf(ds), 1.0)
		var kv = (a.y - 2.0 * b.y + c.y) / (ds * ds)
		if kv < -1e-5:
			v = minf(v, sqrt(.85 * g / -kv))
		plan[i] = v
		lat_use[i] = curv
	if use_line_targets and bot_line.has_meta("target_speeds_kmh"):
		var at = bot_line.get_meta("timing_stations_m")
		var sp = bot_line.get_meta("target_speeds_kmh")
		for i in n:
			var j = 0
			while j < at.size() - 1 and at[j + 1] <= dist[i]:
				j += 1
			plan[i] = minf(plan[i], sp[j] / 3.6)
	# Braking zones: backward passes around the loop (twice, so the lap's end feeds its start). Braking
	# into a corner shares the tyres with cornering: deceleration is cut by the friction circle, so the
	# car arrives slow enough to turn instead of braking at full grip into the apex (the roadster,
	# without ABS, locked its fronts at Spa and went straight on).
	for rep in 2:
		for step in n:
			var i = n - 1 - step
			var nxt = (i + 1) % n
			var seg = dist[i + 1] - dist[i]
			var lat = plan[nxt] * plan[nxt] * lat_use[nxt] / (mu0 * g)
			var decel = brake * sqrt(maxf(1.0 - lat * lat, .1))
			plan[i] = minf(plan[i], sqrt(plan[nxt] * plan[nxt] + 2.0 * decel * seg))


## Curvature (1/m) of the circle through three plan-view points.
static func plan_curvature(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab = b - a
	var bc = c - b
	var ac = c - a
	var den = ab.length() * bc.length() * ac.length()
	if den < 1e-9:
		return 0.0
	return 2.0 * absf(ab.cross(bc)) / den


## Nearest point on the line to `p` (3D), searched near the last one once found.
func project(p: Vector3):
	var n = points.size()
	var from = 0
	var count = n
	if hint >= 0:
		from = hint - 30
		count = 61
	var best = INF
	var best_i = 0
	var best_t = 0.0
	for j in count:
		var i = posmod(from + j, n)
		var a = points[i]
		var b = points[(i + 1) % n]
		var ab = b - a
		var t = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d = p.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			best_i = i
			best_t = t
	hint = best_i
	s = dist[best_i] + (dist[best_i + 1] - dist[best_i]) * best_t
	off_line = sqrt(best)
	var a2 = points[best_i]
	var b2 = points[(best_i + 1) % n]
	var right = (b2 - a2).normalized().cross(Vector3.UP)
	lateral = (p - (a2 + (b2 - a2) * best_t)).dot(right)


## Point on the line at distance `at` (wrapped).
func point_at(at: float) -> Vector3:
	var n = points.size()
	at = fposmod(at, length)
	var lo = 0
	var hi = n - 1
	while lo < hi:
		var mid = (lo + hi + 1) / 2
		if dist[mid] <= at:
			lo = mid
		else:
			hi = mid - 1
	var t = (at - dist[lo]) / maxf(dist[lo + 1] - dist[lo], 1e-9)
	return points[lo].lerp(points[(lo + 1) % n], t)


## Planned speed at distance `at` (the lowest over the next `span` metres, so braking is not missed).
func planned(at: float, span: float) -> float:
	var n = points.size()
	var v = INF
	var step = 2.0
	var x = 0.0
	while x <= span:
		var q = fposmod(at + x, length)
		var lo = 0
		var hi = n - 1
		while lo < hi:
			var mid = (lo + hi + 1) / 2
			if dist[mid] <= q:
				lo = mid
			else:
				hi = mid - 1
		v = minf(v, plan[lo])
		x += step
	return v


## The driver's input for this tick.
func command(car) -> Dictionary:
	project(car.pos)
	var speed = car.speed
	var look = clampf(8.0 + .35 * speed, 8.0, 45.0)
	var target = point_at(s + look)
	var b = car.basis()
	var fwd = b.x
	var right = b.z
	var to = target - car.pos
	var alpha = atan2(to.dot(right), to.dot(fwd))
	var wheelbase = car.p.a + car.p.b
	var delta = atan(2.0 * wheelbase * sin(alpha) / look)
	# Cross-track correction (Stanley): pure pursuit alone lets a fast car sit a metre or two off a line
	# that may run in a lane only a car's width wider than the car (the proving ground's ditch bypass).
	# Gentle and capped: pure pursuit already steers back, and a strong gain doubles the correction and
	# oscillates at speed (a gain of 2 spun the cars).
	delta -= clampf(atan(CROSS_GAIN * lateral / maxf(speed, 5.0)), -CROSS_MAX, CROSS_MAX)
	var max_steer = deg_to_rad(car.setup.maxSteer)
	if car.steer_falloff > 0:
		max_steer /= 1.0 + speed / car.steer_falloff
	var steer = clampf(delta / maxf(max_steer, 1e-3), -1.0, 1.0)
	var want = planned(s, maxf(speed * .6, 4.0))
	var e = want - speed
	# Off the line by more than 1 m: ease off the throttle (a car running wide at the limit can't also
	# tighten). Throttle only: braking harder while turning at full lock locks the fronts and ploughs on.
	var eased = e - 3.0 * maxf(0.0, absf(lateral) - 1.0)
	# Rear stepping out under braking: release the brake as a driver would, fully by 8 degrees of body
	# slip. Without it the aid-free roadster trail-braked into a snap spin at Spa (s 780, -3 deg camber).
	var vb = b.inverse() * car.vel
	var slip = absf(atan2(vb.z, vb.x)) if speed > 5.0 else 0.0
	var release = clampf((deg_to_rad(8.0) - slip) / deg_to_rad(5.0), 0.0, 1.0)
	return {
		"throttle": clampf(eased * .6 + .35, 0.0, 1.0),
		"brake": clampf(-e * .35, 0.0, 1.0) * release,
		"steer": steer,
		"clutch": 0.0,
		"handbrake": 0.0
	}
