extends Control
## Original 448-line console front end. Physics/save ownership stays in game.gd.
const FONT = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const BOLD = preload("res://assets/fonts/Rajdhani-Bold.ttf")
var app
var page = "boot"
var previous_page = "main"
var age = 0.0
var idle = 0.0
var pad_prompts = false
var choices: Control
var prompt: Label
var buttons = []
var selected_track = ""
var race_mode = "Time Trial"
var loading_progress = 0.0
var loading_stage = ""
var loading = false
var loading_serial = 0
var loading_timings = {}
var laps = []
var lap_top_speed = 0.0
var session_top_speed = 0.0
var seen_completed = 0
var replay_time = 0.0
var last_ghost = []
var demo_driver
var demo_ticks = 0
var demo_context = {}
var paint_index = 0
var rim_index = 0
var navigation_log = []
var ui_player: AudioStreamPlayer
var ui_sounds = {}


func initialize(owner_app):
	app = owner_app
	# Godot's built-in UI bindings can be restricted to device zero. Accept
	# any connected pad, including hot-plugged devices, for menu navigation.
	for binding in [
		["ui_accept", JOY_BUTTON_A],
		["ui_cancel", JOY_BUTTON_B],
		["ui_up", JOY_BUTTON_DPAD_UP],
		["ui_down", JOY_BUTTON_DPAD_DOWN],
		["ui_left", JOY_BUTTON_DPAD_LEFT],
		["ui_right", JOY_BUTTON_DPAD_RIGHT]
	]:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = binding[1]
		InputMap.action_add_event(binding[0], event)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices = Control.new()
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(choices)
	choices.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt = Label.new()
	prompt.z_index = 80
	var strip = StyleBoxFlat.new()
	strip.bg_color = Color(.025, .045, .065, .96)
	strip.content_margin_left = 12
	strip.content_margin_top = 5
	prompt.add_theme_stylebox_override("normal", strip)
	prompt.add_theme_font_override("font", FONT)
	prompt.add_theme_font_size_override("font_size", 32)
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_left = 48
	prompt.offset_right = -48
	prompt.offset_top = -50
	ui_player = AudioStreamPlayer.new()
	add_child(ui_player)
	for kind in ["move", "confirm", "back", "error"]:
		ui_sounds[kind] = make_tone(kind)
	demo_driver = preload("res://scripts/showcase_driver.gd").new()
	show_page("boot")


func make_tone(kind):
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration = .055 if kind == "move" else .14
	var frequencies = {"move": 780., "confirm": 1040., "back": 520., "error": 220.}
	var bytes = PackedByteArray()
	bytes.resize(int(duration * 22050) * 2)
	for i in bytes.size() / 2:
		var t = float(i) / 22050
		var envelope = sin(PI * clampf(t / duration, 0, 1)) * exp(-t * 16)
		var f = frequencies[kind] * (1.5 if kind == "confirm" and t > .06 else 1.)
		bytes.encode_s16(i * 2, int(sin(TAU * f * t) * envelope * 7000))
	stream.data = bytes
	return stream


func tone(kind):
	if app.settings.mute or ui_player == null:
		return
	ui_player.stream = ui_sounds[kind]
	ui_player.volume_db = linear_to_db(maxf(.0001, app.settings.volume * app.settings.effects_volume))
	ui_player.play()


func add_option(caption, action, index, position = Vector2(24, 154), width = 264):
	var b = Button.new()
	b.text = caption
	b.name = caption.validate_node_name()
	b.position = (position + Vector2(0, index * 31)) * 2
	b.size = Vector2(width, 29) * 2
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 34)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color(.03, .055, .09, .82) if state == "normal" else Color("e7b747")
		box.border_color = Color("7393a3") if state == "normal" else Color("fff3c1")
		box.border_width_bottom = 2
		box.border_width_left = 2 if state == "normal" else 8
		box.content_margin_left = 18
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Color("eef0df"))
	for state in ["focus", "hover", "pressed"]:
		b.add_theme_color_override("font_" + state + "_color", Color("121a23"))
	choices.add_child(b)
	b.pressed.connect(
		func():
			tone("confirm")
			action.call()
	)
	b.focus_entered.connect(
		func():
			tone("move")
			b.queue_redraw()
	)
	buttons.append(b)
	return b


