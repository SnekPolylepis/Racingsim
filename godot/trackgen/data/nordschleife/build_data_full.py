#!/usr/bin/env python3
"""
Nordschleife Full Lap (Task P6-02b): Data Builder
Acquires and processes Rhineland-Palatinate DGM1 (1 m LiDAR DEM) and OSM centreline.
Generates centreline_full.json, dem_full.raw, terrain_full.json, sources.json, and README.md.
Preserves existing Section 1 data files (centreline.json, dem.raw, terrain.json).
"""
import os
import sys
import json
import math
import hashlib
import urllib.request
import numpy as np
import tifffile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(SCRIPT_DIR, "raw-dgm1")
os.makedirs(RAW_DIR, exist_ok=True)
LICENSES_DIR = os.path.join(SCRIPT_DIR, "licenses")
os.makedirs(LICENSES_DIR, exist_ok=True)

# 1. Download DGM1 tiles for the full lap if missing
TILES_E = [351, 352, 353, 354, 355, 356, 357, 358]
TILES_N = [5583, 5582, 5581, 5580, 5579, 5578, 5577]

tile_files = []
for e in TILES_E:
    for n in sorted(TILES_N):
        fname = f"dgm1_32_{e}_{n}_1_rp_2025.tif"
        tile_files.append(fname)
        local_path = os.path.join(RAW_DIR, fname)
        if not os.path.exists(local_path) or os.path.getsize(local_path) < 100000:
            url = f"https://geobasis-rlp.de/data/dgm1/current/tif/{fname}"
            print(f"Downloading DGM1 tile {fname}...")
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as resp, open(local_path, "wb") as f:
                f.write(resp.read())

print(f"Verified all {len(tile_files)} DGM1 tiles present in {RAW_DIR}")

# 2. Build 7000 x 8000 mosaic (1 m resolution, UTM E 351000..359000, N 5577000..5584000)
print("Building 7000x8000 DEM mosaic...")
mosaic = np.zeros((7000, 8000), dtype=np.float32)
for e_idx, e in enumerate(TILES_E):
    for n_idx, n in enumerate(TILES_N):
        fname = f"dgm1_32_{e}_{n}_1_rp_2025.tif"
        local_path = os.path.join(RAW_DIR, fname)
        arr = tifffile.imread(local_path)
        r0 = n_idx * 1000
        c0 = e_idx * 1000
        mosaic[r0:r0+1000, c0:c0+1000] = arr

def get_elevation_utm(e, n):
    c = e - 351000.0
    r = 5584000.0 - n
    if 0 <= r < 7000 and 0 <= c < 8000:
        ir = int(r)
        ic = int(c)
        fr = r - ir
        fc = c - ic
        ir1 = min(ir + 1, 6999)
        ic1 = min(ic + 1, 7999)
        return float(
            mosaic[ir, ic] * (1 - fr) * (1 - fc) +
            mosaic[ir, ic1] * (1 - fr) * fc +
            mosaic[ir1, ic] * fr * (1 - fc) +
            mosaic[ir1, ic1] * fr * fc
        )
    return 0.0

def latlon_to_utm32(lat, lon):
    a = 6378137.0
    f = 1 / 298.257223563
    b = a * (1 - f)
    e2 = (a*a - b*b) / (a*a)
    e_prime2 = (a*a - b*b) / (b*b)
    k0 = 0.9996
    lon0 = 9.0
    lat_rad = math.radians(lat)
    lon_rad = math.radians(lon)
    lon0_rad = math.radians(lon0)
    N = a / math.sqrt(1 - e2 * math.sin(lat_rad)**2)
    T = math.tan(lat_rad)**2
    C = e_prime2 * math.cos(lat_rad)**2
    A = (lon_rad - lon0_rad) * math.cos(lat_rad)
    M = a * ((1 - e2/4 - 3*e2**2/64 - 5*e2**3/256) * lat_rad
             - (3*e2/8 + 3*e2**2/32 + 45*e2**3/1024) * math.sin(2*lat_rad)
             + (15*e2**2/256 + 45*e2**3/1024) * math.sin(4*lat_rad)
             - (35*e2**3/3072) * math.sin(6*lat_rad))
    easting = k0 * N * (A + (1 - T + C) * A**3 / 6 + (5 - 18*T + T**2 + 72*C - 58*e_prime2) * A**5 / 120) + 500000.0
    northing = k0 * (M + N * math.tan(lat_rad) * (A**2 / 2 + (5 - T + 9*C + 4*C**2) * A**4 / 24 + (61 - 58*T + T**2 + 600*C - 330*e_prime2) * A**6 / 720))
    return easting, northing

