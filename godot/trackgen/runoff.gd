extends SceneTree
## Paints runoff onto a track document from its geometry, then writes it back.
## Usage: godot --headless --path . --script trackgen/runoff.gd -- <in.json> <out.json>
## Outside of each corner, between the curb and 1.5 m short of the auto barrier:
##   slow corners (radius < 90 m)    -> tarmac runoff (paint 3) all the way
##   faster corners (radius < 400 m) -> 5 m tarmac strip, then gravel (paint 2)
## Straights keep grass. Cells that belong to another part of the circuit are skipped.
const TrackModel = preload("res://scripts/track3d.gd")


func _initialize():
	var args = OS.get_cmdline_user_args()
	var doc = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var t = TrackModel.new()
	t.load_data(doc)
	t.build_barriers()
	var paint = {}
	# Barrier distance per side along the lap, measured from the generated barrier segments.
	var reach = {-1: {}, 1: {}}
	for o in t.barriers:
		var mid = Vector2((o.x1 + o.x2) / 2, (o.y1 + o.y2) / 2)
		var pr = t.project(mid.x, mid.y)
		reach[int(o.side)][int(pr.s / 6)] = absf(pr.lat) - pr.width / 2
	var step = .8
	for k in int(t.length / step):
		var s = k * step
		var p = t.pos_at(s)
		var c = t.curvature_at(s, 20.0)
		var peak = 0.0
		for d in range(-40, 41, 10):
			peak = maxf(peak, absf(t.curvature_at(s + d, 15.0)))
		if peak < 1.0 / 400:
			continue
		var side = -1 if c > 0 else 1
		var limit = reach[side].get(int(s / 6), 0.0) - 1.5
		if limit < 4:
			continue
		var slow = peak > 1.0 / 90
		var lat = 1.6
		while lat < limit:
			var off = side * (p.w / 2 + lat)
			var x = p.x - sin(p.h) * off
			var y = p.y + cos(p.h) * off
			var pr = t.project(x, y)
			if (
				absf(pr.lat) > pr.width / 2 + 1.5
				and absf(wrapf(pr.s - s, -t.length / 2, t.length / 2)) < lat + 10
			):
				paint[str(floori(x / 2)) + "," + str(floori(y / 2))] = 3 if slow or lat < 6.5 else 2
			lat += 1.0
	# Close pinholes left where the outer arc spreads the sample rows: an empty cell with at least five
	# painted neighbours takes their majority value (never on the road or curb).
	for sweep in 2:
		var add = {}
		var cells = {}
		for key in paint:
			var xy = key.split(",")
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					cells[Vector2i(int(xy[0]) + dx, int(xy[1]) + dy)] = true
		for cell in cells:
			var key = str(cell.x) + "," + str(cell.y)
			if paint.has(key):
				continue
			var votes = {2: 0, 3: 0}
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var v = paint.get(str(cell.x + dx) + "," + str(cell.y + dy), 0)
					if v:
						votes[v] += 1
			if votes[2] + votes[3] >= 5:
				var pr = t.project(cell.x * 2 + 1, cell.y * 2 + 1)
				if absf(pr.lat) > pr.width / 2 + 1.5:
					add[key] = 2 if votes[2] > votes[3] else 3
		paint.merge(add)
	# Drop specks: connected patches under 60 cells (240 m²) are artefacts of nearby straights.
	var seen = {}
	for key in paint.keys():
		if seen.has(key):
			continue
		var stack = [key]
		var patch = []
		seen[key] = true
		while not stack.is_empty():
			var k = stack.pop_back()
			patch.append(k)
			var xy = k.split(",")
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var n = str(int(xy[0]) + d[0]) + "," + str(int(xy[1]) + d[1])
				if paint.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		if patch.size() < 60:
			for k in patch:
				paint.erase(k)
	doc.paint = paint
	var f = FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  "))
	f.close()
	var counts = {2: 0, 3: 0}
	for v in paint.values():
		counts[v] += 1
	print("RUNOFF gravel=", counts[2], " tarmac=", counts[3], " length=", t.length)
	quit()
