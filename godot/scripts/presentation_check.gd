extends Node
## Look-3 windowed check, run by `--v2-present` after its laps (or alone with `--v2-look`). Each
## presentation mode in turn: apply the Display settings the way Settings does, check the raster and
## UI viewport sizes, time frames while the bot drives, screenshot the drive, the title page and the
## settings panel, and send real mouse, keyboard and controller events that must reach the right
## control at that mode's resolution and aspect.
const MODES = [
	{
		"name": "native-sharp-ui",
		"settings":
		{
			"render_resolution": 2,
			"ui_mode": 1,
			"upscale": 0,
			"output_mode": 0,
			"crt_filter": false,
			"framebuffer_colour": 0,
			"screen_aspect": 1
		}
	},
	{
		"name": "720p-authentic",
		"settings":
		{
			"render_resolution": 1,
			"ui_mode": 0,
			"upscale": 1,
			"output_mode": 0,
			"crt_filter": false,
			"framebuffer_colour": 0,
			"screen_aspect": 1
		}
	},
	{
		"name": "sd-authentic",
		"settings":
		{
			"render_resolution": 0,
			"ui_mode": 0,
			"upscale": 1,
			"output_mode": 0,
			"crt_filter": false,
			"framebuffer_colour": 0,
			"screen_aspect": 1
		}
	},
	{
		"name": "sd-sharp-ui-4x3-rgb555",
		"settings":
		{
			"render_resolution": 0,
			"ui_mode": 1,
			"upscale": 0,
			"output_mode": 0,
			"crt_filter": false,
			"framebuffer_colour": 1,
			"screen_aspect": 0
		}
	},
	{
		"name": "crt-480i",
		"settings":
		{
			"render_resolution": 0,
			"ui_mode": 0,
			"upscale": 1,
			"output_mode": 1,
			"crt_filter": true,
			"framebuffer_colour": 0,
			"screen_aspect": 1
		}
	},
	{
		"name": "sd-authentic-night",
		"settings":
		{
			"render_resolution": 0,
			"ui_mode": 0,
			"upscale": 1,
			"output_mode": 0,
			"crt_filter": false,
			"framebuffer_colour": 0,
			"screen_aspect": 1,
			"time_of_day": 1
		}
	},
]
const WARM_FRAMES = 20
const TIMED_FRAMES = 90
var app
var retro
var checks = {}
var timings = {}
var shots = []
var folder = "user://look-3"


func check(ok: bool, label: String) -> void:
	checks[label] = ok
	if not ok:
		print("LOOK FAIL ", label)


func frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path = folder + "/" + app.v2_track_id + "-" + label + ".png"
	app.get_viewport().get_texture().get_image().save_png(path)
	shots.append(ProjectSettings.globalize_path(path))


## Window (physical) pixels for a point on the 1280x896 UI canvas; Input.parse_input_event takes
## window coordinates, so the whole root-viewport -> presentation -> canvas mapping is exercised.
func window_point(canvas_point: Vector2) -> Vector2:
	var logical = app.get_viewport().get_visible_rect().size
	return retro.from_canvas(canvas_point) * Vector2(app.get_window().size) / logical


func click(control: Control) -> void:
	var at = window_point(control.get_global_rect().get_center())
	var motion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await frames(1)
	for pressed in [true, false]:
		var button = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		Input.parse_input_event(button)
		await frames(1)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)


func pad(button_index: JoyButton) -> void:
	for pressed in [true, false]:
		var event = InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button_index
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)


func button_named(root: Node, caption: String) -> Button:
	for item in root.find_children("*", "Button", true, false):
		if item.text == caption and item.is_visible_in_tree():
			return item
	return null


func run(owner_app) -> Dictionary:
	app = owner_app
	retro = app.retro
	DirAccess.make_dir_recursive_absolute(folder)
	var original = {}
	for key in app.PRESENTATION_SETTINGS:
		original[key] = app.settings[key]
	Engine.time_scale = 1.0
	# Pass 1: sizes, and frame time while the bot drives.
	for mode in MODES:
		apply_mode(mode, true)
		await time_mode(mode.name)
	# Pass 2: the sim holds still so every mode's drive screenshot shows the same moment. The moment
	# is a sim time (the 240 Hz bot lap is deterministic), so reruns compare like for like.
	var moment = ceilf(app.elapsed / 30.0) * 30.0 + 12.0
	while app.elapsed < moment:
		await frames(1)
	app.paused = true
	for mode in MODES:
		apply_mode(mode)
		await frames(8)
		await screenshot(mode.name + "-drive")
	app.paused = false
	# Pass 3: menus, screenshots and input after each switch.
	for mode in MODES:
		apply_mode(mode)
		await menu_mode(mode.name)
	for key in original:
		app.set_v2_setting(key, original[key])
	return {"checks": checks, "timings": timings, "screenshots": shots}


