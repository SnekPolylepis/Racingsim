extends SceneTree
## P3-04: barriers (WallPath) and scenery (RoadScatter) against exact geometry (REBUILD-PLAN.md P3-04).
##   A  freehand concrete wall: invisible to suspension rays (layer 1), inner face exactly where drawn
##      and facing the track for layer-2 rays, top at its height, end caps closed
##   B  road-following walls on an analytic road, flat and banked 10 deg: base line exactly at
##      width + kerb + runoff + verge + offset, following the verge's fall and the bank
##   C  a full-loop wall round the P3-02 proving loop: closes on itself, validates (and bad walls are
##      rejected), and the 296 still laps cleanly, clear of it
##   D  scatter: exact counts, every instance in its band beyond the verge, never on the road,
##      deterministic per seed
## Walls and scenery under a plain node (not a TrackAsset) bake into their own Walls/ or Scenery/ child.
## Run: tools/Godot.exe --headless --path . --script tests/v2/walls.gd
const RoadPath = preload("res://scripts/track/road_path.gd")
const RoadSection = preload("res://scripts/track/road_section.gd")
const WallPath = preload("res://scripts/track/wall_path.gd")
const WallBuilder = preload("res://scripts/track/wall_builder.gd")
const RoadScatter = preload("res://scripts/track/road_scatter.gd")
const TrackAsset = preload("res://scripts/track/track_asset.gd")
const TrackSurface = preload("res://scripts/surface/track_surface.gd")
const CarBody = preload("res://scripts/vehicle/car_body.gd")
const DT = 1.0 / 240
const STRAIGHT_Z = -500.0
const BANKED_Z = -800.0
const K = 22.1
var free_host
var straight_host
var banked_host
var loop_asset
var failures = []
var checks = 0
var frames = 0
var ran = false
var results = {}


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func road(host, z, keys, length = 200.0):
	var r = RoadPath.new()
	r.name = "Road"
	r.closed = false
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, z))
	c.add_point(Vector3(length, 0, z))
	r.curve = c
	r.sections.assign(keys)
	host.add_child(r)
	r.bake()
	return r


func straight_keys(bank):
	var v = {"kerb_right": RoadSection.Kerb.RAMP, "kerb_width": 1.0, "kerb_height": .05, "bank_deg": bank}
	return [RoadSection.make(0.0, v), RoadSection.make(200.0, v)]


func following_wall(host, wall_name, wall_side, kind, extra):
	var w = WallPath.new()
	w.name = wall_name
	w.follow_road = NodePath("../Road")
	w.side = wall_side
	w.kind = kind
	w.offset = extra
	host.add_child(w)
	w.bake()
	return w


func build_loop():
	var asset = Node3D.new()
	asset.set_script(TrackAsset)
	asset.id = "walls_loop_test"
	var r = RoadPath.new()
	r.name = "Main"
	var c = Curve3D.new()
	for p in [
		[Vector3(140, 0, 0), Vector3.ZERO, Vector3.ZERO],
		[Vector3(280, 0, 0), Vector3.ZERO, Vector3(K, 0, 0)],
		[Vector3(320, 0, 40), Vector3(0, 0, -K), Vector3.ZERO],
		[Vector3(320, 0, 80), Vector3.ZERO, Vector3(0, 0, K)],
		[Vector3(280, 0, 120), Vector3(K, 0, 0), Vector3.ZERO],
		[Vector3(0, 0, 120), Vector3.ZERO, Vector3(-K, 0, 0)],
		[Vector3(-40, 0, 80), Vector3(0, 0, K), Vector3.ZERO],
		[Vector3(-40, 0, 40), Vector3.ZERO, Vector3(0, 0, -K)],
		[Vector3(0, 0, 0), Vector3(-K, 0, 0), Vector3.ZERO]
	]:
		c.add_point(p[0], p[1], p[2])
	r.curve = c
	r.sections.assign([RoadSection.make(0.0, {"verge_left": 4.0, "verge_right": 4.0})])
	asset.add_child(r)
	r.owner = asset
	r.bake()
	# Outside of the right-hand corners is the left: a concrete wall right round the loop there.
	var w = WallPath.new()
	w.name = "Outer"
	w.follow_road = NodePath("../Main")
	w.side = WallPath.Side.LEFT
	w.kind = WallBuilder.Kind.CONCRETE
	w.offset = 1.0
	asset.add_child(w)
	w.owner = asset
	w.bake()
	return asset


