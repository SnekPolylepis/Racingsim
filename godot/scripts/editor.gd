extends Control
## Native 2D circuit canvas and document transactions, separate from 3D rendering.
## Every undoable mutation begins with a deep snapshot and ends with commit_change.
## Drag release is also handled globally to finish strokes released over side panels.
## Rebuild spline while dragging geometry; rebuild the 3D world only on drive transitions.
var app
var tool = "select"
var selection = {}
var undo_stack = []
var redo_stack = []
var saved = ""
var dirty = false
var center = Vector2.ZERO
var zoom = 1.0
var snap_enabled = false
var snap_size = 5.0
var brush = 6.0
var gesture = ""
var before = {}
var origin = Vector2.ZERO
var last_world = Vector2.ZERO
var original = {}
var hover = Vector2.ZERO
var drag_handle = 0
var props: VBoxContainer
var tools_panel: PanelContainer
var props_panel: PanelContainer
var buttons = {}
var validation = {"errors": [], "warnings": []}
var refresh_pending = false
const TOOLS = [
	["select", "1  Select / move"],
	["insert", "2  Insert point"],
	["curb", "3  Curb override"],
	["grass", "4  Paint grass"],
	["gravel", "5  Paint gravel"],
	["runoff", "Paint tarmac runoff"],
	["erase", "6  Erase paint"],
	["wall", "7  Wall"],
	["tire", "8  Tire barrier"],
	["cone", "9  Cone"],
	["start", "0  Start / finish"],
	["grid", "Grid position"],
	["pan", "Pan"]
]


func initialize(owner_app):
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	tools_panel = app.ui.panel(self)
	tools_panel.position = Vector2(16, 118)
	tools_panel.custom_minimum_size = Vector2(208, 0)
	var scroll = ScrollContainer.new()
	tools_panel.add_child(scroll)
	scroll.custom_minimum_size = Vector2(188, 610)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	app.ui.label(list, "CIRCUIT TOOLS", 15)
	for item in TOOLS:
		buttons[item[0]] = app.ui.button(list, item[1], func(): set_tool(item[0]))
	var row = HBoxContainer.new()
	list.add_child(row)
	app.ui.button(row, "Undo", undo)
	app.ui.button(row, "Redo", redo)
	app.ui.button(list, "Delete selected", delete_selected)
	app.ui.button(list, "Frame circuit · F", frame_track)
	app.ui.button(
		list,
		"Height profile · H",
		func():
			show_profile = not show_profile
			frame_track()
	)
	app.ui.button(list, "Import real circuit…", func(): app.choose_outline())
	app.ui.button(list, "Test drive · T", func(): app.set_editor(false))
	app.ui.button(list, "Save · Ctrl+S", app.save_track)
	app.ui.button(list, "New circuit", app.new_track)
	props_panel = app.ui.panel(self)
	props_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	props_panel.position = Vector2(-312, 118)
	props_panel.custom_minimum_size = Vector2(296, 0)
	var ps = ScrollContainer.new()
	ps.custom_minimum_size = Vector2(266, 610)
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	props_panel.add_child(ps)
	props = VBoxContainer.new()
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ps.add_child(props)
	resized.connect(
		func():
			layout_panels()
			queue_redraw()
	)
	set_tool("select")


func layout_panels():
	var height = maxf(220, size.y - 180)
	tools_panel.get_child(0).custom_minimum_size.y = height
	props_panel.get_child(0).custom_minimum_size.y = height
	tools_panel.size = Vector2(212, height + 24)
	props_panel.size = Vector2(296, height + 24)
	props_panel.position = Vector2(size.x - 312, 118)


func canvas_rect():
	return Rect2(
		Vector2(238, 118),
		Vector2(maxf(150, size.x - 568), maxf(150, size.y - 166 - (158 if show_profile else 0)))
	)


func to_screen(v):
	return canvas_rect().get_center() + (v - center) * zoom


func to_world(v):
	return center + (v - canvas_rect().get_center()) / zoom


func snap_point(v):
	return (
		v.snapped(Vector2.ONE * snap_size) if snap_enabled or Input.is_physical_key_pressed(KEY_SHIFT) else v
	)


func point2(p):
	return Vector2(p.x, p.y)


func reset_document():
	selection = {}
	undo_stack.clear()
	redo_stack.clear()
	saved = JSON.stringify(app.track.data)
	dirty = false
	gesture = ""
	validate()
	refresh_props()
	frame_track()


