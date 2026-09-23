extends RefCounted
## Physical-key tracking, remapping, keyboard ramps and first-controller polling.
## handle consumes remapping events; update produces normalized physics inputs.
## Godot key/button indices are not browser keycodes/Gamepad indices; see DATA-CONTRACTS.md.
const DEFAULT_KEYS = {
	"throttle": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"clutch": [KEY_C],
	"handbrake": [KEY_SPACE],
	"shiftUp": [KEY_E, KEY_SHIFT],
	"shiftDown": [KEY_Q, KEY_CTRL],
	"reset": [KEY_R]
}
const DEFAULT_PAD = {
	"steer": {"axis": 0},
	"throttle": {"axis": 5},
	"brake": {"axis": 4},
	"clutch": {"button": 9},
	"handbrake": {"button": 2},
	"shiftUp": {"button": 0},
	"shiftDown": {"button": 1},
	"reset": {"button": 4}
}
var keys = DEFAULT_KEYS.duplicate(true)
var pad = DEFAULT_PAD.duplicate(true)
var raw = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "clutch": 0.0, "handbrake": 0.0}
var held_keys = {}
var listening = ""
var listen_pad = false
var events = []
var previous = {}
var dead = .08
var linearity = 1.6
var keyboard_rate = 3.5
## True when the last update() took its values from the controller rather than the keyboard.
var pad_active = false
## Acceptance harnesses inject all inputs and disable unrelated physical devices.
var poll_hardware = true
var event_pad = -1
var event_axes = {}
var event_buttons = {}


func configure(settings):
	keys = DEFAULT_KEYS.duplicate(true)
	pad = DEFAULT_PAD.duplicate(true)
	for k in settings.get("keys", {}):
		if keys.has(k) and settings.keys[k] is Array:
			keys[k] = settings.keys[k]
	for k in settings.get("pad", {}):
		if pad.has(k) and settings.pad[k] is Dictionary:
			pad[k] = settings.pad[k]
	dead = clampf(settings.get("deadzone", .08), 0, .3)
	linearity = clampf(settings.get("linearity", 1.6), 1, 3)
	keyboard_rate = clampf(settings.get("keyboard_rate", 3.5), 1, 8)


## Capture remapping first. Key releases clear held state even when driving is blocked.
func handle(event, active):
	if not listening.is_empty():
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			listening = ""
			return true
		if not listen_pad and event is InputEventKey and event.pressed and not event.echo:
			keys[listening] = [event.physical_keycode]
			listening = ""
			return true
		if listen_pad and event is InputEventJoypadButton and event.pressed and listening != "steer":
			pad[listening] = {"button": event.button_index}
			listening = ""
			return true
		if listen_pad and event is InputEventJoypadMotion and absf(event.axis_value) > .75:
			pad[listening] = {"axis": event.axis, "sign": 1 if event.axis_value > 0 else -1}
			listening = ""
			return true
		return true
	if event is InputEventJoypadMotion:
		event_pad = event.device
		event_axes[event.axis] = event.axis_value if active else 0.0
	elif event is InputEventJoypadButton:
		event_pad = event.device
		event_buttons[event.button_index] = event.pressed and active
	if event is InputEventKey:
		if not event.pressed:
			held_keys.erase(event.physical_keycode)
		elif active and not event.echo:
			held_keys[event.physical_keycode] = true
			for a in ["shiftUp", "shiftDown", "reset"]:
				if event.physical_keycode in keys[a]:
					events.append(a)
	return false


func clear():
	held_keys.clear()
	event_axes.clear()
	event_buttons.clear()
	event_pad = -1
	events.clear()
	for k in raw:
		raw[k] = 0.0


func held(action):
	for code in keys.get(action, []):
		if held_keys.has(int(code)):
			return true
	return false


func pad_value(id, action):
	var mapping = pad.get(action, {})
	if mapping.has("axis"):
		var value = event_axes.get(
			int(mapping.axis), Input.get_joy_axis(id, int(mapping.axis)) if poll_hardware else 0.0
		)
		return value * float(mapping.get("sign", 1))
	var button = int(mapping.get("button", 0))
	return float(
		event_buttons.get(button, Input.is_joy_button_pressed(id, button) if poll_hardware else false)
	)


## Smooth keyboard state and merge active first-controller input; return a fresh input dictionary.
func update(dt, speed):
	var thr = float(held("throttle"))
	var brk = float(held("brake"))
	var st = float(held("right")) - float(held("left"))
	raw.throttle = clampf(
		(
			raw.throttle
			+ (thr - raw.throttle) * minf(1, (3.5 if thr else 8.0) * dt)
			+ (.25 * dt if thr else 0.0)
		),
		0,
		1
	)
	raw.brake = clampf(
		raw.brake + (brk - raw.brake) * minf(1, (4.0 if brk else 10.0) * dt) + (.3 * dt if brk else 0.0), 0, 1
	)
	if not thr:
		raw.throttle = maxf(0, raw.throttle - 6 * dt)
	if not brk:
		raw.brake = maxf(0, raw.brake - 8 * dt)
	raw.steer = (
		clampf(raw.steer + st * keyboard_rate / (1 + speed / 20) * dt, -1, 1)
		if st
		else move_toward(raw.steer, 0, (4 + speed / 8) * dt)
	)
	raw.clutch += (float(held("clutch")) - raw.clutch) * minf(1, 12 * dt)
	raw.handbrake = float(held("handbrake"))
	pad_active = false
	var ids = Input.get_connected_joypads() if poll_hardware else PackedInt32Array()
	if event_pad >= 0 and (not event_axes.is_empty() or not event_buttons.is_empty()):
		ids = PackedInt32Array([event_pad])
	if not ids.is_empty():
		var id = ids[0]
		var input = {}
		for action in ["throttle", "brake", "clutch", "handbrake"]:
			input[action] = clampf(pad_value(id, action), 0, 1)
		var axis = pad_value(id, "steer")
		input.steer = signf(axis) * pow(maxf(0, absf(axis) - dead) / (1 - dead), linearity)
		for action in ["shiftUp", "shiftDown", "reset"]:
			var down = pad_value(id, action) > .5
			if down and not previous.get(action, false):
				events.append(action)
			previous[action] = down
		if (
			absf(input.steer) > .02
			or input.throttle > .02
			or input.brake > .02
			or input.clutch > .02
			or input.handbrake > .02
		):
			raw = input
			pad_active = true
			return raw.duplicate()
	return raw.duplicate()


func binding_text(action, is_pad = false):
	if is_pad:
		var m = pad.get(action, {})
		return (
			("Axis " + str(m.axis) + (" −" if m.get("sign", 1) < 0 else ""))
			if m.has("axis")
			else "Button " + str(m.get("button", 0))
		)
	var names = []
	for code in keys.get(action, []):
		names.append(OS.get_keycode_string(int(code)))
	return " / ".join(names)
