extends Control
## Original 448-line console front end. Physics/save ownership stays in game.gd.
const FONT = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const BOLD = preload("res://assets/fonts/Rajdhani-Bold.ttf")
var app
var page = "boot"
var age = 0.0
var choices: Control
var prompt: Label
var buttons = []
var selected_track = ""
var race_mode = "Time Trial"
var loading_progress = 0.0
var loading_stage = ""
var loading = false
var loading_serial = 0
var laps = []
var lap_top_speed = 0.0
var session_top_speed = 0.0
var seen_completed = 0
var last_ghost = []
var ui_player: AudioStreamPlayer
var ui_sounds = {}
var v2_panels: Control
const V2_TRACKS = {
	"proving_ground": "Proving Ground",
	"spa": "Spa-Francorchamps",
	"nordschleife_s1": "Nordschleife (T13 - Aremberg)",
	"chicago": "Chicago — River & Lake"
}


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
	v2_panels = preload("res://scripts/v2_panels.gd").new()
	add_child(v2_panels)
	v2_panels.initialize(app)


## Release the menu-sound player when the node is freed, like audio.gd, so no playback outlives the leak
## check. Not _exit_tree(): the presentation chain re-parents the UI root into its viewport (Look-3), which
## exits and re-enters the tree, and clearing there broke every menu tone.
func _notification(what):
	if what == NOTIFICATION_PREDELETE and ui_player != null:
		ui_player.stop()
		ui_player.stream = null


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
	show_v2_page(next)


func focus_first():
	if (
		not buttons.is_empty()
		and is_instance_valid(buttons[0])
		and buttons[0].is_inside_tree()
		and (app.ui == null or not app.ui.is_open())
		and (v2_panels == null or not v2_panels.is_open())
		and page != "drive"
	):
		buttons[0].grab_focus()


func back():
	if v2_panels and v2_panels.is_open():
		v2_panels.close()
		return
	match page:
		"drive":
			show_page("pause")
		"pause":
			show_page("drive")
		"loading":
			loading = false
			loading_serial += 1
			show_page("circuit")
		"circuit":
			show_page("car")
		"car":
			show_page("main")
		_:
			show_page("main")


func handle(event):
	if not app.controls.listening.is_empty():
		var was_listening = true
		if app.controls.handle(event, false):
			if was_listening and app.controls.listening.is_empty():
				app.save_settings()
				v2_panels.update_mapping_labels()
			return true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		back()
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		back()
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		if page in ["drive", "pause"] and not v2_panels.is_open():
			back()
			return true


## A new car/setup/record must not reuse the previous session's completion count
## or append a zero-time result when RaceModel.completed returns to zero.
func reset_session_history():
	lap_top_speed = 0
	session_top_speed = 0
	seen_completed = app.race.completed
	laps.clear()
	last_ghost = []


