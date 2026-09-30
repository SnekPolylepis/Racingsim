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
const G = 9.81
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
			if p.is_inside_tree():
				p.play()
	for name in ["intake", "tires", "road", "wind", "whine", "kerb", "impact", "shift"]:
		var p = AudioStreamPlayer.new()
		p.stream = make_sound(name)
		p.volume_db = -80
		add_child(p)
		players[name] = p
		if name not in ["impact", "shift"] and p.is_inside_tree():
			p.play()


## Stop every player and drop its stream before the node goes: quitting with the sixteen looping players
## still active let the audio server hold their playbacks past Godot's exit leak check (intermittently
## AudioStreamWAV + AudioStreamPlaybackWAV "leaked at exit", which fails the windowed gate on stderr).
## Done at PREDELETE rather than _exit_tree(), which also fires when a node is merely re-parented.
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for p in players.values():
			p.stop()
			p.stream = null
		players.clear()
	elif what == NOTIFICATION_ENTER_TREE:
		for name in players:
			if name not in ["impact", "shift"]:
				var p = players[name]
				if not p.playing and p.is_inside_tree():
					p.play()


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
				# Granular rubber scrub + dynamic friction screech.
				var scrub_noise = filtered * .22 + (noise - filtered) * .12
				var screech = (
					sin(TAU * 880 * t + sin(TAU * 21 * t) * 1.1) * .24
					+ sin(TAU * 1320 * t) * .12
				)
				value = scrub_noise + screech
			"road":
				# Road surface texture with high-frequency pavement contact.
				value = filtered * .55 + (noise - filtered) * .08
			"wind":
				# Aerodynamic air turbulence: pink-filtered broadband rush + low buffeting.
				value = (filtered * .42 + (noise - filtered) * .10 + sin(TAU * 48 * t) * .15) * .75
			"whine":
				# Straight-cut spur gear mesh harmonics with subtle tooth chatter.
				value = (
					sin(TAU * 480 * t) * .32
					+ sin(TAU * 960 * t) * .20
					+ sin(TAU * 1440 * t) * .08
					+ (noise - filtered) * .06
				)
			"kerb":
				# Rhythmic kerb strike / rumble strip thrumming.
				var rib_pulse = sin(TAU * 160 * t) * .40 + sin(TAU * 320 * t) * .18
				var edge_snap = (noise * .25) * pow(maxf(0.0, sin(TAU * 80 * t)), 4.0)
				value = rib_pulse + edge_snap
			"impact":
				# Structural thud + metallic scrape.
				var thud = sin(TAU * (75 - 60 * t) * t) * .42 * exp(-t * 18)
				var metal = (filtered * .55 + (noise - filtered) * .35 + sin(TAU * 360 * t) * .2) * exp(-t * 26)
				value = (thud + metal) * minf(t * 800, 1.0)
			"shift":
				# Mechanical shift linkage clack + gear dog engagement.
				var clack = sin(TAU * 220 * t) * .35 * exp(-t * 70)
				var snap = (filtered * .45 + (noise - filtered) * .25) * exp(-t * 90)
				value = (clack + snap) * minf(t * 1000, 1.0)
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
	var car_name = str(car.p.get("name", "")).to_lower()
	var redline = float(car.p.get("redline", 7200.0))
	var voice = 1.0
	var max_pitch = 2.4
	var is_race = false

	if body == "roadster":
		voice = 0.85
	elif body == "coupe" or "gt" in body:
		voice = 0.72
	elif body == "gt3" or "296" in car_name:
		voice = 1.06
		is_race = true
	elif "f2004" in car_name or redline > 17000:
		voice = 1.36
		max_pitch = 3.2
		is_race = true
	elif "rb19" in car_name or redline > 13000:
		voice = 1.16
		max_pitch = 2.7
		is_race = true

	for i in ENGINE_BANDS.size():
		var band = ENGINE_BANDS[i]
		var weight = sqrt(1 - blend) if i == lower else (sqrt(blend) if i == upper else 0.0)
		var pitch = clampf(audible_rpm / band[1] * voice, .35, max_pitch)
		var power = players["engine_" + band[0]]
		var coast = players["coast_" + band[0]]
		power.pitch_scale = pitch
		coast.pitch_scale = pitch
		power.volume_db = linear_to_db(maxf(.00001, engine_level * weight * sqrt(engine_load) * .92))
		coast.volume_db = linear_to_db(
			maxf(.00001, engine_level * weight * (sqrt(1 - engine_load) * .55 + .03))
		)
	players.intake.pitch_scale = clampf(audible_rpm / 4200 * voice, .6, 2.0)
	players.intake.volume_db = linear_to_db(maxf(.00001, engine_level * engine_load * .065))

	var slip = 0.0
	var rough = 0.0
	var kerb_load = 0.0
	var gravel_load = 0.0
	for w in car.wheels:
		if w.surf.id <= 1 or w.surf.id == 4:
			slip = maxf(
				slip,
				(
					clampf((absf(w.slipRatio) - .08) * 2 + maxf(0, absf(w.slipAngle) - .08) * 3, 0, 1)
					* minf(1, car.speed / 6)
				)
			)
		if w.surf.id == 1:
			kerb_load = maxf(kerb_load, w.load / maxf(1.0, float(car.p.get("mass", 1000.0)) * G / 4.0))
		elif w.surf.id == 3:
			gravel_load = maxf(gravel_load, w.load / maxf(1.0, float(car.p.get("mass", 1000.0)) * G / 4.0))
		rough = maxf(rough, [0.0, 1.0 / 3, 2.0 / 3, 1.0, .08][w.surf.id])

	tire_level = lerpf(tire_level, slip, 1 - exp(-dt * 18))
	players.tires.volume_db = linear_to_db(maxf(.00001, effects_level * tire_level * .26))
	players.tires.pitch_scale = clampf(0.85 + (car.speed / 100.0) * 0.3 + slip * 0.25, 0.75, 1.6)

	# Surface & kerb audio
	var road_mult = .05 + rough * .35 + gravel_load * .25
	players.road.volume_db = linear_to_db(
		maxf(.00001, effects_level * minf(car.speed / 45.0, 1) * road_mult)
	)
	players.road.pitch_scale = .7 + minf(car.speed / 55.0, 1.1) + gravel_load * .2

	players.kerb.volume_db = linear_to_db(
		maxf(.00001, effects_level * minf(car.speed / 10.0, 1.0) * minf(kerb_load, 1.5) * .30)
	)
	players.kerb.pitch_scale = clampf(0.55 + car.speed / 22.0, 0.5, 2.5)

	# Transmission gear whine
	var whine_base = 0.14 if is_race else 0.045
	var whine_load = 0.35 + 0.65 * absf(engine_load - 0.15)
	var whine_speed = clampf((car.speed - 2.0) / 40.0, 0.0, 1.0)
	players.whine.volume_db = linear_to_db(
		maxf(.00001, effects_level * whine_base * whine_speed * whine_load)
	)
	players.whine.pitch_scale = clampf(0.48 + car.speed / 22.0, 0.4, 3.2)

	# High-speed aerodynamic wind rush
	var wind_factor = clampf(pow(maxf(0.0, car.speed - 8.0) / 55.0, 1.5), 0.0, 1.6)
	players.wind.volume_db = linear_to_db(
		maxf(.00001, effects_level * wind_factor * .14)
	)
	players.wind.pitch_scale = clampf(0.75 + car.speed / 90.0, 0.65, 1.8)

	if active and car.gear != last_gear and not car.airborne:
		trigger("shift", .32 * effects_level)
	last_gear = car.gear
	impact_cooldown = maxf(0, impact_cooldown - dt)


func impact(strength):
	if impact_cooldown > 0 or not players.has("impact"):
		return
	players.impact.pitch_scale = randf_range(0.92, 1.08)
	trigger("impact", effects_level * clampf(strength / 10.0, .10, .75))
	impact_cooldown = .18


func trigger(kind, level):
	if not players.has(kind):
		return
	players[kind].volume_db = linear_to_db(maxf(.00001, level))
	if players[kind].is_inside_tree():
		players[kind].play()
