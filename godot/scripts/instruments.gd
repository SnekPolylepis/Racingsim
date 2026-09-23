extends Control
## Read-only driving presentation: timing, map, tire cards, telemetry and debug forces.
## Samples physics at approximately 60 Hz, retaining 600 samples; ignores pointer input.
## frame_ms measures root render-update work, not GPU frame time or complete frame cost.
var app
var number_font = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const READ_FONT = preload("res://assets/fonts/Rajdhani-Medium.ttf")
var samples = []
var accumulator = 0.0
var map_points = PackedVector2Array()
var map_low = Vector2.ZERO
var map_scale = 1.0
var map_offset = Vector2.ZERO
var frame_ms = 0.0
const GOLD = Color("f3cd7a")
const INK = Color("0d1c25")
const MUTED = Color("96adb9")


func initialize(owner_app):
	app = owner_app
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func reset():
	samples.clear()
	accumulator = 0
	rebuild_map()


## Cache the minimap polyline after a circuit load/reset rather than projecting it every frame.
func rebuild_map():
	map_points.clear()
	if app.track.samples.is_empty():
		return
	var low = Vector2(INF, INF)
	var high = Vector2(-INF, -INF)
	for sm in app.track.samples:
		low = low.min(Vector2(sm.x, sm.y))
		high = high.max(Vector2(sm.x, sm.y))
	map_scale = minf(202 / maxf(1, high.x - low.x), 125 / maxf(1, high.y - low.y))
	map_offset = Vector2(127, 388) - (low + high) * .5 * map_scale
	for i in range(0, app.track.samples.size(), 4):
		var sm = app.track.samples[i]
		map_points.append(map_offset + Vector2(sm.x, sm.y) * map_scale)
	if map_points.size() > 1:
		map_points.append(map_points[0])


func sample(car, dt):
	accumulator += dt
	if accumulator < 1.0 / 60:
		return
	accumulator = 0
	samples.append([car.speed, car.input.throttle, car.input.brake, car.input.steer])
	if samples.size() > 600:
		samples.pop_front()


