"""Fit Lexyc16's CC BY 4.0 Sketchfab glTF to Racing Sim's roadster preset.

Run beside the source scene.gltf/bin. The fitted model drops the display plane,
source wheels, and an unneeded interior black mesh; car_kit.gd adds wheels.
"""

import json
import math
import struct
from pathlib import Path


HERE = Path(__file__).parent
SOURCE = json.loads((HERE / "scene.gltf").read_text(encoding="utf-8"))
SOURCE_BYTES = (HERE / "scene.bin").read_bytes()
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def matmul(a, b):
    return [sum(a[4 * k + r] * b[4 * c + k] for k in range(4)) for c in range(4) for r in range(4)]


def affine(m, p):
    return tuple(sum(m[4 * k + r] * p[k] for k in range(3)) + m[12 + r] for r in range(3))


def fit_long(z):
    # Both wheel centres and the 3970 mm overall NA length are exact anchors.
    if z < 17.5832748:
        return -1.178 + (z - 17.5832748) * (-2.019 + 1.178) / (-40.045 - 17.5832748)
    if z > 172.779785:
        return 1.087 + (z - 172.779785) * (1.951 - 1.087) / (226.157 - 172.779785)
    return -1.178 + (z - 17.5832748) * 2.265 / (172.779785 - 17.5832748)


def fit(p):
    # Source world units: X lateral, Y up, Z longitudinal; game +X is nose.
    x, y, z = p
    vertical = ((y - 44.831) * .289 / (64.8615 - 44.831) if y < 64.8615 else
                .289 + (y - 64.8615) * .941 / (125.073 - 64.8615))
    return (fit_long(z), vertical, -(x - 160.8315) * 1.675 / (223.001 - 98.662))


def accessor(i):
    a = SOURCE["accessors"][i]
    view = SOURCE["bufferViews"][a["bufferView"]]
    count = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
    kind = {5125: "I", 5126: "f"}[a["componentType"]]
    stride = view.get("byteStride", struct.calcsize("<" + kind * count))
    offset = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return [struct.unpack_from("<" + kind * count, SOURCE_BYTES, offset + j * stride) for j in range(a["count"])]


def node_matrix(node):
    if "matrix" in node:
        return node["matrix"]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    return [
        (1 - 2 * (y * y + z * z)) * sx, 2 * (x * y + z * w) * sx, 2 * (x * z - y * w) * sx, 0,
        2 * (x * y - z * w) * sy, (1 - 2 * (x * x + z * z)) * sy, 2 * (y * z + x * w) * sy, 0,
        2 * (x * z + y * w) * sz, 2 * (y * z - x * w) * sz, (1 - 2 * (x * x + y * y)) * sz, 0,
        tx, ty, tz, 1,
    ]


def world_matrix(node_id, parent=IDENTITY):
    node = SOURCE["nodes"][node_id]
    current = matmul(parent, node_matrix(node))
    if "mesh" in node:
        yield node["mesh"], current
    for child in node.get("children", []):
        yield from world_matrix(child, current)


names = {0: "PaintedBody", 2: "DetailedLamps", 3: "Chrome", 4: "Windscreen", 5: "SideGlass", 6: "Trim", 8: "PaintedLampPods", 10: "PodGlass", 11: "PodTrim"}
material_ids = tuple(sorted({SOURCE["meshes"][i]["primitives"][0]["material"] for i in names}))
material_map = {old: new for new, old in enumerate(material_ids)}
output = {"asset": {"version": "2.0", "generator": "RacingSim CAR-01 fit from Lexyc16 CC BY 4.0"}, "samplers": SOURCE["samplers"]}
output["images"] = SOURCE["images"]
output["textures"] = SOURCE["textures"]
output["materials"] = [json.loads(json.dumps(SOURCE["materials"][i])) for i in material_ids]
for material in output["materials"]:
    material.pop("extensions", None)
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
