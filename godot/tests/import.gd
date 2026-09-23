extends SceneTree
## Headless checks for real-circuit outline import (GPX, GeoJSON, OSM) using synthetic files.
const OutlineImport = preload("res://scripts/outline_import.gd")
const TrackModel = preload("res://scripts/track3d.gd")
const Storage = preload("res://scripts/storage.gd")
var failures = []
var checks = 0


func check(ok, what):
	checks += 1
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


## Circle of radius r metres around (lat0, lon0) with a sinusoidal height profile.
func circle(n, r, lat0 = 50.43, lon0 = 5.97, ele = true):
	var pts = []
	for i in n:
		var a = TAU * i / n
		var dx = cos(a) * r
		var dy = sin(a) * r
		pts.append(
			[
				lon0 + dx / (111320.0 * cos(deg_to_rad(lat0))),
				lat0 + dy / 110540.0,
				100 + 8 * sin(2 * a) if ele else NAN
			]
		)
	return pts


func track_of(doc):
	var t = TrackModel.new()
	t.load_data(doc)
	return t


func _initialize():
	var dir = "user://import-tests"
	DirAccess.make_dir_recursive_absolute(dir)
	var gpx = '<?xml version="1.0"?><gpx><trk><trkseg>'
	for p in circle(720, 300):
		gpx += '<trkpt lat="%.8f" lon="%.8f"><ele>%.2f</ele></trkpt>' % [p[1], p[0], p[2]]
	gpx += "</trkseg></trk></gpx>"
	var f = FileAccess.open(dir + "/ring.gpx", FileAccess.WRITE)
	f.store_string(gpx)
	f.close()
	var r = OutlineImport.load_file(dir + "/ring.gpx")
	check(
		r.has("doc") and Storage.new().validate_track(r.doc).is_empty(),
		"GPX imports as a valid track document"
	)
	var t = track_of(r.doc)
	var zr = Vector2(INF, -INF)
	for sm in t.samples:
		zr = Vector2(minf(zr.x, sm.z), maxf(zr.y, sm.z))
	check(
		absf(t.length - TAU * 300) / (TAU * 300) < .02,
		"GPX circle length %.0f m vs %.0f m" % [t.length, TAU * 300]
	)
	check(
		r.doc.points.size() >= 20 and r.doc.points.size() <= 200,
		"GPX simplified to %d control points" % r.doc.points.size()
	)
	check(
		zr.x >= -.2 and absf(zr.y - zr.x - 16) < 3,
		"GPX elevation kept (range %.1f m, lowest at 0)" % (zr.y - zr.x)
	)
	check(t.validate().errors.is_empty(), "imported circuit is drivable (start line set)")

	var coords = []
	for p in circle(400, 500, 45.62, 9.28, false):
		coords.append([p[0], p[1]])
	coords.append(coords[0])
	f = FileAccess.open(dir + "/ring.geojson", FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{
				"type": "FeatureCollection",
				"features": [{"type": "Feature", "geometry": {"type": "Polygon", "coordinates": [coords]}}]
			}
		)
	)
	f.close()
	r = OutlineImport.load_file(dir + "/ring.geojson")
	t = track_of(r.doc)
	check(absf(t.length - TAU * 500) / (TAU * 500) < .02, "GeoJSON polygon length %.0f m" % t.length)
	var flat = true
	for p in r.doc.points:
		flat = flat and p.z == 0.0
	check(flat, "GeoJSON without altitude imports flat")

	# OSM: circle split into two raceway ways (second stored reversed) plus an unrelated road.
	var pts = circle(200, 250, 52.07, -1.02, false)
	var osm = "<osm>"
	for i in pts.size():
		osm += '<node id="%d" lat="%.8f" lon="%.8f"/>' % [i + 1, pts[i][1], pts[i][0]]
	osm += '<node id="999" lat="52.0" lon="-1.1"/><way id="1">'
	for i in range(0, 101):
		osm += '<nd ref="%d"/>' % (i + 1)
	osm += '<tag k="highway" v="raceway"/></way><way id="2">'
	for i in range(200, 99, -1):
		osm += '<nd ref="%d"/>' % ((i % 200) + 1)
	osm += '<tag k="highway" v="raceway"/></way><way id="3"><nd ref="1"/><nd ref="999"/><tag k="highway" v="service"/></way></osm>'
	f = FileAccess.open(dir + "/ring.osm", FileAccess.WRITE)
	f.store_string(osm)
	f.close()
	r = OutlineImport.load_file(dir + "/ring.osm")
	t = track_of(r.doc)
	check(
		absf(t.length - TAU * 250) / (TAU * 250) < .03,
		"OSM raceway ways stitched into one loop (%.0f m)" % t.length
	)
	check(OutlineImport.load_file(dir + "/missing.gpx").has("error"), "missing file reports an error")
	print(
		(
			"IMPORT %s  %d checks, %d failures"
			% ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()]
		)
	)
	quit(0 if failures.is_empty() else 1)