func mark_saved():
	saved = JSON.stringify(app.track.data)
	dirty = false
	refresh_props()


func validate():
	validation = app.track.validate()


func frame_track():
	var points = app.track.data.points
	if points.is_empty():
		center = Vector2.ZERO
		zoom = 2
		queue_redraw()
		return
	var low = point2(points[0])
	var high = low
	for p in points:
		low = low.min(point2(p))
		high = high.max(point2(p))
	var rect = canvas_rect()
	center = (low + high) / 2
	zoom = clampf(
		minf(rect.size.x / maxf(80, high.x - low.x + 50), rect.size.y / maxf(80, high.y - low.y + 50)),
		.025,
		30
	)
	queue_redraw()


func set_tool(value):
	finish_gesture()
	tool = value
	for k in buttons:
		buttons[k].modulate = Color("73d6d1") if k == tool else Color.WHITE
	if app:
		app.message(
			(
				"%s · %s"
				% [
					value.capitalize(),
					(
						"Drag to paint"
						if value in ["grass", "gravel", "runoff", "erase"]
						else "Click or drag in the circuit workspace"
					)
				]
			)
		)
	queue_redraw()


## Capture pre-edit state before any mutation; one gesture should produce one undo entry.
func begin_change():
	before = app.track.data.duplicate(true)


## Commit a transaction, recompute dirty state, optionally rebuild geometry and refresh UI.
func commit_change(rebuild = true):
	if not before.is_empty() and JSON.stringify(before) != JSON.stringify(app.track.data):
		undo_stack.append(before)
		if undo_stack.size() > 80:
			undo_stack.pop_front()
		redo_stack.clear()
		dirty = JSON.stringify(app.track.data) != saved
	before = {}
	if rebuild:
		app.track.rebuild()
	validate()
	refresh_props()
	queue_redraw()


func restore(d):
	app.track.load_data(d)
	selection = {}
	dirty = JSON.stringify(app.track.data) != saved
	validate()
	refresh_props()
	queue_redraw()


func undo():
	finish_gesture()
	if undo_stack.is_empty():
		return
	redo_stack.append(app.track.data.duplicate(true))
	restore(undo_stack.pop_back())


func redo():
	finish_gesture()
	if redo_stack.is_empty():
		return
	undo_stack.append(app.track.data.duplicate(true))
	restore(redo_stack.pop_back())


func refresh_props():
	if refresh_pending or app == null:
		return
	refresh_pending = true
	call_deferred("build_props")


