#!/usr/bin/env python3
"""Copernicus GLO-30 DSM tile (N43 E007) around Monaco -> dem.json (a small float grid).

Decodes the one 1024 px COG tile that covers the circuit (DEFLATE + floating-point predictor) with the
standard library only. Source: Copernicus DEM GLO-30, (c) DLR e.V. 2010-2014 and (c) Airbus Defence and
Space GmbH 2014-2018, provided under COPERNICUS by the European Union and ESA; licence in README.md.
Usage: dem_sample.py <Copernicus_DSM_COG_10_N43_00_E007_00_DEM.tif>
"""
import json, struct, sys, zlib

d = open(sys.argv[1], "rb").read()
bo = "<" if d[:2] == b"II" else ">"
off = struct.unpack(bo + "I", d[4:8])[0]
tags = {}
for i in range(struct.unpack(bo + "H", d[off:off + 2])[0]):
    tag, typ, cnt, val = struct.unpack(bo + "HHII", d[off + 2 + i * 12:off + 14 + i * 12])
    tags[tag] = (typ, cnt, val)
tile = tags[322][2]
n_across = (tags[256][2] + tile - 1) // tile
offsets = struct.unpack(bo + "%dI" % tags[324][1], d[tags[324][2]:tags[324][2] + 4 * tags[324][1]])
counts = struct.unpack(bo + "%dI" % tags[325][1], d[tags[325][2]:tags[325][2] + 4 * tags[325][1]])
tie = struct.unpack(bo + "6d", d[tags[33922][2]:tags[33922][2] + 48])
scale = struct.unpack(bo + "3d", d[tags[33550][2]:tags[33550][2] + 24])
lon0, lat0, dx, dy = tie[3], tie[4], scale[0], scale[1]
# Monaco window: lat 43.724-43.748, lon 7.405-7.440
r0, r1 = int((lat0 - 43.748) / dy), int((lat0 - 43.724) / dy) + 1
c0, c1 = int((7.405 - lon0) / dx), int((7.440 - lon0) / dx) + 1
cache = {}


def tile_rows(t):
    if t not in cache:
        raw = bytearray(zlib.decompress(d[offsets[t]:offsets[t] + counts[t]]))
        rows = []
        w = tile * 4
        for r in range(tile):
            row = raw[r * w:(r + 1) * w]
            for i in range(1, w):
                row[i] = (row[i] + row[i - 1]) & 0xFF
            # Byte planes, most significant first -> little-endian float32.
            vals = [struct.unpack("<f", bytes((row[3 * tile + k], row[2 * tile + k], row[tile + k], row[k])))[0]
                    for k in range(tile)]
            rows.append(vals)
        cache[t] = rows
    return cache[t]


grid = []
for r in range(r0, r1):
    line = []
    for c in range(c0, c1):
        t = (r // tile) * n_across + c // tile
        line.append(round(tile_rows(t)[r % tile][c % tile], 2))
    grid.append(line)
json.dump({"source": "Copernicus DEM GLO-30 (DSM)", "lat_top": lat0 - r0 * dy, "lon_left": lon0 + c0 * dx,
           "dlat": dy, "dlon": dx, "rows": len(grid), "cols": len(grid[0]), "h": grid}, open("dem.json", "w"))
print("grid", len(grid), "x", len(grid[0]), "min", min(map(min, grid)), "max", max(map(max, grid)))
