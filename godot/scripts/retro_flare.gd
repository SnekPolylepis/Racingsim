extends Control
## Original hexagon flare, rendered inside the world viewport. Terrain ray occludes the sun.
var app


func _process(_dt):
	queue_redraw()


func _draw():
	if app == null or app.editing or app.settings.time_of_day != 0 or app.visuals.world == null:
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
	var query = PhysicsRayQueryParameters3D.create(cam.global_position, point)
	if not cam.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	# Use the already-built render heightfield. ground_height() performs two
	# full circuit projections per sample and caused 40 ms stalls facing the sun.
	# The small bias covers the road ribbon sitting above this 8 m terrain grid.
	for i in range(4, 600, 12):
		var ray = cam.global_position + dir * i
		if app.visuals.world.height(ray.x, ray.z) + .65 > ray.y:
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
