"""Spa polish (P6-01): SPW Orthophotos 2023 Été tiles along the circuit, for road widths and kerbs.

Licence: CC BY 4.0, (c) SPW (Service public de Wallonie) - Orthophotos 2023 Été; catalogue
https://geoportail.wallonie.be/catalogue/ad55c2ce-62ad-4c3c-b3cf-8fbc270a6b6e.html
Tiles (140 m of ground, 0.25 m/px, Web Mercator EPSG:3857 so pixels are square on the ground)
centred every 10th centreline point are cached in ortho-cache/
(git-ignored: only the derived measurements and ortho-tiles.json, the exact request of every tile,
are committed). Tiles are exported directly (f=image; the service's output directory refuses
downloads); box and image are both square, so the requested box is the image's exact extent.
"""
import json, math, pathlib, time, urllib.parse, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
EXPORT = "https://geoservices.wallonie.be/arcgis/rest/services/IMAGERIE/ORTHO_2023_ETE/MapServer/export"
HEADERS = {"User-Agent": "RacingSim/1.0 (public circuit authoring)"}
TILE_M = 140.0
PX = 560
EVERY = 10


R_MERC = 6378137.0


def mercator(lon, lat):
    return R_MERC * math.radians(lon), R_MERC * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))


def get(url, params, binary=False):
    full = url + ("?" + urllib.parse.urlencode(params) if params else "")
    for attempt in range(4):
        try:
            raw = urllib.request.urlopen(urllib.request.Request(full, headers=HEADERS), timeout=90).read()
            return raw if binary else json.loads(raw)
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 + 3 * attempt)


def main():
    centre = json.loads((ROOT / "centreline.json").read_text(encoding="utf-8"))
    lat0, lon0 = centre["origin"]["lat"], centre["origin"]["lon"]
    r = 6371008.8
    ky = math.pi * r / 180
    kx = ky * math.cos(math.radians(lat0))
    pts = centre["points"]
    cache = ROOT / "ortho-cache"
    cache.mkdir(exist_ok=True)
    (cache / ".gitignore").write_text("*" + chr(10), encoding="utf-8")
    tiles = []
    for k, i in enumerate(range(0, len(pts), EVERY)):
        x, z = float(pts[i][0]), float(pts[i][1])
        lon, lat = lon0 + x / kx, lat0 - z / ky
        mx, my = mercator(lon, lat)
        # Mercator metres per ground metre is 1 / cos(lat) at this latitude.
        half = TILE_M / 2 / math.cos(math.radians(lat))
        bbox = [mx - half, my - half, mx + half, my + half]
        dest = cache / f"tile-{k:03d}.jpg"
        if not dest.exists():
            params = {
                "bbox": ",".join(f"{v:.3f}" for v in bbox),
                "bboxSR": 3857,
                "imageSR": 3857,
                "size": f"{PX},{PX}",
                "format": "jpg",
                "transparent": "false",
                "f": "image",
            }
            raw = get(EXPORT, params, binary=True)
            if raw[:2] != bytes([0xFF, 0xD8]):
                raise ValueError(f"tile {k}: not a JPEG: {raw[:200]!r}")
            dest.write_bytes(raw)
            time.sleep(0.4)
        tiles.append(
            {
                "tile": k,
                "centre_point": i,
                "extent_3857": [round(v, 3) for v in bbox],
                "width": PX,
                "height": PX,
            }
        )
        print(f"tile {k + 1}", flush=True)
    out = {
        "schema": 1,
        "source": "SPW Orthophotos 2023 Été (25 cm), MapServer export, Web Mercator (EPSG:3857)",
        "service": EXPORT,
        "licence": "CC BY 4.0",
        "attribution": "© SPW - Orthophotos 2023 Été",
        "tiles": tiles,
    }
    (ROOT / "ortho-tiles.json").write_text(json.dumps(out, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
