"""Spa polish (P6-01): LiDAR cross-sections across the road at every centreline station.

Samples SPW's 0.5 m ground model (same service and licence as build_data.py: SPW MNT 2021-2022,
CC BY 4.0) on lines perpendicular to the OSM centreline in centreline.json, from -14 m (left of the
racing direction) to +14 m (right) every 0.5 m. Raw responses are kept in raw-lidar/xsec/ so the
result rebuilds offline; output is cross-sections.json (heights in metres, absolute DNG).
Python 3 only; requests go one at a time with a short pause (public service).
"""
import json, math, pathlib, time, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
SERVICE = "https://geoservices.wallonie.be/arcgis/rest/services/RELIEF/WALLONIE_MNT_2021_2022/MapServer/identify"
HALF = 14.0
STEP = 0.5
BATCH = 400


def fetch(index, coords):
    dest = ROOT / "raw-lidar" / "xsec" / f"xsec-{index:03d}.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        raw = dest.read_bytes()
    else:
        params = {
            "f": "json",
            "geometryType": "esriGeometryMultipoint",
            "geometry": json.dumps({"points": coords, "spatialReference": {"wkid": 4326}}, separators=(",", ":")),
            "sr": 4326,
            "layers": "all:0",
            "tolerance": 0,
            "mapExtent": "5.95,50.42,5.99,50.46",
            "imageDisplay": "100000,100000,96",
            "returnGeometry": "false",
        }
        req = urllib.request.Request(
            SERVICE,
            data=urllib.parse.urlencode(params).encode(),
            headers={"User-Agent": "RacingSim/1.0 (public circuit authoring)"},
        )
        for attempt in range(4):
            try:
                raw = urllib.request.urlopen(req, timeout=60).read()
                doc = json.loads(raw)
                if len(doc.get("results", [])) != len(coords):
                    raise ValueError(str(doc)[:300])
                dest.write_bytes(raw)
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2 + 3 * attempt)
        time.sleep(0.4)
    values = [float(r["attributes"]["Stretch.Pixel Value"]) for r in json.loads(raw)["results"]]
    if len(values) != len(coords) or not all(math.isfinite(v) and 200 < v < 800 for v in values):
        raise ValueError(f"batch {index}: bad heights")
    return values


def main():
    centre = json.loads((ROOT / "centreline.json").read_text(encoding="utf-8"))
    lat0, lon0 = centre["origin"]["lat"], centre["origin"]["lon"]
    r = 6371008.8
    ky = math.pi * r / 180
    kx = ky * math.cos(math.radians(lat0))
    pts = [(float(p[0]), float(p[1])) for p in centre["points"]]
    n = len(pts)
    offsets = [round(-HALF + k * STEP, 3) for k in range(int(2 * HALF / STEP) + 1)]
    stations = []
    coords = []
    for i in range(n):
        ax, az = pts[i - 1]
        bx, bz = pts[(i + 1) % n]
        tx, tz = bx - ax, bz - az
        norm = math.hypot(tx, tz)
        tx, tz = tx / norm, tz / norm
        # Right of the racing direction with X east, Z south, Y up: right = tangent x up = (-tz, tx).
        rx, rz = -tz, tx
        stations.append({"i": i, "x": pts[i][0], "z": pts[i][1], "right": [round(rx, 6), round(rz, 6)]})
        for o in offsets:
            x, z = pts[i][0] + rx * o, pts[i][1] + rz * o
            coords.append([round(lon0 + x / kx, 8), round(lat0 - z / ky, 8)])
    heights = []
    batches = math.ceil(len(coords) / BATCH)
    for b in range(batches):
        heights += fetch(b, coords[b * BATCH : (b + 1) * BATCH])
        print(f"batch {b + 1}/{batches}", flush=True)
    per = len(offsets)
    for k, s in enumerate(stations):
        s["heights"] = [round(h, 3) for h in heights[k * per : (k + 1) * per]]
    out = {
        "schema": 1,
        "source": "SPW MNT 2021-2022 (updated 2024-01-23), 0.5 m DTM via MapServer identify layer 0",
        "licence": "CC BY 4.0",
        "attribution": "Service public de Wallonie (SPW) - Relief de la Wallonie - MNT 2021-2022",
        "centreline": "centreline.json points (OSM, ODbL)",
        "offsets_m": offsets,
        "offset_sign": "positive = right of the racing direction",
        "stations": stations,
    }
    (ROOT / "cross-sections.json").write_text(json.dumps(out, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"stations {n}, points {len(coords)}")


if __name__ == "__main__":
    main()
