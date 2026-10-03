#!/usr/bin/env python3
"""Monaco data for trackgen/monaco.gd -> city.json, all in local metres about ORIGIN (+X east, +Z south, +Y up).

  road       the lap centreline resampled to 3 m, y from profile.json
  ground     8 m grid of ground heights: the DSM's low envelope (streets and quays between buildings),
             level with the road (0.15 m under) out to 12 m, blending back to the DEM by 35 m
  buildings  OSM footprints; base = ground at the footprint, height = OSM height / building:levels x 3.2 m,
             else the DSM over the footprint minus that ground (measured, clamped 4-120 m)
  trees, parks, piers  from OSM
Inputs: centreline.json, profile.json, dem.json, osm-buildings.json, osm-nature.json. ODbL / Copernicus.
"""
import json, math

ORIGIN = (43.735, 7.4225)
K = math.cos(math.radians(ORIGIN[0]))
M = 111320.0
D = json.load(open("dem.json", encoding="utf-8"))


def xz(lat, lon):
    return ((lon - ORIGIN[1]) * M * K, (ORIGIN[0] - lat) * M)


def latlon(x, z):
    return (ORIGIN[0] - z / M, ORIGIN[1] + x / (M * K))


def dsm(x, z):
    lat, lon = latlon(x, z)
    y = (D["lat_top"] - lat) / D["dlat"] - 0.5
    xx = (lon - D["lon_left"]) / D["dlon"] - 0.5
    i, j = int(y), int(xx)
    fy, fx = y - i, xx - j
    g = D["h"]
    i = min(max(i, 0), len(g) - 2)
    j = min(max(j, 0), len(g[0]) - 2)
    return (g[i][j] * (1 - fx) + g[i][j + 1] * fx) * (1 - fy) + (g[i + 1][j] * (1 - fx) + g[i + 1][j + 1] * fx) * fy


def low(x, z, r=15.0):
    return min([dsm(x, z)] + [dsm(x + r * math.cos(k * math.pi / 4), z + r * math.sin(k * math.pi / 4)) for k in range(8)])


# --- road: resample the OSM centreline to 3 m, profile y.
pts = [xz(*p) for p in json.load(open("centreline.json", encoding="utf-8"))["points"]]
prof = json.load(open("profile.json", encoding="utf-8"))["profile"]
loop = pts + [pts[0]]
cum = [0.0]
for a, b in zip(loop, loop[1:]):
    cum.append(cum[-1] + math.dist(a, b))
L = cum[-1]
n = int(L / 3.0)
res = []
j = 0
for k in range(n):
    s = k * L / n
    while cum[j + 1] < s:
        j += 1
    t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
    res.append((loop[j][0] + (loop[j + 1][0] - loop[j][0]) * t, loop[j][1] + (loop[j + 1][1] - loop[j][1]) * t))
# No global smoothing (two 1-2-1 passes flattened the Nouvelle Chicane and Swimming Pool jinks). Only OSM
# node kinks tighter than the inside barrier's offset (~6.2 m from the centreline) are relaxed, locally:
# below that the barrier folds back across the road. Relaxing to 10 m collapsed the hairpin and Portier.
def radius(a, b, c):
    area = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2
    return 1e9 if area < 1e-9 else math.dist(b, c) * math.dist(a, c) * math.dist(a, b) / (4 * area)


R_MIN = 6.5
for _ in range(60):
    tight = [i for i in range(n) if radius(res[i - 1], res[i], res[(i + 1) % n]) < R_MIN]
    if not tight:
        break
    for i in tight:
        for j in (i - 1, i, (i + 1) % n):
            a, b, c = res[j - 1], res[j], res[(j + 1) % n]
            res[j] = ((a[0] + 2 * b[0] + c[0]) / 4, (a[1] + 2 * b[1] + c[1]) / 4)
print("min radius", round(min(radius(res[i - 1], res[i], res[(i + 1) % n]) for i in range(n)), 1))
# Back to even 3 m spacing after the relax.
ring = res + [res[0]]
cum = [0.0]
for a, b in zip(ring, ring[1:]):
    cum.append(cum[-1] + math.dist(a, b))
