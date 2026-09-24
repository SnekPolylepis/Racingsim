extends Node
## Look-3 PS2 presentation chain for the v2 game (docs/ARCHITECTURE.md, "Presentation").
## The world camera renders into `world_view` (640x448 SD, 720p or native raster); a quarter-size glow,
## two alternating history passes (glow, soft filter, motion persistence, ordered dither) and two
## alternating console output passes (480i fields, composite, RGB555, Authentic UI composite) follow,
## and `display` shows the result in the presentation rectangle. The v2 UI root (HUD, front end,
## settings) renders in `ui_view`, a 1280x896 logical canvas: 640x448 pixels composited by the output
## pass with Authentic UI, or the presentation's physical size overlaid by `sharp_display` with Sharp UI.
## Only built with a display; headless runs keep the UI root in the root viewport. No CPU frame copies.
const UI_CANVAS = Vector2(1280, 896)
const SD = Vector2i(640, 448)
var app
var world_view: SubViewport
var glow_view: SubViewport
var history = []
var passes = []
var display: TextureRect
var layer: CanvasLayer
var cursor = 0
var valid_history = false
var config = ""
var ui_view: SubViewport
var output_views = []
var output_passes = []
var sharp_display: TextureRect
var field_valid = false
var output_clock = 0.0
var field_phase = 0
## The picture in root-viewport (logical) coordinates; black bars fill the rest of the window.
var presentation = Rect2()
var pointer_inside = false


func viewport_at(dimensions, world = false):
	var view = SubViewport.new()
	view.size = dimensions
	view.disable_3d = not world
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if world else SubViewport.UPDATE_DISABLED
	add_child(view)
	return view


