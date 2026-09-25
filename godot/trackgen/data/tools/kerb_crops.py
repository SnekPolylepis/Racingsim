#!/usr/bin/env python3
"""
godot/trackgen/data/tools/kerb_crops.py

Extracts 80m x 80m aerial crops along track centrelines every 40m for kerb inspection.
Supports tracks: 'spa' and 'nordschleife'.
"""

import sys
import os
import json
import math
import time
import urllib.parse
import urllib.request
import requests
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.dirname(SCRIPT_DIR)

CROP_M = 80.0
CROP_PX = 800
STEP_M = 40.0

R_MERC = 6378137.0
R_EARTH_MEAN = 6371008.8


def mercator(lon, lat):
    return R_MERC * math.radians(lon), R_MERC * math.log(math.tan(math.pi / 4.0 + math.radians(lat) / 2.0))


def latlon_to_utm32(lat, lon):
    a = 6378137.0
    f = 1 / 298.257223563
    b = a * (1 - f)
    e2 = (a * a - b * b) / (a * a)
    e_prime2 = (a * a - b * b) / (b * b)
    k0 = 0.9996
    lon0 = 9.0
    lat_rad = math.radians(lat)
    lon_rad = math.radians(lon)
    lon0_rad = math.radians(lon0)
    N = a / math.sqrt(1 - e2 * math.sin(lat_rad) ** 2)
    T = math.tan(lat_rad) ** 2
    C = e_prime2 * math.cos(lat_rad) ** 2
    A = (lon_rad - lon0_rad) * math.cos(lat_rad)
    M = a * (
        (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * lat_rad
        - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * lat_rad)
        + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * lat_rad)
        - (35 * e2 ** 3 / 3072) * math.sin(6 * lat_rad)
    )
    easting = (
        k0
        * N
        * (
            A
            + (1 - T + C) * A ** 3 / 6
            + (5 - 18 * T + T ** 2 + 72 * C - 58 * e_prime2) * A ** 5 / 120
        )
        + 500000.0
    )
    northing = k0 * (
        M
        + N
        * math.tan(lat_rad)
        * (
            A ** 2 / 2
            + (5 - T + 9 * C + 4 * C ** 2) * A ** 4 / 24
            + (61 - 58 * T + T ** 2 + 600 * C - 330 * e_prime2) * A ** 6 / 720
        )
    )
    return easting, northing


def build_resampled_polyline(points, total_len, step_m=2.0):
    n = len(points)
    cum_dists = [0.0]
    for i in range(1, n):
        d = math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1])
        cum_dists.append(cum_dists[-1] + d)

    def sample_at(dist):
        dist = dist % total_len
        idx = 0
        while idx + 1 < n and cum_dists[idx + 1] < dist:
            idx += 1
        if idx + 1 < n:
            t = (dist - cum_dists[idx]) / max(1e-6, cum_dists[idx + 1] - cum_dists[idx])
            x = points[idx][0] + t * (points[idx + 1][0] - points[idx][0])
            z = points[idx][1] + t * (points[idx + 1][1] - points[idx][1])
        else:
            t = (dist - cum_dists[-1]) / max(1e-6, total_len - cum_dists[-1])
            x = points[-1][0] + t * (points[0][0] - points[-1][0])
            z = points[-1][1] + t * (points[0][1] - points[-1][1])
        return x, z

    dense_pts = []
    d = 0.0
    while d < total_len:
        dense_pts.append((d, sample_at(d)))
        d += step_m
    return dense_pts, sample_at


def fetch_image_with_retry(url, params, headers=None, max_retries=4, timeout=45):
    for attempt in range(max_retries):
        try:
            resp = requests.get(url, params=params, headers=headers, timeout=timeout)
            if resp.status_code == 200 and resp.content[:2] in (b"\xff\xd8", b"\x89P"):
                return resp.content
            else:
                time.sleep(1.0 + attempt * 2.0)
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            time.sleep(1.0 + attempt * 2.0)
    raise RuntimeError(f"Failed to fetch {url}")