func show_page(next):
	page = next
	age = 0
	idle = 0
	navigation_log.append(next)
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	buttons.clear()
	app.controls.clear()
	app.in_menu = next not in ["drive", "pause", "attract"]
	if next != "pause":
		app.paused = false
	if next in ["main", "car", "circuit", "title", "boot"]:
		app.menu_time = 0.0
	match next:
		"boot":
			add_option("Skip", func(): show_page("title"), 0, Vector2(244, 358), 150)
		"title":
			add_option("PRESS START", func(): show_page("main"), 0, Vector2(206, 308), 228)
		"main":
			add_option("Race", func(): show_page("race"), 0)
			add_option("Garage", func(): open_panel("garage"), 1)
			add_option("Circuits", func(): show_page("circuits"), 2)
			add_option("Settings", func(): open_panel("settings"), 3)
			add_option("Help", func(): open_panel("help"), 4)
			add_option(
				"Test surfaces (dev)",
				func(): app.get_tree().change_scene_to_file("res://scenes/proving/test_surfaces.tscn"),
				0,
				Vector2(322, 154),
				290
			)
			add_option("Drive Spa (dev)", func(): drive_track_asset("spa"), 1, Vector2(322, 154), 290)
			add_option(
				"Drive proving ground (dev)",
				func(): drive_track_asset("proving_ground"),
				2,
				Vector2(322, 154),
				290
			)
			add_option("Quit", app.request_quit, 5)
			add_option("Back", back, 0, Vector2(500, 370), 112)
		"race":
			add_option(
				"Time Trial",
				func():
					race_mode = "Time Trial"
					show_page("car"),
				0
			)
			add_option(
				"Free Run",
				func():
					race_mode = "Free Run"
					show_page("car"),
				1
			)
			add_option("Back", back, 3)
		"car":
			add_option("Continue to circuit", func(): show_page("circuit"), 0, Vector2(24, 225))
			add_option("Car: " + app.car.p.name, cycle_car, 1, Vector2(24, 225), 410)
			add_option(
				"Paint: " + ["Factory", "Ivory", "Blue metallic"][paint_index],
				cycle_paint,
				2,
				Vector2(24, 225)
			)
			add_option("Rims: " + ["Silver", "Graphite"][rim_index], cycle_rims, 3, Vector2(24, 225))
			add_option("Setup / saved presets", func(): open_panel("garage"), 4, Vector2(24, 225))
			add_option("Back", back, 5, Vector2(24, 225))
		"circuit":
			add_option("Load circuit", prepare_race, 0, Vector2(24, 225))
			add_option(app.track.data.name + "  >", cycle_track, 1, Vector2(24, 225), 354)
			add_option(
				"Light: " + ["Afternoon", "Afterhours"][int(app.settings.time_of_day)],
				cycle_light,
				2,
				Vector2(24, 225)
			)
			add_option("Back", back, 4, Vector2(24, 225))
		"circuits":
			add_option("Circuit library", func(): open_panel("library"), 0)
			add_option("Back", back, 3)
		"pause":
			app.in_menu = false
			app.paused = true
			add_option("Resume", func(): app.set_paused(false), 0, Vector2(196, 106), 250)
			add_option("Restart", prepare_race, 1, Vector2(196, 106), 250)
			add_option("Garage", func(): open_panel("garage"), 2, Vector2(196, 106), 250)
			add_option("Settings", func(): open_panel("settings"), 3, Vector2(196, 106), 250)
			add_option("Help", func(): open_panel("help"), 4, Vector2(196, 106), 250)
			add_option("Time sheet", func(): show_page("results"), 5, Vector2(196, 106), 250)
			add_option("Quit to menu", app.show_main_menu, 6, Vector2(196, 106), 250)
		"results":
			add_option("Retry", prepare_race, 0, Vector2(24, 274), 180)
			add_option("Change car", func(): show_page("car"), 1, Vector2(24, 274), 180)
			add_option("Change circuit", func(): show_page("circuit"), 2, Vector2(24, 274), 180)
			add_option("Main menu", app.show_main_menu, 3, Vector2(24, 274), 180)
			if last_ghost.size() > 2:
				add_option(
					"Last-lap replay",
					func():
						replay_time = 0
						show_page("replay"),
					0,
					Vector2(370, 274),
					244
				)
		"replay", "attract":
			add_option("Back", back, 0, Vector2(500, 16), 112)
		"loading", "grid":
			add_option("Back", back, 0, Vector2(500, 16), 112)
		"drive":
			var pause_button = add_option("Pause", func(): app.set_paused(true), 0, Vector2(532, 16), 80)
			pause_button.focus_mode = Control.FOCUS_NONE
	if not buttons.is_empty():
		call_deferred("focus_first")
	queue_redraw()


