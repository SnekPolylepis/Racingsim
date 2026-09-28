"""Fit a Sketchfab race-car glTF to a Racing Sim car preset (ASSET-02). Run with Blender 5.x:
  blender -b --python tools/blender/build_car.py -- <scene.gltf> <out dir> <a> <b> <wheelR> <nose axis> [max_tris]
Game frame after glTF export: +X nose, +Y up, +Z right; ground at y 0, axles at x=+a and x=-b, height wheelR.
<nose axis> is the source axis the nose points along (e.g. -Y). Writes body.glb (wheels removed, parts joined
per material and named Mat_<material>) and wheel_front.glb / wheel_rear.glb (left wheel, centred on its axle).
"""
import bpy, bmesh, sys, os
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
A, B, R = float(args[2]), float(args[3]), float(args[4])
nose = args[5]
MAX_TRIS = int(args[6]) if len(args) > 6 else 90000
TEX_MAX = 1024
WHEEL_MATS = ("tyre", "tire", "rim", "disc", "wheel")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
bpy.ops.object.select_all(action="DESELECT")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.make_single_user(object=True, obdata=True)
# Bake world transforms into the mesh data and drop the hierarchy.
turn = {"-Y": Matrix.Rotation(1.5707963, 4, "Z"), "+Y": Matrix.Rotation(-1.5707963, 4, "Z"),
        "+X": Matrix.Identity(4), "-X": Matrix.Rotation(3.1415926, 4, "Z")}[nose]
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(turn @ mw)
    o.matrix_world = Matrix.Identity(4)
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)


def bbox(o):
    vs = [v.co for v in o.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    return lo, hi


def mat_name(o):
    return o.data.materials[0].name if o.data.materials and o.data.materials[0] else "none"


tyres = [o for o in meshes if any(k in mat_name(o).lower() for k in ("tyre", "tire")) and len(o.data.vertices)]
centres = []
for o in tyres:
    lo, hi = bbox(o)
    centres.append(((lo + hi) / 2, (hi - lo)))
front = max(c[0].x for c in centres)
rear = min(c[0].x for c in centres)
scale = (A + B) / (front - rear)
radius_src = max(c[1].z for c in centres) / 2
ground = min(c[0].z for c in centres) - radius_src
print("CAR tyres", len(tyres), "scale", scale, "source wheel R", radius_src * scale)
move = Matrix.Translation(Vector((A, 0, 0))) @ Matrix.Scale(scale, 4) @ Matrix.Translation(Vector((-front, 0, -ground)))
# The source tyre radius may differ a little from the preset: lift the body so the axles sit at wheelR.
lift = R - radius_src * scale
for o in meshes:
    o.data.transform(Matrix.Translation(Vector((0, 0, lift))) @ move)
wheel_centres = [move @ c[0] + Vector((0, 0, lift)) for c in centres]

# Wheel parts: every object within a tyre's radius of a tyre centre and made of a wheel material.
wheel_parts = {i: [] for i in range(len(wheel_centres))}
body = []
for o in meshes:
    if not len(o.data.vertices):
        bpy.data.objects.remove(o)
        continue
    lo, hi = bbox(o)
    c = (lo + hi) / 2
    near = min(range(len(wheel_centres)), key=lambda i: (wheel_centres[i] - c).length)
    wheelish = any(k in mat_name(o).lower() for k in WHEEL_MATS)
    if wheelish and (wheel_centres[near] - c).length < R * 1.1:
        wheel_parts[near].append(o)
    else:
        body.append(o)


def keep_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.hide_set(o not in objs)
        o.select_set(o in objs)


def export(objs, path):
    keep_only(objs)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_image_format="AUTO", export_texcoords=True,
                              export_normals=True, export_materials="EXPORT")


def join_by_material(objs, prefix):
    groups = {}
    for o in objs:
        groups.setdefault(mat_name(o), []).append(o)
    joined = []
    for name, group in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in group:
            o.hide_set(False)
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = prefix + name
        o.data.name = o.name
        joined.append(o)
    return joined


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


INTERIOR = ("int_", "seat", "belt", "steer", "electron", "sas", "net", "welding", "racelogic", "punhadura",
            "mangueira", "chrome", "plastic", "carbon", "metal_metal", "display", "led", "borracha_doors")


def decimate(objs, budget):
    """Interior parts, seen only through the glass, are cut to INTERIOR_RATIO; the shell is kept whole
    unless it alone exceeds the budget (thin aero parts tear under collapse decimation)."""
    inside = [o for o in objs if any(k in o.name.lower() for k in INTERIOR)]
    shell = [o for o in objs if o not in inside]
    passes = [(inside, 0.15)]
    shell_tris = sum(tris(o) for o in shell)
    if shell_tris > budget:
        passes.append((shell, budget / shell_tris))
    for group, ratio in passes:
        for o in group:
            if tris(o) < 400:
                continue
            m = o.modifiers.new("dec", "DECIMATE")
            m.ratio = max(ratio, 0.04)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="dec")


def shrink_images():
    for img in bpy.data.images:
        w, h = img.size
        if max(w, h) > TEX_MAX:
            f = TEX_MAX / max(w, h)
            img.scale(max(1, int(w * f)), max(1, int(h * f)))


os.makedirs(out, exist_ok=True)
shrink_images()
body = join_by_material(body, "Mat_")
before = sum(tris(o) for o in body)
decimate(body, MAX_TRIS)
print("CAR body tris", before, "->", sum(tris(o) for o in body), "surfaces", len(body))
export(body, os.path.join(out, "body.glb"))
# One left wheel per axle, moved to its own origin (game: z < 0 is left, Blender +Y is left).
for label, pick in (("front", max), ("rear", min)):
    lefts = [i for i in wheel_parts if wheel_centres[i].y > 0 and wheel_parts[i]]
    i = pick(lefts, key=lambda k: wheel_centres[k].x)
    parts = join_by_material(wheel_parts[i], "Wheel_")
    for o in parts:
        o.data.transform(Matrix.Translation(-wheel_centres[i]))
    decimate(parts, 6000)
    print("CAR wheel", label, "tris", sum(tris(o) for o in parts))
    export(parts, os.path.join(out, "wheel_%s.glb" % label))
