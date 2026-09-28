#!/usr/bin/env python3
"""Build the Chicago route drafts (detours) from retained OpenStreetMap geometry.

Every detour is a chain of real OSM ways: the script routes between named intersections over a directed
road graph, restricted to the streets named for each leg, and reports any leg that would run against a
one-way tag. The two game-only connectors of the baseline route (harbor connector, south connector) are
kept exactly as authored. Output goes to drafts/ next to this file:

    drafts/route-<id>.json   same schema as route.json, loadable by trackgen/chicago.gd (DATA const)
    drafts/index.html        self-contained map comparing the drafts (built from drafts_viewer.tmpl.html)

Run from anywhere:  python3 build_drafts.py
Inputs: route.json (baseline), osm-roads.json (original extract), osm-grid.json (cross streets).
Data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import heapq
import json
import math
import os
import re
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "drafts")
LAT0, LON0 = 41.8848, -87.6244
SKIP = {"cycleway", "footway", "path", "busway", "construction", "pedestrian", "steps"}


def xy(lat, lon):
    """Same local frame as chicago.gd world(): +x east, +y north, metres."""
    return ((lon - LON0) * 82860.0, (lat - LAT0) * 110574.0)


# --- road graph -----------------------------------------------------------------------------------
ELS = {}
for fn in ("osm-roads.json", "osm-grid.json"):
    with open(os.path.join(HERE, fn)) as f:
        for e in json.load(f)["elements"]:
            ELS[e["id"]] = e
P, LL, WAYS = {}, {}, {}
ADJ = defaultdict(list)  # node -> (node, metres, way id, legal in this direction)
for wid, e in ELS.items():
    t = e["tags"]
    if t["highway"] in SKIP:
        continue
    WAYS[wid] = t
    oneway = t.get("oneway") == "yes"
    for n, g in zip(e["nodes"], e["geometry"]):
        LL[n] = (g["lat"], g["lon"])
        P[n] = xy(g["lat"], g["lon"])
    for a, b in zip(e["nodes"], e["nodes"][1:]):
        d = math.dist(P[a], P[b])
        ADJ[a].append((b, d, wid, True))
        ADJ[b].append((a, d, wid, not oneway))


def name(w):
    return WAYS[w].get("name", "")


def matches(w, pat):
    return re.search(pat, name(w)) is not None


def junction(p1, p2, near):
    """Node where a way matching p1 meets one matching p2, closest to `near` (local metres)."""
    best = None
    for n, links in ADJ.items():
        ws = {w for _, _, w, _ in links}
        if any(matches(w, p1) for w in ws) and any(matches(w, p2) for w in ws):
            d = math.dist(P[n], near)
            if best is None or d < best[0]:
                best = (d, n)
    if best is None or best[0] > 60:
        raise KeyError((p1, p2, near))
    return best[1]


def route(a, b, allow):
    """Shortest legal path a->b over ways whose name matches `allow`; None if only illegal ones exist."""
    dist, prev, heap = {a: 0.0}, {}, [(0.0, a)]
    while heap:
        d, u = heapq.heappop(heap)
        if u == b:
            break
        if d > dist[u]:
            continue
        for v, length, w, ok in ADJ[u]:
            if not ok or not matches(w, allow):
                continue
            if d + length < dist.get(v, 1e18):
                dist[v] = d + length
                prev[v] = (u, w)
                heapq.heappush(heap, (d + length, v))
    if b not in prev:
        return None
    path, ways = [b], []
    while path[-1] != a:
        u, w = prev[path[-1]]
        path.append(u)
        ways.append(w)
    return path[::-1], ways[::-1]


def simplify(nodes, tol=4.0):
    """Douglas-Peucker on a node chain; keeps end points."""
    pts = [P[n] for n in nodes]

    def rec(i, j):
        (x1, y1), (x2, y2) = pts[i], pts[j]
        seg = math.hypot(x2 - x1, y2 - y1) or 1e-9
        worst, at = 0.0, None
        for k in range(i + 1, j):
            d = abs((x2 - x1) * (y1 - pts[k][1]) - (x1 - pts[k][0]) * (y2 - y1)) / seg
            if d > worst:
                worst, at = d, k
        if worst <= tol:
            return [j]
        return rec(i, at) + rec(at, j)

    return [nodes[0]] + [nodes[i] for i in rec(0, len(nodes) - 1)]


def street(n):
    """Short label for a node: the distinct street names meeting there."""
    names = []
    for _, _, w, _ in ADJ[n]:
        s = re.sub(r"^(East|West|North|South|Lower|Upper) ", "", name(w))
        s = s.replace(" Street", " St").replace(" Avenue", " Ave").replace(" Drive", " Dr").replace(" Boulevard", " Blvd")
        if s and s not in names:
            names.append(s)
    return " & ".join(names[:2])


# --- baseline --------------------------------------------------------------------------------------
with open(os.path.join(HERE, "route.json")) as f:
    BASE = json.load(f)


class Leg:
    def __init__(self, allow, *stops):
        """stops: (pattern_a, pattern_b, near_x, near_y) junction specs; consecutive stops are routed."""
        self.allow, self.nodes = allow, [junction(*s[:2], s[2:]) for s in stops]

    def build(self):
        chain, ways = [self.nodes[0]], []
        for a, b in zip(self.nodes, self.nodes[1:]):
            if a == b:
                continue
            r = route(a, b, self.allow)
            if r is None:
                raise RuntimeError(f"no legal route {street(a)} -> {street(b)} over /{self.allow}/")
            chain += r[0][1:]
            ways += r[1]
        return chain, ways


def row(n, height, label=None):
    lat, lon = LL[n]
    return [round(lat, 6), round(lon, 6), height, label or street(n)]


def splice(base_points, first, last, legs, height=8):
    """Replace baseline points first..last (inclusive) with the simplified chains of `legs`."""
    new, used = [], []
    for leg in legs:
        chain, ways = leg.build()
        used += ways
        keep = simplify(chain)
        for i, n in enumerate(keep):
            if new and new[-1][:2] == row(n, height)[:2]:
                continue
            new.append(row(n, height))
    return base_points[:first] + new + base_points[last + 1 :], used


# Local-metre anchors on the real grid (E-W: Madison y-300, Monroe -450, Adams -585, Jackson -735;
# N-S: Michigan 0, Wabash -145, Dearborn -415, Franklin -905, S Wacker -1040).
def michigan_weave(zigs):
    """Michigan Ave southbound with real block-by-block jogs: W on a westbound street, S on Wabash,
    E on an eastbound street, back onto Michigan."""
    legs = []
    if "monroe" in zigs:
        legs += [
            Leg("Michigan Avenue|Madison Street", ("Michigan Avenue", "Madison Street", 0, -300), ("Wabash", "Madison Street", -145, -300)),
            Leg("Wabash", ("Wabash", "Madison Street", -145, -300), ("Wabash", "Monroe Street", -145, -450)),
            Leg("Monroe Street", ("Wabash", "Monroe Street", -145, -450), ("Michigan Avenue", "Monroe Street", 0, -440)),
        ]
    if "jackson" in zigs:
        if "monroe" in zigs:
            legs.append(Leg("Michigan Avenue", ("Michigan Avenue", "Monroe Street", 0, -440), ("Michigan Avenue", "Adams Street", 0, -585)))
        else:
            legs.append(Leg("Michigan Avenue", ("Michigan Avenue", "Madison Street", 0, -300), ("Michigan Avenue", "Adams Street", 0, -585)))
        legs += [
            Leg("Adams Street", ("Michigan Avenue", "Adams Street", 0, -585), ("Wabash", "Adams Street", -145, -585)),
            Leg("Wabash", ("Wabash", "Adams Street", -145, -585), ("Wabash", "Jackson Boulevard", -145, -735)),
            Leg("Jackson Boulevard", ("Wabash", "Jackson Boulevard", -145, -735), ("Michigan Avenue", "Jackson Boulevard", 0, -720)),
        ]
    return legs


def west_monroe_franklin():
    """Upper deck S Wacker north to Monroe, east to Franklin, north to the riverfront."""
    return [
        Leg("^(North |South )?Wacker Drive", ("^(North |South )?Wacker Drive", "^(East |West )?Monroe Street", -1040, -460), ("^(North |South )?Wacker Drive", "^(East |West )?Monroe Street", -1040, -460)),
        Leg("Monroe Street", ("^(North |South )?Wacker Drive", "^(East |West )?Monroe Street", -1040, -460), ("Franklin", "Monroe Street", -905, -459)),
        Leg("Franklin", ("Franklin", "Monroe Street", -905, -459), ("Franklin", "Upper Wacker", -915, 225)),
    ]


def west_ladder():
    """Monroe/Franklin then across Washington to Dearborn and north to the riverfront."""
    return [
        Leg("Monroe Street", ("^(North |South )?Wacker Drive", "^(East |West )?Monroe Street", -1040, -460), ("Franklin", "Monroe Street", -905, -459)),
        Leg("Franklin", ("Franklin", "Monroe Street", -905, -459), ("Franklin", "Washington Street", -905, -180)),
        Leg("Washington Street", ("Franklin", "Washington Street", -905, -180), ("Dearborn", "Washington Street", -415, -180)),
        Leg("Dearborn", ("Dearborn", "Washington Street", -415, -180), ("Dearborn", "Upper Wacker", -415, 225)),
    ]


def east_columbus():
    """Jackson Dr east to Columbus, north on Columbus, east on Monroe Dr onto Lake Shore Drive."""
    return [
        Leg("Jackson Drive|Columbus", ("Jackson Drive", "Columbus", 306, -714), ("Columbus", "Monroe Drive", 306, -415)),
        Leg("Monroe Drive", ("Columbus", "Monroe Drive", 306, -415), ("Monroe Drive", "DuSable Lake Shore", 593, -429)),
    ]


DRAFTS = [
    dict(id="a", title="Loop Weave", tag="Michigan Ave becomes a stair of four 90-degree jogs through the Loop",
         michigan=["monroe", "jackson"], west=None, east=False,
         steps=["Michigan Ave ↓", "Madison St ←", "Wabash Ave ↓", "Monroe St →", "Michigan Ave ↓", "Adams St ←",
                "Wabash Ave ↓", "Jackson Blvd →", "Jackson Dr →"]),
    dict(id="b", title="Franklin Return", tag="Upper Wacker return cuts over Monroe and up Franklin",
         michigan=[], west="monroe_franklin", east=False,
         steps=["Upper S Wacker Dr ↑ (to Monroe)", "Monroe St →", "Franklin St ↑", "Upper Wacker Dr →"]),
    dict(id="c", title="Grand Tour", tag="Everything: Loop weave, Franklin/Dearborn ladder and Columbus/Monroe Dr on the lakefront",
         michigan=["monroe", "jackson"], west="ladder", east=True,
         steps=["Michigan Ave ↓", "Madison St ←", "Wabash Ave ↓", "Monroe St →", "Michigan Ave ↓", "Adams St ←",
                "Wabash Ave ↓", "Jackson Blvd →", "Jackson Dr → (to Columbus)", "Columbus Dr ↑", "Monroe Dr →",
                "Lake Shore Dr ↑", "Upper S Wacker Dr ↑ (to Monroe)", "Monroe St →", "Franklin St ↑", "Washington St →",
                "Dearborn St ↑", "Upper Wacker Dr →"]),
    dict(id="d", title="Light Touch", tag="One Michigan jog (Madison-Wabash-Monroe) plus the Franklin return",
         michigan=["monroe"], west="monroe_franklin", east=False,
         steps=["Michigan Ave ↓", "Madison St ←", "Wabash Ave ↓", "Monroe St →", "Michigan Ave ↓ (to Jackson Dr)",
                "Upper S Wacker Dr ↑ (to Monroe)", "Monroe St →", "Franklin St ↑", "Upper Wacker Dr →"]),
    dict(id="e", title="Compact", tag="Shorter lap: Lake Shore Dr exits at Monroe Dr, Columbus Dr drops to Lower Wacker, and the game-only Wacker turnaround becomes a hairpin at Monroe St",
         kind="compact", start="jackson", turn_y=-100,
         steps=["Michigan Ave ↓", "Jackson Dr →", "Lake Shore Dr ↑ (short)", "Monroe Dr ←", "Columbus Dr ↑ (drops to Lower Wacker)",
                "Lower Wacker Dr ←", "S Lower Wacker ↓ (to Washington)", "Hairpin turnaround (game only)", "Upper S Wacker Dr ↑",
                "Upper Wacker Dr →", "Michigan Ave ↓"]),
    dict(id="f", title="Sprint", tag="Shortest: Michigan Ave to Monroe Dr, Columbus Dr to Lower Wacker, short Wacker hairpin. Drops Jackson Dr and Lake Shore Dr",
         kind="compact", start="monroe", turn_y=-100,
         steps=["Michigan Ave ↓ (to Monroe)", "Monroe Dr →", "Columbus Dr ↑ (drops to Lower Wacker)", "Lower Wacker Dr ←",
                "S Lower Wacker ↓ (to Washington)", "Hairpin turnaround (game only)", "Upper S Wacker Dr ↑", "Upper Wacker Dr →",
                "Michigan Ave ↓"]),
    dict(id="g", title="Sprint Plus", tag="Sprint that keeps Michigan Ave to Jackson Dr, then Columbus Dr north to Lower Wacker. Drops Lake Shore Dr",
         kind="compact", start="jackson_columbus", turn_y=-100,
         steps=["Michigan Ave ↓ (to Jackson)", "Jackson Dr → (to Columbus)", "Columbus Dr ↑ (drops to Lower Wacker)", "Lower Wacker Dr ←",
                "S Lower Wacker ↓ (to Washington)", "Hairpin turnaround (game only)", "Upper S Wacker Dr ↑", "Upper Wacker Dr →",
                "Michigan Ave ↓"]),
    dict(id="h", title="Express", tag="Every main road and landmark viewpoint kept. Only the two game-only links are tightened: a diagonal harbor link and a Wacker hairpin below the Willis Tower viewpoint",
         kind="express", turn_y=-560,
         steps=["Michigan Ave ↓", "Jackson Dr →", "Lake Shore Dr ↑ (to Navy Pier view)", "Diagonal harbor link (game only)",
                "Lower Wacker Dr ←", "S Lower Wacker ↓ (past Willis Tower view)", "Hairpin turnaround (game only)",
                "Upper S Wacker Dr ↑", "Upper Wacker Dr →", "Michigan Ave ↓"]),
]


def turn_angle(a, b, c):
    v1, v2 = (b[0] - a[0], b[1] - a[1]), (c[0] - b[0], c[1] - b[1])
    n1, n2 = math.hypot(*v1), math.hypot(*v2)
    if n1 < 1e-6 or n2 < 1e-6:
        return 0.0
    return math.degrees(math.acos(max(-1.0, min(1.0, (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)))))


def _sample(pts, step=20.0):
    out, n = [], len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        k = max(1, int(math.dist(a, b) // step))
        out += [(a[0] + (b[0] - a[0]) * t / k, a[1] + (b[1] - a[1]) * t / k) for t in range(k)]
    return out


def _off(samples, pts, tol=25.0):
    """Metres of `samples` (20 m spacing) farther than `tol` from the closed polyline `pts`."""
    n, far = len(pts), 0
    for s in samples:
        best = 1e18
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            dx, dy = x2 - x1, y2 - y1
            t = 0 if dx == dy == 0 else max(0, min(1, ((s[0] - x1) * dx + (s[1] - y1) * dy) / (dx * dx + dy * dy)))
            best = min(best, math.hypot(s[0] - x1 - t * dx, s[1] - y1 - t * dy))
        far += best > tol
    return far * 20


def stats(points):
    pts = [xy(p[0], p[1]) for p in points]
    n = len(pts)
    length = sum(math.dist(pts[i], pts[(i + 1) % n]) for i in range(n))
    angles = [turn_angle(pts[i - 1], pts[i], pts[(i + 1) % n]) for i in range(n)]
    blocks = [math.dist(pts[i], pts[(i + 1) % n]) for i in range(n)]
    base = [xy(p[0], p[1]) for p in BASE["points"]]
    longest = 0.0
    run = 0.0
    start = next((i for i in range(n) if angles[i] >= 12), 0)
    for k in range(n):
        i = (start + k) % n
        run += blocks[i]
        if angles[(i + 1) % n] >= 12:
            longest, run = max(longest, run), 0.0
    return dict(
        longest_straight_m=round(longest),
        right_angles=sum(1 for a in angles if 75 <= a <= 105),
        new_m=round(_off(_sample(pts), base)),
        dropped_m=round(_off(_sample(base), pts)),
        length_m=round(length),
        corners_35=sum(1 for a in angles if a >= 35),
        corners_75=sum(1 for a in angles if a >= 75),
        shortest_block_m=round(min(blocks)),
    )


def tidy(chain, gap=45.0):
    """Drop interior points that sit within `gap` metres of the previous kept point (carriageway jogs)."""
    out = [chain[0]]
    for n in chain[1:-1]:
        if math.dist(P[n], P[out[-1]]) >= gap and math.dist(P[n], P[chain[-1]]) >= gap:
            out.append(n)
    return out + [chain[-1]]


def ll(x, y):
    return LAT0 + y / 110574.0, LON0 + x / 82860.0


def build_compact(d):
    """Shorter lap: real roads Michigan -> (Jackson Dr, Lake Shore Dr) -> Monroe Dr -> Columbus Dr -> Lower Wacker,
    then the authored lower Wacker run, a game-only hairpin turnaround, and the authored upper deck home."""
    base = BASE["points"]
    if d["start"] == "jackson":
        a = junction("Michigan Avenue", "Jackson Drive", (10, -719))
        allow = "Jackson Drive|DuSable|Lake Shore|Monroe Drive"
    elif d["start"] == "jackson_columbus":
        a = junction("Michigan Avenue", "Jackson Drive", (10, -719))
        allow = "Jackson Drive|Columbus"
    else:
        a = junction("Michigan Avenue", "Monroe Drive", (0, -440))
        allow = "Monroe Drive"
    mc = junction("Columbus", "Monroe Drive", (300, -430))
    end = min(
        (n for n, l in ADJ.items() if any(matches(w, "East Lower Wacker Drive") for _, _, w, _ in l)),
        key=lambda n: math.dist(P[n], (168, 378)),
    )
    r1, r2 = route(a, mc, allow), route(mc, end, "Columbus|East Lower Wacker Drive")
    if r1 is None or r2 is None:
        raise RuntimeError("no legal compact route")
    used = [w for w in r1[1] + r2[1]]
    c1, c2 = tidy(simplify(r1[0])), tidy(simplify(r2[0]))
    pts = [list(base[0])]
    for n in c1:
        pts.append(row(n, 8))
    # Columbus Dr descends from the 8 m street level to the 0 m lower deck along its own length.
    total = sum(math.dist(P[x], P[y]) for x, y in zip(r2[0], r2[0][1:]))
    run = 0.0
    prev = c2[0]
    for n in c2[1:-1]:
        run += math.dist(P[prev], P[n])
        prev = n
        pts.append(row(n, round(8 * max(0.0, 1 - run / total), 1)))
    pts += [list(p) for p in base[13:22]]
    y = d["turn_y"]
    for x_, y_, h in ((-1036, y, 0), (-880, y + 80, 4), (-1036, y + 160, 8)):
        lat, lon = ll(x_, y_)
        pts.append([round(lat, 6), round(lon, 6), h, "Wacker turnaround (game only)"])
    pts += [list(p) for p in base[28:]]
    return pts, sorted(set(used))


def build_express(d):
    """Every main road and landmark viewpoint of route.json kept; only the two game-only links are tightened:
    the harbor connector becomes one diagonal from the Navy Pier view point to the Lower Wacker portal, and the south
    connector becomes a hairpin just below the Willis Tower viewpoint instead of a loop out to Van Buren."""
    pts = [list(p) for p in BASE["points"]]
    y = d["turn_y"]
    hairpin = []
    for x_, y_, h in ((-1036, y, 0), (-880, y + 80, 4), (-1036, y + 160, 8)):
        lat, lon = ll(x_, y_)
        hairpin.append([round(lat, 6), round(lon, 6), h, "Wacker turnaround (game only)"])
    # Baseline 23..26 (south connector: down to Van Buren, east, ramp, back west) -> hairpin. Do the later edit first.
    pts[23:27] = hairpin
    # Baseline 9..10 (harbor connector corner and ramp) dropped: Navy Pier view (8) runs diagonally into the portal (11).
    pts[9:11] = []
    return pts, []


def build(d):
    if d.get("kind") == "express":
        return build_express(d)
    if d.get("kind") == "compact":
        return build_compact(d)
    pts = [list(p) for p in BASE["points"]]
    ways = []
    # Work from the end of the loop backwards so baseline indices stay valid.
    if d["west"]:
        legs = west_monroe_franklin() if d["west"] == "monroe_franklin" else west_ladder()
        # baseline 27..30 (Upper Wacker north, bend, first riverfront point) are replaced; 26 portal stays.
        first = 27
        if d["west"] == "ladder":
            legs = [west_monroe_franklin()[0]] + legs
        pts, w = splice(pts, first, 30, legs)
        ways += w
    if d["east"]:
        # baseline 3 (Lakefront turn) and 4 (LSD at Monroe Dr) are replaced by the real Monroe Dr junction.
        pts, w = splice(pts, 3, 4, east_columbus())
        ways += w
    if d["michigan"]:
        legs = michigan_weave(d["michigan"])
        # Full weave ends on Jackson Blvd at Michigan (= baseline 2); a Monroe-only jog rejoins Michigan first.
        pts, w = splice(pts, 1, 2 if "jackson" in d["michigan"] else 1, legs)
        ways += w
    return pts, sorted(set(ways))


def main():
    os.makedirs(OUT, exist_ok=True)
    summary = dict(
        origin=BASE["origin"],
        baseline=dict(points=BASE["points"], **stats(BASE["points"])),
        drafts=[],
        osm_roads=[],
    )
    for d in DRAFTS:
        pts, used = build(d)
        st = stats(pts)
        real = sorted({name(w) for w in used})
        doc = {
            "origin": BASE["origin"],
            "description": f"DRAFT {d['id'].upper()} - {d['title']}: {d['tag']}. Detours follow real OSM streets "
            "(one-way directions respected); the harbor and south connectors are the same game-only links as route.json. "
            "Heights are authored.",
            "landmarks": BASE["landmarks"],
            "draft": dict(id=d["id"], title=d["title"], streets=real, osm_way_ids=used, **st),
            "points": pts,
        }
        with open(os.path.join(OUT, f"route-{d['id']}.json"), "w") as f:
            json.dump(doc, f, indent=1)
        summary["drafts"].append(dict(id=d["id"], title=d["title"], tag=d["tag"], steps=d["steps"], streets=real, points=pts, **st))
        print(d["id"], d["title"], st, len(pts), "points;", len(used), "ways")
    # Background street network (real OSM) for the map, clipped to the loop area.
    for wid, t in WAYS.items():
        e = ELS[wid]
        if t["highway"] in ("service",):
            continue
        g = [[round(p["lat"], 5), round(p["lon"], 5)] for p in e["geometry"]]
        summary["osm_roads"].append(dict(n=name(wid), h=t["highway"], l=t.get("layer", "0"), g=g))
    tmpl = os.path.join(HERE, "drafts_viewer.tmpl.html")
    if os.path.exists(tmpl):
        with open(tmpl) as f:
            html = f.read().replace("/*DATA*/null", json.dumps(summary, separators=(",", ":"), ensure_ascii=False))
        with open(os.path.join(OUT, "index.html"), "w") as f:
            f.write(html)
    print("baseline", summary["baseline"]["length_m"], "m", summary["baseline"]["corners_35"], "corners >=35deg")


if __name__ == "__main__":
    main()