func open_panel(kind):
	previous_page = page
	match kind:
		"garage":
			app.ui.open_garage()
		"settings":
			app.ui.open_settings()
		"help":
			app.ui.open_help()
		"library":
			app.ui.open_library()
	choices.visible = false


func focus_first():
	if (
		not buttons.is_empty()
		and is_instance_valid(buttons[0])
		and buttons[0].is_inside_tree()
		and not app.ui.is_open()
		and page != "drive"
	):
		buttons[0].grab_focus()


func back():
	tone("back")
	if app.ui.is_open():
		if app.ui.dialogs > 0:
			for dialog in app.find_children("*", "AcceptDialog", true, false):
				if dialog.visible:
					dialog.canceled.emit()
					return
		app.ui.close()
		return
	if loading:
		loading = false
		loading_serial += 1
		show_page("circuit")
		return
	match page:
		"boot":
			show_page("title")
		"title":
			show_page("main")
		"main":
			show_page("title")
		"race", "circuits":
			show_page("main")
		"car":
			show_page("race")
		"circuit":
			show_page("car")
		"pause":
			app.set_paused(false)
		"drive":
			app.set_paused(true)
		"results":
			app.show_main_menu()
		"replay":
			show_page("results")
		"attract":
			end_demo()
			show_page("title")
		"grid":
			show_page("circuit")


func handle(event):
	if event is InputEventKey or event is InputEventMouseButton:
		pad_prompts = false
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad_prompts = true
	var pressed = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if event is InputEventMouseMotion or pressed:
		idle = 0
	if not pressed or not app.controls.listening.is_empty():
		return false
	if app.ui.is_open():
		var tab_step = 0
		if event is InputEventJoypadButton:
			tab_step = (
				int(event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
				- int(event.button_index == JOY_BUTTON_LEFT_SHOULDER)
			)
		elif event is InputEventKey:
			tab_step = int(event.physical_keycode == KEY_PAGEDOWN) - int(event.physical_keycode == KEY_PAGEUP)
		if tab_step != 0:
			for tabs in app.ui.content.find_children("*", "TabContainer", true, false):
				tabs.current_tab = posmod(tabs.current_tab + tab_step, tabs.get_tab_count())
				tabs.get_tab_bar().grab_focus()
			return true
	var cancel = (
		(event is InputEventKey and event.physical_keycode == KEY_ESCAPE)
		or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B)
	)
	var start = (
		(event is InputEventKey and event.physical_keycode == KEY_ENTER)
		or (event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_A])
	)
	if cancel:
		if page == "drive" and event is InputEventJoypadButton:
			return false
		back()
		return true
	if page in ["boot", "title", "attract"] and start:
		if page == "attract":
			end_demo()
		show_page("title" if page in ["boot", "attract"] else "main")
		return true
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
		if page in ["drive", "pause"]:
			app.set_paused(not app.paused)
			return true
	return false


func cycle_car():
	var keys = app.presets.keys()
	app.change_car(keys[(keys.find(app.preset_key) + 1) % keys.size()])
	paint_index = 0
	rim_index = 0
	show_page("car")


