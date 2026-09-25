# Nürburgring Nordschleife Groundwork (acquired 2026-09-23 / 2026-09-24)

This directory contains reproducible geometry and elevation data for:
- Section 1: `trackgen/nordschleife_s1.gd` (`centreline.json`, `dem.raw`, `terrain.json`)
- Full Lap: `trackgen/nordschleife.gd` (`centreline_full.json`, `dem_full.raw`, `terrain_full.json`)

## Geometry: OpenStreetMap
Copyright OpenStreetMap contributors, available under [ODbL 1.0](licenses/ODbL-1.0.txt).
- Section 1 spans from T13 (50.33771 N, 6.95108 E) to Aremberg exit plus return road (9057.5 m total).
- The Full Lap spans the complete ~20.8 km Nordschleife circuit (20782.8 m) from T13 back to T13 through all 33 named corners.

## Elevation: Rhineland-Palatinate LVermGeo (DGM1)
Attribution: **© GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]**
Licence: [Datenlizenz Deutschland – Namensnennung – Version 2.0](licenses/dl-de-by-2.0.txt).

56 tiles of 1 m LiDAR DGM1 (UTM Zone 32, E 351..358, N 5577..5583) were acquired from the
official GeoShop RLP open data service. Road elevations along the full circuit were sampled directly
from the 1 m LiDAR DEM with a 3-sample median filter and Gaussian smoothing (sigma 4.0 samples / ~20 m).
Road crossfall banking and tarmac widths were surveyed directly from DEM cross-sections.

Surrounding terrain is exported as a 5 m grid in:
- Section 1: `dem.raw` (761 × 841, 2,560,004 bytes)
- Full Lap: `dem_full.raw` (1306 × 1045, 5459080 bytes) referenced to start line elevation 619.38 m.

## Kerbs

`kerbs.json` traces 13 individual continuous painted or ribbed runs. Boundaries are traced to 2 m from the 5 m crop ticks.

| Corner | Side | Length | Type |
|---|---|---:|---|
| Sabine-Schmitz-Kurve | right | 40 m | flat |
| Sabine-Schmitz-Kurve | left | 40 m | flat |
| Hatzenbogen | right | 138 m | flat |
| Hatzenbach 2 | left | 30 m | flat |
| Hatzenbach 3 | left | 40 m | flat |
| Hatzenbach 3 | right | 40 m | ribbed |
| Hatzenbach 4 | left | 50 m | flat |
| Hocheichen | left | 70 m | flat |
| Hocheichen | right | 80 m | ribbed |
| Hocheichen exit | right | 30 m | flat |
| Flugplatz–Flugplatz exit | left | 250 m | ribbed |
| Flugplatz | right | 130 m | flat |
| Schwedenkreuz | left | 138 m | flat |

S1 imagery often shows only a white edge line or canopy shadow; entries are limited to visible painted or ribbed strips. No distinctly raised sausage kerb was identifiable. The count remains below the 20–40 estimate because most other bends lack visible painted kerbs in this photo set.