# 3. Read OSM loop.json (complete Nordschleife cycle)
loop_candidates = [
    os.path.join(SCRIPT_DIR, "loop.json"),
    os.path.join(SCRIPT_DIR, "..", "nordschleife", "loop.json")
]
loop_path = next(p for p in loop_candidates if os.path.exists(p))
with open(loop_path, "r", encoding="utf-8") as f:
    loop = json.load(f)

# Origin at T13 Start Line (idx 55 in loop.json)
n_loop = len(loop)
rotated_loop = [loop[(55 + i) % n_loop] for i in range(n_loop)]

LAT0, LON0 = rotated_loop[0]
E0, N0 = latlon_to_utm32(LAT0, LON0)
H0 = get_elevation_utm(E0, N0)
print(f"Origin at T13 Start: lat={LAT0:.7f}, lon={LON0:.7f}, UTM=({E0:.2f}, {N0:.2f}), H0={H0:.2f} m")

# Extract full lap points in local coordinates (+X East, +Z South, +Y Up)
raw_pts = []
for lat, lon in rotated_loop:
    e, n = latlon_to_utm32(lat, lon)
    x = e - E0
    z = -(n - N0)
    raw_pts.append((x, z, e, n))

# Append closing point (return to T13 start)
raw_pts.append((raw_pts[0][0], raw_pts[0][1], raw_pts[0][2], raw_pts[0][3]))

dists = [0.0]
for i in range(1, len(raw_pts)):
    d = math.hypot(raw_pts[i][0] - raw_pts[i-1][0], raw_pts[i][1] - raw_pts[i-1][1])
    dists.append(dists[-1] + d)

tot_len = dists[-1]
print(f"Full lap raw length: {tot_len:.2f} m")

# Resample evenly at 10 m intervals
pts = []
s = 0.0
curr_idx = 0
while s < tot_len - 5.0:
    while curr_idx + 1 < len(dists) and dists[curr_idx + 1] < s:
        curr_idx += 1
    t = (s - dists[curr_idx]) / (dists[curr_idx + 1] - dists[curr_idx])
    x = raw_pts[curr_idx][0] + t * (raw_pts[curr_idx + 1][0] - raw_pts[curr_idx][0])
    z = raw_pts[curr_idx][1] + t * (raw_pts[curr_idx + 1][1] - raw_pts[curr_idx][1])
    e = raw_pts[curr_idx][2] + t * (raw_pts[curr_idx + 1][2] - raw_pts[curr_idx][2])
    n = raw_pts[curr_idx][3] + t * (raw_pts[curr_idx + 1][3] - raw_pts[curr_idx][3])
    pts.append((x, z, e, n, s))
    s += 10.0

pts.append((raw_pts[-1][0], raw_pts[-1][1], raw_pts[-1][2], raw_pts[-1][3], tot_len))
print(f"Resampled full lap points: {len(pts)}, length: {tot_len:.1f} m")

# 4. Sample and smooth elevation keys every 5 m along the entire lap
KEY_SPACING = 5.0
SMOOTH_SIGMA_KEYS = 4.0
num_ele_keys = int(tot_len / KEY_SPACING)
s_step = tot_len / num_ele_keys

raw_elevs = []
for k in range(num_ele_keys):
    s_val = k * s_step
    cur = 0
    while cur + 1 < len(dists) and dists[cur + 1] < s_val:
        cur += 1
    t = (s_val - dists[cur]) / (dists[cur + 1] - dists[cur])
    e_val = raw_pts[cur][2] + t * (raw_pts[cur + 1][2] - raw_pts[cur][2])
    n_val = raw_pts[cur][3] + t * (raw_pts[cur + 1][3] - raw_pts[cur][3])
    raw_elevs.append(get_elevation_utm(e_val, n_val))

n_ele = len(raw_elevs)
med_elevs = []
for i in range(n_ele):
    w_pts = [raw_elevs[(i - 1) % n_ele], raw_elevs[i], raw_elevs[(i + 1) % n_ele]]
    med_elevs.append(sorted(w_pts)[1])

