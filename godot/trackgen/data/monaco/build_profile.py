#!/usr/bin/env python3
"""Road elevation along the lap from dem.json (Copernicus GLO-30 DSM) -> profile.json [[s, h], ...].

The DSM is a surface model, so buildings, trees and the Fairmont over the tunnel read high. The road is
the low ground between them: take the minimum DSM within 12 m of each point, bridge the tunnel linearly
between its portals (OSM tunnel=yes on Boulevard Louis II), then smooth over 80 m.
"""
import json, math

D = json.load(open("dem.json"))
P = json.load(open("centreline.json"))["points"]
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

# Tunnel: every lap way tagged tunnel=yes (Boulevard Louis II under the Fairmont, the Portier underpass).
ways = {e["id"]: e for e in json.load(open("osm-roads.json"))["elements"] if e["type"] == "way"}
LAP = [int(w) for w in open("build_route.py").read().split("LAP = [")[1].split("]")[0].replace("#", ",#").split(",") if w.strip().isdigit()]
tun = [(q["lat"], q["lon"]) for w in LAP if ways[w]["tags"].get("tunnel") == "yes" and w != 1470365907 for q in ways[w]["geometry"]]


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

# 120 m moving average on a closed loop (the 30 m DSM puts cliff edges into the Beau Rivage climb).
out = []
for si, _ in raw:
    num = den = 0.0
    for sj, hj in raw:
        d = abs(sj - si)
        d = min(d, length - d)
        if d < 60:
            w = 1 - d / 60
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
json.dump({"source": "Copernicus GLO-30 DSM, road low envelope (floor 2 m), tunnel bridged, 120 m smooth, grade <= 12 %",
           "length": round(length, 1), "tunnel": [raw[i0][0], raw[i1][0]], "profile": out}, open("profile.json", "w"))
hs = [h for _, h in out]
grades = [abs(out[i + 1][1] - out[i][1]) / max(out[i + 1][0] - out[i][0], 1) for i in range(len(out) - 1)]
print("length", round(length), "min", min(hs), "max", max(hs), "range", round(max(hs) - min(hs), 1), "max grade %.1f%%" % (100 * max(grades)))
for n, lat, lon in [("Start", 43.7340, 7.4214), ("Ste Devote", 43.7369, 7.4217), ("Casino", 43.7394, 7.4274), ("Mirabeau", 43.7411, 7.4288), ("Portier", 43.7410, 7.4303), ("Chicane", 43.7371, 7.4250), ("Tabac", 43.7369, 7.4230), ("Rascasse", 43.7325, 7.4227)]:
    i = nearest_s((lat, lon))
    print(f"{n:11s} s={out[i][0]:6.0f} h={out[i][1]:5.1f}")