func _initialize():
	free_host = Node3D.new()
	var w = WallPath.new()
	w.name = "Free"
	w.kind = WallBuilder.Kind.CONCRETE
	w.track_side = WallPath.Side.LEFT
	var c = Curve3D.new()
	c.add_point(Vector3(0, 0, 50))
	c.add_point(Vector3(100, 0, 50))
	w.curve = c
	free_host.add_child(w)
	w.bake()
	root.add_child(free_host)
	straight_host = Node3D.new()
	road(straight_host, STRAIGHT_Z, straight_keys(0.0))
	following_wall(straight_host, "RightTyres", WallPath.Side.RIGHT, WallBuilder.Kind.TYRE, 2.0)
	following_wall(straight_host, "LeftArmco", WallPath.Side.LEFT, WallBuilder.Kind.ARMCO, 2.0)
	root.add_child(straight_host)
	banked_host = Node3D.new()
	road(banked_host, BANKED_Z, straight_keys(10.0))
	following_wall(banked_host, "LeftArmco", WallPath.Side.LEFT, WallBuilder.Kind.ARMCO, 2.0)
	root.add_child(banked_host)
	loop_asset = build_loop()
	var errors = loop_asset.validate()
	check(errors.is_empty(), "the walled loop validates %s" % [errors])
	var outer = loop_asset.get_node("Walls/Outer")
	var line = outer.get_meta("wall_line")
	var faces = outer.get_node("Collision").shape.get_faces().size() / 3
	check(
		faces == line.size() * 8,
		(
			"a full-loop wall closes on itself: %d triangles for %d points (8 per point, no end caps)"
			% [faces, line.size()]
		)
	)
	outer.set_collision_layer_value(1, true)
	var bad_layer = loop_asset.validate().any(func(e): return "layer 2 only" in e)
	outer.set_collision_layer_value(1, false)
	outer.set_meta("wall_kind", "hay")
	var bad_kind = loop_asset.validate().any(func(e): return "wall_kind" in e)
	outer.set_meta("wall_kind", "concrete")
	check(bad_layer and bad_kind, "validation rejects a wall on the drivable layer and an unknown wall kind")
	root.add_child(loop_asset)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	# If a script error aborted the previous run part-way, fail instead of retrying every frame forever.
	if ran:
		print("WALLS RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	freehand()
	following()
	loop_lap()
	scatter()
	print("WALLS RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)
	return true


func wall_ray(from: Vector3, to: Vector3) -> Dictionary:
	var params = PhysicsRayQueryParameters3D.create(from, to, 1 << 1)
	params.hit_back_faces = true
	return root.get_world_3d().direct_space_state.intersect_ray(params)


func freehand():
	var drive = TrackSurface.new(free_host).contact(Vector3(50, 5, 50.2), Vector3.DOWN, 10)
	var face = wall_ray(Vector3(50, .5, 40), Vector3(50, .5, 60))
	var under_top = wall_ray(Vector3(50, .95, 40), Vector3(50, .95, 60))
	var over_top = wall_ray(Vector3(50, 1.05, 40), Vector3(50, 1.05, 60))
	var cap = wall_ray(Vector3(-5, .5, 50.2), Vector3(5, .5, 50.2))
	check(
		(
			drive.is_empty()
			and not face.is_empty()
			and absf(face.position.z - 50.0) < 1e-3
			and face.normal.dot(Vector3(0, 0, -1)) > .999
			and not under_top.is_empty()
			and over_top.is_empty()
			and not cap.is_empty()
			and absf(cap.position.x) < 1e-3
		),
		(
			"freehand concrete wall: suspension rays pass through it; its face is at z %.4f (50) facing the track; hit at 0.95 m, clear at 1.05 m (height 1.0); end cap at x %.4f"
			% [face.get("position", Vector3.ZERO).z, cap.get("position", Vector3.ZERO).x]
		)
	)


func following():
	var slope = tan(deg_to_rad(3.0))
	# Right: road 5 + ramp kerb 1 (top 5 cm) + 5 cm runoff band + 6 m verge + 2 m, falling 3 deg past the kerb.
	var right = straight_host.get_node("RightTyres/Walls/RightTyres").get_meta("wall_line")
	var lat_r = 5.0 + 1.0 + .05 + 6.0 + 2.0
	var h_r = .05 - slope * (.05 + 6.0 + 2.0)
	# Left: no kerb, so the 1 m kerb band is verge too: road 5 + 1 + 0.05 + 6 + 2, falling from the edge.
	var left = straight_host.get_node("LeftArmco/Walls/LeftArmco").get_meta("wall_line")
	var lat_l = -(5.0 + 1.0 + .05 + 6.0 + 2.0)
	var h_l = -slope * (1.0 + .05 + 6.0 + 2.0)
	var worst = 0.0
	for p in right:
		worst = maxf(worst, maxf(absf(p.z - (STRAIGHT_Z + lat_r)), absf(p.y - h_r)))
	for p in left:
		worst = maxf(worst, maxf(absf(p.z - (STRAIGHT_Z + lat_l)), absf(p.y - h_l)))
	var face = wall_ray(Vector3(100, .3, STRAIGHT_Z), Vector3(100, .3, STRAIGHT_Z + 30))
	var tyre_h = straight_host.get_node("RightTyres/Walls/RightTyres").get_meta("wall_height")
	check(
		(
			worst < 1e-3
			and not face.is_empty()
			and absf(face.position.z - (STRAIGHT_Z + lat_r)) < 1e-3
			and tyre_h == 1.0
		),
		(
			"road-following walls on a flat road: base line within %.5f m of width + kerb + runoff + verge + 2 m on both sides, following the 3° verge; tyre wall face hit at %.3f m from the centreline"
			% [worst, face.get("position", Vector3.ZERO).z - STRAIGHT_Z]
		)
	)
	# Banked 10 deg: right = (0, -sin b, cos b), up = (0, cos b, sin b) in the banked frame.
	var b = deg_to_rad(10.0)
	var banked = banked_host.get_node("LeftArmco/Walls/LeftArmco").get_meta("wall_line")
	var want_z = BANKED_Z + lat_l * cos(b) + h_l * sin(b)
	var want_y = -lat_l * sin(b) + h_l * cos(b)
	var worst_b = 0.0
	for p in banked:
		worst_b = maxf(worst_b, maxf(absf(p.z - want_z), absf(p.y - want_y)))
	check(
		worst_b < 1e-3,
		(
			"road-following wall on a 10° banked road: base line within %.5f m of the banked frame's prediction (raised %.3f m on the high side)"
			% [worst_b, want_y]
		)
	)


## The 296 laps the walled loop at 60 km/h through every gate; its CG never comes within 3 m of the
## wall's inner face line.
func loop_lap():
	var surf = loop_asset.surface()
	var presets = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars.json"))
	var c = CarBody.new()
	c.configure(presets.f296gt3)
	c.wear_enabled = false
	c.steer_falloff = 0.0
	var pole = loop_asset.grid_slots()[0]
	var fwd = -pole.basis.z
	c.place(pole.origin, atan2(fwd.z, fwd.x), pole.origin.y)
	var line = loop_asset.get_node("Walls/Outer").get_meta("wall_line")
	var gates = loop_asset.gates()
	var next = 0
	var started = -1.0
	var lap_time = -1.0
	var hint = -1
	var closest = INF
	var t = 0.0
	var prev = c.pos
	while t < 150 and lap_time < 0:
		var pr = loop_asset.project(c.pos, hint)
		hint = pr.idx
		var target = loop_asset.station(pr.s + 10 + c.speed * .5).pos
		var st = clampf(wrapf(atan2(target.z - c.pos.z, target.x - c.pos.x) - c.h, -PI, PI) * 2.5, -1, 1)
		var e = 60 / 3.6 - c.speed
		c.input = {
			"throttle": clampf(e * .5 + .3, 0, 1),
			"brake": clampf(-e * .3, 0, 1),
			"steer": st,
			"clutch": 0.0,
			"handbrake": 0.0
		}
		c.step(DT, surf, true)
		t += DT
		if int(t * 240) % 24 == 0:
			for p in line:
				closest = minf(closest, Vector2(p.x - c.pos.x, p.z - c.pos.z).length())
		if TrackAsset.crossed(gates[next], prev, c.pos):
			if next == 0:
				if started >= 0:
					lap_time = t - started
				else:
					started = t
				next = 1
			else:
				next = (next + 1) % gates.size()
		prev = c.pos
	results["loop_lap_s"] = lap_time
	results["closest_to_wall_m"] = closest
	check(
		lap_time > 0 and closest > 3.0,
		(
			"the 296 laps the walled loop (%.2f s) and never comes within %.1f m of the wall line (closest %.2f m)"
			% [lap_time, 3.0, closest]
		)
	)


func scatter():
	var r = straight_host.get_node("Road")
	var make = func(random_seed):
		var sc = RoadScatter.new()
		sc.name = "Trees%d" % random_seed
		sc.follow_road = NodePath("../Road")
		sc.random_seed = random_seed
		sc.offset_min = 4.0
		sc.offset_max = 30.0
		sc.per_100m = 12.0
		straight_host.add_child(sc)
		sc.bake()
		return sc
	var a = make.call(7)
	var a_again = make.call(7)
	var other = make.call(8)
	var xa = a.last_bake.xforms
	var same = var_to_str(xa) == var_to_str(a_again.last_bake.xforms)
	var differs = var_to_str(xa) != var_to_str(other.last_bake.xforms)
	var slope = tan(deg_to_rad(3.0))
	var in_band = true
	var worst_y = 0.0
	for i in xa.size():
		var p = xa[i].origin
		var lat = absf(p.z - STRAIGHT_Z)
		var right = p.z > STRAIGHT_Z
		var edge = 5.0 + 1.0 + .05 + 6.0
		var beyond = lat - edge
		in_band = in_band and beyond >= 4.0 - 1e-3 and beyond <= 30.0 + 1e-3
		var top = .05 if right else -slope * 1.0
		var want = top - slope * ((.05 + 6.0 if right else .05 + 6.0) + beyond)
		worst_y = maxf(worst_y, absf(p.y - want))
	var mm = straight_host.get_node("Trees7/Scenery/Trees7").multimesh
	check(
		xa.size() == 48 and mm.instance_count == 48 and in_band and worst_y < 1e-3 and same and differs,
		(
			"scatter: 48 trees (24 per side per 200 m at 12/100 m), all 4..30 m beyond the verge on the ground (height error %.5f m), one MultiMesh; same seed same layout: %s, new seed new layout: %s"
			% [worst_y, same, differs]
		)
	)
