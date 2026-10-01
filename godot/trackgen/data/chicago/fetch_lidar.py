#!/usr/bin/env python3
"""USGS 3DEP LiDAR (IL 4County Cook 2017, public domain) -> 1 m surface grid in the game frame.

Walks the Entwine Point Tile tree on the public usgs-lidar-public bucket, downloads only the tiles over the
requested lat/lon box, and writes lidar-<name>.npz: dsm (max first-surface height), dtm (ground), both in
metres, cells 1 m, origin at the game-frame (x0, z0) of the box's NW corner. Game frame is chicago.gd
world(): x = (lon + 87.6244) * 82860, z = (41.8848 - lat) * 111320.

  python fetch_lidar.py michigan 41.8775 41.8890 -87.6275 -87.6225
"""
import io
import json
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import laspy
import numpy as np
from pyproj import Transformer

EPT = "https://s3-us-west-2.amazonaws.com/usgs-lidar-public/USGS_LPC_IL_4County_Cook_2017_LAS_2019/"
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "..", "..", "..", "assets", "cc0-source", "chicago", "lidar")


def get(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def main():
    name, s, n, w, e = sys.argv[1], *map(float, sys.argv[2:6])
    to_merc = Transformer.from_crs(4326, 3857, always_xy=True)
    to_ll = Transformer.from_crs(3857, 4326, always_xy=True)
    mx0, my0 = to_merc.transform(w, s)
    mx1, my1 = to_merc.transform(e, n)
    meta = json.loads(get(EPT + "ept.json"))
    b = meta["bounds"]

    def overlaps(key):
        d, x, y, z = key
        size = (b[3] - b[0]) / (2 ** d)
        bx, by = b[0] + x * size, b[1] + y * size
        return bx < mx1 and bx + size > mx0 and by < my1 and by + size > my0

    # Hierarchy walk: every node overlapping the box (all depths hold points in EPT).
    nodes = []
    stack = ["0-0-0-0"]
    while stack:
        root = stack.pop()
        h = json.loads(get(EPT + "ept-hierarchy/%s.json" % root))
        for k, count in h.items():
            key = tuple(map(int, k.split("-")))
            if not overlaps(key):
                continue
            if count == -1:
                stack.append(k)
            elif count > 0:
                nodes.append(k)
    print("%d tiles" % len(nodes), flush=True)
    os.makedirs(CACHE, exist_ok=True)
    xs, zs, ys, cls = [], [], [], []
    def read_tile(k):
        las = laspy.read(io.BytesIO(get(EPT + "ept-data/%s.laz" % k)))
        m = (las.x >= mx0) & (las.x <= mx1) & (las.y >= my0) & (las.y <= my1)
        if not m.any():
            return None
        lon, lat = to_ll.transform(np.asarray(las.x[m]), np.asarray(las.y[m]))
        return ((lon + 87.6244) * 82860.0, (41.8848 - lat) * 111320.0,
                np.asarray(las.z[m]), np.asarray(las.classification[m]))

    # Network-bound tile reads; retain the same ordered point reduction and measured data.
    with ThreadPoolExecutor(max_workers=6) as pool:
        for i, points in enumerate(pool.map(read_tile, nodes)):
            if points is not None:
                for target, values in zip((xs, zs, ys, cls), points):
                    target.append(values)
            if i % 50 == 0:
                print(i, sum(len(a) for a in xs), flush=True)
    x = np.concatenate(xs)
    z = np.concatenate(zs)
    y = np.concatenate(ys)
    c = np.concatenate(cls)
    keep = (c != 7) & (c != 18)  # drop noise
    x, z, y, c = x[keep], z[keep], y[keep], c[keep]
    x0, z0 = np.floor(x.min()), np.floor(z.min())
    nx, nz = int(np.ceil(x.max() - x0)) + 1, int(np.ceil(z.max() - z0)) + 1
    ix = (x - x0).astype(int)
    iz = (z - z0).astype(int)
    dsm = np.full((nz, nx), np.nan, np.float32)
    np.fmax.at(dsm, (iz, ix), y.astype(np.float32))
    g = c == 2
    dtm = np.full((nz, nx), np.nan, np.float32)
    np.fmin.at(dtm, (iz[g], ix[g]), y[g].astype(np.float32))
    out = os.path.join(CACHE, "lidar-%s.npz" % name)
    np.savez_compressed(out, dsm=dsm, dtm=dtm, x0=x0, z0=z0)
    print("class counts", dict(zip(*[a.tolist() for a in np.unique(c, return_counts=True)])), flush=True)
    print("points %d, grid %dx%d, ground median %.1f, top %.1f -> %s" % (len(x), nx, nz, np.nanmedian(dtm), np.nanmax(dsm), out))


if __name__ == "__main__":
    main()
