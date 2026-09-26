extends SceneTree
## Scans a track for scenery intruding into the drivable corridor: every `step` metres along the road, rays
## from above hit-test every visible mesh at several lateral offsets (inside the barriers). Anything other than
## the road, barriers, fences, kerb or car geometry above the track surface is reported with its path.
##   tools/Godot.exe --headless --path . --script tests/visual/clip_scan.gd -- --track=chicago [--step=5]
## Prints CLIP lines and CLIP SCAN RESULTS; fails on anything over or across the road except OVERHEAD structures.

var track = "chicago"
var step = 5.0
## How far above the road surface a foreign mesh counts (2 cm catches coplanar streets that z-fight the track).
var threshold = 0.02
const ALLOWED = ["Road", "Walls", "LeftBarrierFence", "RightBarrierFence", "Lights", "Gantry", "TimingLine"]
## Deliberate structures over the road (Upper Wacker over Lower Wacker, signal mast arms, the start gantry).
const OVERHEAD = [
	"Scenery/Wacker",
	"Scenery/LaneMarkings",
	"Scenery/StreetFurniture",
	"Scenery/StartGantry",
	"Scenery/SignPanel"
]
var failures = []


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		elif arg.begins_with("--step="):
			step = float(arg.trim_prefix("--step="))
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not app.load_v2_track(track):
		print("CLIP ERROR load")
		app.queue_free()
		await process_frame
		quit(1)
		return
	var asset = app.track
	# Collect triangles of every candidate mesh once, bucketed on a 20 m grid.
	var grid = {}
	for mi in asset.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var path = str(asset.get_path_to(mi))
		var top = path.split("/")[0]
		if top in ALLOWED:
			continue
		var xf = mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr = mi.mesh.surface_get_arrays(si)
			var v = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var n = idx.size() if idx else v.size()
			for t in range(0, n, 3):
				var a = xf * v[idx[t] if idx else t]
				var b = xf * v[idx[t + 1] if idx else t + 1]
				var c = xf * v[idx[t + 2] if idx else t + 2]
				var lo = Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
				var hi = Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
				if (hi - lo).length() > 400.0:
					continue
				for gx in range(floori(lo.x / 20.0), floori(hi.x / 20.0) + 1):
					for gz in range(floori(lo.y / 20.0), floori(hi.y / 20.0) + 1):
						var k = Vector2i(gx, gz)
						if not grid.has(k):
							grid[k] = []
						grid[k].append([a, b, c, path, si])
	var hits = 0
	var reported = {}
	var s = 0.0
	while s < asset.length:
		var st = asset.station(s)
		var right = st.tangent.cross(Vector3.UP).normalized()
		for off in [-7.0, -4.0, 0.0, 4.0, 7.0]:
			var p = st.pos + right * off
			var k = Vector2i(floori(p.x / 20.0), floori(p.z / 20.0))
			for tri in grid.get(k, []):
				var hit = Geometry3D.ray_intersects_triangle(
					p + Vector3.UP * 300.0, Vector3.DOWN, tri[0], tri[1], tri[2]
				)
				if hit != null and hit.y > p.y + threshold:
					var key = "%s:%d" % [tri[3], int(s / 50.0)]
					if not reported.has(key):
						reported[key] = true
						hits += 1
						var line = (
							"CLIP s=%.0f off=%.0f %s surf %d at %s (road y %.1f)"
							% [s, off, tri[3], tri[4], hit.snapped(Vector3.ONE * 0.1), p.y]
						)
						print(line)
						if not _overhead(tri[3]):
							failures.append(line)
			# Walls and columns standing on the road: a ray 1 m up, along the road to the next station.
			var nxt = asset.station(fposmod(s + step, asset.length))
			var q = nxt.pos + nxt.tangent.cross(Vector3.UP).normalized() * off
			var o = p + Vector3.UP
			var seg = (q + Vector3.UP) - o
			for tri in grid.get(k, []):
				var wall = Geometry3D.ray_intersects_triangle(o, seg.normalized(), tri[0], tri[1], tri[2])
				if wall != null and o.distance_to(wall) < seg.length():
					var wkey = "wall:%s:%d" % [tri[3], int(s / 50.0)]
					if not reported.has(wkey):
						reported[wkey] = true
						hits += 1
						var wline = (
							"CLIP WALL s=%.0f off=%.0f %s surf %d at %s"
							% [s, off, tri[3], tri[4], wall.snapped(Vector3.ONE * 0.1)]
						)
						print(wline)
						failures.append(wline)
		s += step
	app.queue_free()
	await process_frame
	print("CLIP SCAN RESULTS ", JSON.stringify({"checks": 1, "hits": hits, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _overhead(path: String) -> bool:
	for prefix in OVERHEAD:
		if path.begins_with(prefix):
			return true
	return false
