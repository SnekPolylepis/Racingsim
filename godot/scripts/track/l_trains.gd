extends MultiMeshInstance3D
## Moving CTA trains on the elevated L (built by trackgen/chicago_l.gd). Each train runs along its chained
## track line at `speed` m/s and wraps to the start at the end. Visual only; 8 cars per instance block.

const CARS = 8
const CAR_L = 14.63

@export var lines: Array = []  # PackedVector3Array per line, deck-top points
@export var trains: Array = []  # [line index, arc position m, speed m/s]
var _lengths = []


func _ready() -> void:
	for line in lines:
		var total = 0.0
		for i in line.size() - 1:
			total += line[i].distance_to(line[i + 1])
		_lengths.append(total)


func _process(delta: float) -> void:
	for t in trains.size():
		var tr = trains[t]
		var line: PackedVector3Array = lines[tr[0]]
		var span = _lengths[tr[0]] - CARS * CAR_L
		tr[1] = fposmod(tr[1] + tr[2] * delta, maxf(span, 1.0))
		for car in CARS:
			var s0 = tr[1] + car * CAR_L + 0.3
			var a = _at(line, s0)
			var b = _at(line, s0 + CAR_L - 0.6)
			var dir = b - a
			if dir.length_squared() < 1e-4:
				continue
			multimesh.set_instance_transform(t * CARS + car, Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * .5))


static func _at(line: PackedVector3Array, s: float) -> Vector3:
	for i in line.size() - 1:
		var seg = line[i].distance_to(line[i + 1])
		if s <= seg:
			return line[i].lerp(line[i + 1], s / maxf(seg, 0.01))
		s -= seg
	return line[line.size() - 1]
