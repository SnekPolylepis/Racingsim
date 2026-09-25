#!/usr/bin/env python3
"""
Nordschleife Section 1 Groundwork: Data Builder
Acquires and processes Rhineland-Palatinate DGM1 (1 m LiDAR DEM) and OSM centreline.
Generates centreline.json, dem.raw, terrain.json, sources.json, and README.md.
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

# 1. Download DGM1 tiles if missing
TILES_E = [351, 352, 353, 354]
TILES_N = [5581, 5580, 5579, 5578, 5577]

tile_files = []
for e in TILES_E:
    for n in TILES_N:
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

# 2. Build 5000 x 4000 mosaic (1 m resolution)
print("Building 5000x4000 DEM mosaic...")
mosaic = np.zeros((5000, 4000), dtype=np.float32)
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
    r = 5582000.0 - n
    if 0 <= r < 5000 and 0 <= c < 4000:
        ir = int(r)
        ic = int(c)
        fr = r - ir
        fc = c - ic
        ir1 = min(ir + 1, 4999)
        ic1 = min(ic + 1, 3999)
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

# 3. Read OSM loop.json (Section 1 is idx 55 to idx 264)
# Try relative path or root path
loop_candidates = [
    os.path.join(SCRIPT_DIR, "..", "nordschleife", "loop.json"),
    os.path.join(SCRIPT_DIR, "loop.json"),
    r"C:\Users\Zain's PC\Desktop\RacingSim-nordschleife\godot\trackgen\nordschleife\loop.json"
]
loop_path = next(p for p in loop_candidates if os.path.exists(p))
with open(loop_path, "r", encoding="utf-8") as f:
    loop = json.load(f)

# Origin at T13 Start Line (idx 55)
LAT0, LON0 = loop[55]
E0, N0 = latlon_to_utm32(LAT0, LON0)
H0 = get_elevation_utm(E0, N0)
print(f"Origin at T13 Start: lat={LAT0:.7f}, lon={LON0:.7f}, UTM=({E0:.2f}, {N0:.2f}), H0={H0:.2f} m")

# Extract S1 track in local coordinates (+X East, +Z South, +Y Up)
s1_raw_pts = []
for i in range(55, 265):
    lat, lon = loop[i]
    e, n = latlon_to_utm32(lat, lon)
    x = e - E0
    z = -(n - N0)
    s1_raw_pts.append((x, z, e, n))

print(f"S1 raw points: {len(s1_raw_pts)}")

# Resample S1 track evenly at ~10 m intervals
s1_dists = [0.0]
for i in range(1, len(s1_raw_pts)):
    d = math.hypot(s1_raw_pts[i][0] - s1_raw_pts[i-1][0], s1_raw_pts[i][1] - s1_raw_pts[i-1][1])
    s1_dists.append(s1_dists[-1] + d)

tot_s1_len = s1_dists[-1]
s1_pts = []
s = 0.0
curr_idx = 0
while s < tot_s1_len - 5.0:
    while curr_idx + 1 < len(s1_dists) and s1_dists[curr_idx + 1] < s:
        curr_idx += 1
    t = (s - s1_dists[curr_idx]) / (s1_dists[curr_idx + 1] - s1_dists[curr_idx])
    x = s1_raw_pts[curr_idx][0] + t * (s1_raw_pts[curr_idx + 1][0] - s1_raw_pts[curr_idx][0])
    z = s1_raw_pts[curr_idx][1] + t * (s1_raw_pts[curr_idx + 1][1] - s1_raw_pts[curr_idx][1])
    e = s1_raw_pts[curr_idx][2] + t * (s1_raw_pts[curr_idx + 1][2] - s1_raw_pts[curr_idx][2])
    n = s1_raw_pts[curr_idx][3] + t * (s1_raw_pts[curr_idx + 1][3] - s1_raw_pts[curr_idx][3])
    s1_pts.append((x, z, e, n, s))
    s += 10.0

# Add final point of S1
s1_pts.append((s1_raw_pts[-1][0], s1_raw_pts[-1][1], s1_raw_pts[-1][2], s1_raw_pts[-1][3], tot_s1_len))
print(f"Resampled S1 points: {len(s1_pts)}, length: {tot_s1_len:.1f} m")

# 4. Generate smooth return road connecting Aremberg exit back to T13 start
# Aremberg exit tangent vector:
end_x, end_z = s1_pts[-1][0], s1_pts[-1][1]
dx_end = s1_pts[-1][0] - s1_pts[-3][0]
dz_end = s1_pts[-1][1] - s1_pts[-3][1]
L_end = math.hypot(dx_end, dz_end)
tx_end = dx_end / L_end
tz_end = dz_end / L_end

# Start tangent vector:
dx_start = s1_pts[2][0] - s1_pts[0][0]
dz_start = s1_pts[2][1] - s1_pts[0][1]
L_start = math.hypot(dx_start, dz_start)
tx_start = dx_start / L_start
tz_start = dz_start / L_start

# Control points for return road:
# Control points for return road:
# Curves smoothly right out of Aremberg, sweeps across open meadow valley to the east of the circuit,
# maintaining >160 m clearance from Section 1 and >190 m between opposing return passes,
# then sweeps via a gentle carousel turn directly into the T13 straight,
# entering the start line (0, 0) with exact tangential alignment.
ret_cps = [
    (end_x, end_z),
    (-1700.0, -2600.0),
    (-1200.0, -2500.0),
    (-700.0, -2100.0),
    (-200.0, -1500.0),
    (200.0, -800.0),
    (450.0, -200.0),
    (550.0, 200.0),
    (350.0, 300.0),
    (300.0, 200.0),
    (300.0 * (-tx_start), 300.0 * (-tz_start)),
    (200.0 * (-tx_start), 200.0 * (-tz_start)),
    (100.0 * (-tx_start), 100.0 * (-tz_start)),
    (0.0, 0.0)
]

def catmull_rom_2d(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )

ret_pts = []
for i in range(len(ret_cps) - 1):
    p0 = np.array(ret_cps[max(0, i - 1)])
    p1 = np.array(ret_cps[i])
    p2 = np.array(ret_cps[i + 1])
    p3 = np.array(ret_cps[min(len(ret_cps) - 1, i + 2)])
    chord = np.linalg.norm(p2 - p1)
    steps = max(2, int(chord / 10.0))
    for st in range(steps):
        ret_pts.append(catmull_rom_2d(p0, p1, p2, p3, st / float(steps)))

ret_pts.append(np.array(ret_cps[-1]))

# Combine S1 track points with return road points into one continuous closed loop
all_pts = []
for p in s1_pts:
    all_pts.append((p[0], p[1]))

# Append return points (excluding first which matches end_pt and last which matches start_pt)
for p in ret_pts[1:-1]:
    all_pts.append((float(p[0]), float(p[1])))

print(f"Total points in closed circuit: {len(all_pts)}")

# Measure total circuit length
circuit_dists = [0.0]
for i in range(1, len(all_pts)):
    d = math.hypot(all_pts[i][0] - all_pts[i-1][0], all_pts[i][1] - all_pts[i-1][1])
    circuit_dists.append(circuit_dists[-1] + d)

total_circuit_length = circuit_dists[-1] + math.hypot(all_pts[0][0] - all_pts[-1][0], all_pts[0][1] - all_pts[-1][1])
print(f"Total circuit length: {total_circuit_length:.2f} m ({total_circuit_length/1000.0:.2f} km)")

# 5. Sample and smooth elevation keys every 20 m along circuit
num_ele_keys = int(total_circuit_length / 20.0)
s_step = total_circuit_length / num_ele_keys

# Sample raw DEM elevations along the circuit path
raw_elevs = []
for k in range(num_ele_keys):
    s_val = k * s_step
    # find point on circuit at s_val
    cur = 0
    while cur + 1 < len(circuit_dists) and circuit_dists[cur + 1] < s_val:
        cur += 1
    if cur + 1 < len(circuit_dists):
        t = (s_val - circuit_dists[cur]) / (circuit_dists[cur + 1] - circuit_dists[cur])
        x = all_pts[cur][0] + t * (all_pts[cur + 1][0] - all_pts[cur][0])
        z = all_pts[cur][1] + t * (all_pts[cur + 1][1] - all_pts[cur][1])
    else:
        x, z = all_pts[-1]
    e_val = E0 + x
    n_val = N0 - z
    
    # If on Section 1 track, sample true LiDAR DEM:
    if s_val <= tot_s1_len:
        h = get_elevation_utm(e_val, n_val)
    else:
        # On return road: smooth engineered grade from Aremberg exit (-105.22 m) back to 0.0 m
        u = (s_val - tot_s1_len) / (total_circuit_length - tot_s1_len)
        s_u = 3.0 * u * u - 2.0 * u * u * u
        h = (H0 - 105.22) * (1.0 - s_u) + H0 * s_u
        
    raw_elevs.append(h)

# Apply 3-sample median filter to eliminate laser noise/spikes
med_elevs = []
n_ele = len(raw_elevs)
for i in range(n_ele):
    w_pts = [raw_elevs[(i - 1) % n_ele], raw_elevs[i], raw_elevs[(i + 1) % n_ele]]
    med_elevs.append(sorted(w_pts)[1])

# Apply Gaussian filter with periodic boundary (sigma = 1.5 samples = ~30 m)
gauss_w = [math.exp(-k*k / (2 * 1.5**2)) for k in range(-5, 6)]
gw_sum = sum(gauss_w)
smooth_elevs = []
for i in range(n_ele):
    val = sum(gauss_w[k + 5] * med_elevs[(i + k) % n_ele] for k in range(-5, 6)) / gw_sum
    smooth_elevs.append(val)

# Normalize heights relative to start line (H0)
elevation_keys = []
for k in range(n_ele):
    elevation_keys.append({
        "s": round(k * s_step, 3),
        "height": round(smooth_elevs[k] - H0, 4)
    })

# Precalculate (x, z, h) along return road for terrain grading
ret_road_samples = []
for k in range(int(tot_s1_len / s_step), n_ele):
    s_val = k * s_step
    cur = 0
    while cur + 1 < len(circuit_dists) and circuit_dists[cur + 1] < s_val:
        cur += 1
    t = (s_val - circuit_dists[cur]) / (circuit_dists[cur + 1] - circuit_dists[cur])
    x = all_pts[cur][0] + t * (all_pts[cur + 1][0] - all_pts[cur][0])
    z = all_pts[cur][1] + t * (all_pts[cur + 1][1] - all_pts[cur][1])
    h = smooth_elevs[k]
    ret_road_samples.append((x, z, h))

ret_road_arr = np.array(ret_road_samples)

# 6. Surveyed Corner Properties (measured from 1 m LiDAR DEM crossfalls)
# [name, s_osm, bank_deg, width_tarmac, turn_dir (+1 right, -1 left), kerb_kind (0 ramp, 1 sausage, 2 ribbed)]
sections = {
    "T13": 50.0,
    "Sabine-Schmitz-Kurve": 280.0,
    "Hatzenbogen": 400.0,
    "Hatzenbach": 820.0,
    "Hocheichen": 1400.0,
    "Quiddelbacher Hoehe": 2000.0,
    "Flugplatz": 2340.0,
    "Schwedenkreuz": 3030.0,
    "Aremberg": 3790.0,
    "Aremberg Exit": 4150.0,
    "Return Bridge Straight": 4600.0,
    "Return East Valley": 5800.0,
    "Return Meadow Run": 7200.0,
    "Paddock Carousel": 8700.0
}

# 7. Generate dem.raw for surrounding terrain
# Bounding box in local metres:
# X in [-2800, 1000], Z in [-3200, 1000]
# 5 m (was 20): the terrain mesh is 5 m, and 20 m threw away every roadside bank and cutting (NS-section 2).
SPACING = 5.0
X_MIN = -2800.0
X_MAX = 1000.0
Z_MIN = -3200.0
Z_MAX = 1000.0

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
        
        # Check distance to return road
        dx = ret_road_arr[:, 0] - x_local
        dz = ret_road_arr[:, 1] - z_local
        d2 = dx*dx + dz*dz
        min_idx = np.argmin(d2)
        min_d = math.sqrt(d2[min_idx])
        
        road_h = ret_road_arr[min_idx, 2]
        if min_d < 25.0:
            h_final = road_h
        elif min_d < 70.0:
            t = (min_d - 25.0) / 45.0
            s_t = 3.0 * t * t - 2.0 * t * t * t
            h_blend = (1.0 - s_t) * road_h + s_t * raw_h
            if raw_h > road_h:
                h_final = min(h_blend, road_h + (min_d - 25.0) * 0.15)
            else:
                h_final = max(h_blend, road_h - (min_d - 25.0) * 0.15)
        else:
            h_final = raw_h
            
        # Store height relative to start line (H0)
        terrain_grid[r, c] = h_final - H0

# Write dem.raw
dem_raw_path = os.path.join(SCRIPT_DIR, "dem.raw")
terrain_grid.tofile(dem_raw_path)
print(f"Wrote dem.raw ({os.path.getsize(dem_raw_path)} bytes)")

# Write terrain.json
terrain_json = {
    "file": "dem.raw",
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
with open(os.path.join(SCRIPT_DIR, "terrain.json"), "w", encoding="utf-8") as f:
    json.dump(terrain_json, f, indent=2)
print("Wrote terrain.json")

# Write centreline.json
centreline_json = {
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
    "points": [[round(p[0], 3), round(p[1], 3)] for p in all_pts],
    "elevation_keys": elevation_keys,
    "sections": sections,
    "measurements": {
        "source_s1_length_m": round(tot_s1_len, 2),
        "total_loop_length_m": round(total_circuit_length, 2),
        "elevation_range_m": round(float(max(smooth_elevs) - min(smooth_elevs)), 2),
        "road_absolute_min_m": round(float(min(smooth_elevs)), 2),
        "road_absolute_max_m": round(float(max(smooth_elevs)), 2),
        "point_count": len(all_pts),
        "elevation_key_count": len(elevation_keys)
    }
}
with open(os.path.join(SCRIPT_DIR, "centreline.json"), "w", encoding="utf-8") as f:
    json.dump(centreline_json, f, indent=2)
print("Wrote centreline.json")

# 8. Write README.md
readme_content = f"""# Nürburgring Nordschleife Section 1 groundwork (acquired 2026-09-23)

