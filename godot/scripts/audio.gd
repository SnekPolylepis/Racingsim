extends Node
## Recorded CC0 engine RPM/load bank with procedural tire, road, turbo, impact,
## mechanical and environmental spatial effects.
## Multi-bus mixing architecture with peak limiter, compressor, ducking and reverb.
## Source recordings and loop edits documented in THIRD-PARTY.md.

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

var players = {}
var last_gear = 1
var impact_cooldown = 0.0
var engine_level = 0.0
var effects_level = 0.0
var tyres_level = 0.0
var world_level = 0.0
var audible_rpm = 1250.0
var engine_load = 0.0
var tire_level = 0.0
var tire_lat_level = 0.0
var tire_long_level = 0.0

# Turbo and blow-off simulation
var boost_pressure = 0.0
var target_boost = 0.0
var last_throttle = 0.0

# Rev limiter bounce simulation
var limiter_timer = 0.0
var is_limiting = false

# Overrun backfire simulation
var backfire_cooldown = 0.0

# Bottoming / chassis scrape
var scrape_level = 0.0

# Active car profile cache
var current_car_key = ""
var is_turbo_car = false
var is_hybrid_car = false
var is_race_car = false
var engine_voice = 1.0
var engine_max_pitch = 2.4

# Audio debug telemetry structure
var debug_stats = {
	"car_voice": "",
	"audible_rpm": 0.0,
	"redline": 7200.0,
	"load": 0.0,
	"boost": 0.0,
	"limiting": false,
	"layer_weights": [0.0, 0.0, 0.0, 0.0],
	"tire_lat": 0.0,
	"tire_long": 0.0,
	"surface_id": 0,
	"reverb_zone": "Open Air",
	"bus_levels": {}
}


## Safe property access helper for both Object and Dictionary
static func _prop(obj, prop_name: String, fallback = null):
	if obj == null:
		return fallback
	if obj is Dictionary:
		return obj.get(prop_name, fallback)
	var val = obj.get(prop_name)
	return val if val != null else fallback


func _ready():
	setup_audio_buses()
	_init_engine_players()
	_init_procedural_players()


## Initialize and configure standard multi-bus layout in AudioServer
static func setup_audio_buses() -> void:
	var buses = ["Engine", "Tyres", "World", "UI", "Music"]
	for b in buses:
		var idx = AudioServer.get_bus_index(b)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")

	# Master limiter: guarantees zero digital clipping across all simultaneous voices
	var master_has_limiter = false
	for e in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, e) is AudioEffectLimiter:
			master_has_limiter = true
			break
	if not master_has_limiter:
		var limiter = AudioEffectLimiter.new()
		limiter.ceiling_db = -0.2
		limiter.threshold_db = -1.2
		limiter.soft_clip_db = 2.0
		AudioServer.add_bus_effect(0, limiter)

	# Engine bus compressor: glues multi-layer on/off throttle samples smoothly
	var eng_idx = AudioServer.get_bus_index("Engine")
	if eng_idx != -1:
		var eng_has_comp = false
		for e in AudioServer.get_bus_effect_count(eng_idx):
			if AudioServer.get_bus_effect(eng_idx, e) is AudioEffectCompressor:
				eng_has_comp = true
				break
		if not eng_has_comp:
			var comp = AudioEffectCompressor.new()
			comp.threshold = -14.0
			comp.ratio = 3.5
			comp.attack_us = 15000.0
			comp.release_ms = 120.0
			comp.gain = 1.0
			AudioServer.add_bus_effect(eng_idx, comp)

	# Tyres bus compressor
	var tyres_idx = AudioServer.get_bus_index("Tyres")
	if tyres_idx != -1:
		var tyres_has_comp = false
		for e in AudioServer.get_bus_effect_count(tyres_idx):
			if AudioServer.get_bus_effect(tyres_idx, e) is AudioEffectCompressor:
				tyres_has_comp = true
				break
		if not tyres_has_comp:
			var comp = AudioEffectCompressor.new()
			comp.threshold = -10.0
			comp.ratio = 2.5
			comp.attack_us = 10000.0
			comp.release_ms = 80.0
			AudioServer.add_bus_effect(tyres_idx, comp)

	# World bus reverb zone
	var world_idx = AudioServer.get_bus_index("World")
	if world_idx != -1:
		var world_has_reverb = false
		for e in AudioServer.get_bus_effect_count(world_idx):
			if AudioServer.get_bus_effect(world_idx, e) is AudioEffectReverb:
				world_has_reverb = true
				break
		if not world_has_reverb:
			var reverb = AudioEffectReverb.new()
			reverb.room_size = 0.2
			reverb.damping = 0.7
			reverb.spread = 1.0
			reverb.wet = 0.06
			reverb.dry = 0.95
			AudioServer.add_bus_effect(world_idx, reverb)