def generate_crops(track_id):
    track_dir = os.path.join(DATA_DIR, track_id)
    centre_file = os.path.join(track_dir, "centreline.json")
    if not os.path.exists(centre_file):
        print(f"Error: {centre_file} does not exist", file=sys.stderr)
        sys.exit(1)

    with open(centre_file, "r", encoding="utf-8") as f:
        centre_data = json.load(f)

    points = centre_data["points"]
    origin = centre_data["origin"]
    lat0 = origin["lat"]
    lon0 = origin["lon"]

    out_dir = os.path.join(track_dir, "kerb-crops")
    os.makedirs(out_dir, exist_ok=True)

    # Calculate total length
    n_pts = len(points)
    open_poly_len = sum(
        math.hypot(points[i][0] - points[i - 1][0], points[i][1] - points[i - 1][1])
        for i in range(1, n_pts)
    )
    closing_len = math.hypot(points[0][0] - points[-1][0], points[0][1] - points[-1][1])
    total_len = open_poly_len + closing_len

    dense_pts, sample_at = build_resampled_polyline(points, total_len, step_m=2.0)

    # For Nordschleife, Section 1 ends around s = 4160 m (Aremberg exit).
    # The task asks for Section 1 (or the full loop if needed, but S1 is the surveyed race circuit).
    # Let's crop up to 4200m or full loop. Let's crop up to 4240m for Nordschleife so all S1 is covered!
    if track_id == "nordschleife":
        max_s = 4220.0
    else:
        max_s = total_len

    stations = []
    curr_s = 0.0
    while curr_s < max_s:
        stations.append(curr_s)
        curr_s += STEP_M

    print(f"Generating {len(stations)} crops for {track_id} (stations every {STEP_M}m up to {max_s:.0f}m)...")

    # Font setup
    try:
        font = ImageFont.truetype("arial.ttf", 28)
        font_sub = ImageFont.truetype("arial.ttf", 20)
    except Exception:
        font = ImageFont.load_default()
        font_sub = font

    # Projection helpers
    if track_id == "spa":
        ky = math.pi * R_EARTH_MEAN / 180.0
        kx = ky * math.cos(math.radians(lat0))
        export_url = "https://geoservices.wallonie.be/arcgis/rest/services/IMAGERIE/ORTHO_2023_ETE/MapServer/export"
        headers = {"User-Agent": "RacingSim/1.0 (public circuit authoring)"}
    elif track_id == "nordschleife":
        e0, n0 = latlon_to_utm32(lat0, lon0)
        wms_url = "https://geo4.service24.rlp.de/wms/rp_dop20.fcgi"
        headers = {"User-Agent": "RacingSim/1.0"}

    for idx, s in enumerate(stations):
        out_name = f"s{int(round(s)):05d}.jpg"
        out_path = os.path.join(out_dir, out_name)
        if os.path.exists(out_path) and os.path.getsize(out_path) > 10000:
            continue

        cx, cz = sample_at(s)
        # Tangent for driving direction arrow
        ahead_s = (s + 6.0) % total_len
        behind_s = (s - 6.0) % total_len
        ax, az = sample_at(ahead_s)
        bx, bz = sample_at(behind_s)
        tx = ax - bx
        tz = az - bz
        t_len = math.hypot(tx, tz)
        if t_len > 1e-4:
            tx /= t_len
            tz /= t_len
        else:
            tx, tz = 0.0, -1.0

        if track_id == "spa":
            lon = lon0 + cx / kx
            lat = lat0 - cz / ky
            mx, my = mercator(lon, lat)
            # 80m ground extent in Web Mercator
            half_merc = (CROP_M / 2.0) / math.cos(math.radians(lat))
            min_x = mx - half_merc
            max_x = mx + half_merc
            min_y = my - half_merc
            max_y = my + half_merc
            params = {
                "bbox": f"{min_x:.3f},{min_y:.3f},{max_x:.3f},{max_y:.3f}",
                "bboxSR": 3857,
                "imageSR": 3857,
                "size": f"{CROP_PX},{CROP_PX}",
                "format": "jpg",
                "transparent": "false",
                "f": "image",
            }
            raw = fetch_image_with_retry(export_url, params, headers=headers)
            # Map function from local (x, z) to crop pixel (px, py)
            def to_pixel(x, z):
                l_lon = lon0 + x / kx
                l_lat = lat0 - z / ky
                lx, ly = mercator(l_lon, l_lat)
                px = (lx - min_x) / (max_x - min_x) * CROP_PX
                py = (max_y - ly) / (max_y - min_y) * CROP_PX
                return px, py

        elif track_id == "nordschleife":
            # Local: X is East (+e), Z is South (-n)
            # UTM Easting = e0 + cx, Northing = n0 - cz
            east = e0 + cx
            north = n0 - cz
            half_m = CROP_M / 2.0
            min_e = east - half_m
            max_e = east + half_m
            min_n = north - half_m
            max_n = north + half_m
            # WMS 1.3.0 EPSG:25832 uses northing,easting (or easting,northing depending on server)
            # For rp_dop20 on this server, let's verify CRS order.
            # In our curl test earlier: BBOX=354000,5579000,354080,5579080 (min_e, min_n, max_e, max_n) succeeded with CRS=EPSG:25832!
            params = {
                "SERVICE": "WMS",
                "VERSION": "1.3.0",
                "REQUEST": "GetMap",
                "LAYERS": "rp_dop20",
                "STYLES": "",
                "CRS": "EPSG:25832",
                "BBOX": f"{min_e:.3f},{min_n:.3f},{max_e:.3f},{max_n:.3f}",
                "WIDTH": str(CROP_PX),
                "HEIGHT": str(CROP_PX),
                "FORMAT": "image/jpeg",
            }
            raw = fetch_image_with_retry(wms_url, params, headers=headers)

            def to_pixel(x, z):
                lx = e0 + x
                ly = n0 - z
                px = (lx - min_e) / (max_e - min_e) * CROP_PX
                py = (max_n - ly) / (max_n - min_n) * CROP_PX
                return px, py

        # Write to temp image and annotate with Pillow
        temp_img_path = out_path + ".tmp.jpg"
        with open(temp_img_path, "wb") as f:
            f.write(raw)

        img = Image.open(temp_img_path).convert("RGB")
        draw = ImageDraw.Draw(img)

        # Draw centreline in thin cyan (find points within range around station s)
        # Search points within +- 80m of s along track
        poly_sub = []
        # Sample points within +- 80m
        for step_offset in range(-70, 71, 2):
            sample_s = (s + step_offset) % total_len
            sx, sz = sample_at(sample_s)
            px, py = to_pixel(sx, sz)
            if -50 <= px <= CROP_PX + 50 and -50 <= py <= CROP_PX + 50:
                poly_sub.append((px, py))

        if len(poly_sub) >= 2:
            draw.line(poly_sub, fill=(0, 255, 255), width=2)

        # Draw station point (centre dot)
        cpx, cpy = to_pixel(cx, cz)
        r_pt = 3
        draw.ellipse([cpx - r_pt, cpy - r_pt, cpx + r_pt, cpy + r_pt], fill=(255, 0, 0), outline=(255, 255, 255))

        # Driving direction arrow near the centre (offset 30 px along or to the side of track)
        # Tangent vector in pixel space
        t_ahead_px, t_ahead_py = to_pixel(cx + tx * 5.0, cz + tz * 5.0)
        adx = t_ahead_px - cpx
        ady = t_ahead_py - cpy
        ad_len = math.hypot(adx, ady)
        if ad_len > 1e-3:
            ux = adx / ad_len
            uy = ady / ad_len
        else:
            ux, uy = 0.0, -1.0
        # Normal in pixel space
        nx = -uy
        ny = ux

        # Place arrow 40 px ahead or offset
        arr_base_x = cpx + nx * 25.0
        arr_base_y = cpy + ny * 25.0
        arr_tip_x = arr_base_x + ux * 35.0
        arr_tip_y = arr_base_y + uy * 35.0
        arr_left_x = arr_tip_x - ux * 12.0 + nx * 7.0
        arr_left_y = arr_tip_y - uy * 12.0 + ny * 7.0
        arr_right_x = arr_tip_x - ux * 12.0 - nx * 7.0
        arr_right_y = arr_tip_y - uy * 12.0 - ny * 7.0

        draw.line([(arr_base_x, arr_base_y), (arr_tip_x, arr_tip_y)], fill=(255, 255, 0), width=3)
        draw.polygon([(arr_tip_x, arr_tip_y), (arr_left_x, arr_left_y), (arr_right_x, arr_right_y)], fill=(255, 255, 0))

        # Station text in top-left corner
        text = f"s = {int(round(s))} m"
        subtext = f"{track_id.upper()}  (80m x 80m, N-up)"
        # Dark background card for text
        draw.rectangle([15, 15, 280, 85], fill=(0, 0, 0, 180), outline=(0, 255, 255), width=1)
        draw.text((25, 22), text, fill=(255, 255, 255), font=font)
        draw.text((25, 56), subtext, fill=(180, 220, 255), font=font_sub)

        # North indicator in top-right corner
        draw.rectangle([CROP_PX - 85, 15, CROP_PX - 15, 85], fill=(0, 0, 0, 180), outline=(200, 200, 200), width=1)
        draw.text((CROP_PX - 58, 20), "N", fill=(255, 100, 100), font=font)
        draw.polygon(
            [(CROP_PX - 50, 52), (CROP_PX - 58, 75), (CROP_PX - 42, 75)],
            fill=(255, 100, 100)
        )

        img.save(out_path, quality=90)
        try:
            os.remove(temp_img_path)
        except OSError:
            pass

        if (idx + 1) % 20 == 0 or idx == len(stations) - 1:
            print(f"[{track_id}] {idx + 1}/{len(stations)} crops generated (latest s={int(round(s))})", flush=True)

    print(f"Finished generating crops for {track_id} in {out_dir}.")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("spa", "nordschleife", "all"):
        print("Usage: python kerb_crops.py [spa|nordschleife|all]")
        sys.exit(1)

    tracks = ["spa", "nordschleife"] if sys.argv[1] == "all" else [sys.argv[1]]
    for t in tracks:
        generate_crops(t)


if __name__ == "__main__":
    main()
