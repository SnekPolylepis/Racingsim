extends Node
## World-only low-resolution pipeline. Two GPU history targets; no CPU frame copies.
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
var editor_layer: CanvasLayer
var field_valid = false
var output_clock = 0.0
var field_phase = 0
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


func initialize(owner_app):
	app = owner_app
	world_view = viewport_at(Vector2i(712, 448), true)
	world_view.world_3d = app.get_viewport().world_3d
	app.camera.reparent(world_view)
	app.camera.make_current()
	var flare = preload("res://scripts/retro_flare.gd").new()
	flare.app = app
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_view.add_child(flare)
	app.get_viewport().disable_3d = true
	glow_view = viewport_at(Vector2i(178, 112))
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
	ui_view = viewport_at(Vector2i(640, 448))
	ui_view.gui_disable_input = false
	ui_view.handle_input_locally = true
	ui_view.transparent_bg = true
	ui_view.gui_embed_subwindows = true
	ui_view.size_2d_override = Vector2i(1280, 896)
	ui_view.size_2d_override_stretch = true
	ui_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 2:
		var view = viewport_at(Vector2i(640, 448))
		output_views.append(view)
		var mat = panel(view, preload("res://shaders/console_output.gdshader"))
		mat.set_shader_parameter("ui_texture", ui_view.get_texture())
		output_passes.append(mat)
	layer = CanvasLayer.new()
	layer.name = "RetroWorld"
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
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sharp_display = TextureRect.new()
	sharp_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharp_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sharp_display.texture = ui_view.get_texture()
	layer.add_child(sharp_display)
	editor_layer = CanvasLayer.new()
	editor_layer.layer = 1
	app.add_child(editor_layer)
	RenderingServer.frame_pre_draw.connect(apply_projection)
	app.get_viewport().size_changed.connect(apply_settings)
	apply_settings()


func apply_settings():
	var physical = app.get_window().size
	var s = app.settings
	var height = [448, 720, physical.y][clampi(int(s.render_resolution), 0, 2)]
	var aspect = 16.0 / 9 if s.get("screen_aspect", 1) == 1 else 4.0 / 3
	var dimensions = (
		Vector2i(640, height) if s.render_resolution == 0 else Vector2i(roundi(height * aspect), height)
	)
	var output_size = dimensions
	if s.get("output_mode", 0) == 1:
		output_size = Vector2i(640, 448)
		dimensions = Vector2i(640, 224)
	world_view.size = dimensions
	glow_view.size = dimensions / 4
	glow_view.get_child(0).size = Vector2(glow_view.size)
	glow_view.get_child(0).material.set_shader_parameter("threshold", .64 if s.time_of_day == 1 else .82)
	for i in 2:
		history[i].size = dimensions
		history[i].get_child(0).size = Vector2(dimensions)
		passes[i].set_shader_parameter("dithering", false)
		passes[i].set_shader_parameter("glow_strength", 1.1 if s.time_of_day == 1 else .7)
		passes[i].set_shader_parameter("soft", s.upscale == 1)
		output_views[i].size = output_size
		output_views[i].get_child(0).size = Vector2(output_size)
		output_passes[i].set_shader_parameter("authentic_ui", s.get("ui_mode", 0) == 0)
		output_passes[i].set_shader_parameter("interlaced", s.get("output_mode", 0) == 1)
		output_passes[i].set_shader_parameter("composite", s.get("crt_filter", false))
		output_passes[i].set_shader_parameter("rgb16", s.get("framebuffer_colour", 0) == 1)
		output_passes[i].set_shader_parameter("dithering", s.colour_dither)
	ui_view.size = Vector2i(640, 448) if s.get("ui_mode", 0) == 0 else physical
	ui_view.oversampling = s.get("ui_mode", 0) == 1
	var logical = app.get_viewport().get_visible_rect().size
	var draw_size = Vector2(minf(logical.x, logical.y * aspect), minf(logical.y, logical.x / aspect))
	presentation = Rect2((logical - draw_size) * .5, draw_size)
	display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	display.position = presentation.position
	display.size = presentation.size
	sharp_display.position = presentation.position
	sharp_display.size = presentation.size
	sharp_display.visible = s.get("ui_mode", 0) == 1
	var next = (
		str(dimensions)
		+ str(s.time_of_day)
		+ str(s.speed_blur)
		+ str(s.get("ui_mode", 0))
		+ str(s.get("output_mode", 0))
	)
	if next != config:
		valid_history = false
		field_valid = false
		config = next
	if app.ui:
		attach_ui()


func _process(_dt):
	if app == null or app.ui == null:
		return
	layer.visible = not app.editing
	world_view.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED if app.editing else SubViewport.UPDATE_ALWAYS
	)
	if app.editing:
		valid_history = false
		return
	output_clock += _dt
	if app.settings.get("output_mode", 0) == 1 and output_clock < 1.0 / 59.94:
		return
	output_clock = fmod(output_clock, 1.0 / 59.94)
	field_phase = 1 - field_phase
	cursor = 1 - cursor
	var mat = passes[cursor]
	mat.set_shader_parameter("previous_texture", history[1 - cursor].get_texture())
	var weight = [0.0, .12, .25][clampi(int(app.settings.speed_blur), 0, 2)]
	weight *= clampf((app.car.speed - 20) / 30, 0, 1)
	mat.set_shader_parameter("history_weight", weight if valid_history and not app.blocked() else 0.0)
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


## Camera rays use internal pixels. The editor retains its independent native 2D canvas transform.
func world_pixel(screen_position):
	return (screen_position - presentation.position) * Vector2(world_view.size) / presentation.size


func unproject(world_position):
	var point = app.camera.unproject_position(world_position)
	var ratio = (presentation.size.x / presentation.size.y) / (float(world_view.size.x) / world_view.size.y)
	point.x = world_view.size.x * .5 + (point.x - world_view.size.x * .5) / ratio
	return point


func attach_ui():
	var parent = app if app.editing else ui_view
	if app.ui.get_parent() != parent:
		app.ui.reparent(parent)
	if app.editor.get_parent() != editor_layer:
		app.editor.reparent(editor_layer)
		app.editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_view.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED if app.editing else SubViewport.UPDATE_ALWAYS
	)
	app.ui.root.theme.default_font_size = 16 if app.editing else 32
	app.ui.layout.call_deferred()


func forward_input(event):
	if app.editing:
		return false
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
		forwarded.position = (event.position - presentation.position) * Vector2(1280, 896) / presentation.size
		forwarded.global_position = forwarded.position
		if event is InputEventMouseMotion:
			forwarded.relative = event.relative * Vector2(1280, 896) / presentation.size
	ui_view.push_input(forwarded, true)
	return ui_view.is_input_handled()


func apply_projection():
	if app == null or app.editing:
		return
	# The server accepts an affine camera transform. Its X scale compensates
	# non-square SD pixels while keeping the actual 3D raster at 640x448/224.
	var transform = app.camera.global_transform
	var desired_aspect = presentation.size.x / maxf(1, presentation.size.y)
	var raster_aspect = float(world_view.size.x) / world_view.size.y
	transform.basis.x *= desired_aspect / raster_aspect
	RenderingServer.camera_set_transform(app.camera.get_camera_rid(), transform)