func _init_engine_players():
	for band in ENGINE_BANDS:
		for layer in 2:
			var name = ("engine_" if layer == 0 else "coast_") + band[0]
			var stream = band[2 + layer].duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2
			var p = AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Engine"
			p.volume_db = -80
			add_child(p)
			players[name] = p
			if p.is_inside_tree():
				p.play()


func _init_procedural_players():
	var proc_specs = [
		# [name, is_loop, bus_name]
		["intake", true, "Engine"],
		["turbo", true, "Engine"],
		["blowoff", false, "Engine"],
		["electric_whine", true, "Engine"],
		["whine", true, "Engine"],
		["shift", false, "Engine"],
		["shift_cut", false, "Engine"],
		["shift_blip", false, "Engine"],
		["backfire", false, "Engine"],
		["starter", false, "Engine"],
		["shutdown", false, "Engine"],
		["tires", true, "Tyres"],
		["tires_lat", true, "Tyres"],
		["tires_long", true, "Tyres"],
		["road", true, "Tyres"],
		["kerb", true, "Tyres"],
		["gravel", true, "Tyres"],
		["grass", true, "Tyres"],
		["wet_spray", true, "Tyres"],
		["scrape", true, "Tyres"],
		["wind", true, "World"],
		["impact", false, "World"],
		["impact_armco", false, "World"],
		["impact_tyre", false, "World"],
		["impact_concrete", false, "World"],
		["impact_prop", false, "World"],
		["ghost_pass", true, "World"],
		["crowd", true, "World"],
		["spa_ambience", true, "World"]
	]

	for spec in proc_specs:
		var name = spec[0]
		var loop = spec[1]
		var bus_name = spec[2]
		var p = AudioStreamPlayer.new()
		p.stream = make_sound(name)
		p.bus = bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
		p.volume_db = -80
		add_child(p)
		players[name] = p
		if loop and p.is_inside_tree():
			p.play()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for p in players.values():
			p.stop()
			p.stream = null
		players.clear()
	elif what == NOTIFICATION_ENTER_TREE:
		for name in players:
			var p = players[name]
			if p.stream and p.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
				if not p.playing and p.is_inside_tree():
					p.play()


