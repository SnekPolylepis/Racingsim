extends SceneTree
## Which mesh is under a pixel of a visual-review shot. Poses exactly as tests/visual/track_review.gd does for
## that shot, maps the screenshot pixel through the presentation letterbox into the camera's own viewport, and
## ray-casts every visible mesh's triangles. Run windowed (placement args from tools/window_placement.ps1):
##   tools/Godot.exe --position X,Y --path . --script tests/visual/probe_pixel.gd -- --v2-flow-test --mute-audio
##       --track=chicago --shot=040-corner-upper-wacker-portal-exit.png --px=100,205 [--px=...] [--night]
## Prints PROBE lines: pixel, distance, node path, surface, hit point, material.

const Review = preload("res://tests/visual/track_review.gd")
const NightShots = preload("res://tests/v2/night_screenshots.gd")

var track = ""
var shot = ""
var pixels = []
var night = false


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track = arg.trim_prefix("--track=")
		elif arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--px="):
			var p = arg.trim_prefix("--px=").split(",")
			pixels.append(Vector2(float(p[0]), float(p[1])))
		elif arg == "--night":
			night = true
	call_deferred("run")


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.settings.time_of_day = 1 if night else 0
	app.apply_time_of_day()
	if not app.load_v2_track(track):
		print("PROBE ERROR load ", track)
		quit(1)
		return
	app.start_v2_drive()
	var review = Review.new()
	var station = -1.0
	var index = 0
	for item in review.plan(app.track, track):
		var file = "%03d-%s-%s.png" % [index, item[0], item[1]]
		if file == shot:
			station = item[2]
		index += 1
	if station < 0.0:
		print("PROBE ERROR no shot ", shot)
		quit(1)
		return
	var helper = NightShots.new()
	helper.pose(app, station, night)
	app.settings.camera = 0
	app.update_camera(1.0, true)
	for i in 10:
		await process_frame
	var cam: Camera3D = app.camera
	var image = root.get_texture().get_image()
	var content = _content_rect(image)
	var view = cam.get_viewport().get_visible_rect().size
	print("PROBE frame ", image.get_size(), " content ", content, " camera viewport ", view)
	for px in pixels:
		# Screenshot pixel (1280x800 capture) -> this window's pixel -> camera viewport.
		var scale = Vector2(image.get_width(), image.get_height()) / Vector2(1280, 800)
		var p = px * scale
		var uv = (p - Vector2(content.position)) / Vector2(content.size)
		var sp = uv * view
		var o = cam.project_ray_origin(sp)
		var d = cam.project_ray_normal(sp)
		var best = INF
		var what = "sky"
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var bb = mi.global_transform * mi.get_aabb()
			if bb.intersects_ray(o, d) == null and not bb.has_point(o):
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
					var hit = Geometry3D.ray_intersects_triangle(o, d, a, b, c)
					if hit != null and o.distance_to(hit) < best:
						best = o.distance_to(hit)
						var m = mi.get_active_material(si)
						var mat = str(m)
						if m is ShaderMaterial and m.shader:
							mat = m.shader.resource_path.get_file()
						elif m is StandardMaterial3D:
							mat = "Standard " + str(m.albedo_color)
						var path = (
							app.track.get_path_to(mi) if app.track.is_ancestor_of(mi) else mi.get_path()
						)
						what = "%s surf %d at %s %s" % [path, si, hit.snapped(Vector3.ONE * 0.1), mat]
		print("PROBE ", px, " d=", snappedf(best, 0.1), " ", what)
	quit()


## The non-black rectangle of the frame (the presentation letterboxes its 640x448 image).
func _content_rect(image: Image) -> Rect2i:
	var w = image.get_width()
	var h = image.get_height()
	var top = 0
	while top < h / 2 and image.get_pixel(w / 2, top).get_luminance() < 0.01:
		top += 1
	var bottom = h - 1
	while bottom > h / 2 and image.get_pixel(w / 2, bottom).get_luminance() < 0.01:
		bottom -= 1
	var left = 0
	while left < w / 2 and image.get_pixel(left, h / 2).get_luminance() < 0.01:
		left += 1
	var right = w - 1
	while right > w / 2 and image.get_pixel(right, h / 2).get_luminance() < 0.01:
		right -= 1
	return Rect2i(left, top, right - left + 1, bottom - top + 1)
