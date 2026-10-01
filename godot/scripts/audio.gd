extends Node
## Recorded CC0 per-car engine RPM/load banks with physical tire, road, turbo, impact,
## mechanical and environmental spatial effects.
## Multi-bus mixing architecture with peak limiter, compressor, sidechain ducking and reverb.
## Source recordings, synthesis pipelines and loop edits documented in THIRD-PARTY.md.

const RATE = 22050
const G = 9.81
const SOUND_SPEED = 343.0  # Speed of sound in m/s

# Default fallback engine bands (backwards compatible with legacy tests)
const DEFAULT_ENGINE_BANDS = [
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

# Per-car physical engine bank configurations
const CAR_BANK_CONFIGS = {
	"roadster":
	{
		"name": "Mazda MX-5 NA Inline-4",
		"idle_rpm": 850.0,
		"bands":
		[
			[
				"idle",
				850.0,
				"res://assets/audio/roadster_idle_power.wav",
				"res://assets/audio/roadster_idle_coast.wav"
			],
			[
				"low",
				2200.0,
				"res://assets/audio/roadster_low_power.wav",
				"res://assets/audio/roadster_low_coast.wav"
			],
			[
				"mid",
				4200.0,
				"res://assets/audio/roadster_mid_power.wav",
				"res://assets/audio/roadster_mid_coast.wav"
			],
			[
				"high",
				6800.0,
				"res://assets/audio/roadster_high_power.wav",
				"res://assets/audio/roadster_high_coast.wav"
			]
		],
		"voice": 1.0,
		"max_pitch": 2.4,
		"is_turbo": false,
		"is_hybrid": false,
		"is_race": false,
		"resonance_freq": 240.0
	},
	"f296gt3":
	{
		"name": "Ferrari 296 GT3 V6 Twin-Turbo",
		"idle_rpm": 1250.0,
		"bands":
		[
			[
				"idle",
				1250.0,
				"res://assets/audio/f296gt3_idle_power.wav",
				"res://assets/audio/f296gt3_idle_coast.wav"
			],
			[
				"low",
				2800.0,
				"res://assets/audio/f296gt3_low_power.wav",
				"res://assets/audio/f296gt3_low_coast.wav"
			],
			[
				"mid",
				5200.0,
				"res://assets/audio/f296gt3_mid_power.wav",
				"res://assets/audio/f296gt3_mid_coast.wav"
			],
			[
				"high",
				6800.0,
				"res://assets/audio/f296gt3_high_power.wav",
				"res://assets/audio/f296gt3_high_coast.wav"
			]
		],
		"voice": 1.0,
		"max_pitch": 2.5,
		"is_turbo": true,
		"is_hybrid": false,
		"is_race": true,
		"resonance_freq": 380.0
	},
	"gt":
	{
		"name": "Grand Tourer Crossplane V8",
		"idle_rpm": 750.0,
		"bands":
		[
			["idle", 750.0, "res://assets/audio/gt_idle_power.wav", "res://assets/audio/gt_idle_coast.wav"],
			["low", 1800.0, "res://assets/audio/gt_low_power.wav", "res://assets/audio/gt_low_coast.wav"],
			["mid", 3600.0, "res://assets/audio/gt_mid_power.wav", "res://assets/audio/gt_mid_coast.wav"],
			["high", 6200.0, "res://assets/audio/gt_high_power.wav", "res://assets/audio/gt_high_coast.wav"]
		],
		"voice": 1.0,
		"max_pitch": 2.2,
		"is_turbo": false,
		"is_hybrid": false,
		"is_race": false,
		"resonance_freq": 160.0
	},
	"f2004":
	{
		"name": "Ferrari F2004 3.0L V10",
		"idle_rpm": 3500.0,
		"bands":
		[
			[
				"idle",
				3500.0,
				"res://assets/audio/f2004_idle_power.wav",
				"res://assets/audio/f2004_idle_coast.wav"
			],
			[
				"low",
				6500.0,
				"res://assets/audio/f2004_low_power.wav",
				"res://assets/audio/f2004_low_coast.wav"
			],
			[
				"mid",
				11000.0,
				"res://assets/audio/f2004_mid_power.wav",
				"res://assets/audio/f2004_mid_coast.wav"
			],
			[
				"high",
				16500.0,
				"res://assets/audio/f2004_high_power.wav",
				"res://assets/audio/f2004_high_coast.wav"
			]
		],
		"voice": 1.0,
		"max_pitch": 3.2,
		"is_turbo": false,
		"is_hybrid": false,
		"is_race": true,
		"resonance_freq": 650.0
	},
	"rb19":
	{
		"name": "Red Bull RB19 1.6L V6 Turbo Hybrid",
		"idle_rpm": 4000.0,
		"bands":
		[
			[
				"idle",
				4000.0,
				"res://assets/audio/rb19_idle_power.wav",
				"res://assets/audio/rb19_idle_coast.wav"
			],
			["low", 7000.0, "res://assets/audio/rb19_low_power.wav", "res://assets/audio/rb19_low_coast.wav"],
			[
				"mid",
				10500.0,
				"res://assets/audio/rb19_mid_power.wav",
				"res://assets/audio/rb19_mid_coast.wav"
			],
			[
				"high",
				14000.0,
				"res://assets/audio/rb19_high_power.wav",
				"res://assets/audio/rb19_high_coast.wav"
			]
		],
		"voice": 1.0,
		"max_pitch": 2.7,
		"is_turbo": true,
		"is_hybrid": true,
		"is_race": true,
		"resonance_freq": 420.0
	}
}

var current_engine_bands = DEFAULT_ENGINE_BANDS
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
var overrun_timer = 0.0
var overrun_intensity = 0.0

# Wall acoustic occlusion
var wall_occlusion_factor = 0.0

# Trackside marshal post timer
var marshal_pass_cooldown = 0.0

# Bottoming / chassis scrape
var scrape_level = 0.0

# Active car profile cache
var current_car_key = ""
var is_turbo_car = false
var is_hybrid_car = false
var is_race_car = false
var engine_voice = 1.0
var engine_max_pitch = 2.4
var active_resonance_freq = 240.0

# Mix Preset ("Cockpit", "Chase", "TV")
var active_mix_preset = "Chase"

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
	"mix_preset": "Chase",
	"ducking_db": 0.0,
	"wall_occlusion": 0.0,
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
		var eng_has_eq = false
		for e in AudioServer.get_bus_effect_count(eng_idx):
			var eff = AudioServer.get_bus_effect(eng_idx, e)
			if eff is AudioEffectCompressor:
				eng_has_comp = true
			elif eff is AudioEffectEQ6:
				eng_has_eq = true
		if not eng_has_comp:
			var comp = AudioEffectCompressor.new()
			comp.threshold = -9.0
			comp.ratio = 2.2
			comp.attack_us = 25000.0
			comp.release_ms = 140.0
			comp.gain = 1.0
			AudioServer.add_bus_effect(eng_idx, comp)
		if not eng_has_eq:
			var eq = AudioEffectEQ6.new()
			for b in 6:
				eq.set_band_gain_db(b, 0.0)
			AudioServer.add_bus_effect(eng_idx, eq)

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

	# World bus reverb zone & EQ for distance, wall occlusion, and cabin isolation
	var world_idx = AudioServer.get_bus_index("World")
	if world_idx != -1:
		var world_has_reverb = false
		var world_has_eq = false
		for e in AudioServer.get_bus_effect_count(world_idx):
			var eff = AudioServer.get_bus_effect(world_idx, e)
			if eff is AudioEffectReverb:
				world_has_reverb = true
			elif eff is AudioEffectEQ6:
				world_has_eq = true
		if not world_has_reverb:
			var reverb = AudioEffectReverb.new()
			reverb.room_size = 0.2
			reverb.damping = 0.7
			reverb.spread = 1.0
			reverb.wet = 0.06
			reverb.dry = 0.95
			AudioServer.add_bus_effect(world_idx, reverb)
		if not world_has_eq:
			var eq = AudioEffectEQ6.new()
			for b in 6:
				eq.set_band_gain_db(b, 0.0)
			AudioServer.add_bus_effect(world_idx, eq)


func _init_engine_players():
	for band in current_engine_bands:
		for layer in 2:
			var name = ("engine_" if layer == 0 else "coast_") + band[0]
			var stream: AudioStream = band[2 + layer]
			if stream is AudioStreamWAV:
				stream = stream.duplicate()
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


## Direct binary WAV loader: parses RIFF WAV files without editor import dependency
func _load_wav_direct(path: String, loop: bool = true) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return null
	# Check RIFF header
	if bytes[0] != 82 or bytes[1] != 73 or bytes[2] != 70 or bytes[3] != 70:
		return null

	# Find data chunk
	var pos = 12
	var rate = RATE
	var channels = 1
	var bits = 16
	var data_start = 44
	var data_size = bytes.size() - 44

	while pos + 8 <= bytes.size():
		var id0 = bytes[pos]
		var id1 = bytes[pos + 1]
		var id2 = bytes[pos + 2]
		var id3 = bytes[pos + 3]
		var chunk_len = bytes.decode_u32(pos + 4)
		if id0 == 102 and id1 == 109 and id2 == 116 and id3 == 32:  # 'fmt '
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif id0 == 100 and id1 == 97 and id2 == 116 and id3 == 97:  # 'data'
			data_start = pos + 8
			data_size = chunk_len
			break
		pos += 8 + chunk_len

	var pcm = bytes.slice(data_start, data_start + data_size)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.stereo = (channels == 2)
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = pcm.size() / (2 if bits == 16 else 1) / (2 if channels == 2 else 1)
	return stream


func _load_stream_or_synth(path: String, fallback_kind: String, loop: bool = true) -> AudioStream:
	var direct = _load_wav_direct(path, loop)
	if direct != null:
		return direct
	return make_sound(fallback_kind)


func _init_procedural_players():
	var proc_specs = [
		# [name, is_loop, bus_name, asset_path]
		["intake", true, "Engine", ""],
		["turbo", true, "Engine", ""],
		["blowoff", false, "Engine", ""],
		["electric_whine", true, "Engine", ""],
		["whine", true, "Engine", "res://assets/audio/gear_whine.wav"],
		["shift", false, "Engine", ""],
		["shift_cut", false, "Engine", ""],
		["shift_blip", false, "Engine", ""],
		["backfire", false, "Engine", ""],
		["starter", false, "Engine", ""],
		["shutdown", false, "Engine", ""],
		["clutch_bite", false, "Engine", "res://assets/audio/clutch_bite.wav"],
		["tires", true, "Tyres", "res://assets/audio/tyre_scrub_lat.wav"],
		["tires_lat", true, "Tyres", "res://assets/audio/tyre_scrub_lat.wav"],
		["tires_long", true, "Tyres", "res://assets/audio/tyre_spin_long.wav"],
		["road", true, "Tyres", ""],
		["kerb", true, "Tyres", "res://assets/audio/kerb_thrum.wav"],
		["gravel", true, "Tyres", "res://assets/audio/gravel_spray.wav"],
		["grass", true, "Tyres", ""],
		["wet_spray", true, "Tyres", ""],
		["scrape", true, "Tyres", ""],
		["wind", true, "World", "res://assets/audio/wind_rush.wav"],
		["impact", false, "World", ""],
		["impact_armco", false, "World", ""],
		["impact_tyre", false, "World", ""],
		["impact_concrete", false, "World", ""],
		["impact_prop", false, "World", ""],
		["ghost_pass", true, "World", ""],
		["crowd", true, "World", "res://assets/audio/crowd_ambience.wav"],
		["spa_ambience", true, "World", ""],
		["spa_pa", true, "World", "res://assets/audio/spa_pa_announcement.wav"]
	]

	for spec in proc_specs:
		var name = spec[0]
		var loop = spec[1]
		var bus_name = spec[2]
		var asset_path = spec[3]
		var p = AudioStreamPlayer.new()
		if not asset_path.is_empty():
			p.stream = _load_stream_or_synth(asset_path, name, loop)
		else:
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
		"shutdown": 0.85,
		"clutch_bite": 0.35
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
				var roar = sin(TAU * 140.0 * t) * 0.35 + sin(TAU * 280.0 * t) * 0.20
				var throat = filtered * 0.30 + (noise - filtered) * 0.05
				value = (roar + throat) * 0.50
			"turbo":
				var whistle = sin(TAU * 2600.0 * t + sin(TAU * 42.0 * t) * 0.8) * 0.32
				var hiss = (noise - filtered) * 0.15
				value = whistle + hiss
			"blowoff":
				var flutter = sin(TAU * 26.0 * t) * 0.4 + 0.6
				var air_dump = (filtered_hi * 0.6 + noise * 0.25) * flutter * exp(-t * 9.5)
				var chirp = sin(TAU * (2100.0 - 1200.0 * t) * t) * 0.22 * exp(-t * 16.0)
				value = air_dump + chirp
			"electric_whine":
				value = (
					sin(TAU * 1100.0 * t) * 0.32 + sin(TAU * 2200.0 * t) * 0.18 + sin(TAU * 3300.0 * t) * 0.08
				)
			"tires", "tires_lat":
				var scrub = filtered * 0.32 + (noise - filtered) * 0.08
				var screech = (
					sin(TAU * 240.0 * t + sin(TAU * 18.0 * t) * 1.2) * 0.30
					+ sin(TAU * 480.0 * t) * 0.16
					+ sin(TAU * 65.0 * t) * 0.22
				)
				value = scrub + screech
			"tires_long":
				var tear = filtered * 0.42 + (noise - filtered) * 0.08
				var groan = (
					sin(TAU * 180.0 * t + sin(TAU * 14.0 * t) * 1.4) * 0.32 + sin(TAU * 360.0 * t) * 0.18
				)
				value = tear + groan
			"road":
				value = filtered * 0.60 + (noise - filtered) * 0.06
			"wind":
				value = (filtered * 0.52 + (noise - filtered) * 0.06 + sin(TAU * 38.0 * t) * 0.20 + sin(TAU * 76.0 * t) * 0.12) * 0.70
			"whine":
				value = (
					sin(TAU * 440.0 * t) * 0.24
					+ sin(TAU * 880.0 * t) * 0.14
					+ sin(TAU * 1320.0 * t) * 0.06
					+ filtered * 0.04
				)
			"clutch_bite":
				value = (sin(TAU * (320.0 - 140.0 * t) * t) * 0.55 + filtered * 0.20) * exp(-t * 12.0)
			"kerb":
				var rib_pulse = sin(TAU * 58.0 * t) * 0.45 + sin(TAU * 116.0 * t) * 0.28 + sin(TAU * 232.0 * t) * 0.14
				var edge_snap = (filtered * 0.25) * pow(maxf(0.0, sin(TAU * 58.0 * t)), 3.0)
				value = rib_pulse + edge_snap
			"gravel":
				var gravel_roar = filtered * 0.45
				var pebble = 0.85 if rng.randf() > 0.982 else 0.0
				value = gravel_roar + pebble + (noise - filtered) * 0.18
			"grass":
				value = (filtered * 0.48 + sin(TAU * 85.0 * t) * 0.12) * 0.70
			"wet_spray":
				value = (noise - filtered) * 0.52 + sin(TAU * 3400.0 * t) * 0.06
			"scrape":
				var rasp = (noise - filtered) * 0.45 + filtered * 0.25
				var spark = (noise * 0.5) if rng.randf() > 0.96 else 0.0
				value = rasp + spark
			"impact", "impact_concrete":
				var thud = sin(TAU * (85.0 - 55.0 * t) * t) * 0.45 * exp(-t * 22.0)
				var crunch = (filtered * 0.65 + noise * 0.35) * exp(-t * 28.0)
				value = (thud + crunch) * minf(t * 800.0, 1.0)
			"impact_armco":
				var clang = (
					sin(TAU * 110.0 * t) * 0.35 * exp(-t * 14.0)
					+ sin(TAU * 420.0 * t) * 0.28 * exp(-t * 12.0)
					+ sin(TAU * 840.0 * t) * 0.18 * exp(-t * 18.0)
				)
				var rattle = (filtered * 0.45 + (noise - filtered) * 0.25) * exp(-t * 24.0)
				value = (clang + rattle) * minf(t * 800.0, 1.0)
			"impact_tyre":
				var bounce = sin(TAU * (55.0 - 25.0 * t) * t) * 0.65 * exp(-t * 18.0)
				var rub = (filtered * 0.40) * exp(-t * 32.0)
				value = (bounce + rub) * minf(t * 500.0, 1.0)
			"impact_prop":
				var knock = sin(TAU * 320.0 * t) * 0.42 * exp(-t * 38.0)
				var splinter = (noise - filtered) * 0.32 * exp(-t * 42.0)
				value = (knock + splinter) * minf(t * 1000.0, 1.0)
			"shift":
				var clack = sin(TAU * 220.0 * t) * 0.35 * exp(-t * 70.0)
				var snap = (filtered * 0.45 + (noise - filtered) * 0.25) * exp(-t * 90.0)
				value = (clack + snap) * minf(t * 1000.0, 1.0)
			"shift_cut":
				var pop = sin(TAU * (140.0 - 80.0 * t) * t) * 0.55 * exp(-t * 55.0)
				var hiss = (noise - filtered) * 0.35 * exp(-t * 75.0)
				value = (pop + hiss) * minf(t * 1000.0, 1.0)
			"shift_blip":
				var rev = sin(TAU * (160.0 + 80.0 * t) * t) * 0.38 * exp(-t * 16.0)
				var burble = sin(TAU * 65.0 * t) * 0.25 * exp(-t * 14.0)
				value = rev + burble
			"backfire":
				var report = (1.0 if t < 0.006 else -0.5 * exp(-t * 60.0)) * 0.70
				var crackle = (noise * 0.40) * exp(-t * 45.0)
				value = report + crackle
			"starter":
				var crank = (
					(sin(TAU * 32.0 * t) * 0.35 + filtered * 0.2)
					* (1.0 if t < 0.45 else exp(-(t - 0.45) * 8.0))
				)
				var fire = (
					(sin(TAU * 85.0 * (t - 0.45)) * 0.45 * exp(-(t - 0.45) * 6.0)) if t >= 0.45 else 0.0
				)
				value = crank + fire
			"shutdown":
				var spin = sin(TAU * (110.0 * (1.0 - t)) * t) * 0.40 * (1.0 - t)
				var hiss = filtered * 0.22 * (1.0 - t)
				value = spin + hiss
			"ghost_pass":
				var drone = (
					sin(TAU * 310.0 * t + sin(TAU * 12.0 * t) * 0.8) * 0.35
					+ sin(TAU * 620.0 * t) * 0.22
					+ filtered * 0.15
				)
				value = drone
			"crowd":
				var murmur = (filtered * 0.28 + sin(TAU * 2.5 * t) * 0.10) * 0.60
				value = murmur
			"spa_ambience":
				var trees = filtered * 0.25 + (noise - filtered) * 0.08
				var bird = 0.0
				if (t > 0.2 and t < 0.32) or (t > 0.68 and t < 0.78):
					bird = sin(TAU * 2800.0 * t + sin(TAU * 45.0 * t) * 2.5) * 0.14
				value = trees + bird
			"spa_pa":
				var voice = (
					sin(TAU * 440.0 * t + sin(TAU * 4.0 * t) * 1.2) * 0.30 + sin(TAU * 880.0 * t) * 0.22
				)
				var speech = voice * maxf(0.0, sin(TAU * 1.8 * t))
				value = speech + filtered * 0.12

		if loop:
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

	var resolved_key = "roadster"
	if "f2004" in car_name or redline > 17000.0:
		resolved_key = "f2004"
	elif "rb19" in car_name or redline > 13000.0:
		resolved_key = "rb19"
	elif body == "gt3" or "296" in car_name or "gt3" in body:
		resolved_key = "f296gt3"
	elif body == "coupe" or body == "gt":
		resolved_key = "gt"
	elif body == "roadster":
		resolved_key = "roadster"

	var car_key = resolved_key + "_" + str(int(redline))
	if car_key == current_car_key:
		return
	current_car_key = car_key

	var cfg = CAR_BANK_CONFIGS.get(resolved_key, CAR_BANK_CONFIGS["roadster"])
	engine_voice = cfg.voice
	engine_max_pitch = cfg.max_pitch
	is_race_car = cfg.is_race
	is_turbo_car = cfg.is_turbo
	is_hybrid_car = cfg.is_hybrid
	active_resonance_freq = cfg.resonance_freq
	debug_stats.car_voice = cfg.name

	# Switch engine player streams to the car's dedicated acoustic bank
	var new_bands = []
	for b_def in cfg.bands:
		var band_name = b_def[0]
		var ref_rpm = b_def[1]
		var p_path = b_def[2]
		var c_path = b_def[3]
		var p_stream = _load_stream_or_synth(p_path, "engine_" + band_name)
		var c_stream = _load_stream_or_synth(c_path, "coast_" + band_name)
		new_bands.append([band_name, ref_rpm, p_stream, c_stream])

		# Update active players
		var p_player = players.get("engine_" + band_name)
		var c_player = players.get("coast_" + band_name)
		if p_player:
			p_player.stream = p_stream
			if p_player.is_inside_tree() and not p_player.playing:
				p_player.play()
		if c_player:
			c_player.stream = c_stream
			if c_player.is_inside_tree() and not c_player.playing:
				c_player.play()

	current_engine_bands = new_bands


## Smooth master/category gains, pitch from RPM and effects from slip/speed/surface.
func update(car, dt: float, active: bool, settings: Dictionary) -> void:
	if players.is_empty():
		return

	_update_car_voice(car)

	# Read mix preset ("Cockpit", "Chase", "TV")
	var cam_name = str(settings.get("camera_preset", "")).to_lower()
	var cam_idx = int(settings.get("camera", -1))
	if "cockpit" in cam_name or "bonnet" in cam_name or cam_idx == 1 or cam_idx == 2:
		active_mix_preset = "Cockpit"
	elif "tv" in cam_name or "trackside" in cam_name or cam_idx == 4:
		active_mix_preset = "TV"
	else:
		active_mix_preset = "Chase"
	debug_stats.mix_preset = active_mix_preset

	var is_muted = bool(settings.get("mute", false))
	var user_master = float(settings.get("volume", 0.7))
	var eng_setting = float(settings.get("engine_volume", 0.85))
	var eff_setting = float(settings.get("effects_volume", 0.7))
	var tyres_setting = float(settings.get("tyres_volume", eff_setting))
	var world_setting = float(settings.get("world_volume", eff_setting))

	# Driving simulation levels (fade to 0 when not active / in menu)
	var active_mult = 1.0 if (active and not is_muted) else 0.0
	engine_level = lerpf(engine_level, active_mult * eng_setting, 1.0 - exp(-dt * 14.0))
	effects_level = lerpf(effects_level, active_mult * eff_setting, 1.0 - exp(-dt * 14.0))
	tyres_level = lerpf(tyres_level, active_mult * tyres_setting, 1.0 - exp(-dt * 14.0))
	world_level = lerpf(world_level, active_mult * world_setting, 1.0 - exp(-dt * 14.0))

	var car_rpm = float(car.rpm) if "rpm" in car else 1250.0
	var car_speed = float(car.speed) if "speed" in car else 0.0
	var redline = float(car.p.get("redline", 7200.0)) if ("p" in car and car.p is Dictionary) else 7200.0

	# Rev limiter bounce detection
	is_limiting = car_rpm >= redline * 0.985 or bool(car.get("rev_limit") if "rev_limit" in car else false)
	if is_limiting:
		limiter_timer += dt
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

	# Dynamic sidechain ducking: duck World bus by up to -4.5 dB when engine acoustic output is high
	var acoustic_energy = engine_level * (0.35 * (audible_rpm / redline) + 0.65 * engine_load)
	var ducking_db = 0.0
	if acoustic_energy > 0.35:
		ducking_db = -4.5 * clampf((acoustic_energy - 0.35) / 0.35, 0.0, 1.0)
	debug_stats.ducking_db = ducking_db

	# Apply bus volumes to Godot AudioServer (Master bus remains audible for UI in menus)
	_update_bus_volumes(settings, user_master if not is_muted else 0.0, ducking_db)

	# Driveline / clutch bite detection
	var clutch_slip = float(car.clutch_slip if "clutch_slip" in car else 0.0)
	if clutch_slip > 0.08 and raw_throttle > 0.4 and car_speed < 8.0:
		trigger("clutch_bite", engine_level * clampf(clutch_slip * 1.5, 0.15, 0.65))

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

	# RPM layer crossfading across the 4 bands
	var bands = current_engine_bands
	var lower = 0
	for i in range(bands.size() - 1):
		if audible_rpm >= bands[i][1]:
			lower = i
	var upper = mini(lower + 1, bands.size() - 1)
	var blend = clampf(
		log(maxf(audible_rpm, bands[lower][1]) / bands[lower][1]) / log(bands[upper][1] / bands[lower][1]),
		0.0,
		1.0
	)

	# Camera preset multipliers
	var cockpit_filter = active_mix_preset == "Cockpit"
	var engine_gain_preset = 0.95 if cockpit_filter else (1.10 if active_mix_preset == "TV" else 1.0)

	for i in bands.size():
		var band = bands[i]
		var weight = sqrt(1.0 - blend) if i == lower else (sqrt(blend) if i == upper else 0.0)
		debug_stats.layer_weights[i] = (1.0 - blend) if i == lower else (blend if i == upper else 0.0)
		var base_ref = 5625.0 if ("f2004" in current_car_key and band[0] == "high") else band[1]
		var pitch = clampf(audible_rpm / base_ref * engine_voice, 0.35, engine_max_pitch)
		var power = players["engine_" + band[0]]
		var coast = players["coast_" + band[0]]
		power.pitch_scale = pitch
		coast.pitch_scale = pitch

		# Intake resonance modulation under load
		var resonance_boost = 1.0 + (0.25 * engine_load if audible_rpm < band[1] * 1.3 else 0.0)

		power.volume_db = linear_to_db(
			maxf(
				0.00001,
				engine_level * engine_gain_preset * weight * sqrt(engine_load) * 0.92 * resonance_boost
			)
		)
		coast.volume_db = linear_to_db(
			maxf(
				0.00001,
				engine_level * engine_gain_preset * weight * pow(maxf(0.0, 1.0 - engine_load), 0.7) * 0.78
			)
		)

	# Intake induction roar
	players.intake.volume_db = linear_to_db(maxf(0.00001, engine_level * engine_load * 0.075))
	players.intake.pitch_scale = clampf(0.5 + audible_rpm / (redline * 0.8), 0.5, 2.2)

	# Overrun simulation: detect throttle lift at elevated RPM in gear
	var current_gear = int(car.gear if "gear" in car else 1)
	var in_gear = current_gear >= 1
	if raw_throttle < 0.08 and audible_rpm > redline * 0.40 and in_gear:
		if last_throttle >= 0.15:
			# Sudden lift: prime overrun burst
			overrun_intensity = clampf((audible_rpm - redline * 0.40) / (redline * 0.50), 0.35, 1.0)
			overrun_timer = randf_range(1.2, 2.2)
	elif raw_throttle > 0.15:
		overrun_timer = 0.0
		overrun_intensity = 0.0

	if overrun_timer > 0.0:
		overrun_timer -= dt
		overrun_intensity = maxf(0.0, overrun_intensity - dt * 0.40)
		if backfire_cooldown <= 0.0 and audible_rpm > redline * 0.35:
			var pop_vol = engine_level * overrun_intensity * randf_range(0.35, 0.70)
			trigger("backfire", pop_vol)
			backfire_cooldown = randf_range(0.12, 0.30)
	elif backfire_cooldown > 0.0:
		backfire_cooldown -= dt

	# Gearshift events
	if current_gear != last_gear:
		if current_gear > last_gear:
			# Upshift ignition cut pop
			trigger("shift_cut", engine_level * (0.65 if is_race_car else 0.42))
			trigger("shift", engine_level * 0.35)
		else:
			# Downshift blip
			trigger("shift_blip", engine_level * (0.58 if is_race_car else 0.38))
			trigger("shift", engine_level * 0.30)
		last_gear = current_gear

	# Tyre slip & surface acoustic dynamics
	var max_slip = 0.0
	var max_lat_slip = 0.0
	var max_long_slip = 0.0
	var current_surface_id = 0
	var wheels = car.wheels if "wheels" in car else []

	for w in wheels:
		var lat_s = absf(float(_prop(w, "slipAngle", 0.0)))
		var long_s = absf(float(_prop(w, "slipRatio", 0.0)))
		var s = maxf(lat_s, long_s)
		max_slip = maxf(max_slip, s)
		max_lat_slip = maxf(max_lat_slip, lat_s)
		max_long_slip = maxf(max_long_slip, long_s)
		var surf = _prop(w, "surf")
		if surf:
			var s_id = int(_prop(surf, "id", 0))
			if s_id != 0:
				current_surface_id = s_id

	debug_stats.surface_id = current_surface_id

	# Lateral scrub vs longitudinal spin/lockup
	var lat_target = clampf((max_lat_slip - 0.04) / 0.16, 0.0, 1.0)
	var long_target = clampf((max_long_slip - 0.06) / 0.22, 0.0, 1.0)
	var slip_target = clampf((max_slip - 0.05) / 0.20, 0.0, 1.0)

	tire_lat_level = lerpf(tire_lat_level, lat_target, 1.0 - exp(-dt * 18.0))
	tire_long_level = lerpf(tire_long_level, long_target, 1.0 - exp(-dt * 18.0))
	tire_level = lerpf(tire_level, slip_target, 1.0 - exp(-dt * 16.0))

	debug_stats.tire_lat = tire_lat_level
	debug_stats.tire_long = tire_long_level

	var surface_tyre_mult = 1.0
	if current_surface_id == 1:  # Kerb
		surface_tyre_mult = 0.75
	elif current_surface_id == 2:  # Grass
		surface_tyre_mult = 0.35
	elif current_surface_id == 3:  # Gravel
		surface_tyre_mult = 0.25

	players.tires.volume_db = linear_to_db(maxf(0.00001, tyres_level * tire_level * 0.16 * surface_tyre_mult))
	players.tires.pitch_scale = clampf(0.85 + car_speed / 50.0 + max_slip * 0.35, 0.7, 1.55)

	players.tires_lat.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * tire_lat_level * 0.12 * surface_tyre_mult)
	)
	players.tires_lat.pitch_scale = clampf(0.85 + car_speed / 48.0, 0.75, 1.6)

	players.tires_long.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * tire_long_level * 0.18 * surface_tyre_mult)
	)
	players.tires_long.pitch_scale = clampf(0.75 + car_speed / 50.0, 0.65, 1.6)

	# Surface rolling tyre roar (boosted on gravel trap)
	var gravel_road_mult = 1.75 if current_surface_id == 3 else 1.0
	players.road.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * clampf(car_speed / 55.0, 0.0, 1.0) * 0.16 * gravel_road_mult)
	)
	players.road.pitch_scale = clampf(0.7 + car_speed / 60.0, 0.5, 1.6)

	# Kerb vibration thrum
	var on_kerb = current_surface_id == 1
	var kerb_target = 0.45 if on_kerb else 0.0
	players.kerb.volume_db = linear_to_db(
		maxf(0.00001, tyres_level * kerb_target * clampf(car_speed / 28.0, 0.2, 1.2) * 0.40)
	)
	players.kerb.pitch_scale = clampf(0.65 + car_speed / 38.0, 0.6, 1.6)

	# Gravel trap spray & roar
	var on_gravel = current_surface_id == 3
	var gravel_target = 0.55 if on_gravel else 0.0
	if players.has("gravel"):
		players.gravel.volume_db = linear_to_db(
			maxf(0.00001, tyres_level * gravel_target * clampf(car_speed / 18.0, 0.25, 1.2))
		)
		players.gravel.pitch_scale = clampf(0.8 + car_speed / 35.0, 0.7, 1.6)

	# Grass rustle
	var on_grass = current_surface_id == 2
	var grass_target = 0.38 if on_grass else 0.0
	if players.has("grass"):
		players.grass.volume_db = linear_to_db(
			maxf(0.00001, tyres_level * grass_target * clampf(car_speed / 22.0, 0.15, 1.0))
		)
		players.grass.pitch_scale = clampf(0.75 + car_speed / 30.0, 0.6, 1.5)

	# Bottoming scrape
	var scrape_hits = car.get("scrape_hits") if "scrape_hits" in car else []
	var is_scraping = scrape_hits != null and not scrape_hits.is_empty()
	scrape_level = lerpf(scrape_level, 0.55 if is_scraping else 0.0, 1.0 - exp(-dt * 20.0))
	if players.has("scrape"):
		players.scrape.volume_db = linear_to_db(maxf(0.00001, tyres_level * scrape_level * 0.32))
		players.scrape.pitch_scale = clampf(0.9 + car_speed / 35.0, 0.8, 1.6)

	# Transmission gear whine (boosted in cockpit view)
	var whine_boost = 1.4 if cockpit_filter else (0.8 if active_mix_preset == "TV" else 1.0)
	players.whine.volume_db = linear_to_db(
		maxf(
			0.00001,
			engine_level * clampf(car_speed / 65.0, 0.0, 1.0) * (0.045 if is_race_car else 0.015) * whine_boost
		)
	)
	players.whine.pitch_scale = clampf(0.5 + car_speed / 36.0, 0.4, 2.1)

	# Aerodynamic wind rush (Cockpit gets windshield rush, TV gets lower)
	var wind_factor = clampf(car_speed / 72.0, 0.0, 1.6)
	if cockpit_filter:
		wind_factor *= 1.25  # Cabin wind rush on windshield
	elif active_mix_preset == "TV":
		wind_factor *= 0.65
	players.wind.volume_db = linear_to_db(maxf(0.00001, world_level * wind_factor * 0.08))
	players.wind.pitch_scale = clampf(0.8 + car_speed / 65.0, 0.7, 1.8)

	# Ghost Car / passing car Doppler effect
	if players.has("ghost_pass") and "ghost_car" in car and car.ghost_car != null:
		var ghost_pos: Vector3 = car.ghost_car.get("pos") if "pos" in car.ghost_car else Vector3.ZERO
		var car_pos: Vector3 = car.get("pos") if "pos" in car else Vector3.ZERO
		var dist = car_pos.distance_to(ghost_pos)
		if dist < 65.0:
			var rel_vel = (
				(car.get("vel") if "vel" in car else Vector3.ZERO)
				- (car.ghost_car.get("vel") if "vel" in car.ghost_car else Vector3.ZERO)
			)
			var dir = (ghost_pos - car_pos).normalized()
			var radial_speed = rel_vel.dot(dir)
			var doppler_shift = clampf(SOUND_SPEED / (SOUND_SPEED + radial_speed), 0.75, 1.4)
			var dist_atten = 1.0 / (1.0 + (dist / 14.0) * (dist / 14.0))

			players.ghost_pass.volume_db = linear_to_db(maxf(0.00001, world_level * dist_atten * 0.35))
			players.ghost_pass.pitch_scale = doppler_shift
		else:
			players.ghost_pass.volume_db = -80.0
	elif players.has("ghost_pass"):
		players.ghost_pass.volume_db = -80.0

	# Spa Environmental Ambience, PA, and Reverb Zones
	_update_track_spatial_acoustics(car, dt)

	# Update stats for telemetry HUD
	debug_stats.audible_rpm = audible_rpm
	debug_stats.redline = redline
	debug_stats.load = engine_load
	debug_stats.boost = boost_pressure
	debug_stats.limiting = is_limiting


