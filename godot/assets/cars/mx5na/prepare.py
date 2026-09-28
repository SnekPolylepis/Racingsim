"""Bake Berk Gedik's downloaded scene.gltf/bin into Racing Sim's car frame.

Run from this directory before deleting the source scene; the checked-in mx5na.gltf
and mx5na.bin are the result. Textures are downsampled separately to 1024/512 px.
"""

import json
import math
import struct
from pathlib import Path


HERE = Path(__file__).parent
SOURCE = json.loads((HERE / "scene.gltf").read_text(encoding="utf-8"))
SOURCE_BYTES = (HERE / "scene.bin").read_bytes()
FRONT_AXLE, REAR_AXLE = 1.366, -1.286
FRONT_END, REAR_END = 2.26085, -2.23620
BODY_FRONT, BODY_REAR = 2.022, -1.948
WIDTH_SCALE = 0.8375 / 1.2801312
LOW_Y_SCALE = 0.289 / 0.471
UPPER_Y_SCALE = (1.23 - 0.5 * LOW_Y_SCALE) / (1.44353 - 0.5)
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def matmul(a, b):
    return [sum(a[4 * k + r] * b[4 * c + k] for k in range(4)) for c in range(4) for r in range(4)]


def affine(m, p):
    return tuple(sum(m[4 * k + r] * p[k] for k in range(3)) + m[12 + r] for r in range(3))


def fit_long(z):
    if z < REAR_AXLE:
        return -1.178 + (z - REAR_AXLE) * (BODY_REAR + 1.178) / (REAR_END - REAR_AXLE)
    if z > FRONT_AXLE:
        return 1.087 + (z - FRONT_AXLE) * (BODY_FRONT - 1.087) / (FRONT_END - FRONT_AXLE)
    return -1.178 + (z - REAR_AXLE) * (2.265 / (FRONT_AXLE - REAR_AXLE))


def fit(p):
    # Sketchfab node transforms are in centimetres: X lateral, Y up, Z forward.
    x, y, z = (v / 100.0 for v in p)
    return (fit_long(z), y * (LOW_Y_SCALE if y < 0.5 else UPPER_Y_SCALE) + (0 if y < 0.5 else 0.5 * (LOW_Y_SCALE - UPPER_Y_SCALE)), -x * WIDTH_SCALE)


def accessor(i):
    a = SOURCE["accessors"][i]
    view = SOURCE["bufferViews"][a["bufferView"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
    kind = {5125: "I", 5126: "f"}[a["componentType"]]
    stride = view.get("byteStride", struct.calcsize("<" + kind * count))
    offset = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<" + kind * count, SOURCE_BYTES, offset + j * stride) for j in range(a["count"])]


def world_matrix(node_id, parent=IDENTITY):
    node = SOURCE["nodes"][node_id]
    current = matmul(parent, node.get("matrix", IDENTITY))
    if "mesh" in node:
        yield node["mesh"], current
    for child in node.get("children", []):
        yield from world_matrix(child, current)


material_ids = (1, 3, 4)
image_ids = tuple(i for material in material_ids for i in range(material * 3, material * 3 + 3))
image_map = {old: new for new, old in enumerate(image_ids)}
material_map = {old: new for new, old in enumerate(material_ids)}
output = {"asset": SOURCE["asset"], "samplers": SOURCE["samplers"]}
output["images"] = [SOURCE["images"][i] for i in image_ids]
output["textures"] = [{"sampler": 0, "source": image_map[i]} for i in image_ids]
output["materials"] = [json.loads(json.dumps(SOURCE["materials"][i])) for i in material_ids]
for material in output["materials"]:
    for slot in (material.get("normalTexture"), material.get("occlusionTexture"), material["pbrMetallicRoughness"].get("baseColorTexture"), material["pbrMetallicRoughness"].get("metallicRoughnessTexture")):
        if slot:
            slot["index"] = image_map[slot["index"]]
output.update(scene=0, scenes=[{"nodes": []}], nodes=[], meshes=[], accessors=[], bufferViews=[], buffers=[])
binary = bytearray()


def add(values, components, kind):
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    for v in values:
        binary.extend(struct.pack("<" + kind * components, *v))
    output["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset})
    result = {"bufferView": len(output["bufferViews"]) - 1, "componentType": 5125 if kind == "I" else 5126, "count": len(values), "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3"}[components]}
    if components == 3 and kind == "f":
        result.update(min=[min(v[i] for v in values) for i in range(3)], max=[max(v[i] for v in values) for i in range(3)])
    output["accessors"].append(result)
    return len(output["accessors"]) - 1


names = {1: "PaintedBody", 3: "Glass", 4: "TrimAndLamps"}
for root in SOURCE["scenes"][SOURCE["scene"]]["nodes"]:
    for mesh_id, matrix in world_matrix(root):
        if mesh_id not in names:
            continue  # remove the display ground and the oversized static tires
        primitive = SOURCE["meshes"][mesh_id]["primitives"][0]
        attrs = primitive["attributes"]
        local = accessor(attrs["POSITION"])
        positions = [fit(affine(matrix, p)) for p in local]
        uv = accessor(attrs["TEXCOORD_0"])
        indices = [v[0] for v in accessor(primitive["indices"])]
        # Preserve the source winding after baking node transforms. Godot's glTF
        # importer has already accounted for the source hierarchy's handedness.
        normals = [[0.0, 0.0, 0.0] for _ in positions]
        for i in range(0, len(indices), 3):
            a, b, c = indices[i:i + 3]
            u = [positions[b][j] - positions[a][j] for j in range(3)]
            v = [positions[c][j] - positions[a][j] for j in range(3)]
            cross = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            for vertex in (a, b, c):
                for j in range(3):
                    normals[vertex][j] += cross[j]
        normals = [tuple(v / (math.sqrt(sum(t * t for t in n)) or 1.0) for v in n) for n in normals]
        prim = {"attributes": {"POSITION": add(positions, 3, "f"), "NORMAL": add(normals, 3, "f"), "TEXCOORD_0": add(uv, 2, "f")}, "indices": add([(v,) for v in indices], 1, "I"), "material": material_map[primitive["material"]], "mode": 4}
        output["meshes"].append({"name": names[mesh_id], "primitives": [prim]})
        output["nodes"].append({"name": names[mesh_id], "mesh": len(output["meshes"]) - 1})
        output["scenes"][0]["nodes"].append(len(output["nodes"]) - 1)

output["buffers"] = [{"uri": "mx5na.bin", "byteLength": len(binary)}]
(HERE / "mx5na.bin").write_bytes(binary)
(HERE / "mx5na.gltf").write_text(json.dumps(output, separators=(",", ":")), encoding="utf-8")
print(f"Wrote {len(output['meshes'])} exterior meshes and {sum(a['count'] for a in output['accessors'] if a['type'] == 'SCALAR') // 3} triangles")