func build_props():
	refresh_pending = false
	if not is_instance_valid(props):
		return
	app.ui.clear(props)
	app.ui.label(props, "PROPERTIES" + ("  • unsaved" if dirty else ""), 15)
	var name = LineEdit.new()
	name.text = app.track.data.name
	name.placeholder_text = "Circuit name"
	props.add_child(name)
	name.text_submitted.connect(func(v): rename_track(v))
	name.focus_exited.connect(func(): rename_track(name.text))
	app.ui.label(props, "%d points   ·   %.0f m" % [app.track.data.points.size(), app.track.length], 15)
	app.ui.check(
		props,
		"Automatic curbs",
		app.track.data.curbAuto,
		func(v):
			begin_change()
			app.track.data.curbAuto = v
			commit_change()
	)
	app.ui.check(
		props,
		"Automatic trackside barriers",
		app.track.data.get("autoBarriers", true),
		func(v):
			begin_change()
			app.track.data.autoBarriers = v
			commit_change(false)
	)
	app.ui.check(props, "Snap to grid (or hold Shift)", snap_enabled, func(v): snap_enabled = v)
	app.ui.number(props, "Grid spacing", snap_size, 1, 20, 1, func(v): snap_size = v)
	app.ui.number(
		props,
		"Brush radius",
		brush,
		2,
		30,
		1,
		func(v):
			brush = v
			queue_redraw()
	)
	if app.track.data.points.size() >= 3:
		app.ui.button(props, "Reverse direction", reverse_direction)
		app.ui.button(props, "Smooth heights", smooth_heights)
		var all_w = app.ui.number(
			props, "Width, all points (m)", app.track.data.points[0].w, 4, 40, .5, func(_v): pass
		)
		all_w.get_line_edit().text_submitted.connect(func(_t): set_all_widths(all_w.value))
		app.ui.button(props, "Apply width to all points", func(): set_all_widths(all_w.value))
	for error in validation.errors:
		app.ui.wrapped(props, error, Color("ff9788"))
	for warning in validation.warnings:
		app.ui.wrapped(props, warning, Color("e9c46c"))
	if validation.errors.is_empty() and validation.warnings.is_empty():
		app.ui.wrapped(props, "Circuit ready to drive", Color("73d6b0"))
	if selection.get("kind") == "point":
		var p = app.track.data.points[selection.index]
		app.ui.label(props, "POINT " + str(selection.index + 1), 16)
		for field in [
			["x", "X (m)", -10000, 10000, .5],
			["y", "Y (m)", -10000, 10000, .5],
			["w", "Width (m)", 4, 40, .5],
			["z", "Height (m)", -60, 60, .5],
			["bank", "Bank (°)", -20, 20, .5]
		]:
			app.ui.number(
				props, field[1], p[field[0]], field[2], field[3], field[4], func(v): change_point(field[0], v)
			)
		app.ui.button(
			props,
			"Insert after point",
			func():
				insert_at(
					selection.index,
					(
						(
							point2(p)
							+ point2(
								app.track.data.points[(selection.index + 1) % app.track.data.points.size()]
							)
						)
						/ 2
					)
				)
		)
	if selection.get("kind") == "segment":
		app.ui.label(props, "SEGMENT " + str(selection.index + 1), 16)
		app.ui.choice(
			props,
			"Curbs",
			["Automatic", "On", "Off"],
			["auto", "on", "off"].find(app.track.data.curbOverride.get(str(selection.index), "auto")),
			func(index):
				begin_change()
				set_curb(selection.index, ["auto", "on", "off"][index])
				commit_change()
		)
	if selection.get("kind") == "object":
		var o = app.track.data.objects[selection.index]
		app.ui.label(props, o.type.to_upper(), 16)
		for k in ["x", "y"] if o.type == "cone" else ["x1", "y1", "x2", "y2"]:
			app.ui.number(
				props,
				k.to_upper(),
				o[k],
				-10000,
				10000,
				.5,
				func(v):
					begin_change()
					o[k] = v
					if o.type == "cone":
						o.ox = o.x
						o.oy = o.y
					commit_change(false)
			)
	(
		app
		. ui
		. wrapped(
			props,
			"Drag points to reshape. Double-click an edge to insert. Drag barrier endpoints to resize.\n\nCtrl+Z undo · Ctrl+Shift+Z redo\n[ / ] width · , / . height\n; / ' banking · Delete remove",
			Color("94aab5")
		)
	)
	call_deferred("layout_panels")


func rename_track(value):
	if value.strip_edges().is_empty() or value == app.track.data.name:
		return
	begin_change()
	app.track.data.name = value.strip_edges()
	commit_change(false)


func change_point(field, value):
	if selection.get("kind") != "point":
		return
	begin_change()
	app.track.data.points[selection.index][field] = value
	commit_change()


func set_curb(index, value):
	if value == "auto":
		app.track.data.curbOverride.erase(str(index))
	else:
		app.track.data.curbOverride[str(index)] = value


## Keep string curb segment indices aligned when a control point is inserted or deleted.
func shift_overrides(index, delta):
	var out = {}
	for k in app.track.data.curbOverride:
		var i = int(k)
		if delta < 0 and i == index:
			continue
		out[str(i + delta if i >= index else i)] = app.track.data.curbOverride[k]
	app.track.data.curbOverride = out


func insert_at(index, v):
	begin_change()
	var points = app.track.data.points
	var p = {"x": v.x, "y": v.y, "w": 12.0, "z": 0.0, "bank": 0.0}
	if not points.is_empty():
		var a = points[index]
		var b = points[(index + 1) % points.size()]
		for k in ["w", "z", "bank"]:
			p[k] = (a[k] + b[k]) / 2
	shift_overrides(index + 1, 1)
	points.insert(index + 1, p)
	selection = {"kind": "point", "index": index + 1}
	commit_change()


func delete_selected():
	if selection.is_empty():
		return
	begin_change()
	if selection.kind == "point":
		shift_overrides(selection.index, -1)
		app.track.data.points.remove_at(selection.index)
	elif selection.kind == "object":
		app.track.data.objects.remove_at(selection.index)
	elif selection.kind == "segment":
		set_curb(selection.index, "off")
	selection = {}
	commit_change()


