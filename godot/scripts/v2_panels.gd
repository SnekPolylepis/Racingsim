extends Control
## Native v2 settings and garage panels. Ported UI controls and garage/settings flows from
## interface.gd so the legacy UI can be removed without affecting the rebuild path.
const FONT = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const BOLD = preload("res://assets/fonts/Rajdhani-Bold.ttf")
var app
var screen = ""
var shade: ColorRect
var modal: PanelContainer
var title_label: Label
var status_label: Label
var content: VBoxContainer
var mappings = []


func initialize(owner_app) -> void:
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The same 1280x896 logical UI scale as the console front end. This whole Control tree
	# stays below V2UIRoot so the retro UI viewport can adopt it unchanged.
	var ui_theme = Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 30
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var box = StyleBoxFlat.new()
			box.bg_color = Color("203844") if state == "normal" else Color("e7b747")
			box.border_color = Color("64818d") if state == "normal" else Color("fff3c1")
			box.set_border_width_all(2)
			box.border_width_left = 4 if state == "normal" else 10
			box.set_content_margin_all(8)
			ui_theme.set_stylebox(state, type, box)
		ui_theme.set_font("font", type, BOLD)
		ui_theme.set_color("font_color", type, Color("eef0df"))
		ui_theme.set_color("font_focus_color", type, Color("121a23"))
		ui_theme.set_color("font_hover_color", type, Color("121a23"))
		ui_theme.set_color("font_pressed_color", type, Color("121a23"))
	theme = ui_theme
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.04, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", style())
	shade.add_child(modal)
	var body = VBoxContainer.new()
	modal.add_child(body)
	var header = row(body)
	title_label = label(header, "", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "Close · Esc", close)
	status_label = label(body, "", 15)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fill the panel's height too, so the tab pages use it instead of stopping at their minimum and
	# leaving an empty band at the bottom of the panel.
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	resized.connect(layout)
	layout()
	visible = false


