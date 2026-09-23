import json, math

loop = json.load(open('loop.json'))
E = json.load(open('ele.json'))
d = json.load(open('nordschleife.json'))
nodes = {e['id']: (e['lat'], e['lon']) for e in d['elements'] if e['type'] == 'node'}
ways = [e for e in d['elements'] if e['type'] == 'way']

lat0 = sum(p[0] for p in loop) / len(loop)
lon0 = sum(p[1] for p in loop) / len(loop)
kx = 111320 * math.cos(math.radians(lat0))
ky = 110540

# Official length of Nordschleife: 20,832 m
# Compute chord polyline length of raw loop
raw_dist = sum(
    math.hypot((loop[i][1] - loop[i-1][1]) * kx, (loop[i][0] - loop[i-1][0]) * ky)
    for i in range(len(loop))
)
SCALE = 20832.0 / raw_dist
print(f"Raw polyline length: {raw_dist:.1f} m -> Scale factor: {SCALE:.5f} (target 20,832 m)")

P = lambda p: ((p[1] - lon0) * kx * SCALE, -(p[0] - lat0) * ky * SCALE)

# Elevation: take the lower of EU-DEM and SRTM at each 20 m sample,
# 5-sample circular median to drop spikes, then Gaussian smoothing (sigma 3 samples = 60 m).
za = E['z']['eudem25m']
zb = E['z']['srtm30m']
z = [min(a, b) for a, b in zip(za, zb)]
n = len(z)
z = [sorted(z[(i + j) % n] for j in range(-2, 3))[2] for i in range(n)]
w_gauss = [math.exp(-k * k / (2 * 3.0**2)) for k in range(-9, 10)]
sum_w = sum(w_gauss)
zs = [sum(w_gauss[j + 9] * z[(i + j) % n] for j in range(-9, 10)) / sum_w for i in range(n)]
print(f"Raw elevation range: {min(z):.1f} to {max(z):.1f} m | Smoothed: {min(zs):.1f} to {max(zs):.1f} m")

mid = (min(zs) + max(zs)) / 2
ep = [P(p) for p in E['pts']]

earc = [0.0]
for i in range(1, n):
    earc.append(earc[-1] + math.dist(ep[i - 1], ep[i]))
elen = earc[-1] + math.dist(ep[-1], ep[0])

def z_at_point(x, y):
    i = min(range(n), key=lambda k: (ep[k][0] - x)**2 + (ep[k][1] - y)**2)
    j = (i + 1) % n
    a = ep[i]
    b = ep[j]
    dx = b[0] - a[0]
    dy = b[1] - a[1]
    L2 = dx * dx + dy * dy or 1
    t = max(0, min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / L2))
    return zs[i] + (zs[j] - zs[i]) * t - mid

# Resample outline to 4 m first
pts = [P(p) for p in loop]
ev = [pts[0]]
carry = 0.0
for i in range(1, len(pts) + 1):
    a = pts[i - 1]
    b = pts[i % len(pts)]
    seg = math.dist(a, b)
    t = 4.0 - carry
    while t <= seg:
        ev.append((a[0] + (b[0] - a[0]) * t / seg, a[1] + (b[1] - a[1]) * t / seg))
        t += 4.0
    carry = seg - (t - 4.0)

# Resample evenly at ~16 m intervals for uniform Catmull-Rom spline interpolation
cum = [0.0]
for i in range(1, len(ev)):
    cum.append(cum[-1] + math.dist(ev[i - 1], ev[i]))
Ltot = cum[-1] + math.dist(ev[-1], ev[0])
nres = round(Ltot / 16.0)
merged = []
j = 0
for k in range(nres):
    s0 = k * Ltot / nres
    while j + 1 < len(ev) and cum[j + 1] <= s0:
        j += 1
    a = ev[j]
    b = ev[(j + 1) % len(ev)]
    seglen = (cum[j + 1] if j + 1 < len(ev) else Ltot) - cum[j]
    t = (s0 - cum[j]) / max(seglen, 1e-6)
    merged.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))

