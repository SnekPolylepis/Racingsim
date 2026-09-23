"""Deterministic offline texture build. Requires Pillow 12.3.0; never imported by the game."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageEnhance, __version__
import random

if __version__ != "12.3.0":
    raise RuntimeError("Use Pillow 12.3.0 to reproduce the committed palette/texture hashes")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ps2"
OUT.mkdir(parents=True, exist_ok=True)
manifest = {"tool": "Pillow", "version": __version__, "textures": []}


def build(source: Path, name: str, palette: int = 256):
    original = Image.open(source)
    image = original.copy()
    image.thumbnail((256, 256), Image.Resampling.LANCZOS)
    if palette:
        if "A" in image.getbands():
            image = image.convert("RGBA").quantize(palette, Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        else:
            image = image.convert("RGB").quantize(palette, Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        format_name = f"CLUT{4 if palette == 16 else 8}"
    else:
        image = image.convert("RGB").point([round(round(x * 31 / 255) * 255 / 31) for x in range(256)] * 3)
        format_name = "RGB555-expanded"
    dest = OUT / (name + ".png")
    image.save(dest, optimize=True, bits=4 if palette == 16 else 8)
    settings = Path(str(dest) + ".import")
    if settings.exists():
        data = settings.read_text(encoding="utf-8")
        data = data.replace("mipmaps/generate=false", "mipmaps/generate=true").replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
        settings.write_text(data, encoding="utf-8")
    colors = len(image.getcolors(image.width * image.height) or [])
    manifest["textures"].append({
        "source": source.relative_to(ROOT).as_posix(), "output": dest.relative_to(ROOT).as_posix(),
        "format": format_name, "size": list(image.size), "unique_colors": colors,
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
        "nominal_gs_bytes": image.width * image.height * (0.5 if palette == 16 else 1 if palette else 2) + (palette * 4 if palette else 0),
    })


def make_pine():
    source = ROOT / "assets" / "cc0-source"
    photo = Image.open(source / "pine-twig.png").convert("RGBA")
    photo.putalpha(Image.open(source / "pine-alpha.png").convert("L"))
    # Needle colour varies in the source atlas; grade the authored tree to a
    # shaded forest green before palette conversion, preserving alpha/detail.
    channels = photo.split()
    photo = Image.merge("RGBA", (channels[0].point(lambda x: int(x * .64)), channels[1].point(lambda x: int(x * .89)), channels[2].point(lambda x: int(x * .64)), channels[3]))
    twig = photo.crop((0, 0, 255, 455))
    tree = Image.new("RGBA", (256, 512))
    draw = ImageDraw.Draw(tree)
    draw.polygon([(125, 24), (130, 24), (136, 504), (119, 504)], fill=(88, 69, 49, 255))
    rng = random.Random(240448)
    for row in range(23, -1, -1):
        y = 20 + row * 17
        reach = 10 + row * 4.2
        for side in [-1, 1]:
            for spray in range(4):
                branch = twig.resize((int(reach * .9), int(reach * 1.55)), Image.Resampling.LANCZOS)
                branch = ImageEnhance.Color(branch).enhance(.72)
                branch = ImageEnhance.Brightness(branch).enhance(.75 + rng.random() * .65)
                branch = branch.rotate(side * (48 + spray * 14), Image.Resampling.BICUBIC, expand=True)
                px = int(128 + side * reach * .42 - branch.width / 2)
                py = int(y - branch.height / 2 + rng.uniform(-5, 5))
                tree.alpha_composite(branch, (px, py))
    tree.resize((128, 256), Image.Resampling.LANCZOS).save(ROOT / "assets/generated-originals/treetrue.png")


make_pine()
for source in sorted((ROOT / "assets" / "textures").glob("*/*.jpg")):
    build(source, source.stem, 256 if source.stem.endswith("_diff") else 0)
for source in sorted((ROOT / "assets" / "generated-originals").glob("*.png")):
    build(source, source.stem, 16 if source.stem.startswith("tree") or source.stem in {"crowd", "tyre", "armco"} else 0)
(OUT / "texture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"Built {len(manifest['textures'])} textures with Pillow {__version__}")
