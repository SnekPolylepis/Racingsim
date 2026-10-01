#!/usr/bin/env python3
"""Chicago city data (CHI-02): the raw downtown OSM extracts staged in
assets/cc0-source/chicago/roadmap/ -> trackgen/data/chicago/city.json, in CHI-01's local frame.

The frame is trackgen/chicago.gd world(): x = (lon + 87.6244) * 82860, z = (41.8848 - lat) * 111320, in
metres (+X east, +Z south). Output, all coordinates rounded to 0.1 m:
  buildings: [{"f": [[x, z], ...] outer ring, "h": height m above street level, "k": facade kind}]
  roads:     [{"p": [[x, z], ...], "w": carriageway width m, "c": class, "b": 1 if a bridge}]
  water:     [[[x, z], ...], ...] river and water polygons
  parks:     [[[x, z], ...], ...] parks, gardens and grass
Tunnels and roads below street level are dropped (the circuit authors Lower Wacker itself). Buildings use
OSM heights/parts, city storeys and cited landmark overrides, then measured USGS roofs where covered.
Unresolved heights are flagged u:1; the legacy storey-to-metre conversion and 9.8 m placeholder are not
surveyed heights. Retain OSM element IDs (o) for source/coverage auditing. Licence: ODbL 1.0,
(c) OpenStreetMap contributors (the same terms as osm-roads.json); USGS source grids are public domain.
"""
import hashlib
import json
import math
import os
import re
import base64
import glob

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "..", "..", "assets", "cc0-source", "chicago", "roadmap")
OUT = os.path.join(HERE, "city.json")

WIDTHS = {
    "motorway": 22.0, "trunk": 18.0, "primary": 15.0, "secondary": 13.0, "tertiary": 11.0,
    "residential": 9.0, "living_street": 7.0, "service": 5.5,
    "motorway_link": 8.0, "trunk_link": 8.0, "primary_link": 7.5, "secondary_link": 7.0, "tertiary_link": 7.0,
}


def xz(lat, lon):
    return [round((lon + 87.6244) * 82860.0, 1), round((41.8848 - lat) * 111320.0, 1)]


def ring(geom):
    pts = [xz(g["lat"], g["lon"]) for g in geom]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    return pts


def area(pts):
    a = 0.0
    for i in range(len(pts)):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % len(pts)]
        a += x1 * z2 - x2 * z1
    return abs(a) * 0.5


def number(value):
    m = re.match(r"\s*([0-9]+(?:\.[0-9]+)?)", str(value))
    return float(m.group(1)) if m else None


## Roof heights (m) for towers whose OSM outline carries no usable height (their heights sit on
## building:part elements outside this extract). Public figures, roof not antenna.
LANDMARK_HEIGHTS = {
    "Willis Tower": 442.0, "Trump International Hotel & Tower Chicago": 423.0, "Aon Center": 346.0,
    "John Hancock Center": 344.0, "875 North Michigan Avenue": 344.0, "St. Regis Chicago": 363.0,
    "Two Prudential Plaza": 303.0, "311 South Wacker Drive": 293.0, "Crain Communications Building": 261.0,
    "AT&T Corporate Center": 307.0, "Chase Tower": 259.0, "Blue Cross Blue Shield Tower": 227.0,
    "Marina City": 179.0, "Merchandise Mart": 105.0, "Wrigley Building": 134.0, "Tribune Tower": 141.0,
    "Chicago Board of Trade Building": 184.0, "Park Tower": 257.0, "Water Tower Place": 262.0,
    "Olympia Centre": 221.0, "900 North Michigan": 265.0, "Legacy Tower": 249.0, "Vista Tower": 363.0,
}


def height_of(tags, footprint_area, key, landmarks=True):
    for name, h in (LANDMARK_HEIGHTS.items() if landmarks else []):
        if name.lower() in tags.get("name", "").lower():
            return h
    h = tags.get("height")
    if h is not None:
        n = number(h)
        if n is not None:
            return n * 0.3048 if ("ft" in str(h) or "'" in str(h)) else n
    levels = number(tags.get("building:levels", ""))
    if levels:
        return levels * 3.9 + 2.0
    # No OSM height: resolved in main() from the City of Chicago footprints' storey counts.
    return None


