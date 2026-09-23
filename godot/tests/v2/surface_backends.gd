extends SceneTree
## P3-00 spike: which backend should answer TrackSurface.contact() (REBUILD-PLAN.md P3-00, 5.2)?
## Bakes the real Nordschleife ribbon (road with cross-section profile, plus verges) into a triangle
## mesh in Godot axes, then answers the same wheel-style ray queries three ways:
##   A  Godot PhysicsServer3D: ConcavePolygonShape3D + direct_space_state.intersect_ray (float32).
##   B  Our own uniform xz grid over the same triangles, Moller-Trumbore in 64-bit GDScript floats.
##   C  The ribbon's own parametric surface (track3d.gd elev_at: projection + cross-section), as a
##      stand-in for querying an authored road from its (s, t) parameters instead of its mesh.
## Reports cost per query, agreement between A and B (float32 vs 64-bit), determinism, and how
## faceted the mesh surface is compared with the smooth parametric one.
## Run headless: tools/Godot.exe --headless --path . --script tests/v2/surface_backends.gd
const TrackModel = preload("res://scripts/track3d.gd")
const QUERIES = 20000
const GRID = 3.0
var track
var verts = PackedFloat64Array()
var tris = PackedInt32Array()
var grid = {}
var queries = []
var frames = 0
var ran = false
var results = {}
var rng = RandomNumberGenerator.new()


## Simulation (x, y, z-up) to Godot (x, y-up, z), in 64-bit scalars.
func g3(p):
	return [p.x, p.z, p.y]


func surface_point(sm, lat):
	var u = lat / maxf(sm.w * .5, 1e-6)
	if absf(u) > 1:
		return sm.pos + sm.right * lat
	return sm.pos + sm.right * lat - sm.up * TrackModel.profile_drop(sm, u)


## Ribbon mesh: per sample, 9 stations across the road (profile included) and 2 verge stations each
## side on the banked plane, 12 quads to the next sample.
func bake():
	var S = track.samples
	var N = S.size()
	var stations = []
	for sm in S:
		var half = sm.w * .5
		var row = []
		for lat in [-half - 8, -half - 3]:
			row.append(lat)
		for k in 9:
			row.append(-half + sm.w * k / 8.0)
		for lat in [half + 3, half + 8]:
			row.append(lat)
		stations.append(row)
	var per = stations[0].size()
	for i in N:
		for lat in stations[i]:
			var p = g3(surface_point(S[i], lat))
			verts.append(p[0])
			verts.append(p[1])
			verts.append(p[2])
	for i in N:
		var j = (i + 1) % N
		for k in per - 1:
			var a = i * per + k
			var b = i * per + k + 1
			var c = j * per + k
			var d = j * per + k + 1
			tris.append_array([a, c, b, b, c, d])


func vtx(i):
	return Vector3(verts[i * 3], verts[i * 3 + 1], verts[i * 3 + 2])


func key(ix, iz):
	return (ix + 100000) * 1000000 + (iz + 100000)


func build_grid():
	for t in tris.size() / 3:
		var xs = []
		var zs = []
		for k in 3:
			var v = tris[t * 3 + k]
			xs.append(verts[v * 3])
			zs.append(verts[v * 3 + 2])
		for ix in range(floori(xs.min() / GRID), floori(xs.max() / GRID) + 1):
			for iz in range(floori(zs.min() / GRID), floori(zs.max() / GRID) + 1):
				var k = key(ix, iz)
				if not grid.has(k):
					grid[k] = PackedInt32Array()
				grid[k].append(t)