func text_at(at, value, font_size = 16, color = Color("edf0e9"), bold = false):
	draw_string(BOLD if bold else FONT, at, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw():
	if app == null:
		return
	draw_v2()


func _process(dt):
	if app == null:
		return
	age += dt
	choices.visible = page != "drive" and not v2_panels.is_open()
	prompt.visible = page != "drive" and not v2_panels.is_open()
	prompt.text = "ARROWS  Move     ENTER  Select     ESC  Pause / Back"
	queue_redraw()


## P4-06 pages use the same front-end controls with TrackAsset choices and no legacy track data.
func show_v2_page(next: String) -> void:
	page = next
	age = 0.0
	if app.instruments:
		app.instruments.visible = next in ["drive", "pause"]
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	buttons.clear()
	app.in_menu = next not in ["drive", "pause"]
	app.paused = next == "pause"
	app.controls.clear()
	match next:
		"main":
			add_option("Race", func(): show_page("car"), 0)
			add_option("Garage", func(): open_v2_panel("garage"), 1)
			add_option("Settings", func(): open_v2_panel("settings"), 2)
			add_option("Quit", app.request_quit, 3)
		"car":
			add_option("Continue to circuit", func(): show_page("circuit"), 0)
			add_option("Car: " + app.car.p.name, cycle_v2_car, 1)
			add_option("Garage / setup", func(): open_v2_panel("garage"), 2)
			add_option("Back", back, 3)
		"circuit":
			add_option("Load circuit", prepare_v2_race, 0)
			add_option(
				V2_TRACKS.get(selected_track, "Proving Ground") + "  >",
				cycle_v2_track,
				1,
				Vector2(24, 154),
				355
			)
			add_option("Back", back, 2)
		"pause":
			add_option("Resume", func(): show_page("drive"), 0)
			add_option("Restart lap", app.restart_v2_lap, 1)
			add_option("Settings", func(): open_v2_panel("settings"), 2)
			add_option("Garage", func(): open_v2_panel("garage"), 3)
			add_option("Back to menu", app.return_v2_menu, 4)
	if selected_track.is_empty():
		selected_track = app.v2_track_id
	if not buttons.is_empty():
		call_deferred("focus_first")
	queue_redraw()


func open_v2_panel(kind: String) -> void:
	v2_panels.open(kind)
	choices.visible = false
	prompt.visible = false


func cycle_v2_car() -> void:
	var keys = app.presets.keys()
	app.change_v2_car(keys[(keys.find(app.preset_key) + 1) % keys.size()])
	show_page("car")


## Step through every circuit in V2_TRACKS (it used to toggle between the first two only).
func cycle_v2_track() -> void:
	var ids = V2_TRACKS.keys()
	selected_track = ids[(ids.find(selected_track) + 1) % ids.size()]
	show_page("circuit")


## Show loading before the generator bakes; the loader validates and caches by source revision.
func prepare_v2_race() -> void:
	if loading:
		return
	loading = true
	loading_serial += 1
	var serial = loading_serial
	loading_stage = "Preparing " + V2_TRACKS[selected_track]
	loading_progress = 0.1
	show_page("loading")
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if serial != loading_serial:
		return
	var ok = app.load_v2_track(selected_track)
	if serial != loading_serial:
		return
	loading = false
	if not ok:
		show_page("circuit")
		return
	loading_progress = 1.0
	app.start_v2_drive()


## Menu copy uses the asset's public identity and lap length, including before the new asset loads.
func draw_v2() -> void:
	if page == "drive":
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(640, 448))
	draw_rect(Rect2(0, 0, 640, 448), Color(.025, .045, .065, .95))
	draw_line(Vector2(24, 72), Vector2(615, 72), Color("d8b04b"), 2)
	text_at(Vector2(24, 30), "CIRCUIT CLUB", 18, Color("e2c477"), true)
	text_at(
		Vector2(24, 60),
		{"main": "HOME", "car": "SELECT CAR", "circuit": "SELECT CIRCUIT", "loading": "LOADING"}.get(
			page, page.to_upper()
		),
		28,
		Color.WHITE,
		true
	)
	if page == "main":
		text_at(Vector2(24, 125), app.car.p.name, 20)
		text_at(Vector2(24, 150), V2_TRACKS.get(app.v2_track_id, app.v2_track_id), 18)
	elif page == "car":
		text_at(Vector2(24, 125), app.car.p.name, 24, Color.WHITE, true)
	elif page in ["circuit", "loading"]:
		text_at(Vector2(24, 125), V2_TRACKS.get(selected_track, selected_track), 24, Color.WHITE, true)
		if selected_track == app.v2_track_id and app.track is Node3D:
			text_at(Vector2(24, 152), "%.3f km" % (app.track.length / 1000.0), 18)
			text_at(Vector2(24, 179), "BEST  " + app.RaceModel.time_text(app.race.best), 18, Color("e2c477"))
	if page == "loading":
		draw_rect(Rect2(24, 275, 340, 10), Color("293942"))
		draw_rect(Rect2(24, 275, loading_progress * 340, 10), Color("e6bd52"))
		text_at(Vector2(24, 264), loading_stage, 18)