## Switch to a mode the way the Settings panel does; optionally check the resulting sizes.
func apply_mode(mode: Dictionary, verify = false) -> void:
	var name: String = mode.name
	for key in mode.settings:
		app.set_v2_setting(key, mode.settings[key])
	if not mode.settings.has("time_of_day"):
		app.set_v2_setting("time_of_day", 0)
	if not verify:
		return
	var s = app.settings
	var logical = app.get_viewport().get_visible_rect().size
	var native = Vector2i((retro.presentation.size * Vector2(app.get_window().size) / logical).round())
	var aspect = 16.0 / 9 if s.screen_aspect == 1 else 4.0 / 3
	# The 3D raster has square pixels at the presentation aspect; the console raster is what the
	# history passes store (640x448 anamorphic SD, a 640x224 field for 480i).
	var sd_world = Vector2i(roundi(448 * aspect), 448)
	var world = [sd_world, Vector2i(roundi(720 * aspect), 720), native][s.render_resolution]
	var raster = [Vector2i(640, 448), world, world][s.render_resolution]
	if s.output_mode == 1:
		world = sd_world
		raster = Vector2i(640, 224)
	check(retro.world_view.size == world, name + ": square-pixel world " + str(world))
	check(retro.history[0].size == raster, name + ": console raster " + str(raster))
	check(
		retro.ui_view.size == (Vector2i(640, 448) if s.ui_mode == 0 else native),
		name + ": UI viewport " + ("640x448" if s.ui_mode == 0 else "native")
	)
	check(
		absf(retro.presentation.size.x / retro.presentation.size.y - aspect) < .01,
		name + ": presentation aspect"
	)
	check(retro.sharp_display.visible == (s.ui_mode == 1), name + ": sharp UI overlay")


func time_mode(name: String) -> void:
	# Frame time with the bot driving: wall clock between frames, and the world viewport's own
	# render time as the driver reports it.
	var world_rid = retro.world_view.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(world_rid, true)
	await frames(WARM_FRAMES)
	var total = 0.0
	var worst = 0.0
	var gpu = 0.0
	var last = Time.get_ticks_usec()
	for i in TIMED_FRAMES:
		await RenderingServer.frame_post_draw
		var now = Time.get_ticks_usec()
		var ms = (now - last) / 1000.0
		last = now
		total += ms
		worst = maxf(worst, ms)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(world_rid)
	RenderingServer.viewport_set_measure_render_time(world_rid, false)
	timings[name] = {
		"world": str(retro.world_view.size),
		"raster": str(retro.history[0].size),
		"frame_ms": snappedf(total / TIMED_FRAMES, .01),
		"worst_ms": snappedf(worst, .01),
		"world_gpu_ms": snappedf(gpu / TIMED_FRAMES, .01)
	}


func menu_mode(name: String) -> void:
	var frontend = app.frontend
	# Title page, then a mouse click on "Race" must open car selection.
	frontend.show_page("main")
	await frames(3)
	await screenshot(name + "-menu")
	var race_button = button_named(frontend, "Race")
	check(race_button != null, name + ": title page has Race")
	if race_button:
		await click(race_button)
		check(frontend.page == "car", name + ": mouse click on Race opens car selection")
	# Pause page: click Settings, screenshot the panel, click Close.
	frontend.show_page("pause")
	await frames(3)
	var settings_button = button_named(frontend, "Settings")
	if settings_button:
		await click(settings_button)
	var opened = frontend.v2_panels.is_open()
	check(opened, name + ": mouse click on Settings opens the panel")
	await frames(2)
	await screenshot(name + "-settings")
	var close_button = button_named(frontend.v2_panels, "Close · Esc")
	if close_button:
		await click(close_button)
	check(opened and not frontend.v2_panels.is_open(), name + ": mouse click on Close closes the panel")
	# Keyboard focus navigation and a controller confirm reach the same controls.
	await frames(2)
	var focus = retro.ui_view.gui_get_focus_owner()
	check(focus != null and focus.text == "Resume", name + ": pause focuses Resume")
	await key(KEY_DOWN)
	focus = retro.ui_view.gui_get_focus_owner()
	check(focus != null and focus.text == "Restart lap", name + ": arrow key moves focus")
	await key(KEY_UP)
	await pad(JOY_BUTTON_A)
	check(frontend.page == "drive" and not app.paused, name + ": controller A on Resume resumes")