func begin_demo():
	demo_context = {
		"track": app.track,
		"car": app.car,
		"race": app.race,
		"preset": app.preset_key,
		"file": app.active_track_file
	}
	if app.active_track_file != "res://tracks/Spa-Francorchamps.json":
		app.track = app.TrackModel.new()
		app.track.load_data(
			JSON.parse_string(FileAccess.get_file_as_string("res://tracks/Spa-Francorchamps.json"))
		)
		app.active_track_file = "res://tracks/Spa-Francorchamps.json"
		app.rebuild_world()
	app.car = app.CarModel.new()
	app.preset_key = "f296gt3"
	app.car.configure(app.presets.f296gt3)
	app.race = app.RaceModel.new()
	app.apply_settings()
	app.reset_car()
	app.instruments.rebuild_map()
	demo_driver.reset()
	show_page("attract")


func end_demo():
	if demo_context.is_empty():
		return
	var changed_track = app.track != demo_context.track
	app.track = demo_context.track
	app.car = demo_context.car
	app.race = demo_context.race
	app.preset_key = demo_context.preset
	app.active_track_file = demo_context.file
	if changed_track:
		app.rebuild_world()
	app.reset_car()
	app.instruments.rebuild_map()
	if app.ui and app.ui.menu_car:
		app.ui.menu_car.select(app.presets.keys().find(app.preset_key))
	apply_appearance()
	demo_context.clear()


func cycle_track():
	var index = (app.track_files.find(app.active_track_file) + 1) % app.track_files.size()
	app.load_track(index)
	show_page("circuit")


func cycle_light():
	app.ui.setting("time_of_day", 1 - int(app.settings.time_of_day))
	show_page("circuit")


func cycle_paint():
	paint_index = (paint_index + 1) % 3
	apply_appearance()
	show_page("car")


func cycle_rims():
	rim_index = 1 - rim_index
	apply_appearance()
	show_page("car")


func apply_appearance():
	for node in app.model.body.find_children("*", "MeshInstance3D", true, false):
		if (
			node.material_override is ShaderMaterial
			and node.material_override.shader == preload("res://shaders/retro_paint.gdshader")
		):
			var mat = node.material_override.duplicate()
			mat.set_shader_parameter("paint_variant", paint_index)
			node.material_override = mat
	for spin in app.model.spins:
		for node in spin.find_children("*", "MeshInstance3D", true, false):
			if node.material_override is StandardMaterial3D and node.material_override.metallic > .4:
				var mat = node.material_override.duplicate()
				mat.albedo_color = Color("bec4c7") if rim_index == 0 else Color("44494e")
				node.material_override = mat


func prepare_race():
	if loading:
		return
	loading_serial += 1
	var serial = loading_serial
	loading = true
	loading_timings = {}
	show_page("loading")
	loading_stage = "Circuit data"
	loading_progress = 0
	await RenderingServer.frame_post_draw
	if serial != loading_serial:
		return
	var stage_started = Time.get_ticks_usec()
	var validation = app.track.validate()
	loading_timings.validation_ms = (Time.get_ticks_usec() - stage_started) / 1000.0
	if not validation.errors.is_empty():
		loading = false
		app.message(validation.errors[0])
		show_page("circuit")
		return
	loading_progress = .25
	loading_stage = "Vehicle and setup"
	await get_tree().process_frame
	if serial != loading_serial:
		return
	stage_started = Time.get_ticks_usec()
	app.reset_car()
	apply_appearance()
	loading_timings.vehicle_ms = (Time.get_ticks_usec() - stage_started) / 1000.0
	loading_progress = .60
	loading_stage = "Timing and ghost"
	await get_tree().process_frame
	if serial != loading_serial:
		return
	stage_started = Time.get_ticks_usec()
	app.begin_session()
	loading_timings.timing_ms = (Time.get_ticks_usec() - stage_started) / 1000.0
	loading_progress = .8
	loading_stage = "Preparing circuit view"
	await RenderingServer.frame_post_draw
	if serial != loading_serial:
		return
	app.update_camera(1, true)
	await RenderingServer.frame_post_draw
	if serial != loading_serial:
		return
	loading_progress = 1
	loading = false
	reset_session_history()
	show_page("grid")