func text(pos, value, font_size = 16, color = Color.WHITE):
	draw_string(
		number_font if font_size >= 24 else READ_FONT,
		pos,
		str(value),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func box(rect):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(.035, .075, .10, .92)
	style.set_corner_radius_all(10)
	style.border_color = Color("29404d")
	style.set_border_width_all(1)
	draw_style_box(style, rect)


func _draw():
	if app == null or app.editing or app.track.samples.is_empty():
		return
	if app.frontend:
		draw_console()
		return
	var car = app.car
	var race = app.race
	box(Rect2(16, 112, 238, 206))
	text(Vector2(32, 139), "TIME ATTACK", 12, MUTED)
	text(Vector2(32, 170), app.RaceModel.time_text(race.lap_time), 29)
	text(Vector2(32, 197), "BEST  " + app.RaceModel.time_text(race.best), 16, GOLD)
	text(
		Vector2(32, 223),
		(
			"LAST  "
			+ app.RaceModel.time_text(race.last)
			+ (" × " + race.last_reason if race.last > 0 and not race.last_valid else "")
		),
		16,
		MUTED
	)
	text(
		Vector2(32, 246),
		"VALID" if race.valid else "INVALID · " + race.invalid_reason,
		12,
		Color("75d9b0") if race.valid else Color("f58278")
	)
	draw_sectors(race)
	box(Rect2(16, 328, 238, 157))
	if map_points.size() > 1:
		draw_polyline(map_points, Color("9bb4bd"), 2, true)
	var gp = race.ghost_pose()
	if app.settings.ghost and not gp.is_empty():
		draw_circle(map_offset + Vector2(gp[0], gp[1]) * map_scale, 3.5, Color("70cbed"))
	draw_circle(map_offset + Vector2(car.x, car.y) * map_scale, 4.5, GOLD)
	text(
		Vector2(32, 473),
		"%.3f KM  ·  CP %d/%d" % [app.track.length / 1000, race.next_cp, app.track.checkpoints.size()],
		12,
		MUTED
	)
	if race.delta != null:
		var color = Color("75d9b0") if race.delta <= 0 else Color("f58278")
		box(Rect2(size.x / 2 - 86, 112, 172, 54))
		text(Vector2(size.x / 2 - 65, 148), "%+.3f" % race.delta, 28, color)
	var origin = Vector2(size.x - 186, size.y - 132)
	draw_circle(origin, 132, Color(.025, .045, .065, .82))
	var fraction = clampf(car.rpm / car.p.redline, 0, 1)
	var begin = PI * .83
	var end = PI * 2.17
	draw_arc(origin, 119, begin, end, 80, Color("465965"), 10, true)
	draw_arc(
		origin,
		119,
		begin,
		lerpf(begin, end, fraction),
		80,
		GOLD if fraction < .92 else Color("ff6844"),
		10,
		true
	)
	for i in 9:
		var dir = Vector2.from_angle(lerpf(begin, end, i / 8.0))
		draw_line(origin + dir * 103, origin + dir * 114, Color.WHITE, 2, true)
	var speed = car.speed * (2.236936 if app.settings.units == 1 else 3.6)
	text(origin + Vector2(-93, 30), "%03d" % int(speed), 58)
	text(
		origin + Vector2(54, 25), "R" if car.gear < 0 else ("N" if car.gear == 0 else str(car.gear)), 56, GOLD
	)
	text(origin + Vector2(-82, 54), "mph" if app.settings.units == 1 else "km/h", 14, MUTED)
	text(origin + Vector2(-64, 83), "%04d RPM" % int(car.rpm), 17, MUTED)
	text(
		origin + Vector2(-95, -39),
		"ASM" if car.asm_active else ("TCS" if car.tc_active else ("ABS" if car.abs_active else "DRIVE")),
		12,
		GOLD
	)
	draw_circle(origin + Vector2(48, -47), 7, Color("ff653d") if fraction > .93 else Color("42332a"))
	# Tire temperature / wear is always visible, independent of the debug view.
	for i in 4:
		var w = car.wheels[i]
		var pos = Vector2(size.x - 153 + (i % 2) * 67, 117 + floori(i / 2.0) * 57)
		# Colour by position in the tyre's working window: blue cold, green in the window, red overheated.
		var tu = (.65 * w.temp + .35 * w.core - car.setup.tempOpt) / car.setup.tempWindow
		var color = (
			Color("5b9eca").lerp(Color("6fcf8e"), clampf(tu + 1.2, 0, 1))
			if tu < 0
			else Color("6fcf8e").lerp(Color("eb6f5c"), clampf((tu - .5) / .7, 0, 1))
		)
		draw_style_box(tire_style(color), Rect2(pos, Vector2(57, 46)))
		text(pos + Vector2(7, 20), "%.0f°" % w.temp, 16)
		text(pos + Vector2(7, 37), "%.0f° · %.0f%%" % [w.core, w.wear * 100], 11, MUTED)
	if app.settings.telemetry:
		draw_telemetry()
	if app.settings.debug:
		draw_debug()


func draw_console():
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(640, 448))
	var car = app.car
	var race = app.race
	draw_rect(Rect2(18, 15, 202, 109), Color(.02, .03, .05, .70))
	text(
		Vector2(27, 37),
		(
			"LAP %02d  /  %s"
			% [race.completed + 1, "TIME TRIAL" if app.frontend.race_mode == "Time Trial" else "FREE RUN"]
		),
		16
	)
	text(Vector2(27, 67), app.RaceModel.time_text(race.lap_time), 30)
	text(Vector2(27, 92), "BEST  " + app.RaceModel.time_text(race.best), 18, GOLD)
	text(
		Vector2(27, 116),
		"VALID" if race.valid else "INVALID  " + race.invalid_reason,
		16,
		Color("d4e3ce") if race.valid else Color("ff7f69")
	)
	for i in 3:
		var x = 230 + i * 82
		var t = race.sectors[i] if race.sectors[i] > 0 else race.last_sectors[i]
		draw_rect(Rect2(x, 17, 77, 45), Color(.02, .03, .05, .70))
		text(Vector2(x + 6, 35), "S%d" % (i + 1), 16, GOLD)
		text(Vector2(x + 6, 56), "%.2f" % t if t > 0 else "--.--", 16)
	if race.delta != null:
		text(
			Vector2(266, 89), "%+.3f" % race.delta, 26, Color("aee3be") if race.delta < 0 else Color("f2ba8c")
		)
	var low = Vector2(INF, INF)
	var high = Vector2(-INF, -INF)
	# Bounds use the cached map: no track projections or physics changes here.
	for point in map_points:
		low = low.min(point)
		high = high.max(point)
	if map_points.size() > 1:
		var factor = minf(135 / maxf(1, high.x - low.x), 98 / maxf(1, high.y - low.y))
		var offset = Vector2(89, 348) - (low + high) * .5 * factor
		var points = PackedVector2Array()
		for point in map_points:
			points.append(point * factor + offset)
		draw_polyline(points, Color(.02, .04, .05, .8), 6)
		draw_polyline(points, Color("d8dfd9"), 2)
		draw_circle((map_offset + Vector2(car.x, car.y) * map_scale) * factor + offset, 3.5, GOLD)
	var origin = Vector2(548, 352)
	draw_circle(origin, 64, Color(.025, .035, .05, .76))
	var fraction = clampf(car.rpm / car.p.redline, 0, 1)
	draw_arc(origin, 60, PI * .80, PI * 2.20, 40, Color("7a8a92"), 5)
	draw_arc(
		origin,
		60,
		PI * .80,
		lerpf(PI * .80, PI * 2.20, fraction),
		40,
		GOLD if fraction < .93 else Color("ff5e45"),
		5
	)
	for i in 9:
		var dir = Vector2.from_angle(lerpf(PI * .80, PI * 2.20, i / 8.0))
		draw_line(origin + dir * 50, origin + dir * 56, Color.WHITE, 1)
	text(
		origin + Vector2(-46, 21),
		"%03d" % int(car.speed * (2.236936 if app.settings.units == 1 else 3.6)),
		37
	)
	text(origin + Vector2(29, 21), "R" if car.gear < 0 else str(car.gear), 35, GOLD)
	text(origin + Vector2(-36, 42), "mph" if app.settings.units == 1 else "km/h", 16)
	draw_circle(origin + Vector2(28, -22), 4, Color("ff623f") if fraction > .93 else Color("453c34"))
	draw_rect(Rect2(340, 343, 90, 67), Color(.02, .03, .05, .78))
	text(Vector2(348, 363), "TCS %d" % car.tcs_level(), 16, GOLD if car.tc_active else Color.WHITE)
	text(Vector2(348, 384), "ASM %d" % car.asm_level(), 16, GOLD if car.asm_active else Color.WHITE)
	text(
		Vector2(348, 405),
		"ABS " + ("ON" if car.setup.absOn > .5 else "OFF"),
		16,
		GOLD if car.abs_active else Color.WHITE
	)
	text(Vector2(513, 70), "TYRES °C", 16)
	for i in 4:
		var pos = Vector2(513 + (i % 2) * 46, 78 + floori(i / 2.) * 33)
		var w = car.wheels[i]
		var hot = (.65 * w.temp + .35 * w.core - car.setup.tempOpt) / car.setup.tempWindow
		draw_rect(Rect2(pos, Vector2(40, 28)), Color("669c72") if hot < .6 else Color("b66346"))
		text(pos + Vector2(4, 21), "%.0f" % w.temp, 16)
	if app.settings.debug or app.settings.telemetry:
		draw_set_transform(Vector2.ZERO)
		if app.settings.debug:
			draw_debug()
		if app.settings.telemetry:
			draw_telemetry()