## OSM colour names seen downtown -> hex. Anything else must already be #rrggbb.
COLOUR_NAMES = {
    "white": "#e8e6e0", "black": "#2a2a2c", "grey": "#8a8c8e", "gray": "#8a8c8e", "silver": "#b4b8bc",
    "brown": "#6e4b35", "red": "#8c3a2e", "beige": "#d8c8a8", "tan": "#c4a878", "blue": "#4a6a8c",
    "darkgrey": "#4a4c4e", "lightgrey": "#c0c2c4", "cream": "#e8dcc0", "yellow": "#d8c060", "green": "#4a6a50",
    "gold": "#b89850", "bronze": "#6a5438", "darkgray": "#4a4c4e", "lightgray": "#c0c2c4",
}


def colour_of(tags):
    c = str(tags.get("building:colour", tags.get("colour", ""))).strip().lower().replace(" ", "")
    c = COLOUR_NAMES.get(c, c)
    return c if re.fullmatch(r"#[0-9a-f]{6}", c) else ""


def kind_of(tags, h, key):
    material = tags.get("building:material", tags.get("facade:material", "")) + tags.get("building:facade:material", "")
    use = tags.get("building", "")
    r = int(hashlib.md5(("k" + str(key)).encode()).hexdigest()[:6], 16) % 100
    if "glass" in material:
        return "glass" if r < 70 else "glass2"
    if use in ("parking", "garage", "garages"):
        return "concrete"
    if "brick" in material:
        return "brick"
    if "concrete" in material or "plaster" in material:
        return "concrete"
    if "metal" in material or "steel" in material or "aluminium" in material:
        return "glass2"
    if use in ("church", "cathedral", "civic", "public", "government") or "stone" in material:
        return "stone"
    # Untagged: one neutral facade, not a guess.
    return "stone"


def inside(p, poly):
    x, z = p
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            hit = not hit
        j = i
    return hit


def simplify(pts, tol, closed=True):
    """Douglas-Peucker (iterative), keeping the shape within `tol` metres."""
    if len(pts) < 5:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        ax, az = pts[a]
        bx, bz = pts[b]
        dx, dz = bx - ax, bz - az
        seg = math.hypot(dx, dz) or 1e-9
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            px, pz = pts[i]
            d = abs(dx * (az - pz) - (ax - px) * dz) / seg
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    out = [p for p, k in zip(pts, keep) if k]
    return out if len(out) >= 3 else pts


## Area kept for water and parks: the extract's bbox in local metres plus a margin, so the lake ring (the
## whole Lake Michigan shoreline) is cut to what can be seen.
CLIP = (-2600.0, -3200.0, 2700.0, 2000.0)


def clip_rect(pts, rect):
    """Sutherland-Hodgman clip of a polygon to an axis-aligned rectangle (x0, z0, x1, z1)."""
    x0, z0, x1, z1 = rect
    edges = [(lambda p: p[0] >= x0, lambda a, b: x0, 0), (lambda p: p[0] <= x1, lambda a, b: x1, 0),
             (lambda p: p[1] >= z0, lambda a, b: z0, 1), (lambda p: p[1] <= z1, lambda a, b: z1, 1)]
    out = pts
    for inside, value, axis in edges:
        src, out = out, []
        if not src:
            break
        for i in range(len(src)):
            cur, prev = src[i], src[i - 1]
            if inside(cur):
                if not inside(prev):
                    out.append(cross(prev, cur, value(prev, cur), axis))
                out.append(cur)
            elif inside(prev):
                out.append(cross(prev, cur, value(prev, cur), axis))
    return out


def cross(a, b, v, axis):
    t = (v - a[axis]) / ((b[axis] - a[axis]) or 1e-9)
    p = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
    p[axis] = v
    return [round(p[0], 1), round(p[1], 1)]