## Backend B: nearest hit along the ray, all arithmetic in 64-bit scalars.
## Returns [t, nx, ny, nz, tri] or [] on a miss.
func ray_b(ox, oy, oz, dx, dy, dz, maxd):
	var ex = ox + dx * maxd
	var ez = oz + dz * maxd
	var best = maxd
	var hit = []
	for ix in range(floori(minf(ox, ex) / GRID), floori(maxf(ox, ex) / GRID) + 1):
		for iz in range(floori(minf(oz, ez) / GRID), floori(maxf(oz, ez) / GRID) + 1):
			var cell = grid.get(key(ix, iz))
			if cell == null:
				continue
			for t in cell:
				var i0 = tris[t * 3] * 3
				var i1 = tris[t * 3 + 1] * 3
				var i2 = tris[t * 3 + 2] * 3
				var ax = verts[i0]
				var ay = verts[i0 + 1]
				var az = verts[i0 + 2]
				var e1x = verts[i1] - ax
				var e1y = verts[i1 + 1] - ay
				var e1z = verts[i1 + 2] - az
				var e2x = verts[i2] - ax
				var e2y = verts[i2 + 1] - ay
				var e2z = verts[i2 + 2] - az
				var px = dy * e2z - dz * e2y
				var py = dz * e2x - dx * e2z
				var pz = dx * e2y - dy * e2x
				var det = e1x * px + e1y * py + e1z * pz
				if absf(det) < 1e-12:
					continue
				var inv = 1.0 / det
				var sx = ox - ax
				var sy = oy - ay
				var sz = oz - az
				var u = (sx * px + sy * py + sz * pz) * inv
				if u < 0 or u > 1:
					continue
				var qx = sy * e1z - sz * e1y
				var qy = sz * e1x - sx * e1z
				var qz = sx * e1y - sy * e1x
				var v = (dx * qx + dy * qy + dz * qz) * inv
				if v < 0 or u + v > 1:
					continue
				var d = (e2x * qx + e2y * qy + e2z * qz) * inv
				if d >= 0 and d < best:
					best = d
					var nx = e1y * e2z - e1z * e2y
					var ny = e1z * e2x - e1x * e2z
					var nz = e1x * e2y - e1y * e2x
					var nl = sqrt(nx * nx + ny * ny + nz * nz)
					if ny < 0:
						nl = -nl
					hit = [d, nx / nl, ny / nl, nz / nl, t]
	return hit


## Wheel-style rays: from 0.6 m above a random road point, along its normal tilted up to 10°, 1.2 m.
## Stored in 64-bit scalars (Godot axes) plus the sample index for backend C.
func make_queries():
	var S = track.samples
	for q in QUERIES:
		var i = rng.randi_range(0, S.size() - 1)
		var sm = S[i]
		var lat = rng.randf_range(-sm.w * .5, sm.w * .5)
		var p = surface_point(sm, lat)
		var up = sm.up
		var o = g3(p + up * .6)
		var n = g3(up)
		var tilt = deg_to_rad(rng.randf_range(0, 10))
		var az = rng.randf() * TAU
		# Tilt the downward direction by `tilt` about a random horizontal axis.
		var dx = -n[0] + sin(tilt) * cos(az)
		var dy = -n[1]
		var dz = -n[2] + sin(tilt) * sin(az)
		var dl = sqrt(dx * dx + dy * dy + dz * dz)
		queries.append([o[0], o[1], o[2], dx / dl, dy / dl, dz / dl, i, p])


func bench_a():
	var space = root.get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.hit_back_faces = true
	var out = []
	var t0 = Time.get_ticks_usec()
	for q in queries:
		params.from = Vector3(q[0], q[1], q[2])
		params.to = Vector3(q[0] + q[3] * 1.2, q[1] + q[4] * 1.2, q[2] + q[5] * 1.2)
		var r = space.intersect_ray(params)
		out.append(r)
	var us = float(Time.get_ticks_usec() - t0) / queries.size()
	return [us, out]


