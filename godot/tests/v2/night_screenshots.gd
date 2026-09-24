extends SceneTree
## Look-2 windowed review captures of Afterhours (sodium lamps, road streaks, headlights) and their cost.
## Run windowed (never --headless), with the flow-test flag so the user's settings file is untouched:
##   tools/Godot.exe --path . --script tests/v2/night_screenshots.gd -- --v2-flow-test
## Writes docs/rebuild/screenshots/look-2/<shot>.png and prints one NIGHT SHOT line per view with the
## frame's draw calls and GPU time, with the lamps shown and hidden, then NIGHT SHOTS RESULTS.

const TrackLights = preload("res://scripts/track/track_lights.gd")
const FOLDER = "res://docs/rebuild/screenshots/look-2"

var failures = []
var results = {}


func _initialize():
	call_deferred("run")


## [track, shot, station (a corner name plus metres, or metres from the start when negative/number)].
func shots() -> Array:
	return [
		["proving_ground", "proving-ground-start", -45.0],
		["proving_ground", "proving-ground-grandstand", 170.0],
		["proving_ground", "proving-ground-back", 900.0],
		["spa", "spa-la-source", ["La Source", -130.0]],
		["spa", "spa-eau-rouge", ["Eau Rouge", -150.0]],
		["spa", "spa-kemmel", ["Raidillon", 520.0]],
		["spa", "spa-pit-straight", -160.0],
		["nordschleife_s1", "nordschleife-start", -70.0],
		["nordschleife_s1", "nordschleife-t13", 60.0],
	]


func station(track, where) -> float:
	if where is Array:
		return float(track.get_meta("corners", {}).get(where[0], 0.0)) + float(where[1])
	return fposmod(float(where), track.length)


func run():
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	app.settings.time_of_day = 1
	app.apply_time_of_day()
	var loaded = ""
	for shot in shots():
		if shot[0] != loaded:
			if not app.load_v2_track(shot[0]):
				failures.append("load " + shot[0])
				continue
			loaded = shot[0]
			app.start_v2_drive()
		await capture(app, shot, viewport, true)
		if shot[1] == "spa-la-source":
			app.settings.time_of_day = 0
			app.apply_time_of_day()
			await capture(app, [shot[0], shot[1] + "-day", shot[2]], viewport, false)
			app.settings.time_of_day = 1
			app.apply_time_of_day()
	if app.load_v2_track("spa"):
		results["spa_lap_sweep"] = await sweep(app, viewport)
		print("NIGHT SWEEP spa ", JSON.stringify(results["spa_lap_sweep"]))
	app.queue_free()
	await process_frame
	print("NIGHT SHOTS RESULTS ", JSON.stringify({"failures": failures, "results": results}))
	quit(0 if failures.is_empty() else 1)


## Afterhours cost round a whole Spa lap: the chase view every 20 m, three frames each, vsync off.
func sweep(app, viewport) -> Dictionary:
	var worst = 0.0
	var total = 0.0
	var gpu_worst = 0.0
	var gpu_total = 0.0
	var draws_worst = 0.0
	var frames = 0
	var s = 0.0
	while s < app.track.length:
		pose(app, s, true)
		await process_frame
		for i in 3:
			var start = Time.get_ticks_usec()
			await process_frame
			var ms = (Time.get_ticks_usec() - start) / 1000.0
			var gpu = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			worst = maxf(worst, ms)
			total += ms
			gpu_worst = maxf(gpu_worst, gpu)
			gpu_total += gpu
			draws_worst = maxf(
				draws_worst,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			)
			frames += 1
		s += 20.0
	return {
		"frames": frames,
		"mean_frame_ms": snappedf(total / frames, .01),
		"worst_frame_ms": snappedf(worst, .01),
		"mean_fps": snappedf(1000.0 * frames / total, .1),
		"mean_gpu_ms": snappedf(gpu_total / frames, .01),
		"worst_gpu_ms": snappedf(gpu_worst, .01),
		"worst_draw_calls": draws_worst,
	}


## Put the car on the lap line at station s, 1.6 m right of centre, with the chase camera behind it.
func pose(app, s, night) -> void:
	var track = app.track
	var st = track.station(s)
	var forward: Vector3 = st.tangent
	forward.y = 0.0
	forward = forward.normalized()
	var right = forward.cross(Vector3.UP)
	app.set_process(false)
	app.set_physics_process(false)
	app.car.place(st.pos + right * 1.6, atan2(forward.z, forward.x), st.pos.y)
	app.car.rot = Basis(forward, Vector3.UP, right).get_rotation_quaternion()
	app.car.pos = st.pos + right * 1.6 + Vector3.UP * (app.car.setup.cgHeight + .05)
	app.car.sync_legacy()
	app.prev_pose = app.snapshot_v2()
	app.instruments.visible = false
	if app.frontend:
		app.frontend.visible = false
	app.settings.camera = 0
	app.render_v2(1.0)
	app.update_camera(1.0, true)
	TrackLights.update_pool(app.lamp_pool, track, app.camera.global_position, night)


func capture(app, shot, viewport, night):
	var track = app.track
	var s = station(track, shot[2])
	pose(app, s, night)
	for i in 6:
		await process_frame
	var path = FOLDER + "/" + shot[1] + ".png"
	var code = root.get_texture().get_image().save_png(path)
	if code != OK:
		failures.append("save " + path)
	var lit = await measure(viewport)
	var lights = track.get_node_or_null("Lights")
	var dark = lit
	if night and lights:
		lights.visible = false
		TrackLights.update_pool(app.lamp_pool, track, app.camera.global_position, false)
		dark = await measure(viewport)
		lights.visible = true
		TrackLights.update_pool(app.lamp_pool, track, app.camera.global_position, true)
	var pooled = 0
	for light in app.lamp_pool:
		pooled += 1 if light.visible else 0
	var row = {
		"station_m": s,
		"draw_calls": lit.draws,
		"draw_calls_without_lamps": dark.draws,
		"objects": lit.objects,
		"gpu_ms": lit.gpu,
		"gpu_ms_without_lamps": dark.gpu,
		"cpu_ms": lit.cpu,
		"pool_lights_on": pooled,
		"lamps": int(lights.get_meta("lamp_count", 0)) if lights else 0,
	}
	results[shot[1]] = row
	print("NIGHT SHOT ", shot[1], " ", path, " ", JSON.stringify(row))


## Mean draw calls, objects and render times over 60 frames.
func measure(viewport) -> Dictionary:
	for i in 4:
		await process_frame
	var out = {"draws": 0.0, "objects": 0.0, "gpu": 0.0, "cpu": 0.0}
	var frames = 60
	for i in frames:
		await process_frame
		out.draws += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		out.objects += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
		)
		out.gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		out.cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	for key in out:
		out[key] = snappedf(out[key] / frames, .01)
	return out
