#!/usr/bin/env python3
"""Monaco GP lap from OSM ways (osm-roads.json), chained in race order.

Each way is flipped to follow the race direction (its nearer end to the running point comes first).
Consecutive duplicate points are dropped; the result is written to centreline.json as [lat, lon] pairs.
Source: OpenStreetMap contributors, ODbL 1.0.
"""
import json, math

LAP = [
    4226740, 1019174508, 166399479, 1453878835, 161882794,  # Boulevard Albert 1er (start/finish straight)
    1388331344, 1388331346,  # Sainte-Devote
    166399484, 157719644, 254596486,  # Avenue d'Ostende (Beau Rivage climb)
    1551240829, 161775592, 1082515450, 161752645,  # Avenue de Monte-Carlo (Massenet)
    4229658, 4230009,  # Place du Casino
    4230006, 434567309, 166399501,  # Avenue des Spelugues to Mirabeau
    568187257,  # down to the Fairmont hairpin
    4230007, 1148675745, 1470365906, 1470365907, 1148199871,  # Portier
    41929969, 4230891, 1230247123, 160004393, 4229536, 1451501763,  # Boulevard Louis II, the tunnel
    1081401613,  # Nouvelle Chicane
    485746484,  # Quai des Etats-Unis to Tabac
    503475642, 1081401614, 214636589, 1081401615,  # Route de la Piscine, swimming pool
    39839529, 1081401617,  # Quai Antoine 1er, La Rascasse
]


def dist(a, b):
    k = math.cos(math.radians(43.735))
    return 6371000 * math.hypot(math.radians(b[0] - a[0]), math.radians(b[1] - a[1]) * k)


ways = {e["id"]: e for e in json.load(open("osm-roads.json"))["elements"] if e["type"] == "way"}
pts = []
for wid in LAP:
    g = [(p["lat"], p["lon"]) for p in ways[wid]["geometry"]]
    if pts and dist(pts[-1], g[-1]) < dist(pts[-1], g[0]):
        g.reverse()
    for p in g:
        if not pts or dist(pts[-1], p) > 0.5:
            pts.append(p)
gaps = [(i, round(dist(a, b))) for i, (a, b) in enumerate(zip(pts, pts[1:])) if dist(a, b) > 40]
length = sum(dist(a, b) for a, b in zip(pts, pts[1:] + pts[:1]))
print("points", len(pts), "lap m", round(length), "close gap m", round(dist(pts[-1], pts[0])), "gaps>40m", gaps)
json.dump({"source": "OpenStreetMap contributors, ODbL 1.0 (osm-roads.json)", "points": pts}, open("centreline.json", "w"))
