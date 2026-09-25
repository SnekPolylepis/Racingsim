#!/usr/bin/env python3
"""Chicago city data (CHI-02): the raw downtown OSM extracts staged in
assets/cc0-source/chicago/roadmap/ -> trackgen/data/chicago/city.json, in CHI-01's local frame.

The frame is trackgen/chicago.gd world(): x = (lon + 87.6244) * 82860, z = (41.8848 - lat) * 111320, in
metres (+X east, +Z south). Output, all coordinates rounded to 0.1 m:
  buildings: [{"f": [[x, z], ...] outer ring, "h": height m above street level, "k": facade kind}]
  roads:     [{"p": [[x, z], ...], "w": carriageway width m, "c": class, "b": 1 if a bridge}]
  water:     [[[x, z], ...], ...] river and water polygons
  parks:     [[[x, z], ...], ...] parks, gardens and grass
Tunnels and roads below street level are dropped (the circuit authors Lower Wacker itself). Buildings with
no height tag get one from their footprint area and a stable hash, so the skyline does not change between
runs. Licence: ODbL 1.0, (c) OpenStreetMap contributors (the same terms as osm-roads.json).
"""
import hashlib
import json
import math
import os
import re

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


def height_of(tags, footprint_area, key):
    for name, h in LANDMARK_HEIGHTS.items():
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
    # No tags: a stable pseudo-random height by footprint size (the Loop is tall, small lots are low).
    r = int(hashlib.md5(str(key).encode()).hexdigest()[:8], 16) / 0xFFFFFFFF
    if footprint_area < 180:
        return 7.0 + r * 6.0
    if footprint_area < 900:
        return 12.0 + r * 22.0
    return 20.0 + r * 60.0


def kind_of(tags, h, key):
    material = tags.get("building:material", "")
    use = tags.get("building", "")
    r = int(hashlib.md5(("k" + str(key)).encode()).hexdigest()[:6], 16) % 100
    if "glass" in material or h > 110:
        return "glass" if r < 70 else "glass2"
    if use in ("parking", "garage", "garages"):
        return "concrete"
    if "brick" in material:
        return "brick"
    if use in ("church", "cathedral", "civic", "public", "government") or "stone" in material:
        return "stone"
    if h > 55:
        return ["glass", "glass2", "stone", "terracotta"][r % 4]
    if h > 25:
        return ["stone", "terracotta", "brick", "glass2"][r % 4]
    return ["brick", "brick", "stone", "concrete"][r % 4]


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
            buildings.append({"f": simplify(pts, 0.25), "h": round(h, 1), "k": kind_of(tags, h, e["id"])})

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

    out = {
        "schema": 1,
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
