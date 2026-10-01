"""List every city building against chi_shot --route-survey's actual five-metre curve samples.

Usage: python inventory_route.py <game-user-folder>/chi-<tag>-route.json
The 402.5 m candidate cutoff includes the half-sample uncertainty around 400 m.
All buildings remain in the CSV: distance/height screening does not prove visibility or facades.
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np
from build_city import HERE, inside, load


def nearest_route(curve, footprint):
    ring = np.asarray(footprint, dtype=float)
    edge = np.roll(ring, -1, axis=0) - ring
    delta = curve[:, None, :] - ring[None, :, :]
    lengths = (edge * edge).sum(axis=1)
    t = np.clip((delta * edge).sum(axis=2) / np.maximum(lengths, 1e-12), 0, 1)
    distances = np.linalg.norm(delta - t[:, :, None] * edge, axis=2).min(axis=1)
    station = int(distances.argmin())
    return station, 0.0 if inside(curve[station], footprint) else float(distances[station])


def main():
    # One bounded geometry check, including a route sample inside the footprint.
    square = [[0, 0], [2, 0], [2, 2], [0, 2]]
    assert nearest_route(np.array([[1, 1], [3, 1]]), square)[1] == 0
    assert nearest_route(np.array([[4, 1]]), square)[1] == 2
    survey = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    curve = np.asarray(survey["curve"])[:, [0, 2]]
    exclusions = {e["city_index"]: e["reason"] for e in survey.get("excluded", [])}
    city = json.loads(Path(HERE, "city.json").read_text())
    marks = json.loads(Path(HERE, "landmarks.json").read_text())["buildings"]
    raw = {e["type"][0] + str(e["id"]): e.get("tags", {})
           for filename in ("downtown-buildings.json", "downtown-building-parts.json") for e in load(filename)}
    rows = []
    for index, b in enumerate(city["buildings"]):
        if b.get("band"):
            continue
        osm = b.get("o", "")
        tags, mark = raw.get(osm, {}), marks.get(osm, {})
        station, distance = nearest_route(curve, b["f"])
        x, z = np.asarray(b["f"]).mean(axis=0)
        rows.append({"city_index": index, "osm_id": osm, "name": tags.get("name", mark.get("name", "")),
                     "street": tags.get("addr:street", ""), "number": tags.get("addr:housenumber", ""),
                     "x": round(float(x), 1), "z": round(float(z), 1), "height": b["h"],
                     "route_distance": round(distance, 1), "nearest_station": station * survey["curve_step"],
                     "near_route": int(distance <= 402.5), "skyline_candidate": int(b["h"] >= 80),
                     "lidar": int("L" in b), "coverage": b.get("lc", ""), "unresolved": b.get("u", 0),
                     "osm_material": tags.get("building:material", ""), "osm_colour": tags.get("building:colour", ""),
                     "facade_source": mark.get("src", ""), "renderer_exclusion": exclusions.get(index, ""),
                     "map_source": "https://www.openstreetmap.org/%s/%s" % ("way" if osm[:1] == "w" else "relation", osm[1:])})
    rows.sort(key=lambda r: (not r["near_route"], r["nearest_station"], r["route_distance"]))
    output = Path(HERE, "route-inventory.csv")
    with output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print("Inventory: %d buildings, %d near-route candidates, %d skyline candidates, %d unresolved; %s" %
          (len(rows), sum(r["near_route"] for r in rows), sum(r["skyline_candidate"] for r in rows),
           sum(r["unresolved"] for r in rows), output))


if __name__ == "__main__":
    main()
