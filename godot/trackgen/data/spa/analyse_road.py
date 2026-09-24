"""Spa polish (P6-01): measure road half-widths, kerbs and banking at every centreline station.

Inputs: centreline.json (OSM), cross-sections.json (SPW LiDAR, fetch_sections.py) and the cached SPW
Orthophotos 2023 Été tiles (fetch_ortho.py, ortho-cache/). Output: road-profile.json, one row per
centreline point (~10 m): source station s, measured half-widths to the track limit on each side,
kerb width and colour class beyond it, and the crossfall bank (the project's convention: positive
lowers the right side). `--debug N` writes annotated tile N to ortho-cache/debug-N.png.

Edge rule per side, walking out from the OSM centreline in 0.25 m steps: the first white line pixel,
kerb pixel or grass pixel at least MIN_HALF out is the track limit. A run of kerb pixels starting
within 0.75 m beyond it is the kerb. Stations where no edge is found within MAX_HALF, or where the two
sides disagree wildly with their neighbours, are filled from the neighbours (median over +-2).
"""
import json, math, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent
R_MERC = 6378137.0
STEP = 0.25
MIN_HALF = 3.0
MAX_HALF = 11.0
FIT_HALF = 3.5


def classify(rgb):
    r, g, b = (float(v) for v in rgb)
    mx, mn = max(r, g, b), min(r, g, b)
    if mn > 185 and mx - mn < 45:
        return "white"
    if r > 140 and r - g > 55 and r - b > 55:
        return "red"
    if r > 160 and g > 130 and b < 110 and r - b > 80:
        return "yellow"
    if g > r + 8 and g > b + 8:
        return "grass"
    return "tarmac"