const SECTOR_COLORS = {
	"purple": Color("a55de0"),
	"green": Color("3fbf6a"),
	"yellow": Color("d7b53c"),
	"invalid": Color("8a3b38"),
	"": Color("223543")
}


## Three sector cells: completed splits coloured purple/green/yellow, the running sector counting up.
## Before the first split of a lap, the previous lap's sectors stay visible (dimmed).
func draw_sectors(race):
	var showing_last = race.sector_idx == 0 and race.last_sectors.max() > 0 and race.lap_time < 4.0
	for i in 3:
		var rect = Rect2(24 + i * 75, 252, 71, 36)
		var flag = race.last_flags[i] if showing_last else race.flags[i]
		var color = SECTOR_COLORS.get(flag, SECTOR_COLORS[""])
		if showing_last:
			color = color.darkened(.35)
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(5)
		draw_style_box(style, rect)
		var t = race.last_sectors[i] if showing_last else race.sectors[i]
		var running = not showing_last and race.active and i == race.sector_idx and t <= 0
		var value = (
			"%.3f" % t if t > 0 else ("%.1f" % (race.lap_time - race.sector_start) if running else "—")
		)
		text(rect.position + Vector2(6, 13), "S%d" % (i + 1), 10, Color(1, 1, 1, .75))
		text(rect.position + Vector2(6, 30), value, 14, Color.WHITE if t > 0 else MUTED)
	var ideal = race.ideal()
	text(
		Vector2(32, 307),
		"IDEAL  " + app.RaceModel.time_text(ideal),
		12,
		Color("c9a6ee") if ideal > 0 else MUTED
	)


