extends RefCounted
## Converts a real-world circuit outline into a Racing Sim track document.
## Accepts GPX (trkpt/rtept, with <ele>), GeoJSON (LineString/MultiLineString/Polygon, optional
## altitude as the third coordinate) and OpenStreetMap XML (ways tagged highway=raceway are
## stitched end to end). Coordinates are projected to local metres around the outline's centre
## (equirectangular: accurate to well under 0.1 % across a circuit), north up (screen -y).


## Returns {"doc": track document} or {"error": message}.
static func load_file(path, width = 12.0):
	var text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {"error": "Could not read " + path.get_file()}
	var ext = path.get_extension().to_lower()
	var geo = []
	if ext == "gpx":
		geo = parse_gpx(text)
	elif ext in ["geojson", "json"]:
		geo = parse_geojson(text)
	elif ext == "osm" or text.contains("<osm"):
		geo = parse_osm(text)
	else:
		return {"error": "Unsupported file type ." + ext + " (use .gpx, .geojson or .osm)"}
	if geo.size() < 8:
		return {"error": "No usable circuit outline found in " + path.get_file()}
	return {"doc": to_document(geo, path.get_file().get_basename(), width)}


static func parse_gpx(text):
	var out = []
	var xml = XMLParser.new()
	xml.open_buffer(text.to_utf8_buffer())
	var current = null
	var in_ele = false
	while xml.read() == OK:
		var t = xml.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var n = xml.get_node_name()
			if n in ["trkpt", "rtept"]:
				current = [
					float(xml.get_named_attribute_value_safe("lon")),
					float(xml.get_named_attribute_value_safe("lat")),
					NAN
				]
				out.append(current)
			in_ele = n == "ele"
		elif t == XMLParser.NODE_TEXT and in_ele and current != null:
			current[2] = float(xml.get_node_data())
		elif t == XMLParser.NODE_ELEMENT_END:
			in_ele = false
	return out


static func parse_geojson(text):
	var d = JSON.parse_string(text)
	var lines = []
	if not d is Dictionary:
		return []
	var geoms = []
	if d.get("type") == "FeatureCollection":
		for f in d.get("features", []):
			geoms.append(f.get("geometry", {}))
	elif d.get("type") == "Feature":
		geoms.append(d.get("geometry", {}))
	else:
		geoms.append(d)
	for g in geoms:
		if not g is Dictionary:
			continue
		match g.get("type"):
			"LineString":
				lines.append(g.coordinates)
			"MultiLineString", "Polygon":
				lines.append_array(g.coordinates)
			"MultiPolygon":
				for poly in g.coordinates:
					lines.append_array(poly)
	var best = []
	for line in lines:
		if line.size() > best.size():
			best = line
	var out = []
	for c in best:
		out.append([float(c[0]), float(c[1]), float(c[2]) if c.size() > 2 else NAN])
	return out


static func parse_osm(text):
	var xml = XMLParser.new()
	xml.open_buffer(text.to_utf8_buffer())
	var nodes = {}
	var ways = []
	var way = null
	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			match xml.get_node_name():
				"node":
					nodes[xml.get_named_attribute_value_safe("id")] = [
						float(xml.get_named_attribute_value_safe("lon")),
						float(xml.get_named_attribute_value_safe("lat")),
						NAN
					]
				"way":
					way = {"refs": [], "raceway": false}
					ways.append(way)
				"nd":
					if way != null:
						way.refs.append(xml.get_named_attribute_value_safe("ref"))
				"tag":
					if (
						way != null
						and xml.get_named_attribute_value_safe("k") == "highway"
						and xml.get_named_attribute_value_safe("v") == "raceway"
					):
						way.raceway = true
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END and xml.get_node_name() == "way":
			way = null
	var parts = []
	for w in ways:
		if w.raceway and w.refs.size() > 1:
			parts.append(w.refs)
	if parts.is_empty():
		for w in ways:
			if w.refs.size() > 1:
				parts.append(w.refs)
	# Stitch: start from the longest way, repeatedly append a way that shares the current end node.
	parts.sort_custom(func(a, b): return a.size() > b.size())
	if parts.is_empty():
		return []
	var chain = parts.pop_front().duplicate()
	var grown = true
	while grown and not parts.is_empty():
		grown = false
		for i in parts.size():
			var p = parts[i]
			if p[0] == chain[-1]:
				chain.append_array(p.slice(1))
				parts.remove_at(i)
				grown = true
				break
			if p[-1] == chain[-1]:
				var r = p.duplicate()
				r.reverse()
				chain.append_array(r.slice(1))
				parts.remove_at(i)
				grown = true
				break
			if chain[0] == chain[-1]:
				break
	var out = []
	for ref in chain:
		if nodes.has(ref):
			out.append(nodes[ref])
	return out


