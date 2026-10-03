"""Casino de Monte-Carlo (Garnier, 1878), the Casino Square elevation, on its mapped OSM footprint (way
161769674) from city.json. Reference: Commons "Casino Monte Carlo.jpg" (square side): two corner towers
with octagonal belvederes, domes and lanterns; a central pavilion under a verdigris copper dome with oculus
dormers and a crest; a tall arched central window over an arcaded ground floor; cream stone, balustrades.
Original geometry, no photo pixels. Other sides: the stone body with rows of arched windows.
World coordinates: Blender (x, -z, y) of the game's (x, y, z).

blender -b --python-exit-code 1 --python tools/blender/monaco_casino.py -- assets/monaco
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box as baked_box, finish

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)

stone = material("Casino cream stone", (.93, .85, .66), roughness=.75)
trim = material("Casino white mouldings", (.96, .93, .85), roughness=.6)
copper = material("Verdigris copper", (.38, .6, .52), metallic=.35, roughness=.5)
gilt = material("Gilded ornament", (.8, .62, .25), metallic=.8, roughness=.35)
glass = material("Casino dark glass", (.05, .06, .07), metallic=.3, roughness=.15)
roof = material("Casino slate roof", (.25, .27, .28), roughness=.8)

doc = json.loads((ROOT / "trackgen/data/monaco/city.json").read_text())
casino = next(b for b in doc["buildings"] if b[3] == "casino")
ring = [Vector((casino[0][i], -casino[0][i + 1])) for i in range(0, len(casino[0]) - 1, 2)]
if (ring[0] - ring[-1]).length < 0.05:
    ring.pop()
if sum(a.x * b.y - b.x * a.y for a, b in zip(ring, ring[1:] + ring[:1])) < 0:
    ring.reverse()
base = casino[1]
# Casino Square: the lap's road point nearest the corner marker (monaco.gd CORNERS, world_of).
lat, lon = 43.73965, 7.42728
sq = Vector(((lon - 7.4225) * 111320.0 * math.cos(math.radians(43.735)), -(43.735 - lat) * 111320.0))
road = min(doc["road"], key=lambda p: (p[0] - sq.x) ** 2 + (-p[2] - sq.y) ** 2)
square_y = road[1]
cornice = square_y + 17.0
print("CASINO base %.1f square %.1f" % (base, square_y))


def box(name, pos, size, mat, angle=0.0):
    obj = baked_box(name, (0, 0, 0), size, mat)
    obj.location = pos
    obj.rotation_euler = (0, 0, angle)
    return obj


def prism(name, pts, bottom, top, mat):
    n = len(pts)
    verts = [(p.x, p.y, z) for z in (bottom, top) for p in pts]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    return mesh(name, verts, faces, mat)


def cylinder(name, pos, radius, depth, mat, vertices=8, angle=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos, rotation=(0, 0, angle))
    bpy.context.object.name = name
    bpy.context.object.data.materials.append(mat)
    return bpy.context.object


def dome(name, pos, radius, height, mat, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, radius=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius, radius, height)
    # Keep the upper half only.
    bm_verts = obj.data.vertices
    for v in bm_verts:
        v.co.z = max(v.co.z, 0.0)
    obj.data.materials.append(mat)
    return obj


# Body: the mapped footprint in stone up to the square-side cornice, a slate roof deck above.
prism("Casino body", ring, base - 0.5, cornice, stone)

# The square-side elevation: the longest edge whose midpoint faces Casino Square.
best = None
for a, b in zip(ring, ring[1:] + ring[:1]):
    if (b - a).length > 25 and (best is None or ((a + b) / 2 - sq).length < ((best[0] + best[1]) / 2 - sq).length):
        best = (a, b)
a, b = best
t = (b - a).normalized()
n = Vector((t.y, -t.x))
if n.dot(sq - (a + b) / 2) < 0:
    n = -n
L = (b - a).length
angle = math.atan2(t.y, t.x)
P = lambda u, d, z: Vector(((a + t * u + n * d).x, (a + t * u + n * d).y, z))

# Rows of arched windows along every edge of the body (two storeys above the square).
for e0, e1 in zip(ring, ring[1:] + ring[:1]):
    span = (e1 - e0).length
    if span < 6:
        continue
    et = (e1 - e0).normalized()
    en = Vector((et.y, -et.x))
    bays = int(span / 4.5)
    for k in range(bays):
        c = e0 + et * ((k + 0.5) * span / bays) + en * 0.05
        for z0, h in [(square_y + 1.0, 4.2), (square_y + 7.5, 5.0)]:
            if z0 < base:
                continue
            box("Window", (c.x, c.y, z0 + h / 2), (1.7, 0.1, h), glass, math.atan2(et.y, et.x))
            box("Window head", (c.x, c.y, z0 + h + 0.25), (2.1, 0.25, 0.5), trim, math.atan2(et.y, et.x))
    # Cornice and balustrade on every edge.
    mid = (e0 + e1) / 2 + en * 0.3
    box("Cornice", (mid.x, mid.y, cornice - 0.4), (span + 0.6, 0.8, 0.8), trim, math.atan2(et.y, et.x))
    box("Balustrade", (mid.x, mid.y, cornice + 0.5), (span, 0.35, 1.0), trim, math.atan2(et.y, et.x))

# Central pavilion: projects 3 m, rises above the cornice, tall arched window over a three-arch entrance.
pw = min(26.0, L * 0.38)
pc = L / 2
box("Pavilion", P(pc, 1.5, (base + cornice + 3) / 2), (pw, 3.0, cornice + 3 - base), stone, angle)
box("Pavilion cornice", P(pc, 3.2, cornice + 2.6), (pw + 1.0, 0.9, 0.9), trim, angle)
for k in (-1, 0, 1):
    c = P(pc + k * 5.0, 3.06, square_y + 2.6)
    box("Entrance arch", c, (3.6, 0.12, 5.2), glass, angle)
    box("Entrance pier", P(pc + k * 5.0 + 2.5, 3.2, square_y + 2.6), (1.2, 0.4, 5.4), trim, angle)
box("Marquise canopy", P(pc, 5.5, square_y + 5.6), (16.0, 5.0, 0.25), glass, angle)
box("Great window", P(pc, 3.06, square_y + 11.0), (6.0, 0.12, 8.5), glass, angle)
box("Great window frame", P(pc, 3.15, square_y + 15.6), (7.2, 0.3, 1.0), gilt, angle)
for k in (-1, 1):
    for j in (0, 1):
        box("Paired column", P(pc + k * (4.4 + j * 1.1), 3.4, square_y + 11.0), (0.7, 0.7, 9.0), trim, angle)
# The copper dome over the pavilion: a half-ellipsoid with oculus dormers and a gilt crest.
dome("Pavilion dome", P(pc, -6.0, cornice + 3.0), pw / 2, 9.0, copper, 24).scale = (pw / 2 * 1.05, 11.0, 9.0)
bpy.context.object.rotation_euler = (0, 0, angle)
for k in (-1, 0, 1):
    box("Oculus dormer", P(pc + k * 6.5, 2.4, cornice + 5.0), (3.2, 2.0, 3.6), trim, angle)
    cylinder("Oculus", P(pc + k * 6.5, 3.45, cornice + 5.0), 0.9, 0.2, glass, 16).rotation_euler = (math.pi / 2, 0, angle)
box("Crest", P(pc, -6.0, cornice + 12.4), (pw * 0.5, 0.6, 0.8), gilt, angle)

# Corner towers with octagonal belvederes, domes and lanterns.
for u in (4.5, L - 4.5):
    top = cornice + 9.0
    box("Tower", P(u, 0.5, (base + top) / 2), (8.0, 8.0, top - base), stone, angle)
    box("Tower cornice", P(u, 0.5, top - 0.3), (9.0, 9.0, 0.8), trim, angle)
    for k in range(3):
        box("Tower window", P(u, 4.56, cornice + 1.5 + k * 2.6), (1.6, 0.12, 1.8), glass, angle)
    cylinder("Belvedere", P(u, 0.5, top + 2.4), 3.2, 4.8, stone, 8, angle + math.pi / 8)
    for k in range(8):
        aa = angle + k * math.pi / 4
        c = P(u, 0.5, top + 2.4)
        box("Belvedere opening", (c.x + math.cos(aa) * 3.1, c.y + math.sin(aa) * 3.1, top + 2.6), (0.12, 1.4, 3.0),
            glass, aa)
    dome("Tower dome", P(u, 0.5, top + 4.8), 3.4, 3.2, stone, 16)
    cylinder("Lantern", P(u, 0.5, top + 8.8), 0.9, 1.8, copper, 8)
    dome("Lantern cap", P(u, 0.5, top + 9.7), 1.0, 1.2, copper, 8)
    box("Finial", P(u, 0.5, top + 11.4), (0.25, 0.25, 1.6), gilt, angle)

# Slate roof deck over the body.
pts = [Vector((p.x, p.y, cornice + 0.05)) for p in ring]
tris = tessellate_polygon([pts])
mesh("Roof deck", [tuple(p) for p in pts], [tuple(tri) if (pts[tri[1]] - pts[tri[0]]).cross(pts[tri[2]] - pts[tri[0]]).z > 0
                                          else (tri[0], tri[2], tri[1]) for tri in tris], roof)

finish("monaco_casino", OUT)
