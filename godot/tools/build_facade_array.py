"""Packs the six Chicago facade texture sets into one 3x2 atlas per map (albedo, normal, roughness), each
imported by Godot as a Texture2DArray, so every building shares one material (CHI-LOOK-02). Maintainer tool;
the outputs in assets/chicago/facade-array/ are committed. Layer order = ChicagoCity.KINDS order.
    python tools/build_facade_array.py   (from godot/)
"""
from PIL import Image

SETS = ["Facade001", "Facade009", "Travertine009", "GlazedTerracotta001", "Bricks097", "Concrete034"]
SIZE = 512
OUT = "assets/chicago/facade-array/"
for suffix, name in [("color", "albedo"), ("normal", "normal"), ("roughness", "rough")]:
    atlas = Image.new("RGB", (SIZE * 3, SIZE * 2))
    for i, s in enumerate(SETS):
        im = Image.open(f"assets/textures/chicago/{s}/{s}_{suffix}.jpg").convert("RGB")
        atlas.paste(im.resize((SIZE, SIZE), Image.LANCZOS), ((i % 3) * SIZE, (i // 3) * SIZE))
    atlas.save(OUT + name + ".png", optimize=True)
