"""Study-only contact sheets; no reference image enters the game or Git."""
from pathlib import Path
import argparse
from PIL import Image, ImageOps, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--round", default="3")
parser.add_argument("--backend", default="forward")
args = parser.parse_args()
folder = ROOT / "tests/compare" / ("round-" + args.round) / args.backend
out = folder / "sheets"
out.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype(str(ROOT / "assets/fonts/Rajdhani-Medium.ttf"), 24)


def tile(path, label):
    canvas = Image.new("RGB", (640, 518), "#0c1420")
    im = Image.open(path).convert("RGB")
    im = ImageOps.contain(im, (640, 480), Image.Resampling.NEAREST)
    canvas.paste(im, ((640 - im.width) // 2, (480 - im.height) // 2))
    ImageDraw.Draw(canvas).text((10, 485), label, font=font, fill="white")
    return canvas


images = sorted(folder.glob("*.png"))
for path in images:
    if path.name.startswith(("ui-", "output-")):
        reference = ROOT / "reference/gt4-i1iFqNSWI9TiauH.jpg"
        caption = "GT4 photo UI / official gallery; layout study"
    else:
        day = path.name.startswith("afternoon")
        reference = ROOT / ("reference/gt4-i1c3MFDfQ79NhhH.jpg" if day else "reference/nfsu2-road.jpg")
        caption = "GT4 official gameplay / analogous circuit" if day else "NFSU2 storefront / capture settings unknown"
    sheet = Image.new("RGB", (1920, 518), "black")
    before = ROOT / "tests/compare/round-1/forward" / path.name
    before_label = "Round 1 / " if before.exists() else "First captured this round / "
    sheet.paste(tile(before if before.exists() else path, before_label + path.stem), (0, 0))
    sheet.paste(tile(path, "Round " + args.round + " / " + path.stem), (640, 0))
    sheet.paste(tile(reference, caption), (1280, 0))
    sheet.save(out / path.name)
for category in ["afternoon", "afterhours", "ui-1280x800", "ui-1920x1080"]:
    group = [p for p in images if p.stem.startswith(category)]
    for start in range(0, len(group), 6):
        page = Image.new("RGB", (1920, 1036), "black")
        for i, path in enumerate(group[start:start + 6]):
            page.paste(tile(path, path.stem), ((i % 3) * 640, (i // 3) * 518))
        page.save(out / (category + "-contact-" + str(start // 6 + 1) + ".png"))
links = "\n".join(f'<figure><a href="{p.name}"><img src="{p.name}" width="960"></a><figcaption>{p.stem}</figcaption></figure>' for p in sorted(out.glob("*.png")))
(out / "index.html").write_text('<!doctype html><meta charset="utf-8"><title>PS2 study comparisons</title><style>body{background:#101820;color:#eee;font:18px sans-serif}img{max-width:100%}figure{margin:24px 0}</style><h1>Study-only comparison round ' + args.round + '</h1><p>Original game before / current / public reference. Aspect preserved; nearest resampling for every panel. References are analogous scenes, not GT4 Spa. Unknown capture settings are labelled.</p>' + links, encoding="utf-8")
print(f"Built {len(images)} comparison sheets in {out}")
