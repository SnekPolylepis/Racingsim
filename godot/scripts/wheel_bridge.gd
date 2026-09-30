extends RefCounted
## Windows DirectInput bridge for the owner's CSL DD and USB mBooster/CRP2 pedals.
const MAGIC = 0x52494739
var udp = PacketPeerUDP.new()
var process_id = -1
var present = 0
var force_ready = false
var force_status = 0
var axes = PackedFloat32Array()
var buttons = PackedInt32Array()
var last_packet = 0
var peer_port = 0
var torque = 0.0
var active = false


func start(window: Window) -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var path = ProjectSettings.globalize_path("res://native/wheel_bridge.exe")
	if not OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("user://wheel_bridge.exe")
		var binary = FileAccess.get_file_as_bytes("res://native/wheel_bridge.exe")
		if binary.is_empty():
			return
		if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path) != binary:
			var target = FileAccess.open(path, FileAccess.WRITE)
			if target == null:
				return
			target.store_buffer(binary)
			target.close()
	if not FileAccess.file_exists(path) or udp.bind(0, "127.0.0.1") != OK:
		return
	var handle = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window.get_window_id())
	process_id = OS.create_process(path, [str(udp.get_local_port()), str(handle), str(OS.get_process_id())])


func poll() -> void:
	var received = false
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		if packet.size() != 108 or packet.decode_u32(0) != MAGIC:
			continue
		if peer_port != 0 and udp.get_packet_port() != peer_port:
			continue
		peer_port = udp.get_packet_port()
		udp.set_dest_address("127.0.0.1", peer_port)
		present = packet.decode_u32(4)
		force_status = packet.decode_u32(8)
		force_ready = force_status == 1
		axes.resize(16)
		buttons.resize(8)
		for i in range(16):
			axes[i] = packet.decode_float(12 + i * 4)
		for i in range(8):
			buttons[i] = packet.decode_s32(76 + i * 4)
		last_packet = Time.get_ticks_msec()
		received = true
	# Reply after draining: replying inside the loop lets a fast helper keep it alive forever.
	if received:
		_send()
	if Time.get_ticks_msec() - last_packet > 250:
		present = 0
		force_ready = false


func _send(shutdown = false) -> void:
	if peer_port == 0:
		return
	var packet = PackedByteArray()
	packet.resize(12)
	packet.encode_u32(0, MAGIC)
	packet.encode_float(4, clampf(torque, -1.0, 1.0) if active else 0.0)
	packet.encode_u32(8, 2 if shutdown else int(active))
	udp.put_packet(packet)


func stop() -> void:
	active = false
	torque = 0.0
	_send()


func close() -> void:
	stop()
	_send(true)
	udp.close()


func value(mapping: Dictionary, device: int) -> float:
	if (present & (1 << device)) == 0:
		return 0.0
	if mapping.has("button"):
		var button = clampi(int(mapping.button), 0, 127)
		return float((buttons[device * 4 + button / 32] & (1 << (button % 32))) != 0)
	var axis = clampi(int(mapping.get("axis", 0)), 0, 7)
	var released = float(mapping.get("released", 0.0))
	var pressed = float(mapping.get("pressed", 1.0))
	if absf(pressed - released) < 0.001:
		return 0.0
	return clampf((axes[device * 8 + axis] - released) / (pressed - released), 0.0, 1.0)


func command(profile: Dictionary) -> Dictionary:
	var steer = clampf(axes[0] * 2.0 - 1.0, -1.0, 1.0) if (present & 1) else 0.0
	return {
		"steer": steer * float(profile.get("steer_sign", 1.0)),
		"throttle": value(profile.get("throttle", {"axis": 3}), 1),
		"brake": value(profile.get("brake", {"axis": 4}), 1),
		"clutch": 0.0,
		"handbrake": value(profile.get("handbrake", {"button": 2}), 0)
	}