## Create a deterministic 22,050 Hz signed-16-bit mono stream with seamless loop fading.
func make_sound(kind: String) -> AudioStreamWAV:
	var one_shot_durations = {
		"impact": 0.24,
		"impact_armco": 0.32,
		"impact_tyre": 0.26,
		"impact_concrete": 0.28,
		"impact_prop": 0.18,
		"shift": 0.09,
		"shift_cut": 0.08,
		"shift_blip": 0.16,
		"backfire": 0.14,
		"blowoff": 0.38,
		"starter": 0.75,
		"shutdown": 0.85
	}
	var loop = not one_shot_durations.has(kind)
	var count = RATE if loop else int(RATE * one_shot_durations[kind])
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 470 + kind.hash()
	var filtered = 0.0
	var filtered_hi = 0.0

	for i in count:
		var t = float(i) / RATE
		var noise = rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.13)
		filtered_hi = lerpf(filtered_hi, noise - filtered, 0.35)
		var value = 0.0

		match kind:
			"intake":
				value = (noise - filtered) * 0.16
			"turbo":
				# High-speed compressor impeller spool whistle with subtle air vortex
				var whistle = sin(TAU * 2600.0 * t + sin(TAU * 42.0 * t) * 0.8) * 0.32
				var hiss = (noise - filtered) * 0.15
				value = whistle + hiss
			"blowoff":
				# Compressor flutter on sudden throttle lift-off
				var flutter = sin(TAU * 26.0 * t) * 0.4 + 0.6
				var air_dump = (filtered_hi * 0.6 + noise * 0.25) * flutter * exp(-t * 9.5)
				var chirp = sin(TAU * (2100.0 - 1200.0 * t) * t) * 0.22 * exp(-t * 16.0)
				value = air_dump + chirp
			"electric_whine":
				# Modern F1 hybrid MGU-K electric motor whine (dual harmonic)
				value = (
					sin(TAU * 1100.0 * t) * 0.32 + sin(TAU * 2200.0 * t) * 0.18 + sin(TAU * 3300.0 * t) * 0.08
				)
			"tires", "tires_lat":
				# Lateral scrub: dynamic friction rubber screech
				var scrub = filtered * 0.22 + (noise - filtered) * 0.12
				var screech = (
					sin(TAU * 880.0 * t + sin(TAU * 21.0 * t) * 1.1) * 0.24 + sin(TAU * 1320.0 * t) * 0.14
				)
				value = scrub + screech
			"tires_long":
				# Longitudinal slip: lower-pitched wheelspin tear and braking lockup scrub
				var tear = filtered * 0.38 + noise * 0.12
				var groan = (
					sin(TAU * 540.0 * t + sin(TAU * 16.0 * t) * 1.4) * 0.28 + sin(TAU * 810.0 * t) * 0.12
				)
				value = tear + groan
			"road":
				value = filtered * 0.55 + (noise - filtered) * 0.08
			"wind":
				value = (filtered * 0.42 + (noise - filtered) * 0.10 + sin(TAU * 48.0 * t) * 0.15) * 0.75
			"whine":
				value = (
					sin(TAU * 480.0 * t) * 0.32
					+ sin(TAU * 960.0 * t) * 0.20
					+ sin(TAU * 1440.0 * t) * 0.08
					+ (noise - filtered) * 0.06
				)
			"kerb":
				var rib_pulse = sin(TAU * 160.0 * t) * 0.40 + sin(TAU * 320.0 * t) * 0.18
				var edge_snap = (noise * 0.25) * pow(maxf(0.0, sin(TAU * 80.0 * t)), 4.0)
				value = rib_pulse + edge_snap
			"gravel":
				# Heavy pebble spray and underbody stones
				var gravel_roar = filtered * 0.45
				var pebble = 0.85 if rng.randf() > 0.982 else 0.0
				value = gravel_roar + pebble + (noise - filtered) * 0.18
			"grass":
				# Earthy turf rustle
				value = (filtered * 0.48 + sin(TAU * 85.0 * t) * 0.12) * 0.70
			"wet_spray":
				# High-speed wet road water plume hiss
				value = (noise - filtered) * 0.52 + sin(TAU * 3400.0 * t) * 0.06
			"scrape":
				# Titanium / steel skid-block bottoming on asphalt
				var rasp = (noise - filtered) * 0.45 + filtered * 0.25
				var spark = (noise * 0.5) if rng.randf() > 0.96 else 0.0
				value = rasp + spark
			"impact", "impact_concrete":
				# Concrete wall crunch
				var thud = sin(TAU * (85.0 - 55.0 * t) * t) * 0.45 * exp(-t * 22.0)
				var crunch = (filtered * 0.65 + noise * 0.35) * exp(-t * 28.0)
				value = (thud + crunch) * minf(t * 800.0, 1.0)
			"impact_armco":
				# Armco steel barrier clang and resonant deformation
				var clang = (
					sin(TAU * 110.0 * t) * 0.35 * exp(-t * 14.0)
					+ sin(TAU * 420.0 * t) * 0.28 * exp(-t * 12.0)
					+ sin(TAU * 840.0 * t) * 0.18 * exp(-t * 18.0)
				)
				var rattle = (filtered * 0.45 + (noise - filtered) * 0.25) * exp(-t * 24.0)
				value = (clang + rattle) * minf(t * 800.0, 1.0)
			"impact_tyre":
				# Tyre wall soft heavy impact thud
				var bounce = sin(TAU * (55.0 - 25.0 * t) * t) * 0.65 * exp(-t * 18.0)
				var rub = (filtered * 0.40) * exp(-t * 32.0)
				value = (bounce + rub) * minf(t * 500.0, 1.0)
			"impact_prop":
				# Plastic cone / lightweight trackside marker board
				var knock = sin(TAU * 320.0 * t) * 0.42 * exp(-t * 38.0)
				var splinter = (noise - filtered) * 0.32 * exp(-t * 42.0)
				value = (knock + splinter) * minf(t * 1000.0, 1.0)
			"shift":
				var clack = sin(TAU * 220.0 * t) * 0.35 * exp(-t * 70.0)
				var snap = (filtered * 0.45 + (noise - filtered) * 0.25) * exp(-t * 90.0)
				value = (clack + snap) * minf(t * 1000.0, 1.0)
			"shift_cut":
				# Ignition cut pop
				var pop = sin(TAU * (140.0 - 80.0 * t) * t) * 0.55 * exp(-t * 55.0)
				var hiss = (noise - filtered) * 0.35 * exp(-t * 75.0)
				value = (pop + hiss) * minf(t * 1000.0, 1.0)
			"shift_blip":
				# Throttle blip with overrun burble
				var rev = sin(TAU * (160.0 + 80.0 * t) * t) * 0.38 * exp(-t * 16.0)
				var burble = sin(TAU * 65.0 * t) * 0.25 * exp(-t * 14.0)
				value = rev + burble
			"backfire":
				# Exhaust overrun pop / crackle
				var report = (1.0 if t < 0.006 else -0.5 * exp(-t * 60.0)) * 0.70
				var crackle = (noise * 0.40) * exp(-t * 45.0)
				value = report + crackle
			"starter":
				# Starter motor cranking and fire up
				var crank = (
					(sin(TAU * 32.0 * t) * 0.35 + filtered * 0.2)
					* (1.0 if t < 0.45 else exp(-(t - 0.45) * 8.0))
				)
				var fire = (
					(sin(TAU * 85.0 * (t - 0.45)) * 0.45 * exp(-(t - 0.45) * 6.0)) if t >= 0.45 else 0.0
				)
				value = crank + fire
			"shutdown":
				# Engine spooling down to stop
				var spin = sin(TAU * (110.0 * (1.0 - t)) * t) * 0.40 * (1.0 - t)
				var hiss = filtered * 0.22 * (1.0 - t)
				value = spin + hiss
			"ghost_pass":
				# Spatial engine drone passing by
				var drone = (
					sin(TAU * 310.0 * t + sin(TAU * 12.0 * t) * 0.8) * 0.35
					+ sin(TAU * 620.0 * t) * 0.22
					+ filtered * 0.15
				)
				value = drone
			"crowd":
				# Distant circuit spectator crowd murmur and cheers
				var murmur = (filtered * 0.28 + sin(TAU * 2.5 * t) * 0.10) * 0.60
				value = murmur
			"spa_ambience":
				# Ardennes forest wind in pines and distant birds
				var trees = filtered * 0.25 + (noise - filtered) * 0.08
				var bird = 0.0
				if (t > 0.2 and t < 0.32) or (t > 0.68 and t < 0.78):
					bird = sin(TAU * 2800.0 * t + sin(TAU * 45.0 * t) * 2.5) * 0.14
				value = trees + bird

		if loop:
			# Smooth crossfade at loop boundary to guarantee zero clicks or pops
			value *= minf(1.0, minf(t * 100.0, (1.0 - t) * 100.0))

		bytes.encode_s16(i * 2, int(clampf(value, -0.95, 0.95) * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream


## Inspect car specification from data/cars.json and configure sound profile
func _update_car_voice(car) -> void:
	var spec = car.p if ("p" in car and car.p is Dictionary) else {}
	var body = str(spec.get("body", ""))
	var car_name = str(spec.get("name", "")).to_lower()
	var redline = float(spec.get("redline", 7200.0))

	var car_key = body + "_" + str(int(redline))
	if car_key == current_car_key:
		return
	current_car_key = car_key

	engine_voice = 1.0
	engine_max_pitch = 2.4
	is_race_car = false
	is_turbo_car = false
	is_hybrid_car = false

	if body == "roadster":
		# MX-5 NA 1.6 Inline-4: buzzy, raw 4-cylinder bark
		engine_voice = 0.85
		debug_stats.car_voice = "Mazda MX-5 Inline-4"
	elif body == "gt3" or "296" in car_name or "gt3" in body:
		# Ferrari 296 GT3: 120° V6 Twin-Turbo
		engine_voice = 1.06
		is_race_car = true
		is_turbo_car = true
	elif body == "coupe" or body == "gt":
		# Grand Tourer V8: deep throaty baritone crossplane rumble
		engine_voice = 0.72
		debug_stats.car_voice = "Grand Tourer V8"
	elif "f2004" in car_name or redline > 17000.0:
		# Ferrari F2004: Screaming 3.0L Tipo 053 V10
		engine_voice = 1.36
		engine_max_pitch = 3.2
		is_race_car = true
		debug_stats.car_voice = "Ferrari F2004 3.0L V10"
	elif "rb19" in car_name or redline > 13000.0:
		# Red Bull RB19: 1.6L Turbo V6 Hybrid + MGU-K
		engine_voice = 1.16
		engine_max_pitch = 2.7
		is_race_car = true
		is_turbo_car = true
		is_hybrid_car = true
		debug_stats.car_voice = "Red Bull RB19 1.6L V6 Hybrid"
	else:
		debug_stats.car_voice = "Standard Engine"


## Smooth master/category gains, pitch from RPM and effects from slip/speed/surface.
func update(car, dt: float, active: bool, settings: Dictionary) -> void:
	if players.is_empty():
		return

	_update_car_voice(car)

	var master_gain = (
		0.0 if (settings.get("mute", false) or not active) else float(settings.get("volume", 0.7))
	)
	var eng_setting = float(settings.get("engine_volume", 0.85))
	var eff_setting = float(settings.get("effects_volume", 0.7))
	var tyres_setting = float(settings.get("tyres_volume", eff_setting))
	var world_setting = float(settings.get("world_volume", eff_setting))

	engine_level = lerpf(engine_level, master_gain * eng_setting, 1.0 - exp(-dt * 14.0))
	effects_level = lerpf(effects_level, master_gain * eff_setting, 1.0 - exp(-dt * 14.0))
	tyres_level = lerpf(tyres_level, master_gain * tyres_setting, 1.0 - exp(-dt * 14.0))
	world_level = lerpf(world_level, master_gain * world_setting, 1.0 - exp(-dt * 14.0))

	# Apply bus volumes to Godot AudioServer
	_update_bus_volumes(settings, master_gain)

	var car_rpm = float(car.rpm) if "rpm" in car else 1250.0
	var car_speed = float(car.speed) if "speed" in car else 0.0
	var redline = float(car.p.get("redline", 7200.0)) if ("p" in car and car.p is Dictionary) else 7200.0

	# Rev limiter bounce detection
	is_limiting = car_rpm >= redline * 0.985 or bool(car.get("rev_limit") if "rev_limit" in car else false)
	if is_limiting:
		limiter_timer += dt
		# 22 Hz rapid limiter bounce
		var limit_phase = sin(limiter_timer * 138.0)
		if limit_phase > 0.2:
			car_rpm = redline * 0.965
			if backfire_cooldown <= 0.0:
				trigger("backfire", engine_level * 0.45)
				backfire_cooldown = 0.08
	else:
		limiter_timer = 0.0

	audible_rpm = lerpf(audible_rpm, maxf(400.0, car_rpm), 1.0 - exp(-dt * 24.0))

	var raw_throttle = clampf(float(car.throttle_eff if "throttle_eff" in car else 0.0), 0.0, 1.0)
	var load_target = raw_throttle
	if "shift_timer" in car and car.shift_timer > 0.0:
		load_target *= 0.12  # Upshift cut
	engine_load = lerpf(engine_load, load_target, 1.0 - exp(-dt * 25.0))

	# Turbo simulation: boost spools with throttle and RPM, vents on sudden lift
	if is_turbo_car:
		var boost_spool = raw_throttle * clampf((audible_rpm - 2200.0) / (redline - 2200.0), 0.0, 1.0)
		target_boost = boost_spool
		boost_pressure = lerpf(boost_pressure, target_boost, 1.0 - exp(-dt * 4.2))

		# Sudden throttle lift-off triggers blow-off valve
		if raw_throttle < last_throttle - 0.28 and boost_pressure > 0.25:
			trigger("blowoff", engine_level * clampf(boost_pressure * 0.85, 0.2, 0.75))
			boost_pressure *= 0.15  # Vent boost
		last_throttle = raw_throttle

		if players.has("turbo"):
			players.turbo.volume_db = linear_to_db(maxf(0.00001, engine_level * boost_pressure * 0.24))
			players.turbo.pitch_scale = clampf(
				0.75 + boost_pressure * 1.5 + (audible_rpm / redline) * 0.4, 0.65, 2.5
			)

		if is_hybrid_car and players.has("electric_whine"):
			# MGU-K electric motor regenerative whine on throttle and braking
			var mgu_load = maxf(
				raw_throttle, float(car.input.brake if ("input" in car and "brake" in car.input) else 0.0)
			)
			var mgu_speed = clampf(car_speed / 75.0, 0.0, 1.2)
			players.electric_whine.volume_db = linear_to_db(
				maxf(0.00001, engine_level * mgu_load * mgu_speed * 0.16)
			)
			players.electric_whine.pitch_scale = clampf(0.6 + car_speed / 38.0, 0.5, 2.8)

	# RPM layer crossfading
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
		0.0,
		1.0
	)

	for i in ENGINE_BANDS.size():
		var band = ENGINE_BANDS[i]
		var weight = sqrt(1.0 - blend) if i == lower else (sqrt(blend) if i == upper else 0.0)
		debug_stats.layer_weights[i] = weight
		var pitch = clampf(audible_rpm / band[1] * engine_voice, 0.35, engine_max_pitch)
		var power = players["engine_" + band[0]]
		var coast = players["coast_" + band[0]]
		power.pitch_scale = pitch
		coast.pitch_scale = pitch
		power.volume_db = linear_to_db(maxf(0.00001, engine_level * weight * sqrt(engine_load) * 0.92))
		coast.volume_db = linear_to_db(
			maxf(0.00001, engine_level * weight * (sqrt(1.0 - engine_load) * 0.55 + 0.03))
		)

	players.intake.pitch_scale = clampf(audible_rpm / 4200.0 * engine_voice, 0.6, 2.0)
	players.intake.volume_db = linear_to_db(maxf(0.00001, engine_level * engine_load * 0.065))

	# Tyre slip, surfaces, and road interaction
	var slip = 0.0
	var slip_lat = 0.0
	var slip_long = 0.0
	var rough = 0.0
	var kerb_load = 0.0
	var gravel_load = 0.0
	var grass_load = 0.0
	var active_surface = 0

	var car_wheels = car.wheels if "wheels" in car else []
	var car_mass = float(car.p.get("mass", 1000.0)) if ("p" in car and car.p is Dictionary) else 1000.0
	var nominal_wheel_load = maxf(1.0, car_mass * G / 4.0)

	for w in car_wheels:
		var s_id = int(w.surf.id if ("surf" in w and "id" in w.surf) else 0)
		active_surface = s_id
		var s_angle = absf(float(w.slipAngle if "slipAngle" in w else 0.0))
		var s_ratio = absf(float(w.slipRatio if "slipRatio" in w else 0.0))
		var w_load = float(w.load if "load" in w else nominal_wheel_load)

		if s_id <= 1 or s_id == 4:
			var lat_contrib = clampf((s_angle - 0.07) * 3.2, 0.0, 1.0) * minf(1.0, car_speed / 5.0)
			var long_contrib = clampf((s_ratio - 0.08) * 2.8, 0.0, 1.0) * minf(1.0, car_speed / 5.0)
			slip_lat = maxf(slip_lat, lat_contrib)
			slip_long = maxf(slip_long, long_contrib)
			slip = maxf(slip, maxf(lat_contrib, long_contrib))

		if s_id == 1:
			kerb_load = maxf(kerb_load, w_load / nominal_wheel_load)
		elif s_id == 2:
			grass_load = maxf(grass_load, w_load / nominal_wheel_load)
		elif s_id == 3:
			gravel_load = maxf(gravel_load, w_load / nominal_wheel_load)

		rough = maxf(rough, [0.0, 0.33, 0.67, 1.0, 0.08][clampi(s_id, 0, 4)])

	tire_level = lerpf(tire_level, slip, 1.0 - exp(-dt * 18.0))
	tire_lat_level = lerpf(tire_lat_level, slip_lat, 1.0 - exp(-dt * 18.0))
	tire_long_level = lerpf(tire_long_level, slip_long, 1.0 - exp(-dt * 18.0))

	# Master tire player (legacy compatibility)
	players.tires.volume_db = linear_to_db(maxf(0.00001, tyres_level * tire_level * 0.28))
	players.tires.pitch_scale = clampf(0.85 + (car_speed / 100.0) * 0.3 + slip * 0.25, 0.75, 1.6)

	# Dedicated lateral and longitudinal tyre audio
	players.tires_lat.volume_db = linear_to_db(maxf(0.00001, tyres_level * tire_lat_level * 0.26))
	players.tires_lat.pitch_scale = clampf(0.92 + (car_speed / 110.0) * 0.25, 0.8, 1.7)

	players.tires_long.volume_db = linear_to_db(maxf(0.00001, tyres_level * tire_long_level * 0.24))
	players.tires_long.pitch_scale = clampf(0.78 + (car_speed / 90.0) * 0.28, 0.65, 1.5)

	# Road rolling hum and surface textures
	var road_mult = 0.05 + rough * 0.35 + gravel_load * 0.25
	players.road.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * minf(car_speed / 45.0, 1.0) * road_mult)
	)
	players.road.pitch_scale = 0.7 + minf(car_speed / 55.0, 1.1) + gravel_load * 0.2

	# Kerb thrumming
	players.kerb.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * minf(car_speed / 10.0, 1.0) * minf(kerb_load, 1.5) * 0.32)
	)
	players.kerb.pitch_scale = clampf(0.55 + car_speed / 20.0, 0.5, 2.5)

	# Gravel trap roar
	if players.has("gravel"):
		players.gravel.volume_db = linear_to_db(
			maxf(0.00001, tyres_level * minf(gravel_load, 1.5) * minf(car_speed / 15.0, 1.0) * 0.38)
		)
		players.gravel.pitch_scale = clampf(0.8 + car_speed / 35.0, 0.7, 1.6)

	# Grass rustle
	if players.has("grass"):
		players.grass.volume_db = linear_to_db(
			maxf(0.00001, tyres_level * minf(grass_load, 1.5) * minf(car_speed / 20.0, 1.0) * 0.25)
		)

	# Chassis bottoming / scrape
	var scrape_hits = car.get("scrape_hits") if "scrape_hits" in car else []
	var is_scraping = scrape_hits != null and scrape_hits.size() > 0
	scrape_level = lerpf(scrape_level, 1.0 if is_scraping else 0.0, 1.0 - exp(-dt * 20.0))
	if players.has("scrape"):
		players.scrape.volume_db = linear_to_db(maxf(0.00001, tyres_level * scrape_level * 0.32))
		players.scrape.pitch_scale = randf_range(0.95, 1.15)

	# Transmission spur gear whine
	var whine_base = 0.16 if is_race_car else 0.045
	var whine_load = 0.35 + 0.65 * absf(engine_load - 0.15)
	var whine_speed = clampf((car_speed - 2.0) / 40.0, 0.0, 1.0)
	players.whine.volume_db = linear_to_db(
		maxf(0.00001, engine_level * whine_base * whine_speed * whine_load)
	)
	players.whine.pitch_scale = clampf(0.48 + car_speed / 22.0, 0.4, 3.2)

	# Aerodynamic wind rush (perspective aware)
	var camera_mode = int(settings.get("camera", 0))
	var cockpit_boost = 1.35 if (camera_mode == 1 or camera_mode == 2) else 1.0
	var wind_factor = clampf(pow(maxf(0.0, car_speed - 8.0) / 52.0, 1.5), 0.0, 1.7) * cockpit_boost
	players.wind.volume_db = linear_to_db(maxf(0.00001, world_level * wind_factor * 0.15))
	players.wind.pitch_scale = clampf(
		0.75 + car_speed / 85.0 + (0.1 if cockpit_boost > 1.0 else 0.0), 0.65, 1.85
	)

	# Update environmental trackside audio and reverb zones
	_update_environment(car, car_speed)

	# Gear shift handling
	var car_gear = int(car.gear) if "gear" in car else 1
	var car_airborne = bool(car.airborne if "airborne" in car else false)
	if active and car_gear != last_gear and not car_airborne:
		if car_gear > last_gear:
			# Upshift cut
			trigger("shift_cut", 0.35 * engine_level)
			trigger("shift", 0.28 * effects_level)
		else:
			# Downshift blip
			trigger("shift_blip", 0.38 * engine_level)
			trigger("shift", 0.30 * effects_level)
			if audible_rpm > redline * 0.65:
				trigger("backfire", 0.40 * engine_level)
	last_gear = car_gear
	impact_cooldown = maxf(0.0, impact_cooldown - dt)
	backfire_cooldown = maxf(0.0, backfire_cooldown - dt)

	# Update debug stats for HUD telemetry overlay
	debug_stats.audible_rpm = audible_rpm
	debug_stats.redline = redline
	debug_stats.load = engine_load
	debug_stats.boost = boost_pressure
	debug_stats.limiting = is_limiting
	debug_stats.tire_lat = tire_lat_level
	debug_stats.tire_long = tire_long_level
	debug_stats.surface_id = active_surface