func style() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color("11242e")
	box.border_color = Color("d8b04b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(16)
	return box


func layout() -> void:
	if modal == null:
		return
	modal.size = Vector2(minf(1140, size.x - 48), minf(820, size.y - 48))
	modal.position = (size - modal.size) * 0.5


func label(parent: Node, value: String, font_size := 17) -> Label:
	var item = Label.new()
	item.text = value
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", font_size * 2)
	item.add_theme_color_override("font_color", Color("e5eef0"))
	parent.add_child(item)
	return item


func button(parent: Node, value: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = value
	item.custom_minimum_size.y = 54
	parent.add_child(item)
	item.pressed.connect(action)
	return item


func row(parent: Node) -> HBoxContainer:
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", 16)
	parent.add_child(item)
	return item


func number(
	parent: Node, caption: String, value: float, low: float, high: float, step: float, action: Callable
) -> SpinBox:
	var line = row(parent)
	var text_item = label(line, caption)
	text_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 220
	line.add_child(spin)
	spin.value_changed.connect(action)
	return spin


func choice(parent: Node, caption: String, values: Array, selected: int, action: Callable) -> OptionButton:
	var line = row(parent)
	var text_item = label(line, caption)
	text_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picker = OptionButton.new()
	picker.custom_minimum_size.x = 250
	line.add_child(picker)
	for value in values:
		picker.add_item(str(value))
	picker.select(clampi(selected, 0, values.size() - 1))
	picker.item_selected.connect(action)
	return picker


func check(parent: Node, caption: String, enabled: bool, action: Callable) -> CheckBox:
	var item = CheckBox.new()
	item.text = caption
	item.button_pressed = enabled
	parent.add_child(item)
	item.toggled.connect(action)
	return item


func tabs(names: Array) -> Dictionary:
	var container = TabContainer.new()
	container.custom_minimum_size.y = 590
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(container)
	var groups = {}
	for name in names:
		var scroll = ScrollContainer.new()
		scroll.name = name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		container.add_child(scroll)
		var group = VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 10)
		scroll.add_child(group)
		groups[name] = group
	return groups


func open(kind: String) -> void:
	app.controls.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	screen = kind
	status_label.text = ""
	title_label.text = "Garage / setup" if kind == "garage" else "Settings"
	visible = true
	if kind == "garage":
		open_garage()
	else:
		open_settings()


func close() -> void:
	if not app.controls.listening.is_empty():
		app.controls.listening = ""
		update_mapping_labels()
		return
	screen = ""
	visible = false
	app.controls.clear()
	if app.frontend:
		app.frontend.call_deferred("focus_first")


func is_open() -> bool:
	return visible


func notice(value: String) -> void:
	if visible:
		status_label.text = value


func confirm_action(title: String, description: String, action: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	add_child(dialog)
	dialog.confirmed.connect(
		func():
			action.call()
			dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(600, 180))


func save_named_setup(name: String) -> void:
	if app.save_v2_setup(name):
		open("garage")
		notice("Setup saved: " + name)


func ask_setup_name() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Save setup"
	var name_entry = LineEdit.new()
	name_entry.text = app.car.p.name
	name_entry.custom_minimum_size = Vector2(390, 38)
	dialog.add_child(name_entry)
	add_child(dialog)
	dialog.confirmed.connect(
		func():
			var name = name_entry.text.strip_edges()
			if not name.is_empty():
				var file = app.storage.path("setups", app.storage.safe_name(name) + ".json")
				if FileAccess.file_exists(file):
					confirm_action(
						"Replace setup?", file.get_file() + " already exists.", func(): save_named_setup(name)
					)
				else:
					save_named_setup(name)
			dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(440, 130))
	name_entry.grab_focus()
	name_entry.select_all()


func open_garage() -> void:
	var toolbar = row(content)
	button(toolbar, "Save as…", ask_setup_name)
	button(
		toolbar,
		"Defaults",
		func():
			app.car.setup = app.car.p.setup.duplicate(true)
			app.apply_v2_setup()
			open("garage")
	)
	var files = app.storage.list_files("setups")
	if not files.is_empty():
		var line = row(content)
		var picker = OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(picker)
		for file in files:
			picker.add_item(file.get_file().get_basename())
		button(
			line,
			"Load",
			func():
				if app.load_v2_setup(files[picker.selected]):
					open("garage")
		)
		button(
			line,
			"Delete",
			func():
				var file: String = files[picker.selected]
				confirm_action(
					"Delete setup?",
					"Delete " + file.get_file() + "?",
					func():
						if DirAccess.remove_absolute(file) == OK:
							open("garage")
							notice("Deleted " + file.get_file())
						else:
							notice("Could not delete " + file.get_file())
				)
		)
	var groups = {}
	for field in app.setup_fields:
		if not groups.has(field[0]):
			groups[field[0]] = field[0]
	groups = tabs(groups.keys())
	for field in app.setup_fields:
		if field[0] == "Aids":
			continue
		var key: String = field[1]
		var caption: String = field[2] + (" (" + field[6] + ")" if field[6] != "" else "")
		number(
			groups[field[0]],
			caption,
			app.car.setup[key],
			field[3],
			field[4],
			field[5],
			func(value):
				app.car.setup[key] = value
				app.apply_v2_setup()
		)
	number(
		groups.Aids,
		"TCS · traction control",
		app.car.tcs_level(),
		0,
		10,
		1,
		func(value):
			app.car.set_tcs(value)
			app.apply_v2_setup()
	)
	number(
		groups.Aids,
		"ASM · stability management",
		app.car.asm_level(),
		0,
		10,
		1,
		func(value):
			app.car.setup.asmLevel = value
			app.apply_v2_setup()
	)
	check(
		groups.Aids,
		"ABS",
		app.car.setup.absOn > .5,
		func(value):
			app.car.setup.absOn = 1.0 if value else 0.0
			app.apply_v2_setup()
	)
	label(content, "Changes apply immediately and select a record for this setup.", 15)


func setting(key: String, value: Variant) -> void:
	app.set_v2_setting(key, value)


func open_settings() -> void:
	var s = app.settings
	var groups = tabs(["Display", "Driving", "Controls", "Audio"])
	var d = groups.Display
	choice(
		d,
		"Camera",
		["Chase", "High chase", "Bonnet", "Overhead north", "Overhead car"],
		s.camera,
		func(v): setting("camera", v)
	)
	number(d, "Perspective / chase height", s.tilt, 0, 1, .05, func(v): setting("tilt", v))
	choice(d, "Speed units", ["km/h", "mph"], s.units, func(v): setting("units", v))
	check(d, "Vehicle debug overlay", s.debug, func(v): setting("debug", v))
	check(d, "Telemetry graph", s.telemetry, func(v): setting("telemetry", v))
	choice(
		d,
		"Render resolution",
		["480p", "720p", "Native"],
		s.render_resolution,
		func(v): setting("render_resolution", v)
	)
	choice(d, "Upscale", ["Sharp", "Soft"], s.upscale, func(v): setting("upscale", v))
	choice(d, "Output", ["480p component", "480i fields"], s.output_mode, func(v): setting("output_mode", v))
	choice(d, "Screen", ["4:3", "16:9 anamorphic"], s.screen_aspect, func(v): setting("screen_aspect", v))
	choice(d, "UI", ["Authentic", "Sharp UI"], s.ui_mode, func(v): setting("ui_mode", v))
	choice(
		d,
		"Framebuffer",
		["24-bit", "16-bit RGB555"],
		s.framebuffer_colour,
		func(v): setting("framebuffer_colour", v)
	)
	check(d, "CRT / composite", s.crt_filter, func(v): setting("crt_filter", v))
	check(d, "Colour dithering", s.colour_dither, func(v): setting("colour_dither", v))
	choice(d, "Speed blur", ["Off", "Low", "High"], s.speed_blur, func(v): setting("speed_blur", v))
	choice(d, "Time of day", ["Afternoon", "Afterhours"], s.time_of_day, func(v): setting("time_of_day", v))
	choice(d, "Graphics quality", ["Low", "Medium", "High"], s.quality, func(v): setting("quality", v))
	check(d, "Adaptive quality", s.adaptive, func(v): setting("adaptive", v))
	check(d, "Native resolution MSAA 2x", s.native_msaa, func(v): setting("native_msaa", v))
	check(d, "Fullscreen", s.fullscreen, func(v): setting("fullscreen", v))
	var r = groups.Driving
	choice(
		r,
		"Handling model",
		["Simcade", "Simulation"],
		s.handling_model,
		func(v): setting("handling_model", v)
	)
	check(r, "Automatic gearbox", s.automatic, func(v): setting("automatic", v))
	check(r, "Automatic clutch in manual mode", s.auto_clutch, func(v): setting("auto_clutch", v))
	check(r, "Tire wear", s.wear, func(v): setting("wear", v))
	check(r, "Invalidate lap off track", s.off_track, func(v): setting("off_track", v))
	check(r, "Invalidate lap on barrier contact", s.contact, func(v): setting("contact", v))
	check(r, "Show best-lap ghost", s.ghost, func(v): setting("ghost", v))
	number(
		r,
		"TCS",
		app.car.tcs_level(),
		0,
		10,
		1,
		func(v):
			app.car.set_tcs(v)
			app.apply_v2_setup()
	)
	number(
		r,
		"ASM",
		app.car.asm_level(),
		0,
		10,
		1,
		func(v):
			app.car.setup.asmLevel = v
			app.apply_v2_setup()
	)
	check(
		r,
		"ABS",
		app.car.setup.absOn > .5,
		func(v):
			app.car.setup.absOn = 1.0 if v else 0.0
			app.apply_v2_setup()
	)
	var c = groups.Controls
	check(
		c, "Simcade steering grip assist", s.simcade_grip_assist, func(v): setting("simcade_grip_assist", v)
	)
	number(c, "Controller deadzone", s.deadzone, 0, .3, .01, func(v): setting("deadzone", v))
	number(c, "Steering response exponent", s.linearity, 1, 3, .05, func(v): setting("linearity", v))
	number(c, "Keyboard steering rate", s.keyboard_rate, 1, 8, .1, func(v): setting("keyboard_rate", v))
	number(
		c,
		"Speed-sensitive steering · keyboard",
		s.steer_assist_kb,
		0,
		2,
		.05,
		func(v): setting("steer_assist_kb", v)
	)
	number(
		c,
		"Speed-sensitive steering · controller",
		s.steer_assist_pad,
		0,
		2,
		.05,
		func(v): setting("steer_assist_pad", v)
	)
	check(c, "Steering grip assist · keyboard", s.steer_grip_kb, func(v): setting("steer_grip_kb", v))
	check(c, "Steering grip assist · controller", s.steer_grip_pad, func(v): setting("steer_grip_pad", v))
	label(c, "Click a binding, then press a key, button or axis. Esc cancels.", 15)
	mappings.clear()
	for action in [
		"throttle", "brake", "left", "right", "steer", "clutch", "handbrake", "shiftUp", "shiftDown", "reset"
	]:
		var line = row(c)
		var caption = label(line, action.capitalize())
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for is_pad in [false, true]:
			if (action == "steer" and not is_pad) or (action in ["left", "right"] and is_pad):
				continue
			var binding = button(
				line,
				app.controls.binding_text(action, is_pad),
				func():
					app.controls.listening = action
					app.controls.listen_pad = is_pad
					update_mapping_labels()
			)
			binding.custom_minimum_size.x = 150
			mappings.append([binding, action, is_pad])
	button(
		c,
		"Reset mappings",
		func():
			app.controls.keys = app.Controls.DEFAULT_KEYS.duplicate(true)
			app.controls.pad = app.Controls.DEFAULT_PAD.duplicate(true)
			app.save_settings()
			update_mapping_labels()
	)
	var a = groups.Audio
	check(a, "Mute all sound", s.mute, func(v): setting("mute", v))
	number(a, "Master volume", s.volume, 0, 1, .05, func(v): setting("volume", v))
	number(a, "Engine volume", s.engine_volume, 0, 1, .05, func(v): setting("engine_volume", v))
	number(a, "Tires / road / impacts", s.effects_volume, 0, 1, .05, func(v): setting("effects_volume", v))


func update_mapping_labels() -> void:
	for entry in mappings:
		if is_instance_valid(entry[0]):
			entry[0].text = (
				"Press input…"
				if app.controls.listening == entry[1] and app.controls.listen_pad == entry[2]
				else app.controls.binding_text(entry[1], entry[2])
			)