func tire_style(color):
	var style = StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func draw_telemetry():
	var rect = Rect2(16, size.y - 226, maxf(360, size.x - 344), 174)
	box(rect)
	text(rect.position + Vector2(15, 25), "LAST 10 SECONDS", 12, MUTED)
	var cols = [Color("6daef7"), Color("75d9b0"), Color("f58278"), GOLD]
	var names = ["SPEED", "THROTTLE", "BRAKE", "STEER"]
	for k in 4:
		text(rect.position + Vector2(180 + k * 93, 25), names[k], 11, cols[k])
		if samples.size() < 2:
			continue
		var pts = PackedVector2Array()
		for i in samples.size():
			var v = samples[i][k] / 80 if k == 0 else ((samples[i][k] + 1) / 2 if k == 3 else samples[i][k])
			pts.append(
				(
					rect.position
					+ Vector2(
						14 + float(i) / 599 * (rect.size.x - 28),
						rect.size.y - 12 - clampf(v, 0, 1) * (rect.size.y - 54)
					)
				)
			)
		draw_polyline(pts, cols[k], 1.7, true)


func draw_debug():
	var car = app.car
	var x = 280.0
	var y = 183.0
	box(Rect2(x, y, minf(630, size.x - 470), 178))
	text(Vector2(x + 14, y + 24), "VEHICLE TELEMETRY", 13, GOLD)
	text(
		Vector2(x + 14, y + 48),
		(
			"Slip %+.1f°   Yaw %+.1f°/s   Ax %+.2f  Ay %+.2f m/s²"
			% [rad_to_deg(atan2(car.vby, maxf(absf(car.vbx), .01))), rad_to_deg(car.r), car.ax, car.ay]
		),
		14
	)
	text(
		Vector2(x + 14, y + 70),
		(
			"Pitch %+.2f°   Roll %+.2f°   Heave %+.0f mm"
			% [rad_to_deg(car.pitch), rad_to_deg(car.roll), car.z * 1000]
		),
		14
	)
	text(
		Vector2(x + 14, y + 92),
		(
			"Height %.1f m   Grade %+.1f%%   Load %.2f g   Clutch %.0f%%   Align %+.0f N·m"
			% [car.elev, car.grade * 100, car.g_eff / 9.81, car.clutch_eng * 100, car.steer_torque]
		),
		14
	)
	for i in 4:
		var w = car.wheels[i]
		text(
			Vector2(x + 14 + (i % 2) * 280, y + 119 + floori(i / 2.0) * 24),
			(
				"%s  %.0fN  κ %+.2f  α %+.1f°  μ %.2f"
				% [["FL", "FR", "RL", "RR"][i], w.load, w.slipRatio, rad_to_deg(w.slipAngle), w.ellipse]
			),
			12,
			MUTED
		)
	text(
		Vector2(x + 14, y + 167),
		(
			"%d FPS  ·  %.1f ms  ·  quality %d  ·  %s"
			% [
				Engine.get_frames_per_second(),
				frame_ms,
				app.quality,
				"LIMITER" if car.rev_limit else "240 Hz physics"
			]
		),
		12,
		MUTED
	)
	for w in car.wheels:
		var pos = Vector3(w.wx, app.track.elev_at(w.wx, w.wy).z + .15, w.wy)
		var direction = Vector3(cos(car.h), 0, sin(car.h))
		var right = Vector3(-sin(car.h), 0, cos(car.h))
		if not app.camera.is_position_behind(pos):
			var viewport_scale = size / Vector2(app.retro.world_view.size)
			var start = app.retro.unproject(pos) * viewport_scale
			draw_line(
				start,
				app.retro.unproject(pos + (direction * w.fx + right * w.fy) * .0003) * viewport_scale,
				Color("efc774"),
				2,
				true
			)