## Update environmental audio (Spa ambience, crowd, and reverb zones)
func _update_environment(car, speed: float) -> void:
	var parent = get_parent()
	if parent == null:
		return

	var track_name = str(_prop(parent, "active_track_file", "")).to_lower()
	var is_spa = "spa" in track_name

	# Spa ambient forest birds and breeze
	if is_spa and players.has("spa_ambience"):
		var amb_vol = clampf((80.0 - speed) / 60.0, 0.15, 0.85) * world_level * 0.25
		players.spa_ambience.volume_db = linear_to_db(maxf(0.00001, amb_vol))

	# Reverb zone configuration based on track position
	var world_idx = AudioServer.get_bus_index("World")
	if world_idx != -1 and AudioServer.get_bus_effect_count(world_idx) > 0:
		var effect = AudioServer.get_bus_effect(world_idx, 0)
		if effect is AudioEffectReverb:
			var car_x = float(_prop(car, "pos_x", 0.0))
			var car_z = float(_prop(car, "pos_z", 0.0))
			var pos_2d = Vector2(car_x, car_z)

			# Tunnel or bridge check
			var in_tunnel = false
			var near_grandstand = false

			if is_spa:
				# Spa pit straight / Raidillon grandstands: car_z ~ -200 to 400
				if absf(car_x) < 300.0 and car_z > -250.0 and car_z < 350.0:
					near_grandstand = true
			elif "monaco" in track_name:
				# Monaco tunnel check
				if pos_2d.length() > 200.0 and pos_2d.length() < 450.0:
					in_tunnel = true

			if in_tunnel:
				debug_stats.reverb_zone = "Tunnel / Underpass"
				effect.room_size = 0.85
				effect.damping = 0.25
				effect.wet = 0.35
				effect.dry = 0.70
			elif near_grandstand:
				debug_stats.reverb_zone = "Grandstand Slap-Back"
				effect.room_size = 0.42
				effect.damping = 0.35
				effect.wet = 0.18
				effect.dry = 0.85
				if players.has("crowd"):
					players.crowd.volume_db = linear_to_db(maxf(0.00001, world_level * 0.22))
			else:
				debug_stats.reverb_zone = "Open Air"
				effect.room_size = 0.18
				effect.damping = 0.75
				effect.wet = 0.05
				effect.dry = 0.95
				if players.has("crowd"):
					players.crowd.volume_db = -80.0