L2 = cum[-1]
out, j = [], 0
for k in range(n):
    s = k * L2 / n
    while cum[j + 1] < s:
        j += 1
    t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
    out.append((ring[j][0] + (ring[j + 1][0] - ring[j][0]) * t, ring[j][1] + (ring[j + 1][1] - ring[j][1]) * t))
res = out
ps, ph = [p[0] for p in prof], [p[1] for p in prof]


PL = json.load(open("profile.json", encoding="utf-8"))["length"]
road = []
for k, (x, z) in enumerate(res):
    s = k * L / n * PL / L
    y = next((ph[i - 1] + (ph[i] - ph[i - 1]) * (s - ps[i - 1]) / max(ps[i] - ps[i - 1], 1e-9) for i in range(1, len(ps)) if ps[i] >= s), ph[-1])
    road.append([round(x, 2), round(y, 4), round(z, 2)])

# Tunnel: road points nearest the lap's OSM tunnel=yes ways (Boulevard Louis II under the Fairmont).
osm = {e["id"]: e for e in json.load(open("osm-roads.json", encoding="utf-8"))["elements"] if e["type"] == "way"}
# The two long Boulevard Louis II tunnel ways only: the Portier underpass way (1470365900) is also tunnel=yes
# and put the tunnel roof over the Portier corner.
tun_nodes = [xz(q["lat"], q["lon"]) for w in (4230891, 1230247123) for q in osm[w]["geometry"]]
tun_idx = [min(range(len(road)), key=lambda i: math.hypot(road[i][0] - q[0], road[i][2] - q[1])) for q in tun_nodes]
tunnel = [min(tun_idx), max(tun_idx)]
in_tunnel = set(range(tunnel[0], tunnel[1] + 1))