print(f"Resampled to {len(merged)} control points (average knot spacing: {Ltot / len(merged):.2f} m).")

# Map each control point to nearest way name
wayname = {}
for wy in ways:
    for nd in wy['nodes']:
        if nd in nodes:
            wayname.setdefault(tuple(nodes[nd]), wy.get('tags', {}).get('name'))

names = []
for p in merged:
    ll = min(loop, key=lambda q: (P(q)[0] - p[0])**2 + (P(q)[1] - p[1])**2)
    names.append(wayname.get(tuple(ll)))

# Widths: Döttinger Höhe / Antoniusbuche / Tiergarten is 11.5 m, elsewhere 9.5 m
wide_sections = {'Döttinger Höhe', 'Antoniusbuche', 'Tiergarten', 'Hohenrain', 'T13'}
width = [11.5 if names[i] in wide_sections else 9.5 for i in range(len(merged))]

# Vertical curvature relaxation: limit KMAX <= 1/800 m^-1 (effective radius >= 400 m)
zc = [z_at_point(*p) for p in merged]
nz = len(zc)
arcs = [0.0]
for i in range(1, nz):
    arcs.append(arcs[-1] + math.dist(merged[i - 1], merged[i]))
LL = arcs[-1] + math.dist(merged[-1], merged[0])
H = 5.0
ng = int(LL / H)

def interp(s):
    s %= LL
    j = max(k for k in range(nz) if arcs[k] <= s)
    a2 = arcs[j]
    b2 = arcs[j + 1] if j + 1 < nz else LL
    return zc[j] + (zc[(j + 1) % nz] - zc[j]) * (s - a2) / max(b2 - a2, 1e-6)

g = [interp(k * LL / ng) for k in range(ng)]
h = LL / ng
KMAX = 1.0 / 800.0

for it in range(25000):
    worst = 0.0
    for i in range(ng):
        m_val = (g[i - 1] + g[(i + 1) % ng]) / 2.0
        kv = (g[i - 1] - 2.0 * g[i] + g[(i + 1) % ng]) / (h * h)
        if abs(kv) > KMAX:
            worst = max(worst, abs(kv))
            g[i] = m_val - math.copysign(KMAX * h * h / 2.0, kv)
    if worst < KMAX * 1.02:
        break

zs_old = zc[:]
zc = [g[int(round(arcs[i] / h)) % ng] for i in range(nz)]

# Control point level relaxation
seg = [math.dist(merged[i], merged[(i + 1) % nz]) for i in range(nz)]
for it2 in range(25000):
    worst = 0.0
    for i in range(nz):
        h0 = seg[i - 1]
        h1 = seg[i]
        a = zc[i - 1]
        c = zc[(i + 1) % nz]
        lin = (a * h1 + c * h0) / (h0 + h1)
        kv = 2.0 * ((c - zc[i]) / h1 - (zc[i] - a) / h0) / (h0 + h1)
        if abs(kv) > KMAX:
            worst = max(worst, abs(kv))
            zc[i] = lin - math.copysign(KMAX * h0 * h1 / 2.0, kv)
    if worst < KMAX * 1.02:
        break

print(f"Vertical relax iterations: {it}, control clip iterations: {it2}, max dz from DEM: {max(abs(zc[i] - zs_old[i]) for i in range(nz)):.2f} m")

points = [
    {
        "x": round(p[0], 1),
        "y": round(p[1], 1),
        "w": width[i],
        "z": round(zc[i], 2),
        "bank": 0.0
    }
    for i, p in enumerate(merged)
]

# Start line: positioned on the straight approaching T13 (before Sabine-Schmitz-Kurve)
arc = [0.0]
for i in range(1, len(merged)):
    arc.append(arc[-1] + math.dist(merged[i - 1], merged[i]))
L = arc[-1] + math.dist(merged[-1], merged[0])

# Find index of T13 or Hohenrain exit
t13_indices = [i for i, nm in enumerate(names) if nm == 'T13']
if t13_indices:
    start = arc[t13_indices[0]]
else:
    start = 0.0