def city_storeys():
    """City of Chicago Building Footprints (data.cityofchicago.org syp8-uezg): [(ring in our frame, storeys)]."""
    out = []
    with open(os.path.join(RAW, "city-footprints.json"), encoding="utf-8") as f:
        rows = json.load(f)
    for r in rows:
        n = number(r.get("stories") or "0") or number(r.get("no_stories") or "0") or 0
        g = r.get("the_geom") or {}
        if n <= 0 or g.get("type") != "MultiPolygon":
            continue
        for poly in g["coordinates"]:
            out.append(([xz(lat, lon) for lon, lat in poly[0]], n))
    return out


LIDAR_CELL = 2
# Crowns the LiDAR roof replaces (estimated shapes); signs, masts and lit beacons stay.
LIDAR_REPLACES = {"spire", "pyramid", "slant", "cupola", "twin_domes", "gable"}


def lidar_grids():
    """USGS 3DEP surface grids from fetch_lidar.py: [(dsm - ground, x0, z0)]."""
    out = []
    for f in sorted(glob.glob(os.path.join(RAW, "..", "lidar", "lidar-*.npz"))):
        d = np.load(f)
        out.append((d["dsm"] - np.nanmedian(d["dtm"]), float(d["x0"]), float(d["z0"])))
    return out


def lidar_massing(ring, grids, excluded=None):
    """The building's measured roof as a raster over its footprint: [x0, z0, w, h, cell, base64 u16 dm]."""
    if excluded:
        return None  # A cited newer building/roof must not be flattened by an older acquisition.
    from PIL import Image, ImageDraw
    xs = [p[0] for p in ring]
    zs = [p[1] for p in ring]
    for dsm, gx0, gz0 in grids:
        if min(xs) < gx0 or min(zs) < gz0 or max(xs) >= gx0 + dsm.shape[1] - 2 or max(zs) >= gz0 + dsm.shape[0] - 2:
            continue
        c = int(LIDAR_CELL)
        x0, z0 = np.floor(min(xs)), np.floor(min(zs))
        w = int(np.ceil((max(xs) - x0) / c))
        h = int(np.ceil((max(zs) - z0) / c))
        if w < 1 or h < 1:
            return None
        win = dsm[int(z0 - gz0):int(z0 - gz0) + h * c, int(x0 - gx0):int(x0 - gx0) + w * c]
        if win.shape != (h * c, w * c):
            return None
        with np.errstate(all="ignore"):
            hgt = np.nanmedian(win.reshape(h, c, w, c).transpose(0, 2, 1, 3).reshape(h, w, c * c), axis=2)
        img = Image.new("L", (w, h), 0)
        ImageDraw.Draw(img).polygon([((p[0] - x0) / c - 0.5, (p[1] - z0) / c - 0.5) for p in ring], fill=1)
        mask = np.array(img, bool)
        if not mask.any():
            return None
        known = hgt[mask & ~np.isnan(hgt)]
        if known.size == 0:
            return None
        hgt = np.where(np.isnan(hgt), np.median(known), hgt)
        hgt = np.maximum(hgt, 0.5)
        pad = np.pad(hgt * mask, 1)
        neigh = np.max([pad[1 + dj:1 + dj + h, 1 + di:1 + di + w] for dj in (-1, 0, 1) for di in (-1, 0, 1) if dj or di], axis=0)
        hgt = np.where(hgt > neigh + 15.0, neigh, hgt)
        hgt = np.round(hgt * 2) / 2 * mask
        if hgt.max() <= 0:
            return None
        dm = np.clip(np.round(hgt * 10), 0, 65535).astype("<u2")
        return [float(x0), float(z0), w, h, float(c), base64.b64encode(dm.tobytes()).decode()], float(hgt.max()), known.size / int(mask.sum())
    return None


def load(name):
    with open(os.path.join(RAW, name), encoding="utf-8") as f:
        return json.load(f)["elements"]