# Road lookup grid for corridor tests.
CELL = 20.0
grid = {}
for i, (x, y, z) in enumerate(road):
    grid.setdefault((int(x // CELL), int(z // CELL)), []).append((x, y, z, i in in_tunnel))


def near_road(x, z, reach):
    best = None
    cx, cz = int(x // CELL), int(z // CELL)
    r = int(reach // CELL) + 1
    for dx in range(-r, r + 1):
        for dz in range(-r, r + 1):
            for p in grid.get((cx + dx, cz + dz), []):
                d = math.hypot(p[0] - x, p[2] - z)
                if d < reach and (best is None or d < best[0]):
                    best = (d, p[1], p[3], p[0], p[2])
    return best


# --- ground grid
nature = json.load(open("osm-nature.json", encoding="utf-8"))["elements"]
# OSM coastline is directed with land on its left. Local +Z south reverses that sign.
# The DSM includes quay buildings/boats and previously filled the harbour with raised ground.
coast = []
for e in nature:
    if e.get("tags", {}).get("natural") == "coastline":
        line = [xz(q["lat"], q["lon"]) for q in e.get("geometry", [])]
        coast.extend(zip(line, line[1:]))


def shore(x, z):
    # ponytail: offline grid x coastline scan; use spatial buckets if larger maps make rebuilds too slow.
    best, land = float("inf"), True
    for (ax, az), (bx, bz) in coast:
        dx, dz = bx - ax, bz - az
        t = min(max(((x - ax) * dx + (z - az) * dz) / max(dx * dx + dz * dz, 1e-9), 0), 1)
        d = (x - ax - t * dx) ** 2 + (z - az - t * dz) ** 2
        if d < best:
            best, land = d, dx * (z - az) - dz * (x - ax) < 0
    return math.sqrt(best), land


xs = [p[0] for p in road]
zs = [p[2] for p in road]
x0, x1 = min(xs) - 400, max(xs) + 400
z0, z1 = min(zs) - 400, max(zs) + 400
G = 8.0
nx, nz = int((x1 - x0) / G) + 1, int((z1 - z0) / G) + 1

def ign_grid():
    """IGN RGE ALTI bare-earth heights on this grid, cached in ign-grid.json (one network fetch)."""
    key = [round(x0, 2), round(z0, 2), nx, nz, G]
    try:
        cached = json.load(open("ign-grid.json", encoding="utf-8"))
        if cached["key"] == key:
            return cached["h"]
    except FileNotFoundError:
        pass
    import urllib.request
    pts = [latlon(x0 + ix * G, z0 + iz * G) for iz in range(nz) for ix in range(nx)]
    flat = []
    for i in range(0, len(pts), 200):
        batch = pts[i : i + 200]
        body = json.dumps({"lon": "|".join(f"{p[1]:.7f}" for p in batch), "lat": "|".join(f"{p[0]:.7f}" for p in batch),
                           "resource": "ign_rge_alti_wld", "zonly": "true"}).encode()
        req = urllib.request.Request("https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json", body,
                                     {"Content-Type": "application/json"})
        flat += json.load(urllib.request.urlopen(req))["elevations"]
    h = [[round(v, 2) for v in flat[iz * nx : (iz + 1) * nx]] for iz in range(nz)]
    json.dump({"source": "IGN RGE ALTI via data.geopf.fr, Licence Ouverte 2.0", "key": key, "h": h},
              open("ign-grid.json", "w", encoding="utf-8"))
    return h


# Bare-earth DTM when profile.json came from IGN (no rooftops, so no low envelope); else the DSM envelope.
IGN = ign_grid() if "IGN" in json.load(open("profile.json", encoding="utf-8"))["source"] else None
ground = []
paved = []  # 1 within 35 m of the road (pavements, squares), 0 beyond (the hillside's gardens)
for iz in range(nz):
    row = []
    prow = []
    for ix in range(nx):
        x, z = x0 + ix * G, z0 + iz * G
        h = max(IGN[iz][ix] if IGN else low(x, z), -3.0)
        # IGN reports no-data (-99999) offshore.
        h = -3.0 if h < -100 else h
        nr = near_road(x, z, 35.0)
        prow.append(1 if nr else 0)
        if nr:
            # Pavements are level with the road: ground 0.15 m under the tarmac out to 12 m, blending back to
            # the DEM by 35 m. The tunnel is enclosed by its own walls and ceiling (monaco.gd).
            t = max(0.0, (nr[0] - 12.0) / 23.0)
            if IGN and h > nr[1] + 2.0:
                # Uphill of the road Monaco is held by vertical masonry (monaco.gd _retaining_walls stands in
                # front of this step), not a 23 m earth ramp: reach the bare-earth height by 16 m.
                t = max(0.0, (nr[0] - 10.0) / 6.0)
            h = (nr[1] - 0.15) * (1 - t) + h * t if t < 1.0 else h
        distance, land = shore(x, z)
        if not land and not (nr and nr[0] < 12.0):
            h = -2.0
            prow[-1] = 0
        elif -90 < x < 70 and -85 < z < 165:
            # Authored flat Swimming Pool quay: the DSM reads the stands/buildings as cliffs.
            pool_road = near_road(x, z, 100.0)
            if pool_road:
                # Feather the correction back to the sampled hillside; an abrupt rectangle made new cliffs.
                blend = min(1.0, min(x + 90, 70 - x, z + 85, 165 - z) / 24.0)
                h = h * (1.0 - blend) + (pool_road[1] - 0.15) * blend
                prow[-1] = 1
        row.append(round(h, 2))
    ground.append(row)
    paved.append(prow)


def ground_at(x, z):
    fx, fz = (x - x0) / G, (z - z0) / G
    i, j = min(max(int(fz), 0), nz - 2), min(max(int(fx), 0), nx - 2)
    tx, tz = fx - j, fz - i
    g = ground
    return (g[i][j] * (1 - tx) + g[i][j + 1] * tx) * (1 - tz) + (g[i + 1][j] * (1 - tx) + g[i + 1][j + 1] * tx) * tz


# --- buildings
def num(v):
    try:
        return float(str(v).split()[0].replace(",", "."))
    except (ValueError, IndexError):
        return None


# Casino Square landmarks: OSM tags them as 2-level retail/hotel; heights from their facades (Casino with
# its towers ~20 m above the square, measured from its lowest corner 14 m below it: 36 m; Hotel de
# Paris ~26 m). monaco.gd renders them in cream stone.
LANDMARKS = {161769674: ("casino", 36.0), 8280869: ("hotel_de_paris", 26.0), 2093796: ("fairmont", 24.0)}
buildings = []
dropped = 0
for e in json.load(open("osm-buildings.json", encoding="utf-8"))["elements"]:
    rings = []
    if e["type"] == "way":
        rings = [e["geometry"]]
    else:
        rings = [m["geometry"] for m in e.get("members", []) if m.get("role") == "outer" and "geometry" in m]
    t = e.get("tags", {})
    for g in rings:
        ring = [xz(p["lat"], p["lon"]) for p in g]
        if len(ring) < 4:
            continue
        cx = sum(p[0] for p in ring) / len(ring)
        cz = sum(p[1] for p in ring) / len(ring)
        # Frontage buildings keep their footprint: corners within 8 m of the road (the OSM street line is not
        # always the racing line, e.g. the Hotel de Paris on Casino Square) are pushed back to 8 m. Only a
        # footprint whose centre sits on the road is dropped.
        if (lambda h: h and not h[2])(near_road(cx, cz, 6.0)):
            dropped += 1
            continue
        pushed = []
        for px, pz in ring:
            h = near_road(px, pz, 8.0)
            if h and not h[2] and h[0] > 0.01:
                k = 8.0 / h[0]
                px, pz = h[3] + (px - h[3]) * k, h[4] + (pz - h[4]) * k
            pushed.append((px, pz))
        ring = pushed
        hits = [h for h in [near_road(px, pz, 7.5) for px, pz in ring[::max(1, len(ring) // 12)]] + [near_road(cx, cz, 7.5)] if h and h[2]]
        base = min(ground_at(px, pz) for px, pz in ring)
        if hits:  # over the tunnel (the Fairmont): its walls start on the tunnel roof (monaco.gd, 5.4 m)
            base = max(h[1] for h in hits) + 5.4
        h = num(t.get("height"))
        if h is None and num(t.get("building:levels")) is not None:
            h = num(t["building:levels"]) * 3.2 + 1.0
        if h is None:
            samples = [dsm(cx, cz)] + [dsm(cx + (px - cx) * 0.6, cz + (pz - cz) * 0.6) for px, pz in ring[::max(1, len(ring) // 6)]]
            h = sorted(samples)[len(samples) // 2] - base
        h = min(max(h, 4.0), 120.0)
        kind = t.get("building", "yes")
        if e["id"] in LANDMARKS:
            kind, h = LANDMARKS[e["id"]]
        buildings.append([[round(px, 2) for p in ring for px in p], round(base, 2), round(h, 1), kind])

trees = []
for e in nature:
    if e["type"] == "node":
        x, z = xz(e["lat"], e["lon"])
        if not near_road(x, z, 6.0):
            trees.append([round(x, 2), round(ground_at(x, z), 2), round(z, 2)])
parks, piers = [], []
for e in nature:
    t = e.get("tags", {})
    if e["type"] != "way" or "geometry" not in e:
        continue
    ring = [xz(p["lat"], p["lon"]) for p in e["geometry"]]
    flat = [round(v, 2) for p in ring for v in p]
    if t.get("leisure") in ("park", "garden") or t.get("landuse") == "grass":
        parks.append(flat)
    elif t.get("man_made") in ("pier", "breakwater"):
        piers.append(flat)

# Pools (osm-pool.json): the Stade Nautique Rainier III basin beside the Swimming Pool section, and others.
pools = []
for e in json.load(open("osm-pool.json", encoding="utf-8"))["elements"]:
    ring = [xz(q["lat"], q["lon"]) for q in e["geometry"]]
    pools.append([[round(v, 2) for p in ring for v in p], round(min(ground_at(*p) for p in ring), 2)])

json.dump({
    "schema": 1,
    "origin": ORIGIN,
    "frame": "+X east, +Z south, metres about origin",
    "source": "OpenStreetMap contributors (ODbL 1.0); Copernicus DEM GLO-30",
    "road": road,
    "tunnel": tunnel,
    "ground": {"x0": x0, "z0": z0, "cell": G, "nx": nx, "nz": nz, "h": ground, "paved": paved},
    "buildings": buildings, "trees": trees, "parks": parks, "piers": piers, "pools": pools,
}, open("city.json", "w", encoding="utf-8"), separators=(",", ":"))
print("tunnel idx", tunnel, "road pts", len(road), "lap m", round(L), "ground", nx, "x", nz, "buildings", len(buildings), "dropped near road", dropped, "trees", len(trees), "parks", len(parks), "piers", len(piers))