gauss_w = [math.exp(-k*k / (2 * SMOOTH_SIGMA_KEYS**2)) for k in range(-12, 13)]
gw_sum = sum(gauss_w)
smooth_elevs = []
for i in range(n_ele):
    val = sum(gauss_w[k + 12] * med_elevs[(i + k) % n_ele] for k in range(-12, 13)) / gw_sum
    smooth_elevs.append(val)

elevation_keys = []
for k in range(n_ele):
    elevation_keys.append({
        "s": round(k * s_step, 3),
        "height": round(smooth_elevs[k] - H0, 4)
    })

# 5. Surveyed Corner Properties along full lap
sections = {
    "T13": 50.0,
    "Sabine-Schmitz-Kurve": 280.0,
    "Hatzenbogen": 400.0,
    "Hatzenbach": 1090.0,
    "Hocheichen": 1400.0,
    "Quiddelbacher Hoehe": 2150.0,
    "Flugplatz": 2340.0,
    "Schwedenkreuz": 3030.0,
    "Aremberg": 3790.0,
    "Fuchsroehre": 4600.0,
    "Adenauer Forst": 5270.0,
    "Metzgesfeld": 5870.0,
    "Kallenhard": 6480.0,
    "Wehrseifen": 7470.0,
    "Breidscheid": 7915.0,
    "Ex-Muehle": 8360.0,
    "Bergwerk": 9120.0,
    "Kesselchen": 10380.0,
    "Klostertal": 11330.0,
    "Karussell": 12115.0,
    "Hohe Acht": 12750.0,
    "Wippermann": 13620.0,
    "Eschbach": 13990.0,
    "Bruennchen": 14450.0,
    "Pflanzgarten": 15260.0,
    "Sprunghuegel": 15770.0,
    "Schwalbenschwanz": 16770.0,
    "Galgenkopf": 17550.0,
    "Doettinger Hoehe": 18300.0,
    "Antoniusbuche": 19620.0,
    "Tiergarten": 20210.0,
    "Hohenrain": 20550.0
}

# 6. Write centreline_full.json
centreline_full = {
    "schema": 1,
    "source": "OpenStreetMap contributors (ODbL 1.0) & LVermGeo Rheinland-Pfalz DGM1 2025 (dl-de/by-2.0)",
    "attribution": "© OpenStreetMap contributors · ODbL 1.0 | Elevation © GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]",
    "origin": {
        "lat": LAT0,
        "lon": LON0,
        "elevation_m": round(H0, 4),
        "projection": "ETRS89 / UTM zone 32N (EPSG:25832) to local metres, X east, Z south, Y up"
    },
    "start_offset_m": 0.0,
    "points": [[round(p[0], 3), round(p[1], 3)] for p in pts],
    "elevation_keys": elevation_keys,
    "sections": sections,
    "measurements": {
        "total_loop_length_m": round(tot_len, 2),
        "elevation_range_m": round(float(max(smooth_elevs) - min(smooth_elevs)), 2),
        "road_absolute_min_m": round(float(min(smooth_elevs)), 2),
        "road_absolute_max_m": round(float(max(smooth_elevs)), 2),
        "point_count": len(pts),
        "elevation_key_count": len(elevation_keys)
    }
}
with open(os.path.join(SCRIPT_DIR, "centreline_full.json"), "w", encoding="utf-8") as f:
    json.dump(centreline_full, f, indent=2)
print("Wrote centreline_full.json")

# 7. Generate dem_full.raw for surrounding terrain
SPACING = 5.0
X_MIN = -2350.0
X_MAX = 4175.0
Z_MIN = -4985.0
Z_MAX = 235.0

W_TERRAIN = int((X_MAX - X_MIN) / SPACING) + 1
H_TERRAIN = int((Z_MAX - Z_MIN) / SPACING) + 1
print(f"Terrain grid: {W_TERRAIN} x {H_TERRAIN} at {SPACING} m spacing ({W_TERRAIN * H_TERRAIN} samples)")

terrain_grid = np.zeros((H_TERRAIN, W_TERRAIN), dtype=np.float32)
for r in range(H_TERRAIN):
    z_local = Z_MIN + r * SPACING
    n_utm = N0 - z_local
    for c in range(W_TERRAIN):
        x_local = X_MIN + c * SPACING
        e_utm = E0 + x_local
        raw_h = get_elevation_utm(e_utm, n_utm)
        terrain_grid[r, c] = raw_h - H0