func panel(view, shader):
	var rect = ColorRect.new()
	rect.size = Vector2(view.size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	view.add_child(rect)
	return mat


## `ui_root` is the v2 UI CanvasLayer (V2UIRoot); it moves into the UI viewport for good.
func initialize(owner_app, ui_root: Node):
	app = owner_app
	world_view = viewport_at(SD, true)
	world_view.world_3d = app.get_world_3d()
	world_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	app.camera.reparent(world_view)
	app.camera.make_current()
	var flare = preload("res://scripts/retro_flare.gd").new()
	flare.app = app
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.add_child(flare)
	app.get_viewport().disable_3d = true
	glow_view = viewport_at(SD / 4)
	glow_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var glow = panel(glow_view, preload("res://shaders/retro_glow.gdshader"))
	glow.set_shader_parameter("world_texture", world_view.get_texture())
	for i in 2:
		var view = viewport_at(world_view.size)
		history.append(view)
		var mat = panel(view, preload("res://shaders/retro_screen.gdshader"))
		mat.set_shader_parameter("world_texture", world_view.get_texture())
		mat.set_shader_parameter("glow_texture", glow_view.get_texture())
		passes.append(mat)
	ui_view = viewport_at(SD)
	ui_view.handle_input_locally = true
	ui_view.transparent_bg = true
	ui_view.gui_embed_subwindows = true
	ui_view.size_2d_override = Vector2i(UI_CANVAS)
	ui_view.size_2d_override_stretch = true
	ui_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ui_root.reparent(ui_view)
	for i in 2:
		var view = viewport_at(SD)
		output_views.append(view)
		var mat = panel(view, preload("res://shaders/console_output.gdshader"))
		mat.set_shader_parameter("ui_texture", ui_view.get_texture())
		output_passes.append(mat)
	layer = CanvasLayer.new()
	layer.name = "RetroOutput"
	layer.layer = -1
	app.add_child(layer)
	var background = ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display = TextureRect.new()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(display)
	sharp_display = TextureRect.new()
	sharp_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharp_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sharp_display.texture = ui_view.get_texture()
	layer.add_child(sharp_display)
	RenderingServer.frame_pre_draw.connect(apply_projection)
	app.get_viewport().size_changed.connect(apply_settings)
	apply_settings()


## Every Settings > Display choice lands here: on startup, on each change and on window resize.
func apply_settings():
	var s = app.settings
	var logical = app.get_viewport().get_visible_rect().size
	var physical_scale = Vector2(app.get_window().size) / logical
	var aspect = 16.0 / 9 if int(s.screen_aspect) == 1 else 4.0 / 3
	var draw_size = Vector2(minf(logical.x, logical.y * aspect), minf(logical.y, logical.x / aspect))
	presentation = Rect2((logical - draw_size) * .5, draw_size)
	var native = Vector2i((draw_size * physical_scale).round()).max(Vector2i(64, 64))
	var resolution = clampi(int(s.render_resolution), 0, 2)
	var dimensions = [SD, Vector2i(roundi(720 * aspect), 720), native][resolution]
	var output_size = dimensions
	var interlaced = int(s.output_mode) == 1
	if interlaced:
		# 480i is an SD console mode whatever the raster choice: one 640x224 field per output frame.
		output_size = SD
		dimensions = Vector2i(SD.x, SD.y / 2)
	var authentic = int(s.ui_mode) == 0
	var night = int(s.time_of_day) == 1
	world_view.size = dimensions
	world_view.msaa_3d = (
		Viewport.MSAA_2X if s.native_msaa and resolution == 2 and not interlaced else Viewport.MSAA_DISABLED
	)
	glow_view.size = (dimensions / 4).max(Vector2i.ONE)
	glow_view.get_child(0).size = Vector2(glow_view.size)
	glow_view.get_child(0).material.set_shader_parameter("threshold", .64 if night else .88)
	for i in 2:
		history[i].size = dimensions
		history[i].get_child(0).size = Vector2(dimensions)
		passes[i].set_shader_parameter("dithering", s.colour_dither)
		passes[i].set_shader_parameter("glow_strength", 1.1 if night else .4)
		passes[i].set_shader_parameter("soft", int(s.upscale) == 1)
		output_views[i].size = output_size
		output_views[i].get_child(0).size = Vector2(output_size)
		output_passes[i].set_shader_parameter("authentic_ui", authentic)
		output_passes[i].set_shader_parameter("interlaced", interlaced)
		output_passes[i].set_shader_parameter("composite", s.crt_filter)
		output_passes[i].set_shader_parameter("rgb16", int(s.framebuffer_colour) == 1)
		output_passes[i].set_shader_parameter("dithering", s.colour_dither)
	ui_view.size = SD if authentic else native
	# Authentic UI rasterizes glyphs at the 640x448 size they are shown at (16 px from 32 logical).
	ui_view.oversampling = not authentic
	display.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if int(s.upscale) == 1 else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	for rect in [display, sharp_display]:
		rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		rect.position = presentation.position
		rect.size = presentation.size
	sharp_display.visible = not authentic
	var next = str([dimensions, output_size, s.time_of_day, s.speed_blur, s.ui_mode, s.output_mode])
	if next != config:
		valid_history = false
		field_valid = false
		config = next


func _process(dt):
	if app == null:
		return
	output_clock += dt
	if int(app.settings.output_mode) == 1 and output_clock < 1.0 / 59.94:
		return
	output_clock = fmod(output_clock, 1.0 / 59.94)
	field_phase = 1 - field_phase
	cursor = 1 - cursor
	var mat = passes[cursor]
	mat.set_shader_parameter("previous_texture", history[1 - cursor].get_texture())
	var weight = [0.0, .12, .25][clampi(int(app.settings.speed_blur), 0, 2)]
	weight *= clampf((app.car.speed - 20) / 30, 0, 1)
	var blocked = app.in_menu or app.paused
	mat.set_shader_parameter("history_weight", weight if valid_history and not blocked else 0.0)
	history[cursor].render_target_update_mode = SubViewport.UPDATE_ONCE
	var output = output_passes[cursor]
	output.set_shader_parameter("scene_texture", history[cursor].get_texture())
	output.set_shader_parameter("previous_field", output_views[1 - cursor].get_texture())
	output.set_shader_parameter("field_phase", field_phase)
	output.set_shader_parameter("field_valid", field_valid)
	output_views[cursor].render_target_update_mode = SubViewport.UPDATE_ONCE
	display.texture = output_views[cursor].get_texture()
	valid_history = true
	field_valid = true


## A world point in world-raster pixels, with the same non-square-pixel correction as the camera
## (apply_projection). The flare and the debug force arrows use it.
func unproject(world_position):
	var point = app.camera.unproject_position(world_position)
	var ratio = (presentation.size.x / presentation.size.y) / (float(world_view.size.x) / world_view.size.y)
	point.x = world_view.size.x * .5 + (point.x - world_view.size.x * .5) / ratio
	return point


## Root-viewport (logical) position to the 1280x896 UI canvas, and back.
func to_canvas(screen_position: Vector2) -> Vector2:
	return (screen_position - presentation.position) * UI_CANVAS / presentation.size


func from_canvas(canvas_position: Vector2) -> Vector2:
	return presentation.position + canvas_position * presentation.size / UI_CANVAS


## Called from game._input for every event the front end did not take. Mouse events inside the
## picture move to UI canvas coordinates; keys and pad buttons pass unchanged (focus navigation).
## True when a UI control consumed the event.
func forward_input(event) -> bool:
	var forwarded = event.duplicate()
	if event is InputEventMouse:
		if not presentation.has_point(event.position):
			if pointer_inside:
				ui_view.notify_mouse_exited()
				pointer_inside = false
			return false
		if not pointer_inside:
			ui_view.notify_mouse_entered()
			pointer_inside = true
		forwarded.position = to_canvas(event.position)
		forwarded.global_position = forwarded.position
		if event is InputEventMouseMotion:
			forwarded.relative = event.relative * UI_CANVAS / presentation.size
			forwarded.screen_relative = forwarded.relative
			forwarded.velocity = event.velocity * UI_CANVAS / presentation.size
	ui_view.push_input(forwarded, true)
	return ui_view.is_input_handled()


func apply_projection():
	if app == null:
		return
	# The server accepts an affine camera transform. Its X scale compensates
	# non-square SD pixels while keeping the actual 3D raster at 640x448/224.
	var transform = app.camera.global_transform
	var desired_aspect = presentation.size.x / maxf(1, presentation.size.y)
	var raster_aspect = float(world_view.size.x) / world_view.size.y
	transform.basis.x *= desired_aspect / raster_aspect
	RenderingServer.camera_set_transform(app.camera.get_camera_rid(), transform)
