extends SceneTree
## Broad-phase validation must agree with the original exhaustive intersection test.
const Track = preload("res://scripts/track.gd")


func exhaustive(points):
	for i in points.size():
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		for j in range(i + 2, points.size()):
			if i == 0 and j == points.size() - 1:
				continue
			var c = points[j]
			var d = points[(j + 1) % points.size()]
			if (
				(b - a).cross(c - a) * (b - a).cross(d - a) < -.000001
				and (d - c).cross(a - c) * (d - c).cross(b - c) < -.000001
			):
				return true
	return false


func _initialize():
	var rng = RandomNumberGenerator.new()
	rng.seed = 240448
	var cases = [
		[Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)],
		[Vector2(-100, -100), Vector2(100, 100), Vector2(-100, 100), Vector2(100, -100)],
		[Vector2(-80, 40), Vector2(0, 40), Vector2(80, 40), Vector2(0, 40)]
	]
	for n in 100:
		var points = []
		for i in rng.randi_range(3, 30):
			points.append(Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300)))
		cases.append(points)
	var failures = []
	for points in cases:
		var track = Track.new()
		track.data = {"points": points, "startS": 0}
		track.length = 100
		for point in points:
			for repeat in 6:
				track.samples.append({"x": point.x, "y": point.y, "grade": 0})
		var actual = not track.validate().warnings.is_empty()
		if actual != exhaustive(points):
			failures.append(points)
	print("VALIDATION RESULTS ", JSON.stringify({"checks": cases.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
