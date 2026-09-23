# Track generation

Offline tools for building bundled circuits from real data. Not exported with the game.

## Spa-Francorchamps (`spa/`)

1. `cycle.py`: reads an Overpass export of `highway=raceway` ways around the circuit (`spa.json`, query in the script header comment below) and finds the directed cycle closest to 7.004 km. Pit lanes, kart and moto layouts are excluded. Writes `loop.json` (lat/lon).
2. `ele.py eudem25m srtm30m`: samples the loop every 20 m and fetches both elevation models from the public OpenTopoData API (1 request/s). Writes `ele.json`.
3. `build.py`: projects to local metres (scaled to the official 7.004 km), resamples the outline to evenly spaced control points every ~16 m (the game's spline interpolates height per segment, so uneven spacing makes vertical kinks), takes the lower of the two elevation models, median-filters and smooths, then limits vertical curvature (effective vertical radius ~400 m), sets widths (14 m on the pit straight, 12 m elsewhere), places the start line 170 m before La Source, labels corners from the OSM way names and writes `spa_new.json` (kept here as `spa_geometry.json`). It reuses curb colours and theme from the previous file (`old_spa.json`).
4. `godot --headless --path . --script trackgen/runoff.gd -- trackgen/spa/spa_geometry.json tracks/Spa-Francorchamps.json` paints runoff and writes the bundled track.

Overpass query used (September 2026):

```
[out:json][timeout:60];(way["highway"="raceway"](50.425,5.955,50.448,6.005););(._;>;);out body;
```

## Nürburgring Nordschleife (`nordschleife/`)

1. `fetch.py`: fetches `highway=raceway` ways and nodes across `(50.315, 6.910, 50.385, 7.025)` from Overpass API. Writes `nordschleife.json`.
2. `cycle.py`: finds the directed closed cycle corresponding to the full ~20.832 km Nordschleife loop (excluding the modern GP track and pit shortcuts). Writes `loop.json`.
3. `ele.py eudem25m srtm30m`: samples the loop every 20 m and fetches EU-DEM 25m and SRTM 30m from OpenTopoData. Writes `ele.json`.
4. `build.py`: projects to local metres (scaled to 20.832 km), resamples to evenly spaced knots every ~16 m (1302 control points), takes the lower of the elevation models, median-filters and smooths, relaxes vertical curvature ($K_{\text{max}} \le 1/800\text{ m}^{-1}$), sets widths (11.5 m on Döttinger Höhe/Antoniusbuche/Tiergarten, 9.5 m elsewhere), places the start line approaching T13, labels 37 iconic corners from OSM way names, and writes `nordschleife_geometry.json`.
5. `godot --headless --path . --script trackgen/runoff.gd -- trackgen/nordschleife/nordschleife_geometry.json tracks/Nurburgring-Nordschleife.json`: generates tarmac/gravel runoff and writes the bundled circuit document.

## Nordschleife post-processing

Run these on the circuit document after `runoff.gd`. Each writes a new file and changes only the fields named.

- `karussell.gd`: adds cross-section `profile`s to both Karussells. It finds each corner from the circuit's own labels, takes the inside from the sign of the curvature, and fades the ditch in over the last quarter of the corner. Caracciola-Karussell comes out a 1.26 m trough with a 37° concrete wall; Kleines Karussell is 0.69 m and 22°. Only `profile` changes.
- `jumps.gd`: restores Flugplatz, Sprunghügel and Pflanzgarten, which `build.py`'s ~800 m vertical radius smoothed flat. In the smoothed data they needed 322, 227 and 219 km/h to fly. The tool adds a local Gaussian rise at each existing crest and iterates against the ribbon model until a car without downforce takes off at the target speed (160 / 150 / 150 km/h). Rises are 0.59 to 0.93 m. Only `z` changes.

```
godot --headless --path . --script trackgen/karussell.gd -- <in.json> <out.json>
godot --headless --path . --script trackgen/jumps.gd -- <in.json> <out.json>
```

Depths, rises and takeoff speeds are modelled, not surveyed.

## Licences

- Circuit geometry is derived from OpenStreetMap data, © OpenStreetMap contributors, available under the Open Database Licence (ODbL 1.0, https://opendatacommons.org/licenses/odbl/). `tracks/Spa-Francorchamps.json`, `tracks/Nurburgring-Nordschleife.json`, and intermediate geometry files are derived databases and are likewise available under the ODbL.
- Elevation: EU-DEM v1.1 (Copernicus Land Monitoring Service) and SRTM (NASA, public domain), accessed through OpenTopoData.

Widths, curbs, runoff, barriers and scenery are approximations, not surveyed.

