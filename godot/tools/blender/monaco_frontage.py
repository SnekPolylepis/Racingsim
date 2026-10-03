"""Monaco frontage exteriors: every non-landmark building within 30 m of the lap (city.json flag 4), modelled
from its mapped OSM footprint as Riviera street architecture instead of an extruded block:
  ground floor  stone base, shopfronts recessed 0.35 m behind the wall with dark glass, some awnings
  upper floors  3.1 m storeys; recessed windows with sills, louvred shutters on most older blocks, and
                either continuous balconies (modern apartment towers) or French balconies with railings
  top           projecting cornice and parapet over a flat roof
Style per building is seeded by its OSM id, so rebuilds are stable. References: the street-level Commons
photos listed in trackgen/data/monaco/README.md (Boulevard Albert 1er, Avenue d'Ostende, Portier, harbour).
Geometry only, no photo pixels. Positions are world metres: Blender (x, -z, y) of the game's (x, y, z).

blender -b --python-exit-code 1 --python tools/blender/monaco_frontage.py -- assets/monaco
"""
import bpy
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)

# Riviera render colours (monaco.gd TINTS): cream, ochre, salmon, white, pale yellow, terracotta.
TINTS = [(.94, .9, .8), (.88, .74, .52), (.9, .7, .6), (.96, .95, .92), (.95, .88, .62), (.8, .55, .42)]
M = {
    "stone": material("Pale stone base", (.82, .78, .7), roughness=.8),
    "cornice": material("White moulded cornice", (.93, .92, .88), roughness=.7),
    "glass": material("Dark window glass", (.05, .07, .08), metallic=.3, roughness=.15),
    "shop": material("Shopfront glass", (.08, .1, .1), metallic=.3, roughness=.1),
    "rail": material("Dark painted railing", (.1, .11, .1), metallic=.5, roughness=.45),
    "roof": material("Roof membrane", (.32, .31, .29), roughness=.9),
    "frame": material("White window frames", (.9, .9, .87), roughness=.5),
}
for i, c in enumerate(TINTS):
    M["wall%d" % i] = material("Render %d" % i, c, roughness=.85)
for i, c in enumerate([(.2, .36, .25), (.36, .3, .22), (.55, .6, .58), (.75, .72, .62)]):
    M["shutter%d" % i] = material("Shutters %d" % i, c, roughness=.7)
for i, c in enumerate([(.62, .1, .1), (.12, .22, .4), (.18, .35, .25), (.85, .82, .74)]):
    M["awning%d" % i] = material("Awning %d" % i, c, roughness=.8)

geo = {k: ([], [], []) for k in M}  # material -> (vertices, faces, uvs)


def quad(mat, p, uv=None):
    """Four corners counter-clockwise seen from the front."""
    v, f, u = geo[mat]
    n = len(v)
    v.extend(p)
    f.append((n, n + 1, n + 2, n + 3))
    u.extend(uv or [(0, 0), (1, 0), (1, 1), (0, 1)])


def box(mat, c, t, n, size):
    """Box centred on c with half-extents along t (along the wall), n (outward) and up."""
    up = Vector((0, 0, 1))
    hx, hy, hz = (s / 2 for s in size)
    corner = lambda a, b, d: c + t * (a * hx) + n * (b * hy) + up * (d * hz)
    for axis, sign in [(t, 1), (t, -1), (n, 1), (n, -1), (up, 1), (up, -1)]:
        if axis is t:
            pts = [corner(sign, -sign, -1), corner(sign, sign, -1), corner(sign, sign, 1), corner(sign, -sign, 1)]
        elif axis is n:
            pts = [corner(sign, sign, -1), corner(-sign, sign, -1), corner(-sign, sign, 1), corner(sign, sign, 1)]
        else:
            pts = [corner(-1, -sign, sign), corner(1, -sign, sign), corner(1, sign, sign), corner(-1, sign, sign)]
        # Orient outward.
        normal = (pts[1] - pts[0]).cross(pts[3] - pts[0])
        if normal.dot(axis * sign) < 0:
            pts.reverse()
        quad(mat, pts)


