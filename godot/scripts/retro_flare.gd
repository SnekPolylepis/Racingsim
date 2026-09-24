extends Control
## Original hexagon flare, rendered inside the world viewport (Look-3). A ray from the camera toward
## the sun against the TrackAsset's collision (terrain, road, walls) occludes it. TrackSurface queries
## only work in a physics frame, so the ray runs there at 30 Hz and _draw reads the result.
var app
var sun_clear = false
var tick = 0


func _physics_process(_dt):
	tick += 1
	if tick % 8 != 0:
		return
	sun_clear = false
	if app == null or app.v2_surface == null or not app.track is Node3D:
		return
	var dir = app.sun.global_basis.z.normalized()
	sun_clear = app.v2_surface.contact(app.camera.global_position, dir, 800.0).is_empty()


func _process(_dt):
	queue_redraw()


func _draw():
	if app == null or int(app.settings.time_of_day) != 0 or not sun_clear:
		return
	var cam = app.camera
	var dir = app.sun.global_basis.z.normalized()
	var point = cam.global_position + dir * 800
	if cam.is_position_behind(point):
		return
	var pos = app.retro.unproject(point)
	var dimensions = Vector2(app.retro.world_view.size)
	if not Rect2(Vector2.ZERO, dimensions).grow(50).has_point(pos):
		return
	var centre = dimensions * .5
	var strength = clampf(1 - pos.distance_to(centre) / dimensions.length(), 0, 1)
	for item in [
		[0.0, 18.0, Color(1, .87, .55, .16)],
		[.5, 9.0, Color(.35, .75, 1, .09)],
		[1.25, 15.0, Color(.4, 1, .75, .08)],
		[1.7, 23.0, Color(1, .6, .4, .06)]
	]:
		var at = pos.lerp(centre, item[0])
		var points = PackedVector2Array()
		for j in 6:
			points.append(at + Vector2.from_angle(j * TAU / 6) * item[1] * dimensions.y / 448)
		var colour = item[2]
		colour.a *= strength
		draw_colored_polygon(points, colour)
