#!/usr/bin/env python3
"""Road elevation along the lap from dem.json (Copernicus GLO-30 DSM) -> profile.json [[s, h], ...].

The DSM is a surface model, so buildings, trees and the Fairmont over the tunnel read high. The road is
the low ground between them: take the minimum DSM within 12 m of each point, bridge the tunnel linearly
between its portals, limits grade, then smooths on a uniform periodic grid (Gaussian sigma 60 m).
"""
import json, math, bisect

D = json.load(open("dem.json", encoding="utf-8"))
P = json.load(open("centreline.json", encoding="utf-8"))["points"]
K = math.cos(math.radians(43.735))
M_LAT = 111320.0


def dsm(lat, lon):
    y = (D["lat_top"] - lat) / D["dlat"] - 0.5
    x = (lon - D["lon_left"]) / D["dlon"] - 0.5
    i, j = int(y), int(x)
    fy, fx = y - i, x - j
    g = D["h"]
    return (g[i][j] * (1 - fx) + g[i][j + 1] * fx) * (1 - fy) + (g[i + 1][j] * (1 - fx) + g[i + 1][j + 1] * fx) * fy


def low(lat, lon, r=12.0):
    best = dsm(lat, lon)
    for k in range(8):
        a = k * math.pi / 4
        best = min(best, dsm(lat + r * math.sin(a) / M_LAT, lon + r * math.cos(a) / (M_LAT * K)))
    return max(best, 2.0)  # quays sit ~2 m above the sea


s, prev, raw = 0.0, None, []
for p in P:
    if prev:
        s += M_LAT * math.hypot(p[0] - prev[0], (p[1] - prev[1]) * K)
    raw.append([s, low(*p)])
    prev = p
length = s + M_LAT * math.hypot(P[0][0] - P[-1][0], (P[0][1] - P[-1][1]) * K)

# Match build_city.py: the main tunnel only, not the separate Portier underpass.
ways = {e["id"]: e for e in json.load(open("osm-roads.json", encoding="utf-8"))["elements"] if e["type"] == "way"}
tun = [(q["lat"], q["lon"]) for w in (4230891, 1230247123) for q in ways[w]["geometry"]]


def nearest_s(pt):
    return min(range(len(P)), key=lambda i: (P[i][0] - pt[0]) ** 2 + ((P[i][1] - pt[1]) * K) ** 2)


idx = [nearest_s(q) for q in tun]
i0, i1 = min(idx), max(idx)
i0 = max(i0 - 2, 0)
# The DSM stays on rooftops past the portal: bridge on to where the road reaches the harbour front.
while i1 < len(P) - 1 and raw[i1][1] > 10.0:
    i1 += 1
for i in range(i0 + 1, i1):
    t = (raw[i][0] - raw[i0][0]) / (raw[i1][0] - raw[i0][0])
    raw[i][1] = raw[i0][1] + (raw[i1][1] - raw[i0][1]) * t
SIGMA = 60.0
cl_s = [r[0] for r in raw]
SOURCE = "Copernicus GLO-30 DSM, low envelope, tunnel bridged, grade limited then periodic Gaussian sigma 60 m; authored approximation"
try:
    # IGN RGE ALTI (fetch_ign.py): a 1 m bare-earth DTM, so no low envelope and far less smoothing. Its
    # samples replace the DSM; the DTM reads the hill over the tunnel, so bridge between the portals: the
    # last road-level sample before the hill and the first after it, inside the OSM tunnel's window.
    ign = json.load(open("ign.json", encoding="utf-8"))["samples"]
    t0, t1 = raw[i0][0] - 40.0, raw[max(idx)][0] + 40.0
    inside = [k for k, (si, h) in enumerate(ign) if t0 < si < t1 and h > 10.0]
    a, b = inside[0] - 1, inside[-1] + 1
    for k in range(a + 1, b):
        t = (ign[k][0] - ign[a][0]) / (ign[b][0] - ign[a][0])
        ign[k][1] = ign[a][1] + (ign[b][1] - ign[a][1]) * t
    raw = [[si, max(h, 1.0)] for si, h in ign]
    i0, i1 = a, b
    SIGMA = 25.0
    SOURCE = "IGN RGE ALTI 1 m DTM (fetch_ign.py), tunnel bridged between portals, grade limited, periodic Gaussian sigma 25 m"