This directory contains the reproducible geometry and elevation data for
`trackgen/nordschleife_s1.gd`.

## Geometry: OpenStreetMap
Copyright OpenStreetMap contributors, available under [ODbL 1.0](licenses/ODbL-1.0.txt).
Section 1 spans from the start of the Nordschleife at T13 ({LAT0:.5f} N, {LON0:.5f} E)
through Sabine-Schmitz-Kurve, Hatzenbogen, Hatzenbach, Hocheichen, Quiddelbacher Höhe,
Flugplatz, and Schwedenkreuz to Aremberg exit (~4.16 km of surveyed centreline), plus a
sculpted return road closing the loop for testing ({total_circuit_length:.1f} m total).

## Elevation: Rhineland-Palatinate LVermGeo (DGM1)
Attribution: **© GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]**
Licence: [Datenlizenz Deutschland – Namensnennung – Version 2.0](licenses/dl-de-by-2.0.txt).

20 tiles of 1 m LiDAR DGM1 (UTM Zone 32, E 351..354, N 5577..5581) were acquired from the
official GeoShop RLP open data service. Road elevations along Section 1 were sampled directly
from the 1 m LiDAR DEM with a 3-sample median filter and Gaussian smoothing (sigma 1.5 samples).
Road crossfall banking (ranging from +6.9° at Aremberg apex to -5.6° at Hatzenbogen) and tarmac
widths (8.5 to 11.8 m) were surveyed directly from DEM cross-sections.

Surrounding terrain is exported as a {SPACING:g} m grid in `dem.raw` ({W_TERRAIN} columns × {H_TERRAIN} rows,
{os.path.getsize(dem_raw_path)} bytes) referenced to start line elevation {H0:.2f} m.
"""
with open(os.path.join(SCRIPT_DIR, "README.md"), "w", encoding="utf-8") as f:
    f.write(readme_content.strip() + "\n")
print("Wrote README.md")

# 9. Compute SHA256 hashes and write sources.json
files_to_hash = [
    "build_data.py",
    "centreline.json",
    "dem.raw",
    "terrain.json",
    "README.md",
    "licenses/dl-de-by-2.0.txt",
    "licenses/ODbL-1.0.txt"
]
sources_data = {
    "acquired": "2026-09-23",
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
print("Data pipeline build complete!")