## Spatial acoustics: reverb zones, bridge/tunnel wet sends, crowd swell, and PA announcements
func _update_track_spatial_acoustics(car, dt: float) -> void:
	var station = float(car.station if "station" in car else 0.0)
	var track_name = str(car.get("track_name") if "track_name" in car else "").to_lower()
	var is_spa = "spa" in track_name and not track_name.is_empty()

	if players.has("spa_ambience"):
		var amb_vol = world_level * 0.12 if is_spa else 0.0
		players.spa_ambience.volume_db = linear_to_db(maxf(0.00001, amb_vol))

	var world_idx = AudioServer.get_bus_index("World")
	if world_idx != -1 and AudioServer.get_bus_effect_count(world_idx) > 0:
		var effect = AudioServer.get_bus_effect(world_idx, 0)
		if effect is AudioEffectReverb:
			# Detect Bridge / Tunnel Reverb Zones
			var under_bridge = (
				is_spa and ((station > 6910.0 and station < 6965.0) or (station > 900.0 and station < 945.0))
			)  # Pit footbridge  # Eau Rouge stone culvert bridge
			# Detect Grandstands
			var near_grandstand = (
				is_spa
				and (
					(station > 250.0 and station < 480.0)  # La Source
					or (station > 1020.0 and station < 1240.0)  # Raidillon
					or (station > 3520.0 and station < 3750.0)  # Pouhon
					or (station > 6620.0 and station < 6850.0)
				)
			)  # Bus Stop
			# Detect Retaining Wall proximity (Eau Rouge left wall)
			var near_wall = is_spa and (station > 870.0 and station < 1050.0)
			# Detect Pit Wall dividing pit lane from racing line
			var near_pit_wall = is_spa and (station > 6650.0 or station < 150.0)

			# Wall acoustic occlusion factor (low-pass filtering behind barriers)
			var target_occlusion = 0.85 if (near_wall or near_pit_wall) else 0.0
			wall_occlusion_factor = lerpf(wall_occlusion_factor, target_occlusion, 1.0 - exp(-dt * 5.0))
			debug_stats.wall_occlusion = wall_occlusion_factor

			if under_bridge:
				debug_stats.reverb_zone = "Bridge / Tunnel"
				effect.room_size = lerpf(effect.room_size, 0.65, dt * 6.0)
				effect.wet = lerpf(effect.wet, 0.38, dt * 6.0)
				effect.dry = lerpf(effect.dry, 0.68, dt * 6.0)
				effect.damping = lerpf(effect.damping, 0.40, dt * 6.0)
			elif near_grandstand:
				debug_stats.reverb_zone = "Grandstand Reflection"
				effect.room_size = lerpf(effect.room_size, 0.38, dt * 4.0)
				effect.wet = lerpf(effect.wet, 0.20, dt * 4.0)
				effect.dry = lerpf(effect.dry, 0.84, dt * 4.0)
				effect.damping = lerpf(effect.damping, 0.65, dt * 4.0)
			elif near_wall:
				debug_stats.reverb_zone = "Retaining Wall Slapback"
				effect.room_size = lerpf(effect.room_size, 0.28, dt * 5.0)
				effect.wet = lerpf(effect.wet, 0.16, dt * 5.0)
				effect.dry = lerpf(effect.dry, 0.88, dt * 5.0)
				effect.damping = lerpf(effect.damping, 0.50, dt * 5.0)
			else:
				debug_stats.reverb_zone = "Open Air"
				effect.room_size = lerpf(effect.room_size, 0.15, dt * 2.0)
				effect.wet = lerpf(effect.wet, 0.05, dt * 2.0)
				effect.dry = lerpf(effect.dry, 0.95, dt * 2.0)
				effect.damping = lerpf(effect.damping, 0.70, dt * 2.0)

			# Crowd swell near grandstands and spectator banks (Pouhon, Kemmel)
			var near_spectators = (
				near_grandstand
				or (
					is_spa
					and ((station > 1200.0 and station < 1350.0) or (station > 3480.0 and station < 3780.0))
				)
			)
			if players.has("crowd"):
				if near_spectators:
					players.crowd.volume_db = linear_to_db(maxf(0.00001, world_level * 0.25))
				else:
					players.crowd.volume_db = -80.0

			# Spa PA circuit announcer swell around paddock and spectator banks
			if players.has("spa_pa"):
				if is_spa and (near_spectators or (station > 6850.0 or station < 150.0)):
					players.spa_pa.volume_db = linear_to_db(maxf(0.00001, world_level * 0.20))
				else:
					players.spa_pa.volume_db = -80.0

			# Trackside marshal posts (every 350 m in spa.gd)
			if is_spa:
				var dist_marshal = fposmod(station + 18.0, 350.0)
				if dist_marshal < 36.0:
					marshal_pass_cooldown = maxf(marshal_pass_cooldown, 0.6)
			if marshal_pass_cooldown > 0.0:
				marshal_pass_cooldown -= dt


