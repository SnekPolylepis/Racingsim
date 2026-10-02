"""Blender authoring primitives shared by the authored Chicago exterior models."""
import bpy
import math
from pathlib import Path

def material(name, color, metallic=0, roughness=.65, glow=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = glow
    return mat


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def box(name, pos, size, mat, bevel=0):
    x, y, z = pos
    a, b, c = (v / 2 for v in size)
    obj = mesh(name, [(x+dx*a, y+dy*b, z+dz*c) for dx,dy,dz in
               [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],
               [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], mat)
    if bevel:
        mod = obj.modifiers.new("Moulded edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def line(name, points, radius, mat):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.bevel_depth = radius
    data.bevel_resolution = 1
    spline = data.splines.new("POLY")
    spline.points.add(len(points)-1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def text(name, value, pos, size, mat, rotate=(math.pi/2, 0, 0), depth=.045):
    data = bpy.data.curves.new(name, "FONT")
    data.body = value
    data.align_x = "CENTER"
    data.align_y = "CENTER"
    data.size = size
    data.extrude = depth
    data.bevel_depth = .008
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = rotate
    obj.data.materials.append(mat)
    return obj


def arch(name, inner, outer, center, y, thickness, mat, start=0, end=math.pi, segments=40):
    cx, cz = center
    vertices = []
    for i in range(segments+1):
        angle = start+(end-start)*i/segments
        for depth in [y, y+thickness]:
            for r in [inner, outer]:
                vertices.append((cx+r*math.cos(angle), depth, cz+r*math.sin(angle)))
    faces = []
    for i in range(segments):
        a, b = i*4, (i+1)*4
        faces += [(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),
                  (a,a+2,b+2,b),(a+1,b+1,b+3,a+3)]
    faces += [(0,1,3,2),(segments*4,segments*4+2,segments*4+3,segments*4+1)]
    return mesh(name, vertices, faces, mat)


def finish(stem, out):
    """Bake authored details and combine by material for the game."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.convert(target="MESH")
    for mat in list(bpy.data.materials):
        group=[o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.materials and o.data.materials[0]==mat]
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join()
        group[0].name=mat.name
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.select_all(action="SELECT")
    authored = Path(__file__).resolve().parent / "authored"
    authored.mkdir(exist_ok=True)
    (authored / ".gdignore").touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(authored/(stem+".blend")))
    bpy.ops.export_scene.gltf(filepath=str(out/(stem+".glb")),export_format="GLB",use_selection=True)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.selected_objects)
    print(stem.upper(),"AUTHORED",len(bpy.context.selected_objects),"materials;",tris,"triangles")