func _update_bus_volumes(settings: Dictionary, master_gain: float) -> void:
	if AudioServer.bus_count <= 1:
		return
	var eng_idx = AudioServer.get_bus_index("Engine")
	var tyres_idx = AudioServer.get_bus_index("Tyres")
	var world_idx = AudioServer.get_bus_index("World")
	var ui_idx = AudioServer.get_bus_index("UI")
	var music_idx = AudioServer.get_bus_index("Music")

	var eff = float(settings.get("effects_volume", 0.7))
	if eng_idx != -1:
		AudioServer.set_bus_volume_db(
			eng_idx, linear_to_db(maxf(0.0001, float(settings.get("engine_volume", 0.85))))
		)
	if tyres_idx != -1:
		AudioServer.set_bus_volume_db(
			tyres_idx, linear_to_db(maxf(0.0001, float(settings.get("tyres_volume", eff))))
		)
	if world_idx != -1:
		AudioServer.set_bus_volume_db(
			world_idx, linear_to_db(maxf(0.0001, float(settings.get("world_volume", eff))))
		)
	if ui_idx != -1:
		AudioServer.set_bus_volume_db(
			ui_idx, linear_to_db(maxf(0.0001, float(settings.get("ui_volume", 0.8))))
		)
	if music_idx != -1:
		AudioServer.set_bus_volume_db(
			music_idx, linear_to_db(maxf(0.0001, float(settings.get("music_volume", 0.7))))
		)


