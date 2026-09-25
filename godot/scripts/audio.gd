extends Node
## Recorded CC0 engine RPM/load bank with procedural tire/road/mechanical effects.
## Source recordings and reproducible loop edits are documented in THIRD-PARTY.md.
## Mix updates consume vehicle state without mutating it; blocked play fades gain toward zero.
var players = {}
var last_gear = 1
var impact_cooldown = 0.0
var engine_level = 0.0
var effects_level = 0.0
var audible_rpm = 1250.0
var engine_load = 0.0
var tire_level = 0.0
const RATE = 22050
const ENGINE_BANDS = [
	[
		"idle",
		1250.0,
		preload("res://assets/audio/engine-idle.wav"),
		preload("res://assets/audio/coast-idle.wav")
	],
	[
		"low",
		2400.0,
		preload("res://assets/audio/engine-low.wav"),
		preload("res://assets/audio/coast-low.wav")
	],
	[
		"mid",
		4200.0,
		preload("res://assets/audio/engine-mid.wav"),
		preload("res://assets/audio/coast-mid.wav")
	],
	[
		"high",
		6800.0,
		preload("res://assets/audio/engine-high.wav"),
		preload("res://assets/audio/coast-high.wav")
	]
]


func _ready():
	for band in ENGINE_BANDS:
		for layer in 2:
			var name = ("engine_" if layer == 0 else "coast_") + band[0]
			var stream = band[2 + layer].duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2
			var p = AudioStreamPlayer.new()
			p.stream = stream
			p.volume_db = -80
			add_child(p)
			players[name] = p
			p.play()
	for name in ["intake", "tires", "road", "impact", "shift"]:
		var p = AudioStreamPlayer.new()
		p.stream = make_sound(name)
		p.volume_db = -80
		add_child(p)
		players[name] = p
		if name not in ["impact", "shift"]:
			p.play()


## Stop every player and drop its stream before the node goes: quitting with the eleven looping players
## still active let the audio server hold their playbacks past Godot's exit leak check (intermittently
## 11 AudioStreamWAV + 11 AudioStreamPlaybackWAV "leaked at exit", which fails the windowed gate on stderr).
## Done at PREDELETE rather than _exit_tree(), which also fires when a node is merely re-parented.
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for p in players.values():
			p.stop()
			p.stream = null
		players.clear()


## Create a deterministic 22,050 Hz signed-16-bit mono stream; loops are one second.
func make_sound(kind):
	var loop = kind not in ["impact", "shift"]
	var count = RATE if loop else int(RATE * (.24 if kind == "impact" else .09))
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 470 + kind.hash()
	var filtered = 0.0
	for i in count:
		var t = float(i) / RATE
		var noise = rng.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, .13)
		var value = 0.0
		match kind:
			"intake":
				# Quiet broadband intake breath; recorded combustion owns the tone.
				value = (noise - filtered) * .16
			"tires":
				value = (
					sin(TAU * 940 * t + sin(TAU * 17 * t) * .8) * .23
					+ sin(TAU * 1390 * t) * .10
					+ noise * .10
				)
			"road":
				value = filtered * .6
			"impact":
				value = (
					(filtered * .8 + sin(TAU * (110 - 120 * t) * t) * .3) * exp(-t * 22) * minf(t * 500, 1)
				)
			"shift":
				value = (filtered * .5 + sin(TAU * 180 * t) * .3) * exp(-t * 60) * minf(t * 800, 1)
		# Fade procedural noise at loop boundaries. Recorded loops are edited offline.
		if loop:
			value *= minf(1, minf(t * 100, (1 - t) * 100))
		bytes.encode_s16(i * 2, int(clampf(value, -.95, .95) * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream


## Smooth master/category gains, pitch from RPM and effects from slip/speed/surface.
func update(car, dt, active, settings):
	if players.is_empty():
		return
	var master = 0.0 if settings.mute or not active else settings.volume
	engine_level = lerpf(engine_level, master * settings.engine_volume, 1 - exp(-dt * 14))
	effects_level = lerpf(effects_level, master * settings.effects_volume, 1 - exp(-dt * 14))
	audible_rpm = lerpf(audible_rpm, maxf(400, car.rpm), 1 - exp(-dt * 24))
	var load_target = clampf(car.throttle_eff, 0, 1)
	if car.shift_timer > 0:
		load_target *= .12
	engine_load = lerpf(engine_load, load_target, 1 - exp(-dt * 25))
	# Two adjacent RPM layers crossfade with constant power. Each source stays
	# near its recorded register as the engine moves through the tachometer range.
	var lower = 0
	for i in range(ENGINE_BANDS.size() - 1):
		if audible_rpm >= ENGINE_BANDS[i][1]:
			lower = i
	var upper = mini(lower + 1, ENGINE_BANDS.size() - 1)
	var blend = clampf(
		(
			log(maxf(audible_rpm, ENGINE_BANDS[lower][1]) / ENGINE_BANDS[lower][1])
			/ log(ENGINE_BANDS[upper][1] / ENGINE_BANDS[lower][1])
		),
		0,
		1
	)
	var body = str(car.p.get("body", ""))
	var voice = .82 if body == "roadster" else (.92 if body == "gt" else 1.0)
	for i in ENGINE_BANDS.size():
		var band = ENGINE_BANDS[i]
		var weight = sqrt(1 - blend) if i == lower else (sqrt(blend) if i == upper else 0.0)
		var pitch = clampf(audible_rpm / band[1] * voice, .35, 2.4)
		var power = players["engine_" + band[0]]
		var coast = players["coast_" + band[0]]
		power.pitch_scale = pitch
		coast.pitch_scale = pitch
		power.volume_db = linear_to_db(maxf(.00001, engine_level * weight * sqrt(engine_load) * .92))
		coast.volume_db = linear_to_db(maxf(.00001, engine_level * weight * sqrt(1 - engine_load) * .55))
	players.intake.pitch_scale = clampf(audible_rpm / 4200, .6, 1.8)
	players.intake.volume_db = linear_to_db(maxf(.00001, engine_level * engine_load * .065))
	var slip = 0.0
	var rough = 0.0
	for w in car.wheels:
		if w.surf.id <= 1 or w.surf.id == 4:
			slip = maxf(
				slip,
				(
					clampf((absf(w.slipRatio) - .08) * 2 + maxf(0, absf(w.slipAngle) - .08) * 3, 0, 1)
					* minf(1, car.speed / 8)
				)
			)
		rough = maxf(rough, [0.0, 1.0 / 3, 2.0 / 3, 1.0, .08][w.surf.id])
	tire_level = lerpf(tire_level, slip, 1 - exp(-dt * 16))
	players.tires.volume_db = linear_to_db(maxf(.00001, effects_level * tire_level * .23))
	players.tires.pitch_scale = 1 + minf(car.speed / 200, .3)
	players.road.volume_db = linear_to_db(
		maxf(.00001, effects_level * minf(car.speed / 50, 1) * (.05 + rough * .4))
	)
	players.road.pitch_scale = .7 + minf(car.speed / 60, 1)
	if active and car.gear != last_gear:
		trigger("shift", .3 * effects_level)
	last_gear = car.gear
	impact_cooldown = maxf(0, impact_cooldown - dt)


func impact(strength):
	if impact_cooldown > 0:
		return
	trigger("impact", effects_level * clampf(strength / 10, .08, .65))
	impact_cooldown = .18


func trigger(kind, level):
	players[kind].volume_db = linear_to_db(maxf(.00001, level))
	players[kind].play()