## A new car/setup/record must not reuse the previous session's completion count
## or append a zero-time result when RaceModel.completed returns to zero.
func reset_session_history():
	lap_top_speed = 0
	session_top_speed = 0
	seen_completed = app.race.completed
	laps.clear()
	last_ghost = []


func observe_tick():
	lap_top_speed = maxf(lap_top_speed, app.car.speed * 3.6)
	session_top_speed = maxf(session_top_speed, lap_top_speed)
	if app.race.completed != seen_completed:
		seen_completed = app.race.completed
		laps.append(
			{
				"time": app.race.last,
				"sectors": app.race.last_sectors.duplicate(),
				"valid": app.race.last_valid,
				"best": is_equal_approx(app.race.last, app.race.best),
				"top_speed": lap_top_speed,
				"reason": app.race.last_reason
			}
		)
		last_ghost = app.race.last_recording
		lap_top_speed = 0


func text_at(at, value, font_size = 16, color = Color("edf0e9"), bold = false):
	draw_string(BOLD if bold else FONT, at, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func draw_map(rect):
	var points = app.track.samples
	if points.is_empty():
		return
	var low = Vector2(INF, INF)
	var high = Vector2(-INF, -INF)
	for p in points:
		low = low.min(Vector2(p.x, p.y))
		high = high.max(Vector2(p.x, p.y))
	var scale_map = minf(rect.size.x / maxf(1, high.x - low.x), rect.size.y / maxf(1, high.y - low.y))
	var line = PackedVector2Array()
	for i in range(0, points.size(), 4):
		line.append(rect.get_center() + (Vector2(points[i].x, points[i].y) - (low + high) * .5) * scale_map)
	line.append(line[0])
	draw_polyline(line, Color("071018"), 5)
	draw_polyline(line, Color("e7cf77"), 2)


func _draw():
	if app == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(640, 448))
	if page == "drive":
		return
	if page == "boot":
		draw_rect(Rect2(0, 0, 640, 448), Color("071019"))
		draw_polyline(
			PackedVector2Array(
				[
					Vector2(274, 192),
					Vector2(320, 128),
					Vector2(366, 192),
					Vector2(320, 168),
					Vector2(274, 192)
				]
			),
			Color("e7b747"),
			3
		)
		text_at(Vector2(219, 236), "OPEN APEX", 40, Color.WHITE, true)
		text_at(Vector2(246, 265), "M O T O R W O R K S", 16)
		return
	if page == "title":
		draw_rect(Rect2(0, 0, 640, 448), Color(0, .025, .045, .36))
		text_at(Vector2(56, 118), "CIRCUIT CLUB", 58, Color("f1f0e3"), true)
		text_at(Vector2(60, 145), "RACING SIM  /  AFTERNOON TO AFTERHOURS", 16)
		text_at(Vector2(170, 392), "SPA-FRANCORCHAMPS   /   296 GT3", 16)
		return
	if page in ["attract", "replay"]:
		text_at(
			Vector2(24, 36),
			"DEMONSTRATION" if page == "attract" else "LAST LAP  /  REPLAY",
			20,
			Color.WHITE,
			true
		)
		return
	if page == "grid":
		draw_rect(Rect2(0, 164, 640, 122), Color(0, .025, .04, .45))
		text_at(Vector2(276, 244), str(maxi(1, 3 - int(age))), 78, Color("fff4c7"), true)
		text_at(Vector2(210, 276), "TIME TRIAL  /  GET READY", 18)
		return
	draw_rect(Rect2(0, 0, 640, 74), Color(.025, .045, .065, .94))
	draw_rect(Rect2(0, 412, 640, 36), Color(.025, .045, .065, .96))
	draw_line(Vector2(24, 72), Vector2(615, 72), Color("d8b04b"), 2)
	text_at(Vector2(24, 30), "CIRCUIT CLUB", 18, Color("e2c477"), true)
	var titles = {
		"main": "HOME",
		"race": "RACE",
		"car": "SELECT CAR",
		"circuit": "SELECT CIRCUIT",
		"circuits": "CIRCUITS",
		"pause": "PAUSED",
		"results": "SESSION TIME SHEET",
		"loading": "LOADING CIRCUIT"
	}
	text_at(Vector2(24, 60), titles.get(page, page.to_upper()), 28, Color.WHITE, true)
	if page in ["main", "race", "circuits"]:
		draw_rect(Rect2(18, 86, 316, 61), Color(.02, .035, .05, .88))
		text_at(Vector2(26, 113), app.car.p.name.to_upper(), 18)
		text_at(Vector2(26, 139), app.track.data.name, 16, Color("d4c693"))
	if page == "car":
		draw_rect(Rect2(16, 81, 376, 119), Color(.02, .035, .05, .9))
		text_at(Vector2(24, 103), app.car.p.name, 24, Color.WHITE, true)
		text_at(
			Vector2(24, 129),
			(
				"%d kg   /   %s   /   %d RPM"
				% [app.car.p.mass, ["RWD", "FWD", "AWD"][int(app.car.setup.layout)], app.car.p.redline]
			),
			16
		)
		var power = 0.0
		for point in app.car.p.torqueCurve:
			power = maxf(
				power, point[0] * app.car.p.redline * TAU / 60 * point[1] * app.car.p.engineTorque / 1000
			)
		text_at(Vector2(24, 153), "POWER  %.0f kW  /  %.0f hp" % [power, power * 1.341], 16)
		text_at(
			Vector2(24, 182),
			(
				"SETUP  %s  /  TCS %d  ASM %d"
				% [
					["SIMCADE", "SIMULATION"][int(app.settings.handling_model)],
					app.car.tcs_level(),
					app.car.asm_level()
				]
			),
			16,
			Color("e2c477")
		)
	if page in ["circuit", "loading"]:
		draw_rect(Rect2(16, 81, 366, 119), Color(.02, .035, .05, .9))
		draw_rect(Rect2(387, 82, 237, 319), Color(.02, .035, .05, .9))
		text_at(Vector2(24, 103), app.track.data.name, 24, Color.WHITE, true)
		text_at(
			Vector2(24, 129),
			(
				"%.3f km   /   %d named corners"
				% [app.track.length / 1000, app.track.data.get("presentation", {}).get("labels", []).size()]
			),
			16
		)
		text_at(Vector2(24, 154), "BEST  " + app.RaceModel.time_text(app.race.best), 18, Color("e2c477"))
		text_at(
			Vector2(24, 179),
			"GHOST  " + ("AVAILABLE" if app.race.ghost.size() > 1 else "NO RECORD FOR THIS SETUP"),
			16
		)
		draw_map(Rect2(400, 98, 200, 164))
		var profile = PackedVector2Array()
		var low_z = INF
		var high_z = -INF
		for p in app.track.samples:
			low_z = minf(low_z, p.z)
			high_z = maxf(high_z, p.z)
		for i in range(0, app.track.samples.size(), 8):
			var p = app.track.samples[i]
			profile.append(
				Vector2(
					390 + 220. * i / app.track.samples.size(),
					359 - 56 * (p.z - low_z) / maxf(1, high_z - low_z)
				)
			)
		if profile.size() > 1:
			draw_polyline(profile, Color("b3d6d2"), 2)
		text_at(Vector2(390, 385), "ELEVATION  %.0f m" % (high_z - low_z), 16)
	if page == "loading":
		draw_rect(Rect2(24, 275, 340, 10), Color("293942"))
		draw_rect(Rect2(24, 275, loading_progress * 340, 10), Color("e6bd52"))
		text_at(Vector2(24, 264), loading_stage, 18)
		text_at(Vector2(24, 326), "TIP  Brake before you turn; unwind the", 16)
		text_at(Vector2(24, 348), "steering as you feed in the throttle.", 16)
	if page == "results":
		draw_rect(Rect2(16, 82, 608, 182), Color(.02, .045, .065, .88))
		var columns = [26, 77, 205, 302, 399, 502]
		var headings = ["LAP", "TIME", "S1", "S2", "S3", "STATUS"]
		for column in columns.size():
			text_at(Vector2(columns[column], 106), headings[column], 16)
		if laps.is_empty():
			text_at(Vector2(26, 142), "No completed laps this session", 20)
		for i in mini(laps.size(), 4):
			var lap = laps[maxi(0, laps.size() - 4) + i]
			var values = [
				"%02d" % (maxi(0, laps.size() - 4) + i + 1),
				app.RaceModel.time_text(lap.time),
				"%06.2f" % lap.sectors[0],
				"%06.2f" % lap.sectors[1],
				"%06.2f" % lap.sectors[2],
				"INVALID" if not lap.valid else ("BEST" if lap.best else "VALID")
			]
			for column in columns.size():
				text_at(
					Vector2(columns[column], 137 + i * 24),
					values[column],
					16,
					Color("d8bd6b") if lap.best else Color.WHITE
				)
		text_at(Vector2(26, 250), "TOP SPEED  %.1f km/h" % session_top_speed, 18)


