#!/usr/bin/env python3
"""Ground height along the lap from IGN RGE ALTI (1 m DTM, bare earth: no buildings) -> ign.json.

The Geoplateforme altimetry service covers Monaco. Samples every 5 m of the OSM centreline. Inside the
tunnel the DTM reads the hillside above it; build_profile.py bridges that span between the portals.
Run once; needs network. Licence: IGN Licence Ouverte 2.0 (Etalab).
"""
import json, math, urllib.request

P = json.load(open("centreline.json", encoding="utf-8"))["points"]
K = math.cos(math.radians(43.735))
M = 111320.0
URL = "https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json"

pts, s = [], 0.0
loop = P + [P[0]]
for a, b in zip(loop, loop[1:]):
    d = M * math.hypot(b[0] - a[0], (b[1] - a[1]) * K)
    n = max(1, math.ceil(d / 5.0))
    for k in range(n):
        t = k / n
        pts.append([s + d * t, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t])
    s += d

out = []
for i in range(0, len(pts), 100):
    batch = pts[i : i + 100]
    body = json.dumps({
        "lon": "|".join(f"{p[2]:.7f}" for p in batch),
        "lat": "|".join(f"{p[1]:.7f}" for p in batch),
        "resource": "ign_rge_alti_wld",
        "zonly": "true",
    }).encode()
    req = urllib.request.Request(URL, body, {"Content-Type": "application/json"})
    z = json.load(urllib.request.urlopen(req))["elevations"]
    out += [[round(p[0], 1), round(h, 2)] for p, h in zip(batch, z)]

json.dump({"source": "IGN RGE ALTI via data.geopf.fr, Licence Ouverte 2.0", "length": round(s, 1), "samples": out},
          open("ign.json", "w", encoding="utf-8"))
print("samples", len(out), "length", round(s), "min", min(h for _, h in out), "max", max(h for _, h in out))