class Face:
    """One wall edge: a -> b along t, outward n; points at (u along, z up, d out)."""

    def __init__(self, a, b):
        self.a = a
        self.t = (b - a).normalized()
        self.n = Vector((self.t.y, -self.t.x, 0))
        self.length = (b - a).length

    def p(self, u, z, d=0.0):
        return self.a + self.t * u + self.n * d + Vector((0, 0, z))

    def rect(self, mat, u0, u1, z0, z1, d=0.0):
        if u1 - u0 < 1e-3 or z1 - z0 < 1e-3:
            return
        uv = [(u0 / 3, z0 / 3), (u1 / 3, z0 / 3), (u1 / 3, z1 / 3), (u0 / 3, z1 / 3)]
        quad(mat, [self.p(u0, z0, d), self.p(u1, z0, d), self.p(u1, z1, d), self.p(u0, z1, d)], uv)

    def opening(self, wall, inner, glass, u0, u1, z0, z1, wu0, wu1, wz0, wz1, depth):
        """Wall cell [u0,u1]x[z0,z1] with a recessed opening; reveals in `inner`, pane at the back."""
        self.rect(wall, u0, wu0, z0, z1)
        self.rect(wall, wu1, u1, z0, z1)
        self.rect(wall, wu0, wu1, z0, wz0)
        self.rect(wall, wu0, wu1, wz1, z1)
        d = -depth
        # Reveals face into the opening.
        quad(inner, [self.p(wu0, wz0, d), self.p(wu0, wz0), self.p(wu0, wz1), self.p(wu0, wz1, d)])
        quad(inner, [self.p(wu1, wz0), self.p(wu1, wz0, d), self.p(wu1, wz1, d), self.p(wu1, wz1)])
        quad(inner, [self.p(wu0, wz0), self.p(wu0, wz0, d), self.p(wu1, wz0, d), self.p(wu1, wz0)])
        quad(inner, [self.p(wu0, wz1, d), self.p(wu0, wz1), self.p(wu1, wz1), self.p(wu1, wz1, d)])
        self.rect(glass, wu0, wu1, wz0, wz1, d)

    def strip(self, mat, z, height, depth, inset=0.0):
        """A moulding along the whole edge: string course, cornice, balcony slab."""
        c = self.p(self.length / 2, z + height / 2, depth / 2)
        box(mat, c, self.t, self.n, (self.length - 2 * inset + depth * 2 * (inset == 0), depth, height))


