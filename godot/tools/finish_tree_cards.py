"""Split the rendered plant sheets into single cards, bleed colour into the transparent border, and pack
two atlases: assets/trees/tree_atlas.png (canopy: spruce, fir, three deciduous species, bush) and
assets/undergrowth/undergrowth_atlas.png (Look-10: fern, bramble, long grass, bush, sapling).
Usage: python tools/finish_tree_cards.py <cards_dir> (the output of tools/bake_tree_cards.gd)"""
import json, sys
import numpy as np
from PIL import Image

src = sys.argv[1]
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


def pack(out_path, json_path, atlas_w, atlas_h, cols, rows, items):
    """items: [(kind, PIL image), ...], bottom-aligned in a cols x rows grid of equal cells."""
    cell_w = atlas_w // cols
    cell_h = atlas_h // rows
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    cards = []
    for i, (kind, im) in enumerate(items):
        col, row = i % cols, i // cols
        x, y, w, h = col * cell_w, row * cell_h, cell_w, cell_h
        im = bleed(im)
        fit = min((w - 2 * PAD) / im.width, (h - 2 * PAD) / im.height)
        nw, nh = max(1, int(im.width * fit)), max(1, int(im.height * fit))
        im = im.resize((nw, nh), Image.LANCZOS)
        ox, oy = x + (w - nw) // 2, y + h - PAD - nh
        atlas.paste(im, (ox, oy))
        cards.append({"kind": kind, "uv": [ox / atlas_w, oy / atlas_h, nw / atlas_w, nh / atlas_h], "aspect": nw / nh})
    atlas = bleed(atlas, 12)
    atlas.save(out_path, optimize=True)
    json.dump(cards, open(json_path, "w"), indent=1)
    for c in cards:
        print(c["kind"], round(c["aspect"], 2))


# --- Canopy atlas (Look-6 originals + Look-10's three deciduous species) ---
spruce = split("fir_sapling_medium")
tall = split("fir_tree_01")
beech = split("tree_small_02")
bush = split("shrub_02")
oak = split("island_tree_02")
birch = split("island_tree_03")
print("canopy source counts:", len(spruce), len(tall), len(beech), len(bush), len(oak), len(birch))
tree_items = (
    [("spruce", p) for p in spruce[:3]]
    + [("fir", p) for p in tall[:3]]
    + [("beech", beech[0])]
    + [("oak", oak[0])]
    + [("birch", birch[0])]
    + [("bush", p) for p in bush[:2]]
)
pack("assets/trees/tree_atlas.png", "assets/trees/tree_atlas.json", 2048, 1536, 4, 3, tree_items)

# --- Undergrowth atlas (Look-10, ART-DIRECTION.md "Trackside enclosure") ---
fern = split("fern_02")
bramble = split("wild_rooibos_bush")
grass = split("grass_medium_01", min_w=15)
flower_shrub = split("shrub_04")
sapling = split("pine_sapling_small")
print("undergrowth source counts:", len(fern), len(bramble), len(grass), len(flower_shrub), len(sapling))
# Widest/most distinct instances first from each split (bramble and grass over-produce near-duplicates).
bramble.sort(key=lambda im: -im.width)
grass.sort(key=lambda im: -im.width)
undergrowth_items = (
    [("fern", p) for p in fern[:2]]
    + [("bramble", p) for p in bramble[:3]]
    + [("grass", p) for p in grass[:3]]
    + [("shrub", p) for p in flower_shrub[:3]]
    + [("sapling", p) for p in sapling[:3]]
)
pack("assets/undergrowth/undergrowth_atlas.png", "assets/undergrowth/undergrowth_atlas.json", 2048, 1024, 5, 3, undergrowth_items)
