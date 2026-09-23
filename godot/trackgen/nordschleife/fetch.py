import urllib.request, urllib.parse, json, ssl, sys, time, os

OVERPASS_MIRRORS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]

def fetch_osm():
    query = """[out:json][timeout:90];(way["highway"="raceway"](50.315,6.910,50.385,7.025););(._;>;);out body;"""
    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"}
    ctx = ssl._create_unverified_context()
    
    for mirror in OVERPASS_MIRRORS:
        print(f"Trying Overpass mirror: {mirror}...")
        try:
            data = urllib.parse.urlencode({"data": query}).encode("utf-8")
            req = urllib.request.Request(mirror, data=data, headers=headers)
            with urllib.request.urlopen(req, context=ctx, timeout=90) as resp:
                if resp.status == 200:
                    text = resp.read().decode("utf-8")
                    parsed = json.loads(text)
                    elements = parsed.get("elements", [])
                    ways = [e for e in elements if e.get("type") == "way"]
                    nodes = [e for e in elements if e.get("type") == "node"]
                    print(f"Success from {mirror}! Elements: {len(elements)} ({len(ways)} ways, {len(nodes)} nodes)")
                    if len(ways) >= 5:
                        with open("nordschleife.json", "w") as f:
                            f.write(text)
                        return True
        except Exception as e:
            print(f"Mirror {mirror} failed: {e}")
            time.sleep(1)
            
    print("All Overpass mirrors failed.")
    return False

if __name__ == "__main__":
    if not fetch_osm():
        sys.exit(1)