func hit(screen):
	var points = app.track.data.points
	for i in points.size():
		if to_screen(point2(points[i])).distance_to(screen) < 11:
			return {"kind": "point", "index": i}
	for i in app.track.data.objects.size():
		var o = app.track.data.objects[i]
		if o.type == "cone":
			if to_screen(point2(o)).distance_to(screen) < 11:
				return {"kind": "object", "index": i, "handle": 0}
		else:
			var a = to_screen(Vector2(o.x1, o.y1))
			var b = to_screen(Vector2(o.x2, o.y2))
			if a.distance_to(screen) < 10:
				return {"kind": "object", "index": i, "handle": 1}
			if b.distance_to(screen) < 10:
				return {"kind": "object", "index": i, "handle": 2}
			if Geometry2D.get_closest_point_to_segment(screen, a, b).distance_to(screen) < 8:
				return {"kind": "object", "index": i, "handle": 0}
	if not app.track.samples.is_empty():
		var w = to_world(screen)
		var pr = app.track.project(w.x, w.y)
		if absf(pr.lat) * zoom < maxf(14, pr.width * zoom / 2):
			return {"kind": "segment", "index": app.track.samples[pr.idx].seg}
	return {}


func press(screen, double_click = false):
	if show_profile and profile_rect().has_point(screen):
		var i = profile_hit(screen)
		if i >= 0:
			selection = {"kind": "point", "index": i}
			begin_change()
			gesture = "profile"
			refresh_props()
			queue_redraw()
		return
	if not canvas_rect().has_point(screen):
		return
	var v = snap_point(to_world(screen))
	origin = v
	last_world = v
	hover = screen
	if tool == "pan" or Input.is_physical_key_pressed(KEY_SPACE):
		gesture = "pan"
		return
	if double_click and not app.track.samples.is_empty():
		var pr = app.track.project(v.x, v.y)
		insert_at(app.track.samples[pr.idx].seg, Vector2(pr.px, pr.py))
		return
	if tool == "select":
		selection = hit(screen)
		refresh_props()
		if selection.is_empty() and app.track.data.points.size() < 3:
			insert_at(app.track.data.points.size() - 1, v)
			return
		if selection.get("kind") in ["point", "object"]:
			begin_change()
			gesture = selection.kind
			original = (
				(app.track.data.points if gesture == "point" else app.track.data.objects)[selection.index]
				. duplicate(true)
			)
			drag_handle = selection.get("handle", 0)
	elif tool == "insert":
		if app.track.samples.is_empty():
			insert_at(app.track.data.points.size() - 1, v)
		else:
			var pr = app.track.project(v.x, v.y)
			insert_at(app.track.samples[pr.idx].seg, Vector2(pr.px, pr.py))
	elif tool in ["curb", "start", "grid"]:
		if app.track.samples.is_empty():
			app.message("Add at least three points first")
			return
		begin_change()
		var pr = app.track.project(v.x, v.y)
		if tool == "curb":
			var index = app.track.samples[pr.idx].seg
			var old = app.track.data.curbOverride.get(str(index), "auto")
			set_curb(index, {"auto": "on", "on": "off", "off": "auto"}[old])
			selection = {"kind": "segment", "index": index}
		else:
			app.track.data["startS" if tool == "start" else "gridS"] = pr.s
		commit_change()
	elif tool in ["grass", "gravel", "runoff", "erase"]:
		begin_change()
		gesture = "paint"
		paint_at(v)
	elif tool in ["wall", "tire"]:
		begin_change()
		gesture = "create"
		app.track.data.objects.append({"type": tool, "x1": v.x, "y1": v.y, "x2": v.x, "y2": v.y})
		selection = {"kind": "object", "index": app.track.data.objects.size() - 1}
	elif tool == "cone":
		begin_change()
		app.track.data.objects.append({"type": "cone", "x": v.x, "y": v.y, "ox": v.x, "oy": v.y})
		selection = {"kind": "object", "index": app.track.data.objects.size() - 1}
		commit_change(false)
	queue_redraw()