## Backend A with the wheel as a shape: sweep a tyre-sized cylinder (r 0.345 m, 0.30 m wide, axis
## across the car) down the same path, then read the contact point and normal where it stops. This is
## a tyre envelope for free: kerb edges and steps are met by the tread's curve, not a point.
func bench_d():
	var space = root.get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var tyre = CylinderShape3D.new()
	tyre.radius = .345
	tyre.height = .30
	params.shape = tyre
	var hits = 0
	var t0 = Time.get_ticks_usec()
	for q in queries:
		var down = Vector3(q[3], q[4], q[5])
		# Cylinder axis (local Y) across the car: any horizontal direction perpendicular to the ray.
		var side = down.cross(Vector3(1, 0, 0)).normalized()
		var fwd = side.cross(down).normalized()
		# Right-handed basis (x = fwd, y = side, z = fwd x side). A mirrored basis is tolerated by
		# GodotPhysics but makes Jolt miss almost every contact.
		params.transform = Transform3D(Basis(fwd, side, fwd.cross(side)), Vector3(q[0], q[1], q[2]))
		params.motion = down * 1.2
		var frac = space.cast_motion(params)
		if frac[1] < 1.0:
			params.transform.origin += params.motion * frac[1]
			params.motion = Vector3.ZERO
			var info = space.get_rest_info(params)
			if not info.is_empty():
				hits += 1
			params.motion = down * 1.2
	var us = float(Time.get_ticks_usec() - t0) / queries.size()
	return [us, hits]


func bench_b():
	var out = []
	var t0 = Time.get_ticks_usec()
	for q in queries:
		out.append(ray_b(q[0], q[1], q[2], q[3], q[4], q[5], 1.2))
	var us = float(Time.get_ticks_usec() - t0) / queries.size()
	return [us, out]


## Backend C, as a car would call it: sequential wheel positions along the lap carrying a hint.
func bench_c():
	var S = track.samples
	var n = QUERIES
	var hint = 0
	var t0 = Time.get_ticks_usec()
	for k in n:
		var sm = S[(k * 3) % S.size()]
		var p = sm.pos + sm.right * 1.0
		var e = track.elev_at(p.x, p.y, hint)
		hint = (k * 3) % S.size()
	var warm = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	for q in queries.slice(0, 5000):
		var p = q[7]
		track.elev_at(p.x, p.y, -1)
	var cold = float(Time.get_ticks_usec() - t0) / 5000
	return [warm, cold]


## Facets: walk a line 1 m right of centre every 5 cm for 3 km and record how the surface normal
## changes step to step, for the mesh (B) and the smooth parametric surface (C).
func facets():
	var S = track.samples
	var worst_mesh = 0.0
	var worst_smooth = 0.0
	var jumps_mesh = 0
	var jumps_smooth = 0
	var prev_mesh = Vector3.ZERO
	var prev_smooth = Vector3.ZERO
	var hint = 0
	var steps = 0
	var i = 0
	while steps < 60000 and i < S.size() - 1:
		var a = S[i]
		var b = S[i + 1]
		var sub = maxi(1, int(a.len / .05))
		for k in sub:
			var f = float(k) / sub
			var pos = a.pos.lerp(b.pos, f)
			var right = a.right.lerp(b.right, f).normalized()
			var up = a.up.lerp(b.up, f).normalized()
			var p = pos + right * 1.0
			var o = g3(p + up * .5)
			var d = g3(-up)
			var hb = ray_b(o[0], o[1], o[2], d[0], d[1], d[2], 1.0)
			var e = track.elev_at(p.x, p.y, hint)
			hint = i
			if hb.is_empty():
				continue
			var nm = Vector3(hb[1], hb[2], hb[3])
			var ns = Vector3(e.up.x, e.up.z, e.up.y)
			if steps > 0:
				var dm = rad_to_deg(prev_mesh.angle_to(nm))
				worst_mesh = maxf(worst_mesh, dm)
				if dm > .05:
					jumps_mesh += 1
				var ds = rad_to_deg(prev_smooth.angle_to(ns))
				worst_smooth = maxf(worst_smooth, ds)
				if ds > .05:
					jumps_smooth += 1
			prev_mesh = nm
			prev_smooth = ns
			steps += 1
		i += 1
	return [steps, worst_mesh, jumps_mesh, worst_smooth, jumps_smooth]


