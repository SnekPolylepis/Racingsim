extends SceneTree
const Bridge = preload("res://scripts/wheel_bridge.gd")


func _initialize():
	var rig = Bridge.new()
	rig.axes = PackedFloat32Array([0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	rig.buttons = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	rig.present = 3
	var profile = {"throttle": {"axis": 4}, "brake": {"axis": 3}}
	assert(rig.command(profile).throttle == 0.0)
	assert(rig.command(profile).brake == 0.0)
	assert(absf(rig.command(profile).steer) < 0.0001)
	rig.axes[12] = 1.0
	rig.axes[0] = 0.0
	assert(rig.command(profile).throttle == 1.0)
	assert(rig.command(profile).brake == 0.0)
	assert(rig.command(profile).steer == -1.0)
	rig.axes[11] = 0.7
	assert(is_equal_approx(rig.value({"axis": 3, "pressed": 0.7}, 1), 1.0))
	assert(is_zero_approx(rig.value({"axis": 3, "released": 0.7, "pressed": 0.0}, 1)))
	rig.buttons[0] = 1 << 5
	assert(rig.value({"button": 5}, 0) == 1.0)
	assert(rig.value({"button": 5}, 1) == 0.0)
	rig.present = 0
	assert(rig.command(profile).throttle == 0.0)
	assert(rig.value({"button": 5}, 0) == 0.0)
	rig.active = true
	rig.torque = 0.8
	rig.stop()
	assert(not rig.active and rig.torque == 0.0)
	var ffb = preload("res://scripts/ffb.gd").new()
	ffb.wheel = rig
	rig.present = 1
	ffb.update({"speed": 0.0, "input": {"steer": 1.0}}, .01, 0, true, {"wheel_gain": .35}, -1)
	assert(rig.active and rig.torque < 0 and absf(rig.torque) <= .35)
	ffb.update({}, .01, 0, false, {}, -1)
	assert(not rig.active and rig.torque == 0.0)
	# One poll must acknowledge a batch once, rather than feed a reply/read loop.
	var sender = PacketPeerUDP.new()
	assert(sender.bind(0, "127.0.0.1") == OK)
	assert(rig.udp.bind(0, "127.0.0.1") == OK)
	sender.set_dest_address("127.0.0.1", rig.udp.get_local_port())
	var packet = PackedByteArray()
	packet.resize(108)
	packet.encode_u32(0, Bridge.MAGIC)
	sender.put_packet(packet)
	sender.put_packet(packet)
	await create_timer(.02).timeout
	rig.poll()
	await create_timer(.02).timeout
	assert(sender.get_available_packet_count() == 1)
	sender.close()
	rig.close()
	print('WHEEL RESULTS {"checks":18,"failures":[]}')
	quit()