func _process(dt):
	if app == null:
		return
	age += dt
	idle += dt
	visible = true
	choices.visible = not app.ui.is_open()
	choices.modulate.a = clampf(age / .12, 0, 1)
	prompt.visible = true
	prompt.text = (
		"[NAV] Move   [1] Select   [2] Back   [MENU] Pause"
		if pad_prompts
		else "ARROWS  Move     ENTER  Select     ESC  Back"
	)
	if app.ui.is_open():
		prompt.text = (
			"[NAV] Move  [1] Select  [2] Back  [L/R] Tabs"
			if pad_prompts
			else "TAB  Move   ENTER  Select   ESC  Back   PGUP/DN  Tabs"
		)
	elif page == "drive":
		prompt.text = "[MENU] Pause   /   [VIEW] Camera" if pad_prompts else "ESC  Pause     V  Camera"
	elif page == "grid":
		prompt.text = "[2] Return to circuit selection" if pad_prompts else "ESC  Return to circuit selection"
	elif page in ["boot", "title"]:
		prompt.text = "[1] Continue    [2] Back" if pad_prompts else "ENTER  Continue    ESC  Back"
	if page == "boot" and age > 1.2:
		show_page("title")
	elif page == "title" and idle > 25:
		begin_demo()
	elif page == "grid":
		var pos = app.model.root.position
		var a = -1.1 + age * .28
		app.camera.position = pos + Vector3(cos(a) * 7, 2.3, sin(a) * 7)
		app.camera.look_at(pos + Vector3.UP * .6)
		if age > 3:
			show_page("drive")
	elif page == "replay" and last_ghost.size() > 2:
		replay_time = fmod(replay_time + dt, maxf(.1, last_ghost[-1][0]))
		var index = mini(int(replay_time * 30), last_ghost.size() - 2)
		var a = last_ghost[index]
		var b = last_ghost[index + 1]
		var t = clampf((replay_time - a[0]) / maxf(.001, b[0] - a[0]), 0, 1)
		var pose = app.car.snapshot()
		pose.x = lerpf(a[1], b[1], t)
		pose.y = lerpf(a[2], b[2], t)
		pose.h = lerp_angle(a[3], b[3], t)
		pose.steer = lerpf(a[4], b[4], t)
		app.visuals.pose_car(app.model, pose, app.track)
		app.update_camera(dt, true)
	queue_redraw()


## Pass the requested TrackAsset to the standalone 6-DOF scene without changing saved track choice.
func drive_track_asset(id: String) -> void:
	app.get_tree().set_meta("dev_track_id", id)
	app.get_tree().change_scene_to_file("res://scenes/proving/track_drive.tscn")
