"""Split the rendered tree sheets into single cards, bleed colour into the transparent border, and pack
one 2048x2048 atlas (assets/trees/tree_atlas.png) plus assets/trees/tree_atlas.json.
Usage: python tools/finish_tree_cards.py <cards_dir> (the output of tools/bake_tree_cards.gd)"""
import json, sys
import numpy as np
from PIL import Image, ImageFilter

src = sys.argv[1]
OUT = "assets/trees/"
ATLAS = 2048
PAD = 6


def split(name, min_w=40):
    im = Image.open(f"{src}/{name}_raw.png").convert("RGBA")
    a = np.array(im)[:, :, 3] > 20
    cols = a.any(axis=0)
    parts, start, gap = [], None, 0
    for x, c in enumerate(cols):
        if c:
            if start is None:
                start = x
            gap = 0
            end = x
        elif start is not None:
            gap += 1
            if gap > 6:
                parts.append((start, end))
                start = None
    if start is not None:
        parts.append((start, end))
    out = []
    for s, e in parts:
        if e - s < min_w:
            continue
        piece = im.crop((s, 0, e + 1, im.height))
        box = piece.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
        out.append(piece.crop(box))
    return out


def bleed(im, iters=24):
    """Fill fully transparent pixels with the nearest opaque colour so mipmaps don't darken edges."""
    arr = np.array(im).astype(np.float32)
    rgb, alpha = arr[:, :, :3], arr[:, :, 3]
    known = alpha > 20
    rgb[~known] = 0
    w = known.astype(np.float32)
    for _ in range(iters):
        pr = np.pad(rgb * w[:, :, None], ((1, 1), (1, 1), (0, 0)))
        pw = np.pad(w, 1)
        s = sum(pr[1 + dy : 1 + dy + rgb.shape[0], 1 + dx : 1 + dx + rgb.shape[1]] for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        c = sum(pw[1 + dy : 1 + dy + rgb.shape[0], 1 + dx : 1 + dx + rgb.shape[1]] for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        fill = (w == 0) & (c > 0)
        rgb[fill] = s[fill] / c[fill][:, None]
        w[fill] = 1
    arr[:, :, :3] = rgb
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


spruce = split("fir_sapling_medium")
tall = split("fir_tree_01")
decid = split("tree_small_02")
shrub = split("shrub_02")
print(len(spruce), len(tall), len(decid), len(shrub))
# slot rectangles (x, y, w, h) in the atlas: 4 tall slots per row, the last two are split in halves
S = ATLAS // 4
slots = [(i * S, 0, S, 1024) for i in range(4)]
slots += [(0, 1024, S, 1024), (S, 1024, S, 1024)]
slots += [(2 * S, 1024, S, 512), (2 * S, 1536, S, 512), (3 * S, 1024, S, 512), (3 * S, 1536, S, 512)]
items = (
    [("spruce", p) for p in spruce[:3]]
    + [("fir", p) for p in tall[:3]]
    + [("beech", decid[0])]
    + [("bush", p) for p in shrub[:2]]
)
atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
cards = []
for (kind, im), (x, y, w, h) in zip(items, slots):
    im = bleed(im)
    fit = min((w - 2 * PAD) / im.width, (h - 2 * PAD) / im.height)
    nw, nh = int(im.width * fit), int(im.height * fit)
    im = im.resize((nw, nh), Image.LANCZOS)
    # bottom-align inside the slot; trunks sit on the ground line
    ox, oy = x + (w - nw) // 2, y + h - PAD - nh
    atlas.paste(im, (ox, oy))
    cards.append({"kind": kind, "uv": [ox / ATLAS, oy / ATLAS, nw / ATLAS, nh / ATLAS], "aspect": nw / nh})
# bleed the whole atlas once more so cell borders carry colour
atlas = bleed(atlas, 12)
atlas.save(OUT + "tree_atlas.png", optimize=True)
json.dump(cards, open(OUT + "tree_atlas.json", "w"), indent=1)
for c in cards:
    print(c["kind"], round(c["aspect"], 2))
