import json, math, time, urllib.request, urllib.parse, sys, ssl

loop = json.load(open('loop.json'))

def m(a, b):
    la = math.radians((a[0] + b[0]) / 2)
    return math.hypot((a[1] - b[1]) * 111320 * math.cos(la), (a[0] - b[0]) * 110540)

pts = [loop[0]]
acc = 0
for i in range(1, len(loop) + 1):
    a = loop[i - 1]
    b = loop[i % len(loop)]
    seg = m(a, b)
    t = 20 - acc
    while t <= seg:
        pts.append((a[0] + (b[0] - a[0]) * t / seg, a[1] + (b[1] - a[1]) * t / seg))
        t += 20
    acc = seg - (t - 20)

print(f"Resampled to {len(pts)} elevation sample points at 20 m intervals.")

datasets = sys.argv[1:] if len(sys.argv) > 1 else ['eudem25m', 'srtm30m']
out = {}
ctx = ssl._create_unverified_context()

for ds in datasets:
    zs = []
    print(f"Fetching {ds} from OpenTopoData...")
    for k in range(0, len(pts), 100):
        chunk = pts[k:k+100]
        loc = '|'.join('%.6f,%.6f' % tuple(p) for p in chunk)
        url = 'https://api.opentopodata.org/v1/' + ds
        data = urllib.parse.urlencode({'locations': loc}).encode()
        req = urllib.request.Request(url, data=data, headers={'User-Agent': 'RacingSim-track-builder/1.0'})
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
                r = json.loads(resp.read().decode('utf-8'))
                elevs = [x.get('elevation') for x in r.get('results', [])]
                zs.extend(elevs)
                print(f"  {ds}: fetched {len(zs)}/{len(pts)} points (latest: {elevs[-1]} m)...")
        except Exception as e:
            print(f"Error fetching chunk {k}: {e}")
            raise
        time.sleep(1.2)
    out[ds] = zs
    valid_zs = [z for z in zs if z is not None]
    print(f"{ds} range: min={min(valid_zs):.1f} m, max={max(valid_zs):.1f} m, total={len(zs)}")

json.dump({'pts': pts, 'z': out}, open('ele.json', 'w'))
print("Saved ele.json successfully.")