func _update_bus_volumes(settings: Dictionary, master_gain: float, ducking_db: float = 0.0) -> void:
	if AudioServer.bus_count <= 1:
		return
	var eng_idx = AudioServer.get_bus_index("Engine")
	var tyres_idx = AudioServer.get_bus_index("Tyres")
	var world_idx = AudioServer.get_bus_index("World")
	var ui_idx = AudioServer.get_bus_index("UI")
	var music_idx = AudioServer.get_bus_index("Music")

	var eff = float(settings.get("effects_volume", 0.7))

	# Master Bus volume reflects user volume slider (stays audible for menus)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master_gain)))

	if eng_idx != -1:
		AudioServer.set_bus_volume_db(eng_idx, 0.0)
		# Configure Engine EQ for Cockpit vs Chase vs TV presets
		for e in AudioServer.get_bus_effect_count(eng_idx):
			var eff_obj = AudioServer.get_bus_effect(eng_idx, e)
			if eff_obj is AudioEffectEQ6:
				if active_mix_preset == "Cockpit":
					# Cockpit: boost low cabin rumble, intake (320 Hz) and whine (1 kHz), cut exterior rasp at 10 kHz
					eff_obj.set_band_gain_db(0, 1.5)
					eff_obj.set_band_gain_db(1, 2.0)
					eff_obj.set_band_gain_db(2, 2.5)
					eff_obj.set_band_gain_db(3, 1.5)
					eff_obj.set_band_gain_db(4, -2.0)
					eff_obj.set_band_gain_db(5, -5.0)
				elif active_mix_preset == "TV":
					# TV: broadcast camera with punchy low-end presence
					eff_obj.set_band_gain_db(0, 1.0)
					eff_obj.set_band_gain_db(1, 1.5)
					eff_obj.set_band_gain_db(2, 1.0)
					eff_obj.set_band_gain_db(3, 1.5)
					eff_obj.set_band_gain_db(4, 0.5)
					eff_obj.set_band_gain_db(5, -2.0)
				else:
					# Chase: warm body curve eliminating digital glare
					eff_obj.set_band_gain_db(0, 1.5)
					eff_obj.set_band_gain_db(1, 2.0)
					eff_obj.set_band_gain_db(2, 1.0)
					eff_obj.set_band_gain_db(3, 0.0)
					eff_obj.set_band_gain_db(4, -1.0)
					eff_obj.set_band_gain_db(5, -3.0)
				break

	if tyres_idx != -1:
		AudioServer.set_bus_volume_db(tyres_idx, 0.0)

	if world_idx != -1:
		# Ducking applied to World bus
		AudioServer.set_bus_volume_db(world_idx, ducking_db)

		# Configure World EQ for cabin isolation (Cockpit) and wall acoustic occlusion
		for e in AudioServer.get_bus_effect_count(world_idx):
			var eff_obj = AudioServer.get_bus_effect(world_idx, e)
			if eff_obj is AudioEffectEQ6:
				if active_mix_preset == "Cockpit":
					# Cabin muffling on exterior sound
					eff_obj.set_band_gain_db(0, 0.0)
					eff_obj.set_band_gain_db(1, -1.0)
					eff_obj.set_band_gain_db(2, -3.0)
					eff_obj.set_band_gain_db(3, -5.5)
					eff_obj.set_band_gain_db(4, -8.0)
					eff_obj.set_band_gain_db(5, -12.0)
				elif active_mix_preset == "TV":
					eff_obj.set_band_gain_db(0, -2.0)
					eff_obj.set_band_gain_db(1, -1.0)
					eff_obj.set_band_gain_db(2, 1.0)
					eff_obj.set_band_gain_db(3, 1.5)
					eff_obj.set_band_gain_db(4, 0.5)
					eff_obj.set_band_gain_db(5, -2.5)
				else:
					# Chase: apply wall occlusion low-pass attenuation if behind barrier/wall
					var occ = -8.0 * wall_occlusion_factor
					eff_obj.set_band_gain_db(0, 0.0)
					eff_obj.set_band_gain_db(1, 0.0)
					eff_obj.set_band_gain_db(2, occ * 0.25)
					eff_obj.set_band_gain_db(3, occ * 0.50)
					eff_obj.set_band_gain_db(4, occ * 0.75)
					eff_obj.set_band_gain_db(5, occ)
				break

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