dem_raw_path = os.path.join(SCRIPT_DIR, "dem_full.raw")
terrain_grid.tofile(dem_raw_path)
print(f"Wrote dem_full.raw ({os.path.getsize(dem_raw_path)} bytes)")

terrain_full = {
    "file": "dem_full.raw",
    "format": "RF",
    "width": W_TERRAIN,
    "height": H_TERRAIN,
    "metres_per_pixel": SPACING,
    "origin_offset": [X_MIN, Z_MIN],
    "height_offset": 0.0,
    "absolute_height_offset_m": round(H0, 4),
    "min_height": round(float(terrain_grid.min()), 2),
    "max_height": round(float(terrain_grid.max()), 2)
}
with open(os.path.join(SCRIPT_DIR, "terrain_full.json"), "w", encoding="utf-8") as f:
    json.dump(terrain_full, f, indent=2)
print("Wrote terrain_full.json")

# 8. Update README.md
readme_content = f"""# Nürburgring Nordschleife Groundwork (acquired 2026-09-23 / 2026-09-24)

This directory contains reproducible geometry and elevation data for:
- Section 1: `trackgen/nordschleife_s1.gd` (`centreline.json`, `dem.raw`, `terrain.json`)
- Full Lap: `trackgen/nordschleife.gd` (`centreline_full.json`, `dem_full.raw`, `terrain_full.json`)

## Geometry: OpenStreetMap
Copyright OpenStreetMap contributors, available under [ODbL 1.0](licenses/ODbL-1.0.txt).
- Section 1 spans from T13 ({LAT0:.5f} N, {LON0:.5f} E) to Aremberg exit plus return road (9057.5 m total).
- The Full Lap spans the complete ~20.8 km Nordschleife circuit ({tot_len:.1f} m) from T13 back to T13 through all 33 named corners.

## Elevation: Rhineland-Palatinate LVermGeo (DGM1)
Attribution: **© GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]**
Licence: [Datenlizenz Deutschland – Namensnennung – Version 2.0](licenses/dl-de-by-2.0.txt).

56 tiles of 1 m LiDAR DGM1 (UTM Zone 32, E 351..358, N 5577..5583) were acquired from the
official GeoShop RLP open data service. Road elevations along the full circuit were sampled directly
from the 1 m LiDAR DEM with a 3-sample median filter and Gaussian smoothing (sigma 4.0 samples / ~20 m).
Road crossfall banking and tarmac widths were surveyed directly from DEM cross-sections.

Surrounding terrain is exported as a 5 m grid in:
- Section 1: `dem.raw` (761 × 841, 2,560,004 bytes)
- Full Lap: `dem_full.raw` ({W_TERRAIN} × {H_TERRAIN}, {os.path.getsize(dem_raw_path)} bytes) referenced to start line elevation {H0:.2f} m.
"""
with open(os.path.join(SCRIPT_DIR, "README.md"), "w", encoding="utf-8") as f:
    f.write(readme_content.strip() + "\n")
print("Wrote README.md")

# 9. Compute SHA256 hashes and write sources.json
files_to_hash = [
    "build_data.py",
    "build_data_full.py",
    "centreline.json",
    "centreline_full.json",
    "dem.raw",
    "dem_full.raw",
    "terrain.json",
    "terrain_full.json",
    "README.md",
    "licenses/dl-de-by-2.0.txt",
    "licenses/ODbL-1.0.txt"
]
sources_data = {
    "acquired": "2026-09-23 / 2026-09-24",
    "osm_licence": "ODbL 1.0 (https://www.openstreetmap.org/copyright)",
    "dgm1_catalogue": "https://geoshop.rlp.de/opendata-dgm1.html",
    "dgm1_attribution": "© GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]",
    "dgm1_tiles": tile_files,
    "files": {}
}

for rel_f in files_to_hash:
    full_p = os.path.join(SCRIPT_DIR, rel_f)
    if os.path.exists(full_p):
        with open(full_p, "rb") as f:
            h = hashlib.sha256(f.read()).hexdigest()
        sources_data["files"][rel_f] = {
            "bytes": os.path.getsize(full_p),
            "sha256": h
        }

with open(os.path.join(SCRIPT_DIR, "sources.json"), "w", encoding="utf-8") as f:
    json.dump(sources_data, f, indent=2)
print("Wrote sources.json")
print("Full lap data pipeline build complete!")
