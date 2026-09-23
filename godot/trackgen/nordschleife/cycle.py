import json, math, sys

sys.setrecursionlimit(30000)

d = json.load(open('nordschleife.json'))
nodes = {e['id']: (e['lat'], e['lon']) for e in d['elements'] if e['type'] == 'node'}
ways = [e for e in d['elements'] if e['type'] == 'way']

skip = {
    'Nürburgring Sprintstrecke', 'Müllenbachschleife', 'Rallycross circuit',
    'Boxengasse', 'Boxengasse an T13', 'Anbindung zum GP Kurs',
    'Variante 24h-Rennen', 'Mercedes-Benz-Tribüne', 'Fahrerlager', 'Pit Lane',
    'Anbindung zur Nordschleife'
}

def dist(a, b):
    la = math.radians((nodes[a][0] + nodes[b][0]) / 2)
    return math.hypot((nodes[a][1] - nodes[b][1]) * 111320 * math.cos(la), (nodes[a][0] - nodes[b][0]) * 110540)

adj = {}
wayof = {}
for w in ways:
    n = w.get('tags', {}).get('name')
    if n in skip or w.get('tags', {}).get('sport') in ['karting', 'rc_car']:
        continue
    ns = w['nodes']
    both = w.get('tags', {}).get('oneway') != 'yes'
    for a, b in zip(ns, ns[1:]):
        adj.setdefault(a, []).append(b)
        wayof[(a, b)] = n
        if both:
            adj.setdefault(b, []).append(a)
            wayof[(b, a)] = n

dot = [w for w in ways if w.get('tags', {}).get('name') == 'Döttinger Höhe']
start = dot[0]['nodes'][0]
best = []

def dfs(u, path, L, seen):
    if L > 22000:
        return
    for v in adj.get(u, []):
        if v == start and L > 18000:
            best.append((L + dist(u, v), path[:]))
            continue
        if v in seen:
            continue
        seen.add(v)
        path.append(v)
        dfs(v, path, L + dist(u, v), seen)
        path.pop()
        seen.discard(v)

print(f"Finding cycle starting at {start}...")
dfs(start, [start], 0, {start})
best.sort(key=lambda c: abs(c[0] - 20832))

print(f"Found {len(best)} cycle(s). Best length: {round(best[0][0])} m, nodes: {len(best[0][1])}")
names = []
for a, b in zip(best[0][1], best[0][1][1:]):
    n = wayof.get((a, b))
    if n and (not names or names[-1] != n):
        names.append(n)
print(f"Corner sequence ({len(names)}):", names)

json.dump([nodes[n] for n in best[0][1]], open('loop.json', 'w'))
print("Wrote loop.json")