func motion(screen, relative):
	hover = screen
	profile_hover_at(screen)
	if gesture == "pan":
		center -= relative / zoom
		queue_redraw()
		return
	if gesture == "profile":
		var z = clampf(profile_z(screen.y, profile_range()), -60, 60)
		z = snappedf(z, .5 if Input.is_physical_key_pressed(KEY_SHIFT) or snap_enabled else .1)
		app.track.data.points[selection.index].z = z
		app.track.rebuild()
		refresh_props()
		queue_redraw()
		return
	if show_profile and profile_rect().has_point(screen):
		queue_redraw()
	var v = snap_point(to_world(screen))
	if gesture == "point":
		var p = app.track.data.points[selection.index]
		var pos = snap_point(point2(original) + v - origin)
		p.x = pos.x
		p.y = pos.y
		app.track.rebuild()
	elif gesture == "object":
		var o = app.track.data.objects[selection.index]
		var delta = v - origin
		if o.type == "cone":
			o.x = original.x + delta.x
			o.y = original.y + delta.y
			o.ox = o.x
			o.oy = o.y
		else:
			for endpoint in [1, 2]:
				if drag_handle == 0 or drag_handle == endpoint:
					o["x" + str(endpoint)] = original["x" + str(endpoint)] + delta.x
					o["y" + str(endpoint)] = original["y" + str(endpoint)] + delta.y
	elif gesture == "create":
		var o = app.track.data.objects[selection.index]
		o.x2 = v.x
		o.y2 = v.y
	elif gesture == "paint":
		var distance = last_world.distance_to(v)
		var steps = maxi(1, ceili(distance / maxf(1, brush * .4)))
		for i in range(1, steps + 1):
			paint_at(last_world.lerp(v, float(i) / steps))
	last_world = v
	queue_redraw()


func paint_at(v):
	var radius = ceili(brush / 2)
	for x in range(floori(v.x / 2) - radius, floori(v.x / 2) + radius + 1):
		for y in range(floori(v.y / 2) - radius, floori(v.y / 2) + radius + 1):
			if Vector2(x * 2 + 1, y * 2 + 1).distance_to(v) > brush:
				continue
			var k = str(x) + "," + str(y)
			if tool == "erase":
				app.track.data.paint.erase(k)
			else:
				app.track.data.paint[k] = {"gravel": 2, "runoff": 3}.get(tool, 1)
	queue_redraw()


## Commit on pointer release even outside the canvas; discard zero-length barrier creation.
func finish_gesture():
	if gesture.is_empty():
		return
	if gesture == "create":
		var o = app.track.data.objects[selection.index]
		if Vector2(o.x2 - o.x1, o.y2 - o.y1).length() < .2:
			app.track.data.objects.remove_at(selection.index)
			selection = {}
	if gesture != "pan":
		commit_change(gesture in ["point", "profile"])
	gesture = ""
	queue_redraw()


func zoom_at(screen, factor):
	var before_pos = to_world(screen)
	zoom = clampf(zoom * factor, .025, 40)
	center += before_pos - to_world(screen)
	queue_redraw()


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			gesture = "pan" if event.pressed else ""
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press(event.position, event.double_click)
			else:
				finish_gesture()
		elif (
			event.pressed
			and (
				event.button_index
				in [
					MOUSE_BUTTON_WHEEL_UP,
					MOUSE_BUTTON_WHEEL_DOWN,
					MOUSE_BUTTON_WHEEL_LEFT,
					MOUSE_BUTTON_WHEEL_RIGHT
				]
			)
		):
			var sign_value = (
				1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else -1
			)
			if (
				app.settings.trackpad == 1
				and not (event.ctrl_pressed or event.is_command_or_control_pressed())
			):
				center += (
					(
						Vector2(-sign_value * 30, 0)
						if event.shift_pressed or event.button_index >= MOUSE_BUTTON_WHEEL_LEFT
						else Vector2(0, -sign_value * 30)
					)
					/ zoom
				)
				queue_redraw()
			else:
				zoom_at(event.position, pow(1.12, sign_value))
	elif event is InputEventMouseMotion:
		motion(event.position, event.relative)
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		center += event.delta * 12 / zoom
		queue_redraw()


func _input(event):
	# Release can land over a panel; still end the transaction and pointer capture.
	if (
		visible
		and event is InputEventMouseButton
		and not event.pressed
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]
	):
		finish_gesture()


