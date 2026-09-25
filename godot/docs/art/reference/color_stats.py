#!/usr/bin/env python3
"""Mean saturation and luminance spread (stdev) for a set of images, HSV-based.
Usage: color_stats.py <file-or-glob> [<file-or-glob> ...]
Prints one line per file: name  mean_sat  mean_lum  lum_stdev
"""
import sys
import glob
from PIL import Image
import numpy as np


def stats(path):
    im = Image.open(path).convert("RGB")
    im.thumbnail((512, 512))
    arr = np.asarray(im).astype(np.float32) / 255.0
    hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    sat = hsv[..., 1]
    # Perceptual luminance (Rec. 709)
    lum = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
    return sat.mean(), lum.mean(), lum.std()


def main(argv):
    paths = []
    for pattern in argv:
        paths.extend(sorted(glob.glob(pattern)))
    if not paths:
        print("no files matched", file=sys.stderr)
        return 1
    rows = []
    for p in paths:
        try:
            s, l, lstd = stats(p)
            rows.append((p, s, l, lstd))
        except Exception as e:
            print(f"{p}\tERROR {e}", file=sys.stderr)
    for p, s, l, lstd in rows:
        print(f"{p}\tsat={s:.3f}\tlum={l:.3f}\tlum_std={lstd:.3f}")
    if rows:
        import statistics

        print(
            "MEAN\tsat={:.3f}\tlum={:.3f}\tlum_std={:.3f}".format(
                statistics.mean(r[1] for r in rows),
                statistics.mean(r[2] for r in rows),
                statistics.mean(r[3] for r in rows),
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
