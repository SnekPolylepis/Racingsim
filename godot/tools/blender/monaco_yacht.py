"""A moored motor yacht for Port Hercule, unit length (1 m long along +X, bow at +X, beam 1 m; heights in real
metres for a ~20 m yacht scaled down: monaco.gd scales X/Z per instance and keeps Y). Replaces the box hull
and box cabin, which read as white slabs beside Nouvelle Chicane. Lofted hull with a raked, flared bow and
a transom; two tapered superstructure decks with dark window bands; a radar arch. Original geometry.

blender -b --python-exit-code 1 --python tools/blender/monaco_yacht.py -- assets/monaco
"""
import bpy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, finish

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
white = material("Yacht gelcoat", (.95, .95, .93), roughness=.25)
navy = material("Yacht boot stripe", (.06, .09, .16), roughness=.3)
glass = material("Yacht dark glass", (.04, .05, .06), metallic=.4, roughness=.08)
teak = material("Yacht teak deck", (.55, .4, .26), roughness=.7)

# Hull: stations along X (0 stern .. 1 bow) as (x, half beam at deck, half beam at chine, keel depth, sheer).
STATIONS = [(-.5, .5, .44, -.7, 1.3), (-.25, .5, .45, -.85, 1.3), (0, .5, .44, -.95, 1.35), (.2, .48, .38, -.95, 1.45),
            (.35, .4, .25, -.85, 1.6), (.45, .24, .08, -.6, 1.75), (.5, .02, .0, -.2, 1.85)]
verts, faces = [], []
for x, deck, chine, keel, sheer in STATIONS:
    # Ring: deck edge right, chine right, keel, chine left, deck edge left (y = beam, z = up).
    verts += [(x, deck, sheer), (x, chine, 0.15), (x, 0.0, keel), (x, -chine, 0.15), (x, -deck, sheer)]
n = 5
for i in range(len(STATIONS) - 1):
    a, b = i * n, (i + 1) * n
    for k in range(n - 1):
        faces.append((a + k, b + k, b + k + 1, a + k + 1))
faces.append(tuple(reversed(range(n))))  # transom
deck_ring = [i * n for i in range(len(STATIONS))] + [i * n + 4 for i in reversed(range(len(STATIONS)))]
mesh("Hull", verts, faces, white)
mesh("Deck", [(verts[i][0], verts[i][1], verts[i][2] - 0.02) for i in deck_ring], [tuple(range(len(deck_ring)))], teak)
# Boot stripe just above the waterline.
mesh("Boot stripe", [(x, chine * 1.01, z) for x, d, chine, k, s in STATIONS[:5] for z in (0.1, 0.35)] +
     [(x, -chine * 1.01, z) for x, d, chine, k, s in STATIONS[:5] for z in (0.1, 0.35)],
     [(i * 2, i * 2 + 2, i * 2 + 3, i * 2 + 1) for i in range(4)] +
     [(10 + i * 2 + 1, 10 + i * 2 + 3, 10 + i * 2 + 2, 10 + i * 2) for i in range(4)], navy)


def deckhouse(name, x0, x1, half_aft, half_fwd, z0, z1, mat):
    """A tapered box: wider aft, narrower and raked forward."""
    v = [(x0, -half_aft, z0), (x1, -half_fwd, z0), (x1, half_fwd, z0), (x0, half_aft, z0),
         (x0, -half_aft * .95, z1), (x1 - .04, -half_fwd * .9, z1), (x1 - .04, half_fwd * .9, z1), (x0, half_aft * .95, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(name, v, f, mat)


deckhouse("Main deckhouse", -.32, .22, .42, .3, 1.3, 2.5, white)
deckhouse("Main windows", -.3, .2, .425, .305, 1.65, 2.25, glass)
deckhouse("Flybridge", -.22, .1, .34, .26, 2.5, 3.3, white)
deckhouse("Flybridge windows", -.2, .08, .345, .265, 2.7, 3.1, glass)
deckhouse("Radar arch", -.1, -.04, .2, .2, 3.3, 4.1, white)

finish("monaco_yacht", OUT)