func shortcut(event):
	if not event is InputEventKey or not event.pressed:
		return
	var code = event.physical_keycode
	if event.ctrl_pressed or event.is_command_or_control_pressed():
		if code == KEY_Z:
			redo() if event.shift_pressed else undo()
		elif code == KEY_Y:
			redo()
		elif code == KEY_S:
			app.save_track()
		return
	if code >= KEY_1 and code <= KEY_9:
		set_tool(
			["select", "insert", "curb", "grass", "gravel", "erase", "wall", "tire", "cone"][code - KEY_1]
		)
	elif code == KEY_0:
		set_tool("start")
	elif code in [KEY_DELETE, KEY_BACKSPACE]:
		delete_selected()
	elif code == KEY_F:
		frame_track()
	elif code == KEY_H:
		show_profile = not show_profile
		frame_track()
	elif code == KEY_T:
		app.set_editor(false)
	elif code in [KEY_EQUAL, KEY_PLUS, KEY_MINUS]:
		zoom_at(canvas_rect().get_center(), 1.2 if code != KEY_MINUS else 1 / 1.2)
	elif selection.get("kind") == "point":
		var p = app.track.data.points[selection.index]
		if code in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
			change_point("w", clampf(p.w + (-.5 if code == KEY_BRACKETLEFT else .5), 4, 40))
		elif code in [KEY_COMMA, KEY_PERIOD]:
			change_point(
				"z",
				clampf(p.z + (-1 if code == KEY_COMMA else 1) * (2.0 if event.shift_pressed else .5), -60, 60)
			)
		elif code in [KEY_SEMICOLON, KEY_APOSTROPHE]:
			change_point("bank", clampf(p.bank + (-.5 if code == KEY_SEMICOLON else .5), -20, 20))


func _draw():
	if app == null or not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("162629"))
	var rect = canvas_rect()
	var step = 5 if zoom > 5 else (20 if zoom > 1 else 100)
	var low = to_world(rect.position)
	var high = to_world(rect.end)
	for x in range(floori(low.x / step) * step, ceili(high.x), step):
		draw_line(to_screen(Vector2(x, low.y)), to_screen(Vector2(x, high.y)), Color("25393b"))
	for y in range(floori(low.y / step) * step, ceili(high.y), step):
		draw_line(to_screen(Vector2(low.x, y)), to_screen(Vector2(high.x, y)), Color("25393b"))
	for k in app.track.data.paint:
		var xy = k.split(",")
		var pos = to_screen(Vector2(float(xy[0]) * 2, float(xy[1]) * 2))
		if rect.grow(5).has_point(pos):
			draw_rect(
				Rect2(pos, Vector2.ONE * maxf(1, zoom * 2)),
				{2: Color("918c70"), 3: Color("5c6266")}.get(int(app.track.data.paint[k]), Color("496b4e"))
			)
	var S = app.track.samples
	for i in S.size():
		var a = S[i]
		var b = S[(i + 1) % S.size()]
		var av = point2(a)
		var bv = point2(b)
		var an = Vector2(a.nx, a.ny)
		var bn = Vector2(b.nx, b.ny)
		if not rect.grow(80).has_point(to_screen(av)):
			continue
		if a.curb:
			draw_road_quad(
				PackedVector2Array(
					[
						to_screen(av - an * (a.w / 2 + 1.4)),
						to_screen(bv - bn * (b.w / 2 + 1.4)),
						to_screen(bv + bn * (b.w / 2 + 1.4)),
						to_screen(av + an * (a.w / 2 + 1.4))
					]
				),
				Color("c66554") if int(a.s / 2.5) % 2 else Color("dce2d8")
			)
		var shade = clampf(.29 + a.grade * .8, .22, .42)
		draw_road_quad(
			PackedVector2Array(
				[
					to_screen(av - an * a.w / 2),
					to_screen(bv - bn * b.w / 2),
					to_screen(bv + bn * b.w / 2),
					to_screen(av + an * a.w / 2)
				]
			),
			Color(shade, shade + .035, shade + .04)
		)
	for o in app.track.data.objects:
		if o.type == "cone":
			draw_circle(to_screen(point2(o)), maxf(3, .3 * zoom), Color("f8a557"))
		else:
			draw_line(
				to_screen(Vector2(o.x1, o.y1)),
				to_screen(Vector2(o.x2, o.y2)),
				Color("b87c75") if o.type == "tire" else Color("a5bec8"),
				maxf(3, zoom * (1.2 if o.type == "tire" else .7))
			)
	for cs in app.track.checkpoints:
		draw_cross_line(cs, Color(.3, .7, .9, .4), 1)
	if app.track.data.startS != null:
		draw_cross_line(app.track.data.startS, Color("73e2b9"), 3)
	if not S.is_empty():
		var p = app.track.grid_pose()
		var pos = to_screen(point2(p))
		var direction = Vector2(cos(p.h), sin(p.h))
		draw_line(pos, pos + direction * 16, Color("f2c872"), 3)
		draw_circle(pos, 4, Color("f2c872"))
	var points = app.track.data.points
	for i in points.size():
		var p = points[i]
		var pos = to_screen(point2(p))
		if points.size() > 1:
			draw_line(pos, to_screen(point2(points[(i + 1) % points.size()])), Color(.6, .8, .85, .22))
		draw_circle(
			pos,
			7 if selection.get("kind") == "point" and selection.index == i else 5,
			Color("f5c96d") if selection.get("kind") == "point" and selection.index == i else Color("dce9e9")
		)
		if rect.has_point(pos):
			draw_string(
				ThemeDB.fallback_font,
				pos + Vector2(9, -9),
				"%d  %.1fm" % [i + 1, p.z],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color("b1c9cf")
			)
	if selection.get("kind") == "object":
		var o = app.track.data.objects[selection.index]
		for v in [point2(o)] if o.type == "cone" else [Vector2(o.x1, o.y1), Vector2(o.x2, o.y2)]:
			draw_arc(to_screen(v), 9, 0, TAU, 24, Color("f5c96d"), 2)
	if tool in ["grass", "gravel", "runoff", "erase"] and rect.has_point(hover):
		draw_arc(hover, brush * zoom, 0, TAU, 48, Color("f5c96d"), 1.5)
	if show_profile:
		draw_profile()


