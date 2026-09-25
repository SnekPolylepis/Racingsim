# Downtown Chicago roadmap (staged, unintegrated)

Four raw Overpass/OpenStreetMap extracts covering downtown Chicago (the Loop, Streeterville and the
Near North riverfront) — wider than CHI-01's own `trackgen/data/chicago/osm-roads.json`, which only
pulled the named streets the race route itself uses (Wacker, Michigan Avenue, Lake Shore Drive, Jackson
Drive, Monroe Street, Franklin Street). These four files add the full surrounding street grid, every
building footprint, the river/lake/park geometry and named landmarks, for anyone building out the city
*around* the circuit rather than just the circuit itself (background blocks, skyline massing, crowd/prop
placement, a wider drivable area, etc.).

Bounding box for all four: `41.873,-87.648,41.908,-87.598` (south,west,north,east) — the Loop, River
North, Streeterville and Navy Pier, with margin around Willis Tower (SW corner) and Navy Pier (NE
corner). Fetched 2026-09-25 from `https://overpass.openstreetmap.fr/api/interpreter` (the mirror CHI-01
used, `overpass.kumi.systems`, was unreachable this session — timed out — and the canonical
`overpass-api.de` returned 406 to this container's outbound proxy; `overpass.openstreetmap.fr` and
`overpass.osm.ch` both worked).

## Files and queries

**`downtown-roads.json`** (4,793 elements) — the full road network, not just the named route streets:
```overpass
[out:json][timeout:90];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|living_street|service|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"]
    (41.873,-87.648,41.908,-87.598);
);
out geom;
```

**`downtown-buildings.json`** (4,613 elements) — every tagged building footprint (way and relation),
with whatever `building:levels`/`height`/`name` tags OSM carries for it:
```overpass
[out:json][timeout:120];
(
  way["building"](41.873,-87.648,41.908,-87.598);
  relation["building"](41.873,-87.648,41.908,-87.598);
);
out geom;
```

**`downtown-water-leisure.json`** (3,603 elements) — the Chicago River, Lake Michigan, parks and
bridges:
```overpass
[out:json][timeout:90];
(
  way["natural"="water"](41.873,-87.648,41.908,-87.598);
  way["waterway"="riverbank"](41.873,-87.648,41.908,-87.598);
  relation["natural"="water"](41.873,-87.648,41.908,-87.598);
  way["leisure"="park"](41.873,-87.648,41.908,-87.598);
  way["landuse"="grass"](41.873,-87.648,41.908,-87.598);
  way["leisure"="garden"](41.873,-87.648,41.908,-87.598);
  way["bridge"="yes"](41.873,-87.648,41.908,-87.598);
);
out geom;
```

**`downtown-landmarks.json`** (242 elements) — named POIs/artwork plus explicit name matches for the
five CHI-01-required landmarks and a few more:
```overpass
[out:json][timeout:60];
(
  node["tourism"="attraction"](41.873,-87.648,41.908,-87.598);
  node["tourism"="artwork"](41.873,-87.648,41.908,-87.598);
  way["tourism"="artwork"](41.873,-87.648,41.908,-87.598);
  node["amenity"="theatre"](41.873,-87.648,41.908,-87.598);
  node["leisure"="amusement_arcade"](41.873,-87.648,41.908,-87.598);
  way["building"~"skyscraper|tower"](41.873,-87.648,41.908,-87.598);
  node["name"~"Willis Tower|Navy Pier|Cloud Gate|Millennium Park|Buckingham Fountain|Trump Tower|Marina City",i](41.873,-87.648,41.908,-87.598);
  way["name"~"Willis Tower|Navy Pier|Cloud Gate|Millennium Park|Buckingham Fountain|Trump Tower|Marina City",i](41.873,-87.648,41.908,-87.598);
);
out geom;
```

## License

Raw Overpass API JSON, same terms CHI-01's own `osm-roads.json` already carries: **ODbL 1.0**
(https://opendatacommons.org/licenses/odbl/1-0/), © OpenStreetMap contributors
(https://www.openstreetmap.org/copyright). Not baked, not simplified, not attached to any generator or
export — raw reference data only, same as CHI-01's own `osm-roads.json`/`route.json` split (`route.json`
there is "a simplified, edited derivative" of the raw pull; nothing here has had that editing pass yet).

## Using this

Not integrated — `trackgen/chicago.gd` is CHI-01's, untouched here. This is reference/raw material for a
follow-up task: e.g. block out background buildings from `downtown-buildings.json`'s footprints with the
Kenney city-kit models in `../models/`, or extend the drivable area/city context beyond the closed race
lap. `trackgen/chicago.gd`'s own `world()` helper (line 23) converts lon/lat to local metres as
`Vector3((lon + 87.6244) * 82860.0, height, (41.8848 - lat) * 111320.0)` — a flat equirectangular
projection about 41.8848 N, 87.6244 W, with 82860 m/degree longitude (111320 × cos(41.8848°)) and
111320 m/degree latitude. Apply the same formula to anything pulled from these four files to line it up
with CHI-01's circuit in the same local frame.