except FileNotFoundError:
    pass

# 120 m moving average on a closed loop (the 30 m DSM puts cliff edges into the Beau Rivage climb).
out = []
for si, _ in raw:
    num = den = 0.0
    for sj, hj in raw:
        d = abs(sj - si)
        d = min(d, length - d)
        if d < SIGMA:
            w = 1 - d / SIGMA
            num += hj * w
            den += w
    out.append([round(si, 1), round(num / den, 2)])
# Grade limit: the steepest real stretches (Mirabeau descent, Beau Rivage) are about 12 %; the 30 m
# DSM makes cliff-edge steps. Forward and backward passes spread a step instead of cutting it.
G = 0.12
for _ in range(3):
    for rng in (range(1, len(out)), range(len(out) - 2, -1, -1)):
        for i in rng:
            j = i - 1 if rng.step == 1 else i + 1
            ds = abs(out[i][0] - out[j][0])
            out[i][1] = round(min(max(out[i][1], out[j][1] - G * ds), out[j][1] + G * ds), 2)
# Resample before smoothing: OSM vertices have uneven spacing, and the closing segment had no
# samples. Explicit periodic interpolation prevents a flat tail followed by a launch ramp at s=0.
stations = [p[0] for p in out] + [length]
heights = [p[1] for p in out] + [out[0][1]]
n = math.ceil(length / 3.0)
step = length / n
uniform = []
for i in range(n):
    s = i * step
    j = min(bisect.bisect_right(stations, s) - 1, len(stations) - 2)
    t = (s - stations[j]) / (stations[j + 1] - stations[j])
    uniform.append(heights[j] + (heights[j + 1] - heights[j]) * t)
# Smooth the grade limiter's sharp transitions as well as the DEM. This models the broad street
# profile, not rooftop edges; preserve planar chicanes. A denser surveyed profile can replace it.
sigma = SIGMA
reach = math.ceil(4 * sigma / step)
weights = [math.exp(-0.5 * (k * step / sigma) ** 2) for k in range(-reach, reach + 1)]
weight_sum = sum(weights)
out = [[round(i * step, 4), round(sum(uniform[(i + k) % n] * w for k, w in zip(range(-reach, reach + 1), weights)) / weight_sum, 4)] for i in range(n)]
out.append([round(length, 4), out[0][1]])
json.dump({"source": SOURCE,
           "length": round(length, 1), "tunnel": [raw[i0][0], raw[i1][0]], "profile": out}, open("profile.json", "w", encoding="utf-8"))
hs = [h for _, h in out]
grades = [abs(out[i + 1][1] - out[i][1]) / max(out[i + 1][0] - out[i][0], 1) for i in range(len(out) - 1)]
print("length", round(length), "min", min(hs), "max", max(hs), "range", round(max(hs) - min(hs), 1), "max grade %.1f%%" % (100 * max(grades)))
for n, lat, lon in [("Start", 43.7340, 7.4214), ("Ste Devote", 43.7369, 7.4217), ("Casino", 43.7394, 7.4274), ("Mirabeau", 43.7411, 7.4288), ("Portier", 43.7410, 7.4303), ("Chicane", 43.7371, 7.4250), ("Tabac", 43.7369, 7.4230), ("Rascasse", 43.7325, 7.4227)]:
    s = cl_s[nearest_s((lat, lon))]
    i = min(range(len(out)), key=lambda k: abs(out[k][0] - s))
    print(f"{n:11s} s={out[i][0]:6.0f} h={out[i][1]:5.1f}")