def stitch(parts):
    """Join open way segments (a multipolygon's outer members) end to end into closed rings."""
    parts = [p[:] for p in parts if len(p) >= 2]
    rings = []
    while parts:
        cur = parts.pop(0)
        grew = True
        while grew and cur[0] != cur[-1]:
            grew = False
            for i, p in enumerate(parts):
                if p[0] == cur[-1]:
                    cur += p[1:]
                elif p[-1] == cur[-1]:
                    cur += p[::-1][1:]
                elif p[-1] == cur[0]:
                    cur = p[:-1] + cur
                elif p[0] == cur[0]:
                    cur = p[::-1][:-1] + cur
                else:
                    continue
                parts.pop(i)
                grew = True
                break
        if cur[0] == cur[-1]:
            rings.append(cur[:-1])
    return rings


def outer_rings(e):
    if e["type"] == "way" and "geometry" in e:
        pts = [xz(g["lat"], g["lon"]) for g in e["geometry"]]
        return [pts[:-1]] if len(pts) > 3 and pts[0] == pts[-1] else []
    if e["type"] == "relation":
        segs = [[xz(g["lat"], g["lon"]) for g in m["geometry"]] for m in e.get("members", []) if m.get("role") == "outer" and "geometry" in m]
        return stitch(segs)
    return []