func _initialize():
	rng.seed = 3000
	var t0 = Time.get_ticks_msec()
	track = TrackModel.new()
	track.load_data(
		JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Nurburgring-Nordschleife.json"))
	)
	bake()
	build_grid()
	var ext = 0.0
	for i in verts.size():
		if i % 3 != 1:
			ext = maxf(ext, absf(verts[i]))
	results["samples"] = track.samples.size()
	results["triangles"] = tris.size() / 3
	results["max_abs_xz_m"] = ext
	results["grid_cells"] = grid.size()
	var faces = PackedVector3Array()
	for t in tris:
		faces.append(vtx(t))
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)
	make_queries()
	results["setup_ms"] = Time.get_ticks_msec() - t0
	results["physics_server"] = (
		"%s (setting %s)"
		% [PhysicsServer3D.get_class(), ProjectSettings.get_setting("physics/3d/physics_engine")]
	)
	print(
		(
			"Nordschleife: %d samples, %d triangles, |x|,|z| up to %.0f m, %d grid cells, setup %d ms, physics %s"
			% [results.samples, results.triangles, ext, grid.size(), results.setup_ms, results.physics_server]
		)
	)


func _physics_process(_delta):
	frames += 1
	if frames < 3:
		return false
	# If a script error aborted the previous run part-way, fail instead of retrying every frame forever.
	if ran:
		print("BACKENDS RESULTS aborted by a script error (see stderr)")
		quit(1)
		return true
	ran = true
	var a = bench_a()
	var a2 = bench_a()
	var b = bench_b()
	var c = bench_c()
	var d = bench_d()
	var hits_a = 0
	var hits_b = 0
	var both = 0
	var worst_dy = 0.0
	var worst_far = 0.0
	var disagree = 0
	var same = true
	for k in queries.size():
		var ra = a[1][k]
		var ra2 = a2[1][k]
		var rb = b[1][k]
		if var_to_str(ra) != var_to_str(ra2):
			same = false
		if not ra.is_empty():
			hits_a += 1
		if not rb.is_empty():
			hits_b += 1
		if ra.is_empty() != rb.is_empty():
			disagree += 1
			continue
		if ra.is_empty():
			continue
		both += 1
		var q = queries[k]
		var yb = q[1] + q[4] * rb[0]
		var dy = absf(float(ra.position.y) - yb)
		worst_dy = maxf(worst_dy, dy)
		if absf(q[0]) > 2000 or absf(q[2]) > 2000:
			worst_far = maxf(worst_far, dy)
	var f = facets()
	results["us_per_query"] = {
		"D_cylinder_cast": d[0],
		"A_physics_server": a[0],
		"B_own_grid_64bit": b[0],
		"C_parametric_warm": c[0],
		"C_parametric_cold": c[1]
	}
	results["hits"] = {"A": hits_a, "B": hits_b, "disagree": disagree}
	results["A_vs_B_max_height_diff_m"] = worst_dy
	results["A_vs_B_max_height_diff_beyond_2km_m"] = worst_far
	results["A_deterministic"] = same
	results["facets"] = {
		"steps_5cm": f[0],
		"mesh_max_normal_step_deg": f[1],
		"mesh_steps_over_0.05deg": f[2],
		"smooth_max_normal_step_deg": f[3],
		"smooth_steps_over_0.05deg": f[4]
	}
	print(
		(
			"A  physics server   %.2f µs/query, %d/%d hits, repeat identical: %s"
			% [a[0], hits_a, queries.size(), same]
		)
	)
	print("B  own grid, 64-bit %.2f µs/query, %d/%d hits" % [b[0], hits_b, queries.size()])
	print(
		(
			"D  physics server, tyre cylinder cast + rest info %.2f µs/query, %d/%d contacts"
			% [d[0], d[1], queries.size()]
		)
	)
	print("C  parametric       %.2f µs/query warm (hinted), %.2f µs cold" % [c[0], c[1]])
	print(
		(
			"A vs B: %d disagree on hit/miss; max |Δheight| %.6f m overall, %.6f m beyond 2 km"
			% [disagree, worst_dy, worst_far]
		)
	)
	print(
		(
			"Facets over %d 5-cm steps: mesh normal jumps up to %.3f° (%d steps > 0.05°); smooth surface max %.3f° (%d steps > 0.05°)"
			% [f[0], f[1], f[2], f[3], f[4]]
		)
	)
	print("BACKENDS RESULTS ", JSON.stringify(results))
	quit()
	return true
