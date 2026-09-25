# Spa v0 source data (acquired 2026-09-23)

This directory contains the reproducible geometry and elevation inputs for
`trackgen/spa.gd`. Runtime terrain is a **20 m sample grid from SPW's 0.5 m LiDAR
DTM**, not a full-resolution 0.5 m or 1 m terrain mesh. The road uses independently
queried LiDAR heights about every 20 m. No synthetic published-profile fallback,
SRTM, Copernicus or legacy game physics was used.

## Polish (P6-01, 2026-09-23): measured widths, kerbs and banking

- `fetch_sections.py` samples the same SPW MNT 0.5 m ground model across the road at every
  centreline point, from 14 m left to 14 m right every 0.5 m (39,843 points). The result is
  `cross-sections.json`. The raw responses (`raw-lidar/xsec/`, 5.5 MB) are a local cache that the
  script rebuilds; they are not committed.
- `fetch_ortho.py` exports 70 SPW **Orthophotos 2023 Été** tiles (CC BY 4.0, © SPW) along the
  circuit: 140 m, 0.25 m/px, Web Mercator, requested with `f=image` because the service's output
  directory refuses downloads. Requests are in `ortho-tiles.json`; the images live in the git-ignored
  `ortho-cache/`.
- `analyse_road.py` writes `road-profile.json`: per station, half-widths to the inside of the white
  track-limit lines (or kerb or grass), kerb width and colours beyond them, and the crossfall bank.
  The bank is a line fit to the LiDAR within ±3.5 m (positive lowers the right side). Edges were found
  at 97.4 % (left) and 99.1 % (right) of stations; gaps take the median of ±2 neighbours.
  Half-widths: median 5.0 / 4.8 m (range 3.8–10.2). Bank: −3.8° to +4.4°, changing at most
  0.11°/m.
- Paved runoff could not be measured from the photos: forest shadow, buildings and paddock all
  classify as "not grass". Runoffs and verges stay authored in `spa.gd`.

## Geometry: OpenStreetMap