## Height profile strip under the canvas: elevation along the lap from the start line, coloured by
## grade (green < 6 %, amber < 12 %, red above). Control-point handles drag vertically to set height.
var show_profile = true
var profile_hover = -1.0


func profile_rect():
	var c = canvas_rect()
	return Rect2(Vector2(c.position.x, c.end.y + 10), Vector2(c.size.x, 138))


func profile_range():
	var zmin = INF
	var zmax = -INF
	for sm in app.track.samples:
		zmin = minf(zmin, sm.z)
		zmax = maxf(zmax, sm.z)
	for p in app.track.data.points:
		zmin = minf(zmin, p.z)
		zmax = maxf(zmax, p.z)
	if zmax - zmin < 6:
		var mid = (zmin + zmax) / 2
		zmin = mid - 3
		zmax = mid + 3
	var pad = (zmax - zmin) * .12
	return Vector2(zmin - pad, zmax + pad)


func profile_s(s):
	var start = float(app.track.data.startS) if app.track.data.startS != null else 0.0
	return fposmod(s - start, maxf(app.track.length, 1))


func profile_to_screen(s, z, range_z):
	var r = profile_rect().grow_individual(-44, -12, -12, -20)
	return Vector2(
		r.position.x + profile_s(s) / maxf(app.track.length, 1) * r.size.x,
		r.end.y - (z - range_z.x) / (range_z.y - range_z.x) * r.size.y
	)


func profile_z(screen_y, range_z):
	var r = profile_rect().grow_individual(-44, -12, -12, -20)
	return range_z.x + (r.end.y - screen_y) / r.size.y * (range_z.y - range_z.x)


## Arc distance of each control point (start of its spline segment).
func point_arcs():
	var arcs = {}
	for sm in app.track.samples:
		if not arcs.has(sm.seg):
			arcs[sm.seg] = sm.s
	return arcs


func profile_hit(screen):
	if app.track.samples.is_empty():
		return -1
	var rz = profile_range()
	var arcs = point_arcs()
	for i in app.track.data.points.size():
		if (
			arcs.has(i)
			and profile_to_screen(arcs[i], app.track.data.points[i].z, rz).distance_to(screen) < 10
		):
			return i
	return -1