def building(ring, base, top, kind, osm_id, flag=1):
    rng = random.Random(osm_id)
    pts = [Vector((ring[i], -ring[i + 1], 0)) for i in range(0, len(ring) - 1, 2)]
    if len(pts) > 2 and (pts[0] - pts[-1]).length < 0.05:
        pts.pop()
    if sum(a.x * b.y - b.x * a.y for a, b in zip(pts, pts[1:] + pts[:1])) < 0:
        pts.reverse()
    h = top - base
    wall = "wall%d" % rng.randrange(len(TINTS))
    modern = h > 22 and rng.random() < 0.6
    shutters = None if modern or rng.random() < 0.2 else "shutter%d" % rng.randrange(4)
    balconies = "continuous" if modern else ("french" if rng.random() < 0.45 else None)
    shops = kind in ("retail", "hotel", "yes", "apartments", "residential") and rng.random() < 0.85
    ground = 4.6 if kind in ("retail", "hotel") else 4.2
    if h < 7:
        ground = h - 0.8
    storey = 3.1
    floors = max(0, int((h - ground - 1.2) / storey))
    upper_top = base + ground + floors * storey
    win_w = 1.5 if modern else 1.15
    awning = "awning%d" % rng.randrange(4) if shops and rng.random() < 0.4 else None
    if flag == 2:
        # The Fairmont (1975) over the tunnel: white balcony bands on every storey, dark glass wall to wall.
        wall, modern, shutters, balconies, shops, awning = "wall3", True, None, "continuous", False, None
        ground, win_w = storey, 99.0
        floors = max(0, int((h - ground - 1.2) / storey))
        upper_top = base + ground + floors * storey
    for a, b in zip(pts, pts[1:] + pts[:1]):
        f = Face(a, b)
        L = f.length
        if L < 2.6:
            f.rect(wall, 0, L, base - 0.5, top)
            continue
        bays = max(1, round(L / 3.2))
        pitch = L / bays
        # Ground floor: stone, with shopfronts or plain windows.
        for k in range(bays):
            u0, u1 = k * pitch, (k + 1) * pitch
            if shops and pitch > 2.2:
                f.opening("stone", "stone", "shop", u0, u1, base - 0.5, base + ground,
                          u0 + 0.45, u1 - 0.45, base + 0.05, base + ground - 0.9, 0.35)
                if awning:
                    c = f.p((u0 + u1) / 2, base + ground - 0.55, 0.55)
                    box(awning, c, f.t, f.n, (pitch - 0.7, 1.1, 0.08))
            else:
                f.opening("stone", "stone", "glass", u0, u1, base - 0.5, base + ground,
                          (u0 + u1) / 2 - 0.55, (u0 + u1) / 2 + 0.55, base + 1.0, base + ground - 1.0, 0.25)
        f.strip("cornice", base + ground - 0.15, 0.3, 0.22)
        # Upper storeys.
        for row in range(floors):
            z0 = base + ground + row * storey
            for k in range(bays):
                u0, u1 = k * pitch, (k + 1) * pitch
                mid = (u0 + u1) / 2
                w = min(win_w, pitch - 0.4 if flag == 2 else pitch - 0.6)
                if w < 0.6:
                    f.rect(wall, u0, u1, z0, z0 + storey)
                    continue
                sill = z0 + (0.15 if balconies else 0.85)
                head = z0 + 2.55
                f.opening(wall, "frame", "glass", u0, u1, z0, z0 + storey, mid - w / 2, mid + w / 2, sill, head, 0.2)
                box("cornice", f.p(mid, sill - 0.04, 0.06), f.t, f.n, (w + 0.2, 0.14, 0.08))
                if shutters and pitch > w + 1.3:
                    for s in (-1, 1):
                        box(shutters, f.p(mid + s * (w * 0.75 + 0.02), (sill + head) / 2, 0.03), f.t, f.n,
                            (w / 2, 0.04, head - sill))
                if balconies == "french":
                    box("cornice", f.p(mid, sill - 0.08, 0.3), f.t, f.n, (w + 0.5, 0.6, 0.12))
                    box("rail", f.p(mid, sill + 0.95, 0.58), f.t, f.n, (w + 0.5, 0.04, 0.06))
                    box("rail", f.p(mid, sill + 0.5, 0.58), f.t, f.n, (w + 0.5, 0.02, 0.9))
            if balconies == "continuous":
                f.strip("cornice", z0 - 0.09, 0.18, 1.3, inset=0.3)
                box("rail", f.p(L / 2, z0 + 1.0, 1.25), f.t, f.n, (L - 0.6, 0.05, 0.06))
                box("rail", f.p(L / 2, z0 + 0.55, 1.25), f.t, f.n, (L - 0.6, 0.02, 0.85))
        # Parapet and cornice.
        f.rect(wall, 0, L, upper_top, top)
        if h >= 7:
            f.strip("cornice", top - 1.1, 0.45, 0.45)
    # Flat roof; a building standing over the road (flag 2) also closes its underside.
    tris = tessellate_polygon([[p.to_3d() for p in pts]])
    for z, mat, up in [(top, "roof", True)] + ([(base - 0.5, "cornice", False)] if flag == 2 else []):
        for tri in tris:
            v, faces, uvs = geo[mat]
            n = len(v)
            v.extend(Vector((pts[i].x, pts[i].y, z)) for i in tri)
            ccw = (pts[tri[1]] - pts[tri[0]]).cross(pts[tri[2]] - pts[tri[0]]).z > 0
            faces.append((n, n + 1, n + 2) if ccw == up else (n, n + 2, n + 1))
            uvs.extend((pts[i].x / 4, pts[i].y / 4) for i in tri)


doc = json.loads((ROOT / "trackgen/data/monaco/city.json").read_text())
count = 0
for b in doc["buildings"]:
    if len(b) > 4 and b[4]:
        building(b[0], b[1], b[1] + b[2], b[3], b[5], b[4])
        count += 1

objects = []
for key, (v, f, u) in geo.items():
    if not f:
        continue
    data = bpy.data.meshes.new(key)
    data.from_pydata([tuple(p) for p in v], [], f)
    layer = data.uv_layers.new(name="UVMap")
    for poly in data.polygons:
        for li in poly.loop_indices:
            layer.data[li].uv = u[data.loops[li].vertex_index]
    data.update()
    obj = bpy.data.objects.new(M[key].name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(M[key])
    objects.append(obj)
OUT.mkdir(parents=True, exist_ok=True)
authored = Path(__file__).resolve().parent / "authored"
authored.mkdir(exist_ok=True)
(authored / ".gdignore").touch()
bpy.ops.wm.save_as_mainfile(filepath=str(authored / "monaco_frontage.blend"))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT / "frontage.glb"), export_format="GLB", use_selection=True)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
print("MONACO_FRONTAGE AUTHORED", count, "buildings;", len(objects), "materials;", tris, "triangles")