# Extract corner labels from OSM way names
corner_map = [
    ('T13', 'T13'),
    ('Sabine-Schmitz-Kurve', 'Sabine-Schmitz-Kurve'),
    ('Hatzenbach', 'Hatzenbach'),
    ('Hocheichen', 'Hocheichen'),
    ('Quiddelbacher Höhe', 'Quiddelbacher Höhe'),
    ('Flugplatz', 'Flugplatz'),
    ('Schwedenkreuz', 'Schwedenkreuz'),
    ('Aremberg', 'Aremberg'),
    ('Fuchsröhre', 'Fuchsröhre'),
    ('Adenauer Forst', 'Adenauer Forst'),
    ('Metzgesfeld', 'Metzgesfeld'),
    ('Kallenhard', 'Kallenhard'),
    ('Wehrseifen', 'Wehrseifen'),
    ('Breidscheid', 'Breidscheid'),
    ('Ex-Mühle', 'Exmühle'),
    ('Bergwerk', 'Bergwerk'),
    ('Kesselchen', 'Kesselchen'),
    ('Mutkurve', 'Mutkurve'),
    ('Klostertal', 'Klostertal'),
    ('Steilstrecke', 'Steilstrecke'),
    ('Caracciola-Karussell', 'Karussell'),
    ('Hohe Acht', 'Hohe Acht'),
    ('Hedwigshöhe', 'Hedwigshöhe'),
    ('Wippermann', 'Wippermann'),
    ('Eschbach', 'Eschbach'),
    ('Brünnchen', 'Brünnchen'),
    ('Eiskurve', 'Eiskurve'),
    ('Pflanzgarten', 'Pflanzgarten'),
    ('Sprunghügel', 'Sprunghügel'),
    ('Stefan-Bellof-S', 'Stefan-Bellof-S'),
    ('Schwalbenschwanz', 'Schwalbenschwanz'),
    ('Kleines Karussell', 'Mini-Karussell'),
    ('Galgenkopf', 'Galgenkopf'),
    ('Döttinger Höhe', 'Döttinger Höhe'),
    ('Antoniusbuche', 'Antoniusbuche'),
    ('Tiergarten', 'Tiergarten'),
    ('Hohenrain', 'Hohenrain')
]

labels = []
loop_tuples = {tuple(q) for q in loop}
for label, osm_name in corner_map:
    cands = [
        wy for wy in ways
        if wy.get('tags', {}).get('name') == osm_name
        and any(tuple(nodes.get(nd, (0, 0))) in loop_tuples for nd in wy['nodes'])
    ]
    if cands:
        wy = max(cands, key=lambda q: len(q['nodes']))
        mid_node = wy['nodes'][len(wy['nodes']) // 2]
        c = P(nodes[mid_node])
        labels.append({"name": label, "x": round(c[0], 1), "y": round(c[1], 1)})

print(f"Generated {len(labels)} corner labels.")

pres = {
    "curbColors": ["#df3330", "#ffffff"],
    "description": f"Complete 20.83 km Nordschleife from OSM survey data with real elevation ({max(zs)-min(zs):.0f} m range). Widths, curbs, runoff and scenery are approximations.",
    "labels": labels,
    "scenery": {
        "pines": 0.65,
        "treeHeight": 1.6,
        "treeline": 18.0,
        "trees": 5.2
    },
    "source": "OpenStreetMap raceway centreline (© OpenStreetMap contributors, ODbL); elevation: lower of EU-DEM 25 m and SRTM 30 m via OpenTopoData, median + 60 m smoothing, effective vertical radius ~400 m",
    "theme": "nordschleife"
}

doc = {
    "schema": 1,
    "name": "Nürburgring Nordschleife",
    "savedAt": None,
    "points": points,
    "curbAuto": True,
    "curbOverride": {},
    "paint": {},
    "objects": [],
    "autoBarriers": True,
    "startS": round(start, 1),
    "gridS": None,
    "presentation": pres
}

json.dump(doc, open('nordschleife_geometry.json', 'w'), indent=2)
print(f"Saved nordschleife_geometry.json with {len(points)} points, polyline {round(L)} m, startS: {round(start, 1)} m.")
