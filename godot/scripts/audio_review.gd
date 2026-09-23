extends Node
## Bounded rendered/mixer regression for amber lighting and the recorded engine bank.
var app
var output = ""
var checks = 0
var failures = []
var measurements = []
var capture: AudioEffectCapture


func check(value, label):
	checks += 1
	if not value:
		failures.append(label)
		push_error("AUDIO REVIEW: " + label)


func sample(name, rpm, throttle, active = true):
	app.car.rpm = rpm
	app.car.throttle_eff = throttle
	app.car.shift_timer = 0
	for i in 90:
		app.sound.update(app.car, 1.0 / 60, active, app.settings)
	await get_tree().create_timer(.16).timeout
	capture.clear_buffer()
	await get_tree().create_timer(.3).timeout
	var frames = capture.get_buffer(capture.get_frames_available())
	var sum = 0.0
	var peak = 0.0
	var bytes = PackedByteArray()
	bytes.resize(frames.size() * 4)
	for i in frames.size():
		sum += frames[i].length_squared() * .5
		peak = maxf(peak, maxf(absf(frames[i].x), absf(frames[i].y)))
		bytes.encode_s16(i * 4, int(clampf(frames[i].x, -1, 1) * 32767))
		bytes.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1, 1) * 32767))
	var rms = sqrt(sum / maxi(1, frames.size()))
	measurements.append({"case": name, "rpm": rpm, "rms": rms, "peak": peak, "frames": frames.size()})
	check(frames.size() > 1000, name + " mixed frames")
	check(is_finite(rms) and peak < .98, name + " finite unclipped output")
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.stereo = true
	wave.mix_rate = int(AudioServer.get_mix_rate())
	wave.data = bytes
	check(wave.save_to_wav(output.path_join(name + ".wav")) == OK, name + " captured")
	return rms


func run(owner_app):
	app = owner_app
	var backend = RenderingServer.get_current_rendering_method()
	output = (
		("res://tests/audio-study" if OS.has_feature("editor") else "user://native-tests/audio-review")
		. path_join(backend)
	)
	DirAccess.make_dir_recursive_absolute(output)
	app.settings = app.DEFAULT_SETTINGS.duplicate(true)
	app.settings.folder = "user://native-tests"
	app.settings.effects_volume = 0
	app.settings.adaptive = false
	app.start_drive()
	app.apply_settings()
	app.set_physics_process(false)
	app.set_process(false)
	app.frontend.set_process(false)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 1
	var effect_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	for band in app.sound.ENGINE_BANDS:
		for prefix in ["engine_", "coast_"]:
			var stream = app.sound.players[prefix + band[0]].stream
			check(
				stream.get_length() > .5 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
				prefix + band[0] + " recorded loop"
			)
	for rpm in [1250, 2400, 4200, 6800, 8000]:
		check(await sample("power-" + str(rpm), rpm, .9) > .01, "audible RPM " + str(rpm))
	var power = await sample("loaded", 4200, 1.0)
	var coast = await sample("coasting", 4200, 0.0)
	check(coast > .005 and coast < power * .9, "lift-off softens the recorded engine")
	app.settings.mute = true
	check(await sample("muted", 4200, 1.0) < .0001, "mute silences the bank")
	app.settings.mute = false
	check(await sample("paused", 4200, 1.0, false) < .0001, "pause silences the bank")
	app.settings.engine_volume = 0
	check(await sample("engine-volume-zero", 4200, 1.0) < .0001, "engine slider silences bank and intake")
	app.settings.engine_volume = .8
	for preset in ["roadster", "gt", "f296gt3"]:
		app.change_car(preset)
		app.set_physics_process(false)
		check(await sample("voice-" + preset, 4500, .8) > .01, preset + " recorded voice")
	AudioServer.remove_bus_effect(0, effect_index)
	app.settings.time_of_day = 1
	app.apply_settings()
	var lamps = app.scenery.get_node("NightCircuit")
	var all_amber = true
	var count = 0
	for light in lamps.find_children("*", "OmniLight3D", true, false):
		all_amber = (
			all_amber
			and light.light_color.r > light.light_color.g
			and light.light_color.g > light.light_color.b
		)
		count += 1
	check(count > 20 and all_amber, "every circuit lamp emits amber")
	for name in ["Grid", "Eau Rouge", "Kemmel"]:
		var distance = float(app.track.data.startS)
		for marker in app.track.data.presentation.labels:
			if str(marker.name) == name:
				distance = app.track.project(marker.x, marker.y).s - 60
		var p = app.track.pos_at(distance)
		app.car.reset_pose(p)
		app.prev_pose = {}
		app.frontend.show_page("drive")
		app.ui.sync_menus()
		for i in 40:
			app._process(.016)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(
			(
				app.get_viewport().get_texture().get_image().save_png(
					output.path_join(name.to_lower().replace(" ", "-") + ".png")
				)
				== OK
			),
			name + " amber screenshot"
		)
	var report = {"checks": checks, "failures": failures, "measurements": measurements, "renderer": backend}
	app.storage.write_json(output.path_join("audio-results.json"), report)
	print("AUDIO REVIEW " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