def main():
    centre = json.loads((ROOT / "centreline.json").read_text(encoding="utf-8"))
    lat0, lon0 = centre["origin"]["lat"], centre["origin"]["lon"]
    ky = math.pi * 6371008.8 / 180
    kx = ky * math.cos(math.radians(lat0))
    xsec = json.loads((ROOT / "cross-sections.json").read_text(encoding="utf-8"))
    tiles = json.loads((ROOT / "ortho-tiles.json").read_text(encoding="utf-8"))["tiles"]
    images = {}
    pts = centre["points"]
    n = len(pts)
    length = float(centre["measurements"]["source_polyline_length_m"])

    def pixel(tile, x, z):
        lon, lat = lon0 + x / kx, lat0 - z / ky
        mx = R_MERC * math.radians(lon)
        my = R_MERC * math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))
        x0, y0, x1, y1 = tile["extent_3857"]
        return (mx - x0) / (x1 - x0) * tile["width"], (y1 - my) / (y1 - y0) * tile["height"]

    def rgb_at(i, x, z):
        tile = tiles[min(len(tiles) - 1, int(round(i / 10.0)))]
        if tile["tile"] not in images:
            images[tile["tile"]] = np.asarray(
                Image.open(ROOT / "ortho-cache" / f"tile-{tile['tile']:03d}.jpg").convert("RGB")
            )
        img = images[tile["tile"]]
        px, py = pixel(tile, x, z)
        if not (0 <= px < img.shape[1] - 1 and 0 <= py < img.shape[0] - 1):
            return None
        return img[int(py), int(px)]

    rows = []
    offsets = xsec["offsets_m"]
    fit_idx = [k for k, o in enumerate(offsets) if abs(o) <= FIT_HALF]
    for i in range(n):
        st = xsec["stations"][i]
        rx, rz = st["right"]
        x, z = float(pts[i][0]), float(pts[i][1])
        row = {"i": i, "s": round(i * length / n, 2)}
        for side, sign in (("left", -1.0), ("right", 1.0)):
            edge, kind, kerb, kerb_class = None, None, 0.0, None
            d = MIN_HALF
            while d <= MAX_HALF:
                c = rgb_at(i, x + rx * sign * d, z + rz * sign * d)
                if c is None:
                    break
                k = classify(c)
                if k in ("white", "red", "yellow", "grass"):
                    edge, kind = d, k
                    break
                d += STEP
            if edge is not None:
                # Kerb: kerb-coloured pixels (red, yellow, or white between them) starting within
                # 0.75 m beyond the limit; its width runs until tarmac or grass.
                run_start, run_end, colours = None, None, set()
                d2 = edge
                while d2 <= edge + 4.0:
                    c = rgb_at(i, x + rx * sign * d2, z + rz * sign * d2)
                    if c is None:
                        break
                    k = classify(c)
                    if k in ("red", "yellow"):
                        colours.add(k)
                        if run_start is None and d2 <= edge + .75:
                            run_start = d2
                        run_end = d2
                    elif k != "white" and run_start is not None:
                        break
                    elif k in ("grass", "tarmac") and run_start is None and d2 > edge + .75:
                        break
                    d2 += STEP
                if run_start is not None:
                    kerb = round(run_end - run_start + STEP, 2)
                    kerb_class = "+".join(sorted(colours))
            row["half_" + side] = edge
            row["edge_" + side] = kind
            row["kerb_" + side] = kerb
            row["kerb_colour_" + side] = kerb_class
        h = st["heights"]
        xs = np.array([offsets[k] for k in fit_idx])
        ys = np.array([h[k] for k in fit_idx])
        slope = np.polyfit(xs, ys, 1)[0]
        row["bank_deg"] = round(-math.degrees(math.atan(slope)), 3)
        rows.append(row)
    # Fill and smooth: median over +-2 stations of the detected half-widths.
    detected = {s: sum(1 for r in rows if r["half_" + s] is not None) for s in ("left", "right")}
    for side in ("left", "right"):
        raw = [r["half_" + side] for r in rows]
        for i in range(n):
            window = [raw[(i + k) % n] for k in range(-2, 3) if raw[(i + k) % n] is not None]
            rows[i]["half_" + side + "_m"] = round(float(np.median(window)), 2) if window else None
    for i in range(n):
        window = [rows[(i + k) % n]["bank_deg"] for k in range(-2, 3)]
        rows[i]["bank_smooth_deg"] = round(float(np.mean(window)), 3)
    out = {
        "schema": 1,
        "sources": {
            "centreline": "centreline.json (OSM, ODbL)",
            "widths_kerbs": "SPW Orthophotos 2023 Été, CC BY 4.0 (ortho-tiles.json)",
            "bank": "SPW MNT 2021-2022 0.5 m, CC BY 4.0 (cross-sections.json), line fit within +-3.5 m",
        },
        "method": __doc__.strip().splitlines()[-4:],
        "detected_fraction": {k: round(v / n, 3) for k, v in detected.items()},
        "stations": rows,
    }
    (ROOT / "road-profile.json").write_text(json.dumps(out, indent=0) + "\n", encoding="utf-8")
    print("stations", n, "edge detected", out["detected_fraction"])
    lw = [r["half_left_m"] for r in rows if r["half_left_m"]]
    rw = [r["half_right_m"] for r in rows if r["half_right_m"]]
    print("half-width left %.1f..%.1f median %.1f; right %.1f..%.1f median %.1f" % (min(lw), max(lw), np.median(lw), min(rw), max(rw), np.median(rw)))
    print("kerb stations left %d right %d" % (sum(r["kerb_left"] > 0 for r in rows), sum(r["kerb_right"] > 0 for r in rows)))
    if "--debug" in sys.argv:
        t = int(sys.argv[sys.argv.index("--debug") + 1])
        tile = tiles[t]
        img = Image.open(ROOT / "ortho-cache" / f"tile-{t:03d}.jpg").convert("RGB")
        draw = ImageDraw.Draw(img)
        for r in rows:
            if int(round(r["i"] / 10.0)) != t:
                continue
            st = xsec["stations"][r["i"]]
            rx, rz = st["right"]
            x, z = float(pts[r["i"]][0]), float(pts[r["i"]][1])
            for side, sign, col in (("left", -1, (0, 255, 255)), ("right", 1, (255, 0, 255))):
                hw = r["half_" + side + "_m"]
                if hw is None:
                    continue
                a = pixel(tile, x, z)
                b = pixel(tile, x + rx * sign * hw, z + rz * sign * hw)
                draw.line([a, b], fill=col, width=2)
                if r["kerb_" + side] > 0:
                    c = pixel(tile, x + rx * sign * (hw + r["kerb_" + side]), z + rz * sign * (hw + r["kerb_" + side]))
                    draw.line([b, c], fill=(255, 255, 0), width=3)
        img.save(ROOT / "ortho-cache" / f"debug-{t}.png")
        print("debug image", ROOT / "ortho-cache" / f"debug-{t}.png")


if __name__ == "__main__":
    main()