def main():
    buildings = []
    for e in load("downtown-buildings.json"):
        tags = e.get("tags", {})
        if tags.get("building") in ("roof", "canopy", "construction", "no") or number(tags.get("layer", "0") or 0) and number(tags.get("layer")) < 0:
            continue
        for pts in outer_rings(e):
            if len(pts) < 3:
                continue
            a = area(pts)
            if a < 20:
                continue
            h = height_of(tags, a, e["id"])
            b = {"f": simplify(pts, 0.25), "h": round(h, 1) if h is not None else None, "k": kind_of(tags, h or 0, e["id"])}
            if colour_of(tags):
                b["c"] = colour_of(tags)
            b["o"] = e["type"][0] + str(e["id"])
            buildings.append(b)

    # Heights OSM lacks: the city's storey count for the footprint containing the building's centre.
    storeys = city_storeys()
    cells = {}
    for i, (r, n) in enumerate(storeys):
        cx = sum(p[0] for p in r) / len(r)
        cz = sum(p[1] for p in r) / len(r)
        cells.setdefault((int(cx // 50), int(cz // 50)), []).append(i)
    unresolved = []
    for b in buildings:
        if b["h"] is not None:
            continue
        cx = sum(p[0] for p in b["f"]) / len(b["f"])
        cz = sum(p[1] for p in b["f"]) / len(b["f"])
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for i in cells.get((int(cx // 50) + dx, int(cz // 50) + dz), []):
                    if b["h"] is None and inside((cx, cz), storeys[i][0]):
                        b["h"] = round(storeys[i][1] * 3.9 + 2.0, 1)
        if b["h"] is None:
            unresolved.append(b)
    # No height anywhere: 2 storeys, flagged "u" so it can be found and fixed; never a made-up tower.
    for b in unresolved:
        b["h"] = 9.8
        b["u"] = 1
    print("heights: %d from city storeys data, %d unknown (2-storey placeholder)" % (sum(1 for b in buildings if "u" not in b) , len(unresolved)))

    # Real 3-D shapes: OSM building:part elements (setbacks, podiums, crowns). Where parts exist the parent
    # outline is not drawn (the OSM 3-D convention); parts stack from min_height / building:min_level.
    parts = []
    for e in load("downtown-building-parts.json"):
        tags = e.get("tags", {})
        for pts in outer_rings(e):
            if len(pts) < 3 or area(pts) < 4:
                continue
            h = height_of(tags, area(pts), e["id"], landmarks=False)
            if h is None:
                continue
            mh = number(tags.get("min_height", "")) or ((number(tags.get("building:min_level", "")) or 0) * 3.9)
            if h <= mh + 0.5:
                continue
            b = {"o": e["type"][0] + str(e["id"]), "f": simplify(pts, 0.25), "h": round(h, 1), "k": kind_of(tags, h, e["id"])}
            if mh:
                b["m"] = round(mh, 1)
            if colour_of(tags):
                b["c"] = colour_of(tags)
            parts.append(b)
    centres = [(sum(p[0] for p in b["f"]) / len(b["f"]), sum(p[1] for p in b["f"]) / len(b["f"])) for b in parts]
    kept = [b for b in buildings if not any(inside(c, b["f"]) for c in centres)]
    replaced = [b for b in buildings if any(inside(c, b["f"]) for c in centres)]
    print("parts %d replace %d parent outlines" % (len(parts), len(buildings) - len(kept)))
    buildings = kept + parts

    # Sourced per-building overrides (landmarks.json): height, facade, colour, facade bands, roof crown.
    with open(os.path.join(HERE, "landmarks.json"), encoding="utf-8") as f:
        marks = json.load(f)["buildings"]
    used = set()
    extra = []
    for b in buildings:
        m = marks.get(b.get("o", ""))
        if m is None:
            continue
        used.add(m["name"])
        b.pop("u", None)
        if m.get("lidar_exclude"):
            b["lr"] = m["lidar_exclude"]
        for key in ("h", "k", "c"):
            if key in m:
                b[key] = m[key]
        if "crown" in m:
            b["cr"] = m["crown"]
        if "photo" in m:
            b["ph"] = m["photo"]
        if m.get("glass"):
            b["gl"] = 1
        if m.get("pk"):
            b["pk"] = 1
        for lo, hi, kind, colour in m.get("bands", []):
            extra.append({"f": b["f"], "h": min(hi, b["h"]), "m": lo, "k": kind, "c": colour, "band": 1})
    # Landmarks drawn by their OSM parts: facade on every part, crown and top band on the tallest,
    # base band on the ground-level parts. OSM part heights stay (they are the real massing).
    for parent in replaced:
        m = marks.get(parent.get("o", ""))
        if m is None:
            continue
        mine = [b for b, c in zip(parts, centres) if inside(c, parent["f"])]
        if not mine:
            continue
        used.add(m["name"])
        for b in mine:
            if m.get("lidar_exclude"):
                b["lr"] = m["lidar_exclude"]
            for key in ("k", "c"):
                if key in m:
                    b[key] = m[key]
        top = max(mine, key=lambda b: b["h"])
        if "crown" in m:
            top["cr"] = m["crown"]
        for lo, hi, kind, colour in m.get("bands", []):
            if lo == 0:
                for b in mine:
                    if not b.get("m"):
                        extra.append({"f": b["f"], "h": min(hi, b["h"]), "m": 0, "k": kind, "c": colour, "band": 1})
            else:
                span = hi - lo
                extra.append({"f": top["f"], "h": top["h"], "m": top["h"] - span, "k": kind, "c": colour, "band": 1})
    buildings += extra

    # Measured roofs (USGS LiDAR) for every building the grids cover. In LiDAR areas the OSM parts are
    # not needed: the measured surface already holds each setback, so parents come back and parts go.
    grids = lidar_grids()
    if grids:
        def covered(b):
            return lidar_massing(b["f"], grids, b.get("lr")) is not None
        n0 = len(buildings)
        buildings = [b for b in buildings if not (b in parts and covered(b))]
        for parent in replaced:
            if not marks.get(parent.get("o", ""), {}).get("lidar_exclude") and covered(parent):
                m = marks.get(parent.get("o", ""), {})
                for key in ("k", "c"):
                    if key in m:
                        parent[key] = m[key]
                if "crown" in m:
                    parent["cr"] = m["crown"]
                if "photo" in m:
                    parent["ph"] = m["photo"]
                if m.get("pk"):
                    parent["pk"] = 1
                buildings.append(parent)
        lidar = 0
        for b in buildings:
            if b.get("band"):
                continue
            got = lidar_massing(b["f"], grids, b.get("lr"))
            if got is None:
                continue
            b["L"], b["h"] = got[0], round(got[1], 1)
            b["lc"] = round(got[2], 4)  # Fraction of roof cells supported by returns before gap filling.
            b.pop("u", None)
            b.pop("m", None)
            if b.get("cr", {}).get("type") in LIDAR_REPLACES and "beacon" not in b["cr"]:
                b.pop("cr")
            lidar += 1
        # Facade bands follow the measured roof; drop those that sit on replaced parts.
        buildings = [b for b in buildings if not (b.get("band") and covered(b) and b.get("m", 0) > 0)]
        print("lidar massing: %d buildings (%d -> %d entries)" % (lidar, n0, len(buildings)))
    print("landmark overrides applied: %d/%d %s" % (len(used), len(marks), sorted(set(m["name"] for m in marks.values()) - used)))

    roads = []
    for e in load("downtown-roads.json"):
        tags = e.get("tags", {})
        if tags.get("tunnel") not in (None, "no") or (number(tags.get("layer", "0")) or 0) < 0:
            continue
        cls = tags.get("highway", "")
        if cls not in WIDTHS or "geometry" not in e:
            continue
        lanes = number(tags.get("lanes", ""))
        w = WIDTHS[cls]
        if lanes:
            w = max(w * 0.6, min(lanes * 3.4, 26.0))
        roads.append({"p": simplify([xz(g["lat"], g["lon"]) for g in e["geometry"]], 0.3), "w": round(w, 1), "c": cls, "b": 1 if tags.get("bridge") not in (None, "no") else 0})

    water, parks = [], []
    for e in load("downtown-water-leisure.json"):
        tags = e.get("tags", {})
        is_water = tags.get("natural") == "water" or tags.get("waterway") == "riverbank"
        is_park = tags.get("leisure") in ("park", "garden") or tags.get("landuse") == "grass"
        if not (is_water or is_park):
            continue
        for pts in outer_rings(e):
            if len(pts) >= 3 and area(pts) > 150:
                cut = clip_rect(pts, CLIP)
                if len(cut) >= 3 and area(cut) > 150:
                    (water if is_water else parks).append(simplify(cut, 0.8))

    # Real mapped trees (OSM natural=tree) with the LiDAR canopy height where the survey covers them, footpaths
    # inside parks, and park structures (pavilions, fountains) flagged so they don't get office facades.
    trees = []
    paths = []
    tp = load("downtown-trees-paths.json")
    for e in tp:
        t = e.get("tags", {})
        if e["type"] == "node" and t.get("natural") == "tree":
            x, z = xz(e["lat"], e["lon"])
            h = 0.0
            for dsm, gx0, gz0 in grids:
                i, j = int(x - gx0), int(z - gz0)
                if 1 <= i < dsm.shape[1] - 1 and 1 <= j < dsm.shape[0] - 1:
                    with np.errstate(all="ignore"):
                        v = np.nanmax(dsm[j - 1:j + 2, i - 1:i + 2])
                    if not np.isnan(v) and 3.0 < v < 35.0:
                        h = round(float(v), 1)
            trees.append([x, z, h])
        elif e["type"] == "way" and "geometry" in e:
            pts = [xz(g["lat"], g["lon"]) for g in e["geometry"]]
            mid = pts[len(pts) // 2]
            if any(inside(mid, pk) for pk in parks):
                paths.append({"p": simplify(pts, 0.3, closed=False), "w": 4.0 if t.get("highway") == "pedestrian" else 2.6})
    for b in buildings:
        c = (sum(p[0] for p in b["f"]) / len(b["f"]), sum(p[1] for p in b["f"]) / len(b["f"]))
        if b["h"] < 25.0 and any(inside(c, pk) for pk in parks):
            b["pk"] = 1
    print("trees %d (%d with LiDAR height), park paths %d, park structures %d" % (len(trees), sum(1 for t in trees if t[2]), len(paths), sum(1 for b in buildings if b.get("pk"))))

    # Sculptural steel measured by LiDAR (Pritzker Pavilion headdress and the Great Lawn trellis): the surface
    # itself as a thin shell raster [x0, z0, w, h, 1 m, base64 u16 dm, shell thickness m].
    shells = []
    for x0s, z0s, x1s, z1s, lo, hi, thick in ((158, 118, 264, 182, 14.0, 60.0, 1.5), (170, 182, 252, 346, 12.0, 32.0, 0.35)):
        for dsm, gx0, gz0 in grids:
            if x0s < gx0 or z0s < gz0 or x1s > gx0 + dsm.shape[1] or z1s > gz0 + dsm.shape[0]:
                continue
            win = dsm[int(z0s - gz0):int(z1s - gz0), int(x0s - gx0):int(x1s - gx0)]
            hgt = np.where((win > lo) & (win < hi), win, 0)
            hgt = np.nan_to_num(np.round(hgt * 2) / 2)
            dm = np.clip(np.round(hgt * 10), 0, 65535).astype("<u2")
            shells.append([float(x0s), float(z0s), dm.shape[1], dm.shape[0], 1.0, base64.b64encode(dm.tobytes()).decode(), thick])
    print("steel shells %d" % len(shells))

    # Harbours: real OSM mooring points (a moored boat on each), piers and breakwaters.
    moorings, piers = [], []
    for e in load("harbor.json"):
        t = e.get("tags", {})
        if e["type"] == "node" and (t.get("mooring") or "mooring" in t.get("seamark:type", "")):
            moorings.append(xz(e["lat"], e["lon"]))
        elif e["type"] == "way" and t.get("man_made") in ("pier", "breakwater") and "geometry" in e:
            piers.append({"p": [xz(g["lat"], g["lon"]) for g in e["geometry"]], "w": 6.0 if t["man_made"] == "breakwater" else 3.0})
    print("moorings %d, piers/breakwaters %d" % (len(moorings), len(piers)))

    # The real elevated 'L' (OSM railway=subway on bridges): one polyline per track.
    elevated = []
    for e in load("downtown-rail.json"):
        t = e.get("tags", {})
        if t.get("railway") == "subway" and t.get("bridge") in ("yes", "viaduct", "movable") and "geometry" in e:
            elevated.append({"p": [xz(g["lat"], g["lon"]) for g in e["geometry"]], "n": t.get("name", "")})
    # Chain the OSM track pieces end to end (within 1.5 m) so trains can run along whole lines.
    def chain(pieces):
        left = [list(map(tuple, t["p"])) for t in pieces]
        out = []
        while left:
            line = left.pop()
            grown = True
            while grown:
                grown = False
                for i, q in enumerate(left):
                    for a, b, rev in ((line[-1], q[0], False), (line[-1], q[-1], True), (line[0], q[-1], None), (line[0], q[0], "front_rev")):
                        if math.dist(a, b) < 1.5:
                            q = left.pop(i)
                            if rev is False:
                                line = line + q[1:]
                            elif rev is True:
                                line = line + q[::-1][1:]
                            elif rev is None:
                                line = q[:-1] + line
                            else:
                                line = q[::-1][:-1] + line
                            grown = True
                            break
                    if grown:
                        break
            out.append([list(p) for p in line])
        return out
    lines = [c for c in chain(elevated) if sum(math.dist(c[i], c[i + 1]) for i in range(len(c) - 1)) > 300]
    print("elevated L tracks: %d, chained train lines: %d" % (len(elevated), len(lines)))

    out = {
        "schema": 1,
        "elevated": elevated,
        "l_lines": lines,
        "trees": trees,
        "moorings": moorings,
        "shells": shells,
        "piers": piers,
        "paths": paths,
        "source": "OpenStreetMap contributors (ODbL 1.0), Overpass extracts fetched 2026-09-25; see assets/cc0-source/chicago/roadmap/README.md",
        "frame": "trackgen/chicago.gd world(): x = (lon + 87.6244) * 82860, z = (41.8848 - lat) * 111320",
        "buildings": buildings,
        "roads": roads,
        "water": water,
        "parks": parks,
    }
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, separators=(",", ":"))
    print("buildings %d, roads %d, water %d, parks %d, %.1f MB" % (len(buildings), len(roads), len(water), len(parks), os.path.getsize(OUT) / 1e6))
    hs = sorted(b["h"] for b in buildings)
    print("heights: median %.0f m, p90 %.0f m, max %.0f m" % (hs[len(hs) // 2], hs[int(len(hs) * 0.9)], hs[-1]))


if __name__ == "__main__":
    main()
