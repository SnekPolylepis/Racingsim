extends CanvasLayer
## Native toolbar, modal screens and dialog helpers; calls game.gd for application actions.
## Instruments is a child Control of root. Modals/dialog counts block custom physics.
## The player handbook is loaded from docs/PLAYER-GUIDE.md, which must be included in export.
var app
var root: Control
var blocker: ColorRect
var modal: PanelContainer
var content: VBoxContainer
var title_label: Label
var status: Label
var track_picker: OptionButton
var car_picker: OptionButton
var dialogs = 0
var screen = ""
var garage_before = ""
var mapping_buttons = []
var main_menu: Control
var pause_menu: Control
var menu_track: OptionButton
var menu_car: OptionButton
var menu_best: Label
var menu_first: Button
var pause_first: Button
var pause_info: Label
var selection_bars = []


func style(color = "11242e", border = "2b424f", radius = 8):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color)
	s.border_color = Color(border)
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	return s


func panel(parent):
	var node = PanelContainer.new()
	parent.add_child(node)
	node.add_theme_stylebox_override("panel", style())
	return node


func label(parent, value, font_size = 17, color = Color("e5eef0")):
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override(
		"font_size", maxi(32, font_size * 2) if app and app.frontend else font_size
	)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func wrapped(parent, value, color = Color("9ab1bd")):
	var l = label(parent, value, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func button(parent, value, action):
	var b = Button.new()
	b.text = value
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = 52 if app and app.frontend else 34
	parent.add_child(b)
	b.pressed.connect(action)
	return b


func row(parent):
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	return r


func clear(parent):
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func number(parent, caption, value, low, high, step, action):
	var r = row(parent)
	var l = label(r, caption, 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 168 if app.frontend else 108
	r.add_child(spin)
	spin.value_changed.connect(action)
	return spin


func choice(parent, caption, values, selected, action):
	var r = row(parent)
	var l = label(r, caption, 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p = OptionButton.new()
	p.focus_mode = Control.FOCUS_ALL
	p.custom_minimum_size.x = 250 if app.frontend else 160
	r.add_child(p)
	for v in values:
		p.add_item(v)
	p.select(maxi(0, selected))
	p.item_selected.connect(action)
	return p


func check(parent, caption, enabled, action):
	var b = CheckBox.new()
	b.text = caption
	b.button_pressed = enabled
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.toggled.connect(action)
	return b


func section(parent, name):
	label(parent, "\n" + name.to_upper(), 14, Color("e7c67e"))


func initialize(owner_app):
	app = owner_app
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/Rajdhani-Medium.ttf")
	theme.default_font_size = 16
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, style("1b303c", "334d5b", 5))
		theme.set_stylebox("hover", type, style("294756", "6ba8b7", 5))
		theme.set_stylebox("focus", type, style("294756", "e7c67e", 5))
		theme.set_stylebox("pressed", type, style("315967", "8ec3cf", 5))
		theme.set_color("font_color", type, Color("e4eef0"))
	theme.set_stylebox("panel", "PopupMenu", style())
	root.theme = theme
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var box_style = theme.get_stylebox(state, type)
			box_style.content_margin_top = 6
			box_style.content_margin_bottom = 6
	app.instruments = app.Instruments.new()
	root.add_child(app.instruments)
	app.instruments.initialize(app)
	track_picker = OptionButton.new()
	track_picker.focus_mode = Control.FOCUS_NONE
	track_picker.item_selected.connect(app.load_track)
	car_picker = OptionButton.new()
	car_picker.focus_mode = Control.FOCUS_NONE
	for key in app.presets:
		car_picker.add_item(app.presets[key].name)
	car_picker.item_selected.connect(func(i): app.change_car(app.presets.keys()[i]))
	status = label(root, "", 14)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 20
	status.offset_top = -36
	status.offset_right = -20
	status.clip_text = true
	build_menus()
	blocker = ColorRect.new()
	root.add_child(blocker)
	blocker.color = Color(0, .015, .025, .72)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.visible = false
	modal = panel(blocker)
	var body = VBoxContainer.new()
	modal.add_child(body)
	var header = row(body)
	title_label = label(header, "", 24, Color("f3cd7a"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "Close · Esc", close)
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	root.resized.connect(layout)
	layout()


## Title screen and pause menu. Visibility is driven every frame by sync_menus() from game.gd state
## (in_menu / paused), so code that sets app.paused directly still shows the right overlay.
## Buttons here take keyboard/controller focus (arrows or D-pad + Enter/A), unlike toolbar buttons.
func menu_button(parent, value, action, primary = false):
	var b = button(parent, value, action)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(340, 50 if primary else 44)
	b.add_theme_font_size_override("font_size", 21 if primary else 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bar = ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = Color("f3cd7a")
	bar.position = Vector2(0, 4)
	bar.size = Vector2(5, 36)
	b.add_child(bar)
	selection_bars.append([b, bar])
	if primary:
		b.add_theme_stylebox_override("normal", style("17566a", "47e4ed", 3))
		b.add_theme_stylebox_override("hover", style("246d83", "e3fbef", 3))
		b.add_theme_stylebox_override("focus", style("246d83", "ffffff", 3))
	return b


func build_menus():
	main_menu = Control.new()
	main_menu.name = "MainMenu"
	root.add_child(main_menu)
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.visible = false
	var shade = ColorRect.new()
	shade.color = Color(.02, .05, .07, .86)
	main_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 560
	var edge = ColorRect.new()
	edge.color = Color("42d4e0")
	main_menu.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 560
	edge.offset_right = 563
	var col = VBoxContainer.new()
	main_menu.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 70
	col.offset_right = 500
	col.offset_top = 52
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 10)
	label(col, "RACING SIM", 60, Color("e8ecdd"))
	label(col, "C I R C U I T   C L U B", 26, Color("4ce5e9"))
	label(col, "AFTERNOON TO AFTERHOURS  /  TIME ATTACK", 15, Color("9ab1bd"))
	var gap = Control.new()
	gap.custom_minimum_size.y = 26
	col.add_child(gap)
	label(col, "CIRCUIT", 12, Color("9ab1bd"))
	menu_track = OptionButton.new()
	menu_track.focus_mode = Control.FOCUS_ALL
	menu_track.custom_minimum_size = Vector2(340, 40)
	col.add_child(menu_track)
	menu_track.item_selected.connect(func(i): app.load_track(i))
	label(col, "CAR", 12, Color("9ab1bd"))
	menu_car = OptionButton.new()
	menu_car.focus_mode = Control.FOCUS_ALL
	menu_car.custom_minimum_size = Vector2(340, 40)
	col.add_child(menu_car)
	for key in app.presets:
		menu_car.add_item(app.presets[key].name)
	menu_car.item_selected.connect(func(i): app.change_car(app.presets.keys()[i]))
	menu_best = label(col, "", 15, Color("e7c67e"))
	gap = Control.new()
	gap.custom_minimum_size.y = 16
	col.add_child(gap)
	menu_first = menu_button(col, "Drive", app.start_drive, true)
	menu_button(col, "Garage", open_garage)
	menu_button(col, "Circuit library", open_library)
	menu_button(col, "Settings", open_settings)
	menu_button(col, "Help", open_help)
	menu_button(col, "Quit game", app.request_quit)
	var foot = Control.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(foot)
	label(col, "Arrows / D-pad and Enter / A to choose  ·  Esc pauses while driving", 12, Color("6f8894"))

	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	root.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	var dim = ColorRect.new()
	dim.color = Color(0, .02, .03, .55)
	pause_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	pause_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card = panel(center)
	card.custom_minimum_size = Vector2(400, 0)
	var list = VBoxContainer.new()
	card.add_child(list)
	list.add_theme_constant_override("separation", 8)
	label(list, "PAUSED", 34, Color("f3cd7a"))
	pause_info = label(list, "", 14, Color("9ab1bd"))
	gap = Control.new()
	gap.custom_minimum_size.y = 8
	list.add_child(gap)
	pause_first = menu_button(list, "Resume", func(): app.set_paused(false), true)
	menu_button(
		list,
		"Restart run",
		func():
			app.reset_car()
			app.set_paused(false)
	)
	menu_button(list, "Garage", open_garage)
	menu_button(list, "Settings", open_settings)
	menu_button(list, "Help", open_help)
	menu_button(list, "Main menu", app.show_main_menu)
	menu_button(list, "Quit game", app.request_quit)


## Called each frame by game.gd. Refreshes pickers and grabs focus when an overlay first appears.
func sync_menus():
	if app.frontend:
		main_menu.visible = false
		pause_menu.visible = false
		app.instruments.visible = app.frontend.page == "drive"
		return
	for item in selection_bars:
		item[1].visible = item[0].has_focus()
		item[1].modulate.a = .65 + .35 * sin(Time.get_ticks_msec() * .006)
		item[1].size.y = item[0].size.y - 8
	var show_main = app.in_menu
	var show_pause = app.paused and not app.in_menu
	status.visible = not app.in_menu
	app.instruments.visible = not app.in_menu
	if show_main and not main_menu.visible:
		menu_track.clear()
		for i in track_picker.item_count:
			menu_track.add_item(track_picker.get_item_text(i))
		menu_track.select(track_picker.selected)
		menu_car.select(app.presets.keys().find(app.preset_key))
	if show_main:
		menu_best.text = (
			"Best lap  " + app.RaceModel.time_text(app.race.best)
			if app.race.best > 0
			else "No best lap yet for this car and setup"
		)
	if show_pause:
		pause_info.text = "%s  ·  %s" % [app.track.data.name, app.car.p.name]
	var grab = (show_main and not main_menu.visible) or (show_pause and not pause_menu.visible)
	main_menu.visible = show_main
	pause_menu.visible = show_pause
	if grab and not is_open():
		(menu_first if show_main else pause_first).grab_focus()


func layout():
	var viewport = root.size
	modal.size = Vector2(minf(920, viewport.x - 48), minf(740, viewport.y - 52))
	modal.position = (viewport - modal.size) / 2


func open(title, key):
	if screen == "garage" and key != "garage":
		apply_garage()
	app.controls.clear()
	clear(content)
	screen = key
	title_label.text = title
	if app.frontend:
		title_label.add_theme_font_size_override("font_size", 40)
	blocker.visible = true
	layout()
	if app.frontend:
		var close_button = modal.find_children("*", "Button", true, false)
		if not close_button.is_empty():
			close_button[0].grab_focus()


func close():
	if not app.controls.listening.is_empty():
		app.controls.listening = ""
		update_mapping_labels()
		return
	if screen == "garage":
		apply_garage()
	blocker.visible = false
	screen = ""
	app.controls.clear()
	if app.frontend and not app.frontend.buttons.is_empty():
		app.frontend.call_deferred("focus_first")


func is_open():
	return blocker.visible or dialogs > 0


func apply_garage():
	if garage_before != JSON.stringify(app.car.setup):
		app.reset_car()
		app.load_record()
	garage_before = JSON.stringify(app.car.setup)


func confirm(title, description, action):
	dialogs += 1
	app.controls.clear()
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = description
	add_child(dialog)
	dialog.confirmed.connect(
		func():
			dialogs -= 1
			dialog.queue_free()
			action.call()
	)
	dialog.canceled.connect(
		func():
			dialogs -= 1
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(450, 150))


func ask_name(title, value, action):
	dialogs += 1
	app.controls.clear()
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	var entry = LineEdit.new()
	entry.text = value
	entry.custom_minimum_size = Vector2(390, 40)
	dialog.add_child(entry)
	add_child(dialog)
	dialog.confirmed.connect(
		func():
			var result = entry.text.strip_edges()
			dialogs -= 1
			dialog.queue_free()
			if not result.is_empty():
				action.call(result)
	)
	dialog.canceled.connect(
		func():
			dialogs -= 1
			dialog.queue_free()
	)
	entry.text_submitted.connect(func(_v): dialog.confirmed.emit())
	dialog.popup_centered(Vector2i(440, 125))
	entry.grab_focus()
	entry.select_all()


func open_garage():
	if screen != "garage":
		garage_before = JSON.stringify(app.car.setup)
	open("Garage / setup", "garage")
	var toolbar = row(content)
	button(toolbar, "Save as…", func(): ask_name("Setup name", app.car.p.name, app.save_setup))
	button(toolbar, "Import JSON…", func(): app.choose_file("setup", false))
	button(toolbar, "Export JSON…", func(): app.choose_file("setup", true))
	button(
		toolbar,
		"Defaults",
		func():
			app.car.setup = app.car.p.setup.duplicate(true)
			open_garage()
	)
	var files = app.storage.list_files("setups")
	if not files.is_empty():
		var line = row(content)
		var list = OptionButton.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(list)
		for path in files:
			list.add_item(path.get_file().get_basename())
		button(line, "Load", func(): app.import_setup(files[list.selected]))
		button(
			line,
			"Delete",
			func():
				confirm(
					"Delete setup",
					"Delete " + files[list.selected].get_file() + "?",
					func():
						app.delete_file(files[list.selected])
						open_garage()
				)
		)
	var tabs = TabContainer.new()
	tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	tabs.custom_minimum_size.y = 450
	content.add_child(tabs)
	var groups = {}
	for field in app.setup_fields:
		if not groups.has(field[0]):
			var scroll = ScrollContainer.new()
			scroll.name = field[0]
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			tabs.add_child(scroll)
			var group = VBoxContainer.new()
			group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group.add_theme_constant_override("separation", 10)
			scroll.add_child(group)
			groups[field[0]] = group
		if field[0] == "Aids":
			continue
		var caption = field[2] + (" (" + field[6] + ")" if field[6] != "" else "")
		number(
			groups[field[0]],
			caption,
			app.car.setup[field[1]],
			field[3],
			field[4],
			field[5],
			func(v): app.car.setup[field[1]] = v
		)
	number(groups.Aids, "TCS · traction control", app.car.tcs_level(), 0, 10, 1, func(v): app.car.set_tcs(v))
	number(
		groups.Aids,
		"ASM · stability management",
		app.car.asm_level(),
		0,
		10,
		1,
		func(v): app.car.setup.asmLevel = v
	)
	check(groups.Aids, "ABS", app.car.setup.absOn > .5, func(v): app.car.setup.absOn = 1.0 if v else 0.0)
	wrapped(
		groups.Aids,
		"0 disables the aid. Higher TCS trims wheelspin earlier; higher ASM applies selective braking and reduces torque when the car departs from your intended turn."
	)
	wrapped(
		content,
		"Changes take effect when you close the garage. A changed setup starts a fresh run and loads its own best lap."
	)


func open_library():
	open("Circuit library", "library")
	app.refresh_tracks()
	wrapped(content, "Storage: " + ProjectSettings.globalize_path(app.storage.root))
	var actions = row(content)
	button(actions, "Local saves", app.use_local_storage)
	button(actions, "Rescan", open_library)
	var files = app.track_files.duplicate()
	for file in files:
		var r = row(content)
		var name = file.get_file().get_basename()
		var l = label(r, name, 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(r, "Load", func(): app.request_track_file(file))
	section(content, "Best lap / ghost")
	var ghost_row = row(content)
	button(ghost_row, "Import ghost…", func(): app.choose_file("ghost", false))
	button(ghost_row, "Export ghost…", func(): app.choose_file("ghost", true))
	button(
		ghost_row,
		"Clear best lap",
		func():
			confirm(
				"Clear best lap",
				"Remove the saved best lap for this circuit, car and setup?",
				app.clear_ghost
			)
	)


func setting(key, value):
	var changed = app.settings[key] != value
	app.settings[key] = value
	app.apply_settings()
	app.save_settings()
	if changed and key in ["wear", "off_track", "contact", "handling_model"]:
		app.reset_car()
		app.load_record()


func open_settings():
	open("Settings", "settings")
	var s = app.settings
	var tabs = TabContainer.new()
	tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	tabs.custom_minimum_size.y = 530
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var groups = {}
	for name in ["Display", "Driving", "Controls", "Audio"]:
		var scroll = ScrollContainer.new()
		scroll.name = name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 12)
		scroll.add_child(box)
		groups[name] = box
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
	check(d, "Vehicle debug overlay · B", s.debug, func(v): setting("debug", v))
	check(d, "10-second telemetry graph · Y", s.telemetry, func(v): setting("telemetry", v))
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
	check(d, "Native resolution MSAA 2x", s.native_msaa, func(v): setting("native_msaa", v))
	choice(d, "Graphics quality", ["Low", "Medium", "High"], s.quality, func(v): setting("quality", v))
	check(d, "Adaptive quality", s.adaptive, func(v): setting("adaptive", v))
	check(d, "Fullscreen · F11", s.fullscreen, func(v): setting("fullscreen", v))
	var r = groups.Driving
	number(
		r,
		"TCS",
		app.car.tcs_level(),
		0,
		10,
		1,
		func(v):
			app.car.set_tcs(v)
			app.reset_car()
			app.load_record()
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
			app.reset_car()
			app.load_record()
	)
	check(
		r,
		"ABS",
		app.car.setup.absOn > .5,
		func(v):
			app.car.setup.absOn = 1.0 if v else 0.0
			app.reset_car()
			app.load_record()
	)
	choice(
		r,
		"Handling model",
		["Simcade", "Simulation"],
		s.handling_model,
		func(v): setting("handling_model", v)
	)
	check(
		r, "Invalidate lap when all four tires leave the road", s.off_track, func(v): setting("off_track", v)
	)
	check(r, "Invalidate lap on barrier contact", s.contact, func(v): setting("contact", v))
	check(r, "Tire wear", s.wear, func(v): setting("wear", v))
	check(r, "Show best-lap ghost", s.ghost, func(v): setting("ghost", v))
	check(r, "Automatic gearbox · M", s.automatic, func(v): setting("automatic", v))
	check(r, "Automatic clutch in manual mode", s.auto_clutch, func(v): setting("auto_clutch", v))
	var c = groups.Controls
	check(
		c, "Simcade steering grip assist", s.simcade_grip_assist, func(v): setting("simcade_grip_assist", v)
	)
	var ids = Input.get_connected_joypads()
	wrapped(c, "Controller: " + ("not connected" if ids.is_empty() else Input.get_joy_name(ids[0])))
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
	wrapped(
		c,
		"Speed-sensitive steering reduces steering lock as speed rises. 1 halves lock at 50 km/h (the original feel); 0 turns it off for full lock at any speed."
	)
	check(c, "Steering grip assist · controller", s.steer_grip_pad, func(v): setting("steer_grip_pad", v))
	check(c, "Steering grip assist · keyboard", s.steer_grip_kb, func(v): setting("steer_grip_kb", v))
	wrapped(
		c,
		"Grip assist stops you steering the front tyres far past their peak grip, the way a sim wheel's force feedback would warn you. It never limits countersteer."
	)
	wrapped(
		c,
		"Click a binding, then press a key, button or move an axis. Esc cancels. Steering uses a signed axis; pedals use positive trigger travel."
	)
	mapping_buttons = []
	for action in [
		"throttle", "brake", "left", "right", "steer", "clutch", "handbrake", "shiftUp", "shiftDown", "reset"
	]:
		var line = row(c)
		var caption = label(line, action.capitalize(), 15)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for is_pad in [false, true]:
			if (action == "steer" and not is_pad) or (action in ["left", "right"] and is_pad):
				continue
			var b = button(
				line,
				app.controls.binding_text(action, is_pad),
				func():
					app.controls.listening = action
					app.controls.listen_pad = is_pad
					update_mapping_labels()
			)
			b.custom_minimum_size.x = 170
			mapping_buttons.append([b, action, is_pad])
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
	wrapped(
		a,
		"Procedural engine harmonics follow RPM and throttle. Tire squeal follows slip; gravel, shifts and impacts have separate effects. Sound fades out in menus and while paused."
	)


func update_mapping_labels():
	for item in mapping_buttons:
		if not is_instance_valid(item[0]):
			continue
		item[0].text = (
			"Press input…"
			if app.controls.listening == item[1] and app.controls.listen_pad == item[2]
			else app.controls.binding_text(item[1], item[2])
		)


## Render the packaged handbook by chapter. The Markdown file is the single source
## for player help; only level-two headings and plain paragraph text are supported.
func open_help():
	open("Player handbook", "help")
	var source = FileAccess.get_file_as_string("res://docs/PLAYER-GUIDE.md")
	var chapters = []
	for chunk in source.split("\n## ").slice(1):
		var newline = chunk.find("\n")
		if newline > 0:
			chapters.append([chunk.left(newline).strip_edges(), chunk.substr(newline + 1).strip_edges()])
	if chapters.is_empty():
		wrapped(
			content,
			"The player handbook could not be loaded. See godot/docs/PLAYER-GUIDE.md in the source project."
		)
		return
	var names = []
	for chapter in chapters:
		names.append(chapter[0])
	var picker = choice(content, "Chapter", names, 0, func(index): show_help_chapter(index, chapters))
	picker.name = "HelpChapters"
	var body = VBoxContainer.new()
	body.name = "HelpBody"
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	show_help_chapter(0, chapters)


## Rebuild only the chapter body so selection/navigation remain available.
func show_help_chapter(index, chapters):
	var body = content.get_node("HelpBody")
	clear(body)
	label(body, chapters[index][0], 22, Color("f3cd7a"))
	for paragraph in chapters[index][1].split("\n\n", false):
		wrapped(body, paragraph, Color("d4e2e7"))
	content.get_parent().scroll_vertical = 0