## Collision impact with material differentiation (armco, tyre wall, concrete, props)
func impact(strength: float, kind: String = "impact") -> void:
	if impact_cooldown > 0.0:
		return

	var player_key = "impact"
	if kind == "armco" and players.has("impact_armco"):
		player_key = "impact_armco"
	elif kind == "tyre" and players.has("impact_tyre"):
		player_key = "impact_tyre"
	elif (kind == "concrete" or kind == "wall") and players.has("impact_concrete"):
		player_key = "impact_concrete"
	elif kind == "prop" and players.has("impact_prop"):
		player_key = "impact_prop"

	if players.has(player_key):
		players[player_key].pitch_scale = randf_range(0.92, 1.08)
		trigger(player_key, world_level * clampf(strength / 9.0, 0.12, 0.85))

	# Trigger fallback impact player for compatibility
	if player_key != "impact" and players.has("impact"):
		trigger("impact", world_level * clampf(strength / 12.0, 0.08, 0.60))

	impact_cooldown = 0.18


func trigger(kind: String, level: float) -> void:
	if not players.has(kind):
		return
	players[kind].volume_db = linear_to_db(maxf(0.00001, level))
	if players[kind].is_inside_tree():
		players[kind].play()


func start_engine() -> void:
	trigger("starter", engine_level * 0.7)


func stop_engine() -> void:
	trigger("shutdown", engine_level * 0.6)