func draw_profile():
	var r = profile_rect()
	draw_rect(r, Color("11201f"))
	draw_rect(r, Color("2b4245"), false, 1)
	if app.track.samples.size() < 2:
		draw_string(
			ThemeDB.fallback_font,
			r.position + Vector2(12, 24),
			"HEIGHT PROFILE · add at least three points",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("7f989f")
		)
		return
	var rz = profile_range()
	var S = app.track.samples
	var order = range(S.size())
	order.sort_custom(func(a, b): return profile_s(S[a].s) < profile_s(S[b].s))
	var plot = r.grow_individual(-44, -12, -12, -20)
	for k in 5:
		var z = lerpf(rz.x, rz.y, k / 4.0)
		var y = profile_to_screen(0, z, rz).y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, .06))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(r.position.x + 6, y + 4),
			"%.0f m" % (0.0 if absf(z) < .5 else z),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color("7f989f")
		)
	for k in range(1, order.size()):
		var a = S[order[k - 1]]
		var b = S[order[k]]
		var g = absf(a.grade)
		var col = Color("5fc88a") if g < .06 else (Color("e3b74d") if g < .12 else Color("e56b5d"))
		draw_line(profile_to_screen(a.s, a.z, rz), profile_to_screen(b.s, b.z, rz), col, 2, true)
	var arcs = point_arcs()
	for i in app.track.data.points.size():
		if not arcs.has(i):
			continue
		var pos = profile_to_screen(arcs[i], app.track.data.points[i].z, rz)
		var sel = selection.get("kind") == "point" and selection.index == i
		draw_circle(pos, 6 if sel else 4, Color("f5c96d") if sel else Color("dce9e9"))
	draw_string(
		ThemeDB.fallback_font,
		r.position + Vector2(46, 14),
		"HEIGHT PROFILE  ·  drag points up/down  ·  green < 6 %  amber < 12 %  red steeper",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("94aab5")
	)
	if profile_hover >= 0:
		var pr = app.track.pos_at(profile_hover)
		var el = app.track.elev_at(pr.x, pr.y)
		var pos = profile_to_screen(profile_hover, pr.z, rz)
		draw_line(Vector2(pos.x, plot.position.y), Vector2(pos.x, plot.end.y), Color(1, 1, 1, .25))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(minf(pos.x + 6, r.end.x - 150), plot.position.y + 12),
			"%.0f m · %.1f m · %+.1f %%" % [profile_s(profile_hover), pr.z, el.grade * 100],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color("e8f0f0")
		)


func profile_hover_at(screen):
	profile_hover = -1.0
	if not show_profile or app.track.samples.is_empty() or not profile_rect().has_point(screen):
		return
	var plot = profile_rect().grow_individual(-44, -12, -12, -20)
	var start = float(app.track.data.startS) if app.track.data.startS != null else 0.0
	profile_hover = fposmod(
		start + clampf((screen.x - plot.position.x) / plot.size.x, 0, 1) * app.track.length, app.track.length
	)


## Reverse driving direction: reverse control points, remap curb overrides and mirror start/grid.
func reverse_direction():
	if app.track.data.points.size() < 3:
		return
	begin_change()
	var n = app.track.data.points.size()
	var L = app.track.length
	var last = point_arcs().get(n - 1, 0.0)
	app.track.data.points.reverse()
	var out = {}
	for k in app.track.data.curbOverride:
		out[str(posmod(n - 2 - int(k), n))] = app.track.data.curbOverride[k]
	app.track.data.curbOverride = out
	for key in ["startS", "gridS"]:
		if app.track.data.get(key) != null:
			app.track.data[key] = fposmod(last - float(app.track.data[key]), L)
	for p in app.track.data.points:
		p.bank = -p.bank
	commit_change()
	app.message("Direction reversed")


## Replace every point's width (keeps per-point edits undoable as one step).
func set_all_widths(w):
	begin_change()
	for p in app.track.data.points:
		p.w = w
	commit_change()


## One pass of neighbour averaging on control-point heights (useful after importing GPS elevation).
func smooth_heights():
	begin_change()
	var P = app.track.data.points
	var n = P.size()
	var z = []
	for i in n:
		z.append((P[posmod(i - 1, n)].z + 2 * P[i].z + P[(i + 1) % n].z) / 4)
	for i in n:
		P[i].z = snappedf(z[i], .1)
	commit_change()


func draw_cross_line(s, color, width):
	var p = app.track.pos_at(s)
	var n = Vector2(-sin(p.h), cos(p.h)) * p.w / 2
	draw_line(to_screen(point2(p) - n), to_screen(point2(p) + n), color, width)


## Very short OSM sample strips can collapse or cross at tight bends. Draw their two finite triangles.
func draw_road_quad(points, colour):
	for ids in [[0, 1, 2], [0, 2, 3]]:
		var a = points[ids[0]]
		var b = points[ids[1]]
		var c = points[ids[2]]
		if absf((b - a).cross(c - a)) > .00001:
			draw_colored_polygon(PackedVector2Array([a, b, c]), colour)
