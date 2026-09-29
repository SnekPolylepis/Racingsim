# Circuit de Monaco (MON-01)

The Grand Prix lap on the real streets, built offline by `trackgen/monaco.gd` from `city.json`.

## Pipeline (run in this folder, Python 3 standard library only)

1. `build_route.py` chains the lap's OpenStreetMap ways in race order (`osm-roads.json`) into
   `centreline.json`: 3.32 km against the official 3.337 km.
2. `dem_sample.py <Copernicus_DSM_COG_10_N43_00_E007_00_DEM.tif>` decodes the Copernicus GLO-30 tile
   around Monaco into `dem.json` (the tile itself is not kept).
3. `build_profile.py` reads road height as the DSM's low envelope (the DSM includes buildings), bridges
   the tunnel between its portals, smooths over 120 m and limits grade to 12 % -> `profile.json`.
   Harbour 2-6 m, Sainte-Devote 5.5 m, peak ~50 m before Casino Square, Mirabeau 40 m, Portier 14 m.
4. `build_city.py` writes `city.json`: the 3 m road with heights (no global smoothing, so the Nouvelle
   Chicane and Swimming Pool jinks keep the OSM raceway shape; only node kinks under 6.5 m radius are relaxed,
   below which the inside barrier folds over the road), an 8 m ground grid (level with the road
   out to 12 m), 3,900 OSM buildings (heights from OSM tags, else measured from the DSM), trees, parks, piers.

## References (not distributed)

- Layout: Wikimedia Commons "Monte Carlo Formula 1 track map with streets.svg" (corner numbering, chicanes).
- Tunnel and exit: Commons "Circuit de Monaco - Tunnel (54776971893)", "- Entrance of the tunnel
  (54777070030)", "- Sortie du Tunnel (54783799505)": flat concrete ceiling, tiled inner wall with a lamp strip,
  open bays on the sea side, armco throughout, masonry retaining walls at the exit.

## Known limits

- The DSM is 30 m: the total climb reads ~49 m against the ~42 m usually quoted; corner heights are
  within a few metres. No LiDAR is openly available for Monaco.
- Road widths and kerbs are authored per corner from the published layout, not surveyed.
- Buildings are extruded footprints with a shared facade shader; no landmark models (Casino, Hotel de Paris).

## Sources and licences

- Streets, buildings, trees, parks, piers: (c) OpenStreetMap contributors, ODbL 1.0
  (`osm-roads.json`, `osm-circuit.json`, `osm-buildings.json`, `osm-nature.json`, via overpass-api.de, 2026-09-29).
- Elevation: Copernicus DEM GLO-30, (c) DLR e.V. 2010-2014 and (c) Airbus Defence and Space GmbH 2014-2018,
  provided under COPERNICUS by the European Union and ESA; all rights reserved. Free use licence:
  https://spacedata.copernicus.eu/documents/20123/121286/CSCDA_ESA_Mission-specific+Annex_31_Oct_22.pdf
  (tile from the AWS open-data registry, copernicus-dem-30m).