Copyright OpenStreetMap contributors. The raw OSM extracts and the derived
centreline database are available under [ODbL 1.0](licenses/ODbL-1.0.txt).
[Attribution and copyright](https://www.openstreetmap.org/copyright).

The requested Overpass query was attempted on overpass-api.de, overpass.kumi.systems
and overpass.private.coffee. The first returned HTTP 406 / dispatcher timeout;
the two mirrors timed out. A direct way-ID Overpass request also returned 406.
Consequently **fresh way and node JSON were downloaded from the official OSM
API**, preserving the requested OSM source while changing its transport.
`osm-ways.json` and `osm-nodes.json` are those unmodified response bodies.
Exact URLs and the attempted query are recorded in `osm-query.json`.

Way IDs were discovered from the repository's existing OSM extract, then all ways
and nodes were downloaded afresh. The named circuit is split into connected
`highway=raceway` ways named for its corners rather than a single way named
Circuit de Spa-Francorchamps. Pit lanes, karting and the Moto layout were excluded.
The surviving one-way graph forms one closed GP loop in racing direction.

Projection is equirectangular using Earth mean radius 6,371,008.8 m, centred at
50.43696855 N, 5.968565 E. X points east; Z points south; Y points up. The first
point is on the start straight 170 m before the OSM La Source midpoint, at
50.44488296 N, 5.96443240 E. This is an approximate timing-line placement.
The coordinates have **not** been stretched to force an exact nominal lap length.

## Elevation: Service public de Wallonie

Attribution: **Service public de Wallonie (SPW) - Relief de la Wallonie - Modèle
Numérique de Terrain (MNT) 2021-2022 (2024-01-23)**, © SPW 2021-2022.
[Dataset and licence](https://geoportail.wallonie.be/catalogue/a004e570-99d6-4fe5-b83d-49b774409278.html),
[CC BY 4.0](licenses/CC-BY-4.0.txt). The licence was rechecked on acquisition day.

The preferred provincial 1 m GeoTIFF ZIP is 9.5 GB; its HTTP header request timed
out. The official service instead exposes the same campaign's **0.5 m** DTM:
[MapServer layer 0](https://geoservices.wallonie.be/arcgis/rest/services/RELIEF/WALLONIE_MNT_2021_2022/MapServer/0).
`lidar-layer-metadata.json` preserves its metadata. This is a classified ground
model, excluding bridges, buildings, vegetation and vehicles. Native coordinates
are Belgian Lambert 2008 (EPSG:3812); heights use DNG (EPSG:5710). Requests specify
WGS84 lon/lat (EPSG:4326), and the service performs the coordinate transformation.

The MapServer `identify` operation accepts multipoints and returns numeric
`Stretch.Pixel Value` attributes. These are raw elevation values in metres,
not colour/shading intensities. `raw-lidar/road.json` preserves all 350 road
samples; `terrain-000.json` through `terrain-051.json` preserve 20,625 grid
samples. Requests use tolerance 0 and a 100000 × 100000 display over the recorded
extent to request the finest source sampling, with 400 points per terrain batch.
Request coordinates/parameters are recorded or reconstructable from
`lidar-road-query.json`, `lidar-terrain-query.json` and `build_data.py`.
Six independently requested point values exactly matched their positions in the
multipoint batches; see `sample-verification.json`.

The terrain crop spans local X -1240..1240 m and Z -1640..1640 m, at least 600 m
beyond the circuit bounds. `dem.raw` is 125 columns × 165 rows of little-endian
IEEE 754 float32 values, row-major west to east then north to south (82,500 bytes).
Spacing is 20 m in both axes. `terrain.json` is its header. Heights are relative
to 418.562076128 m DNG, the smoothed road at the start line. There are no no-data,
NaN or infinite samples. Terrain's absolute range is 338.866241..537.760010 m.

Modifications: local projection, crop, 20 m terrain sampling, relative-height
offset; a three-sample circular median and a Gaussian with sigma one sample
(~20 m) on the road; a finite-difference curvature cap and verification of the
periodic C2 elevation spline used by RoadBuilder. The curvature cap required no
large flattening. Maximum height change from the LiDAR road samples is 0.456 m.
The generator may interpolate terrain to a denser mesh; that adds no survey detail.
Road banking, widths, kerbs, runoff and scenery are authoring approximations.
The 2021-22 survey predates/comprises some circuit reconstruction work; road
crossfall is hand authored, and bridges are not supplied by this terrain model.

## Measurements and reproduction

## Kerbs

`kerbs.json` traces 44 separate painted runs from SPW Orthophotos 2023 Été apex crops (40 m square, 1200 px, 5 m station ticks).

| Corner | Side | Length | Type |
|---|---|---:|---|
| La Source | left | 10 m | flat |
| La Source | left | 10 m | flat |
| La Source | left | 10 m | flat |
| Straight | left | 30 m | flat |
| Eau Rouge | left | 10 m | flat |
| Eau Rouge | left | 10 m | flat |
| Raidillon | left | 10 m | flat |
| Raidillon | left | 20 m | flat |
| Raidillon | left | 40 m | flat |
| Straight | right | 10 m | flat |
| Straight | left | 20 m | flat |
| Les Combes exit | left | 10 m | flat |
| Bruxelles | left | 30 m | flat |
| Bruxelles | left | 10 m | flat |
| Straight | left | 10 m | flat |
| Straight | right | 10 m | flat |
| No Name | right | 10 m | flat |
| No Name | right | 10 m | flat |
| Straight | right | 20 m | flat |
| Straight | right | 20 m | flat |
| Pouhon | right | 10 m | flat |
| Pouhon | right | 20 m | flat |
| Pouhon | right | 20 m | flat |
| Straight | right | 20 m | flat |
| Straight | left | 10 m | flat |
| Fagnes | left | 10 m | flat |
| Stavelot | left | 30 m | flat |
| Paul Frere | right | 10 m | flat |
| Paul Frere | right | 10 m | flat |
| Paul Frere | right | 10 m | flat |
| Paul Frere | right | 10 m | flat |
| Paul Frere | right | 10 m | flat |
| Paul Frere | right | 10 m | flat |
| Straight | right | 10 m | flat |
| Straight | left | 30 m | flat |
| Straight | left | 20 m | flat |
| Straight | left | 10 m | flat |
| Straight | left | 20 m | flat |
| Straight | left | 30 m | flat |
| Straight | left | 10 m | flat |
| Straight | right | 10 m | flat |
| Straight | right | 20 m | flat |
| Bus Stop | left | 10 m | flat |
| Bus Stop exit | left | 30 m | flat |

Widths and boundaries are approximate traces against the 5 m ticks. Entries in canopy shadow are marked low confidence. Top-down imagery does not show enough surface relief to distinguish raised forms everywhere.
