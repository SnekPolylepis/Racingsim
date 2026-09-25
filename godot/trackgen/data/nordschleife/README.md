# Nürburgring Nordschleife Section 1 groundwork (acquired 2026-09-23)

This directory contains the reproducible geometry and elevation data for
`trackgen/nordschleife_s1.gd`.

## Geometry: OpenStreetMap
Copyright OpenStreetMap contributors, available under [ODbL 1.0](licenses/ODbL-1.0.txt).
Section 1 spans from the start of the Nordschleife at T13 (50.33771 N, 6.95108 E)
through Sabine-Schmitz-Kurve, Hatzenbogen, Hatzenbach, Hocheichen, Quiddelbacher Höhe,
Flugplatz, and Schwedenkreuz to Aremberg exit (~4.16 km of surveyed centreline), plus a
sculpted return road closing the loop for testing (9057.5 m total).

## Elevation: Rhineland-Palatinate LVermGeo (DGM1)
Attribution: **© GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]**
Licence: [Datenlizenz Deutschland – Namensnennung – Version 2.0](licenses/dl-de-by-2.0.txt).

20 tiles of 1 m LiDAR DGM1 (UTM Zone 32, E 351..354, N 5577..5581) were acquired from the
official GeoShop RLP open data service. Road elevations along Section 1 were sampled directly
from the 1 m LiDAR DEM with a 3-sample median filter and Gaussian smoothing (sigma 1.5 samples).
Road crossfall banking (ranging from +6.9° at Aremberg apex to -5.6° at Hatzenbogen) and tarmac
widths (8.5 to 11.8 m) were surveyed directly from DEM cross-sections.

Surrounding terrain is exported as a 5 m grid in `dem.raw` (761 columns × 841 rows,
2560004 bytes) referenced to start line elevation 619.38 m.

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
