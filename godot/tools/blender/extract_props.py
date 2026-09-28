"""Split a Sketchfab pack into game props (ASSET-02). Run with Blender 5.x:
  blender -b --python tools/blender/extract_props.py -- <scene.gltf> <out dir> <spec json>
spec: {"props": {"<out name>": {"match": ["<object or parent name prefix>", ...], "scale": 1.0,
                                  "max_tris": 4000, "up": "Z"}}, "texture_max": 1024}
Each prop is joined, its world transform baked in, scaled, decimated to max_tris, moved so its footprint is
centred on the origin and its lowest point is at 0, and exported as <out dir>/<name>.glb (Y up)."""
import bpy, sys, json, os
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out, spec = args[0], args[1], json.load(open(args[2]))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
tex_max = spec.get("texture_max", 1024)
for img in bpy.data.images:
    w, h = img.size
    if max(w, h) > tex_max:
        f = tex_max / max(w, h)
        img.scale(max(1, int(w * f)), max(1, int(h * f)))
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.make_single_user(object=True, obdata=True)
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    o.matrix_world = Matrix.Identity(4)


def names(o):
    return [o.name] + [o.data.name]


os.makedirs(out, exist_ok=True)
for name, p in spec["props"].items():
    group = []
    for o in meshes:
        if o.name in bpy.data.objects and any(o.name.startswith(m) for m in p["match"]):
            group.append(o)
    if not group:
        print("PROP missing", name)
        continue
    # Copies, so one source object can feed several props.
    parts = []
    for o in group:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        parts.append(c)
    bpy.ops.object.select_all(action="DESELECT")
    for c in parts:
        c.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.transform(Matrix.Scale(p.get("scale", 1.0), 4))
    vs = [v.co for v in ob.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    ob.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    t = sum(len(f.vertices) - 2 for f in ob.data.polygons)
    if t > p.get("max_tris", 4000):
        m = ob.modifiers.new("dec", "DECIMATE")
        m.ratio = p["max_tris"] / t
        bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    size = hi - lo
    print("PROP", name, "tris", t, "->", sum(len(f.vertices) - 2 for f in ob.data.polygons),
          "size", tuple(round(x * p.get("scale", 1.0), 2) for x in size))
    bpy.data.objects.remove(ob)
