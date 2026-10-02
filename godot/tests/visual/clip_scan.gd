extends SceneTree
## Scans a track for scenery intruding into the drivable corridor: every `step` metres along the road, rays
## from above hit-test every visible mesh at several lateral offsets (inside the barriers). Anything other than
## the road, barriers, fences, kerb or car geometry above the track surface is reported with its path.
##   tools/Godot.exe --path . --script tests/visual/clip_scan.gd -- --track=chicago [--step=5]
## Run windowed: the headless renderer discards MultiMesh instance transforms.
## Prints CLIP lines and CLIP SCAN RESULTS; fails on anything over or across the road except OVERHEAD structures.

const RoadBuilder = preload("res://scripts/track/road_builder.gd")
const TrackDrive = preload("res://scripts/proving/track_drive.gd")
var track = "chicago"
var step = 5.0
## How far above the road surface a foreign mesh counts (2 cm catches coplanar streets that z-fight the track).
var threshold = 0.02
const ALLOWED = ["Road", "Walls", "LeftBarrierFence", "RightBarrierFence", "Lights", "Gantry", "TimingLine"]
## Deliberate structures over the road (Upper Wacker over Lower Wacker, the elevated L, signal mast arms, the
## start gantry).
const OVERHEAD = [
	"Scenery/Wacker",
	"Scenery/City/ElevatedL",
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
	if DisplayServer.get_name() == "headless":
		push_error("Clip scan requires a renderer to inspect MultiMesh instance transforms")
		quit(1)
		return
	call_deferred("run")


func run():
	var asset = TrackDrive.load_asset(track)
	if asset == null:
		print("CLIP ERROR load")
		quit(1)
		return
	root.add_child(asset)
	await process_frame
	var road = asset.get_node("Main")
	# Only projections into cells queried by the road rays can affect this scan.
	# Bound each instance before expanding its shared mesh (dense native windows).
	var road_cells = {}
	var station_m = 0.0
	while station_m < asset.length:
		var station = asset.station(station_m)
		var section = RoadBuilder.section_at(road.sections, station_m, asset.length, road.closed)
		var right = station.tangent.cross(Vector3.UP).normalized()
		for fraction in [-.875, -.5, 0.0, .5, .875]:
			var off = fraction * (section.width_left if fraction < 0.0 else section.width_right)
			var p = station.pos + right * off
			road_cells[Vector2i(floori(p.x / 20.0), floori(p.z / 20.0))] = true
		station_m += step
	# Collect triangles of every candidate mesh once, bucketed on a 20 m grid.
	var grid = {}
	for mi in asset.find_children("*", "GeometryInstance3D", true, false):
		if not (mi is MeshInstance3D or mi is MultiMeshInstance3D):
			continue
		var mesh = mi.mesh if mi is MeshInstance3D else mi.multimesh.mesh
		if mesh == null:
			continue
		var path = str(asset.get_path_to(mi))
		var top = path.split("/")[0]
		if top in ALLOWED:
			continue
		var transforms = [mi.global_transform]
		if mi is MultiMeshInstance3D:
			transforms.clear()
			# One renderer readback per group, not a synchronous getter per window.
			var mm = mi.multimesh
			var buffer = mm.buffer
			var stride = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			if mm.transform_format != MultiMesh.TRANSFORM_3D or buffer.size() != mm.instance_count * stride:
				failures.append("Cannot inspect MultiMesh buffer: " + path)
				continue
			for instance in mm.instance_count:
				var j = instance * stride
				var basis = Basis(
					Vector3(buffer[j], buffer[j + 4], buffer[j + 8]),
					Vector3(buffer[j + 1], buffer[j + 5], buffer[j + 9]),
					Vector3(buffer[j + 2], buffer[j + 6], buffer[j + 10])
				)
				var origin = Vector3(buffer[j + 3], buffer[j + 7], buffer[j + 11])
				transforms.append(mi.global_transform * Transform3D(basis, origin))
		for xf in transforms:
			var bounds = xf * mesh.get_aabb()
			var relevant = false
			for gx in range(floori(bounds.position.x / 20.0), floori(bounds.end.x / 20.0) + 1):
				for gz in range(floori(bounds.position.z / 20.0), floori(bounds.end.z / 20.0) + 1):
					if road_cells.has(Vector2i(gx, gz)):
						relevant = true
			if not relevant:
				continue
			for si in mesh.get_surface_count():
				var arr = mesh.surface_get_arrays(si)
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
							if not road_cells.has(k):
								continue
							if not grid.has(k):
								grid[k] = []
							grid[k].append([a, b, c, path, si])
	var hits = 0
	var reported = {}
	var s = 0.0
	while s < asset.length:
		var st = asset.station(s)
		var right = st.tangent.cross(Vector3.UP).normalized()
		var section = RoadBuilder.section_at(road.sections, s, asset.length, road.closed)
		for fraction in [-.875, -.5, 0.0, .5, .875]:
			var off = fraction * (section.width_left if fraction < 0.0 else section.width_right)
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
						if not _overhead(tri[3], hit.y - p.y, p.y):
							failures.append(line)
			# Walls and columns standing on the road: a ray 1 m up, along the road to the next station.
			var nxt = asset.station(fposmod(s + step, asset.length))
			var next_section = RoadBuilder.section_at(
				road.sections, fposmod(s + step, asset.length), asset.length, road.closed
			)
			var next_off = (
				fraction * (next_section.width_left if fraction < 0.0 else next_section.width_right)
			)
			var q = nxt.pos + nxt.tangent.cross(Vector3.UP).normalized() * next_off
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
	asset.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("CLIP SCAN RESULTS ", JSON.stringify({"checks": 1, "hits": hits, "failures": failures}))
	call_deferred("quit", 0 if failures.is_empty() else 1)


func _overhead(path: String, clearance: float = 0.0, road_y: float = 8.0) -> bool:
	# Upper-street furniture is separated from Lower Wacker by the concrete deck.
	if path.begins_with("Scenery/Prop_") and road_y < 3.6 and road_y + clearance >= 7.9:
		return true
	if path.begins_with("Scenery/ChicagoBridge") and clearance >= 3.0:
		return true
	for prefix in OVERHEAD:
		if path.begins_with(prefix):
			return true
	return false