## Project, resample, simplify and build the document. Height comes from elevation data when
## every point has it (lowest point = 0 m, lightly smoothed); otherwise the circuit is flat.
static func to_document(geo, name, width):
	var lat0 = 0.0
	var lon0 = 0.0
	for g in geo:
		lon0 += g[0] / geo.size()
		lat0 += g[1] / geo.size()
	var kx = 111320.0 * cos(deg_to_rad(lat0))
	var ky = 110540.0
	var pts = []
	var has_ele = true
	var low = INF
	for g in geo:
		pts.append(Vector3((g[0] - lon0) * kx, -(g[1] - lat0) * ky, g[2]))
		has_ele = has_ele and not is_nan(g[2])
		if not is_nan(g[2]):
			low = minf(low, g[2])
	if pts[0].distance_to(pts[-1]) < 1.0:
		pts.pop_back()
	# Resample at 4 m so Douglas-Peucker sees even spacing.
	var even = [pts[0]]
	var carry = 0.0
	for i in range(1, pts.size() + 1):
		var a = pts[i - 1]
		var b = pts[i % pts.size()]
		var seg = Vector2(b.x - a.x, b.y - a.y).length()
		var d = 4.0 - carry
		while d <= seg:
			even.append(a.lerp(b, d / seg))
			d += 4.0
		carry = seg - (d - 4.0)
	var keep = simplify(even, 1.2)
	# Limit spacing so the spline follows the outline: split gaps > 45 m, merge points < 6 m apart.
	var out = []
	for i in keep.size():
		var a = even[keep[i]]
		var b = even[keep[(i + 1) % keep.size()]]
		out.append(a)
		var gap = Vector2(b.x - a.x, b.y - a.y).length()
		for k in range(1, int(gap / 45.0) + 1):
			out.append(a.lerp(b, float(k) / (int(gap / 45.0) + 1)))
	var merged = []
	for p in out:
		if merged.is_empty() or Vector2(p.x - merged[-1].x, p.y - merged[-1].y).length() >= 6.0:
			merged.append(p)
	var points = []
	for i in merged.size():
		var z = 0.0
		if has_ele:
			for j in range(-2, 3):
				z += (merged[posmod(i + j, merged.size())].z - low) / 5.0
		points.append(
			{
				"x": snappedf(merged[i].x, .1),
				"y": snappedf(merged[i].y, .1),
				"w": width,
				"z": snappedf(clampf(z, -60, 60), .1),
				"bank": 0.0
			}
		)
	if points.size() > 2000:
		points = points.slice(0, 2000)
	return {
		"schema": 1,
		"name": name,
		"points": points,
		"objects": [],
		"paint": {},
		"curbOverride": {},
		"curbAuto": true,
		"autoBarriers": true,
		"startS": 0.0,
		"gridS": null
	}


## Closed-loop Douglas-Peucker on an evenly sampled polyline; returns kept indices in order.
static func simplify(pts, tolerance):
	var n = pts.size()
	var keep = {0: true, n / 2: true}
	var stack = [[0, n / 2], [n / 2, n]]
	while not stack.is_empty():
		var r = stack.pop_back()
		var a = pts[r[0] % n]
		var b = pts[r[1] % n]
		var best = -1.0
		var at = -1
		for i in range(r[0] + 1, r[1]):
			var p = pts[i % n]
			var d = (
				Geometry2D
				. get_closest_point_to_segment(Vector2(p.x, p.y), Vector2(a.x, a.y), Vector2(b.x, b.y))
				. distance_to(Vector2(p.x, p.y))
			)
			if d > best:
				best = d
				at = i
		if best > tolerance:
			keep[at % n] = true
			stack.append([r[0], at])
			stack.append([at, r[1]])
	var idx = keep.keys()
	idx.sort()
	return idx
