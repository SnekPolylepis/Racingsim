# Prompt: build the Chicago "Route I" layout as a variant in Racing Sim

You are working in the Racing Sim repo (Godot 4.6.2, GDScript, Windows/macOS racing game; everything under `godot/`).
Read `CLAUDE.md`, `AGENTS.md`, `godot/docs/LLM-GUIDE.md` first. Edit specific functions; do not rewrite whole files.

## Goal
Add a new Chicago circuit variant that uses the "Route I" layout below, selectable alongside the existing
"Chicago — River & Lake" track. Keep the original `route.json` track working and unchanged.

## What Route I is
Same circuit as the current Chicago route (same Lake Shore Dr, Navy Pier view, harbor connector, Lower Wacker, south
connector, upper Wacker river run, same landmarks and city geometry) with these real-street changes, all on
OpenStreetMap roads in their legal one-way direction:
1. Michigan Ave southbound becomes a block-by-block weave: Michigan -> W Madison -> S Wabash -> E Monroe -> S Michigan ->
   W Adams -> S Wabash -> E Jackson Blvd -> Jackson Dr (140 m blocks).
2. East side: Jackson Dr east to Columbus Dr, north on Columbus Dr, east on Monroe Dr onto Lake Shore Dr
   (skips the Jackson Dr / Lake Shore Dr corner).
3. West/upper return: from the Upper Wacker portal north on S Wacker Dr to Monroe St, east on Monroe to Franklin St, north on
   Franklin to Washington St, east on Washington to State St, north on State St to Upper Wacker Dr, then the existing
   Upper Wacker river bends to Michigan Ave. (Replaces the upper S Wacker run and the first part of the riverfront.)
Totals: about 8.96 km, 26 corners of 35 degrees or more. The harbor connector and south connector are game-only links, as before.

## Data (same schema as `godot/trackgen/data/chicago/route.json`; [lat, lon, height_m, label])
Local frame in `trackgen/chicago.gd` `world()`: x = (lon + 87.6244) * 82860, z = (41.8848 - lat) * 111320. Closed loop (last point connects to first).
```
[41.8848, -87.6244, 8, "Michigan Avenue"],
[41.882115, -87.624508, 8, "Michigan Ave & Madison St"],
[41.882079, -87.626192, 8, "Madison St & Wabash Ave"],
[41.880802, -87.626161, 8, "Monroe St & Wabash Ave"],
[41.880835, -87.624471, 8, "Michigan Ave & Monroe St"],
[41.879556, -87.624444, 8, "Michigan Ave & Adams St"],
[41.879529, -87.62613, 8, "Adams St & Wabash Ave"],
[41.878262, -87.626099, 8, "Jackson Blvd & Wabash Ave"],
[41.878294, -87.624413, 8, "Michigan Ave & Jackson Blvd"],
[41.878341, -87.62071, 8, "Jackson Dr & Columbus Dr"],
[41.880877, -87.620794, 8, "Columbus Dr & Monroe Dr"],
[41.880924, -87.617244, 8, "DuSable Lake Shore Dr & Monroe Dr"],
[41.8823, -87.6168, 8, "Lake Shore Drive"],
[41.8834, -87.6155, 9, "Lake Shore Drive"],
[41.8841, -87.6141, 11, "Lake Shore Drive"],
[41.8862, -87.6139, 13, "Navy Pier view"],
[41.8876, -87.6139, 13, "Harbor connector"],
[41.8877, -87.6155, 5, "Harbor connector ramp"],
[41.88765, -87.6175, 0, "Lower Wacker portal"],
[41.88791, -87.62075, 0, "Lower Wacker"],
[41.8882, -87.6224, 0, "Lower Wacker"],
[41.88825, -87.6245, 0, "Lower Michigan crossing"],
[41.88802, -87.6257, 0, "Lower Wacker"],
[41.88742, -87.62621, 0, "Lower Wacker river bend west"],
[41.88709, -87.6266, 0, "Lower Wacker river bend"],
[41.8869, -87.6273, 0, "Lower Wacker"],
[41.8869, -87.6348, 0, "Lower Wacker west"],
[41.8864, -87.6361, 0, "Lower Wacker bend"],
[41.88575, -87.6369, 0, "Lower Wacker south"],
[41.8819, -87.6369, 0, "Lower Wacker south"],
[41.877, -87.6369, 0, "South connector"],
[41.877, -87.6345, 0, "South connector"],
[41.878, -87.6345, 4, "South connector ramp"],
[41.878, -87.6369, 8, "Upper Wacker portal"],
[41.880628, -87.636998, 8, "Wacker Dr & Monroe St"],
[41.88065, -87.635307, 8, "Franklin St & Monroe St"],
[41.883239, -87.635376, 8, "Franklin St & Washington St"],
[41.883248, -87.627866, 8, "State St & Washington St"],
[41.885755, -87.627936, 8, "Lake St & State St"],
[41.886817, -87.627892, 8, "Upper Wacker Dr & State St"],
[41.88715, -87.62633, 8, "Upper Wacker river bend west"],
[41.88768, -87.62586, 8, "Upper Wacker river bend"],
[41.88817, -87.62536, 8, "Upper Wacker river bend east"],
[41.88823, -87.62496, 8, "Upper Wacker Michigan approach"],
[41.88825, -87.6245, 8, "Michigan turn"],
[41.8873, -87.6244, 8, "Michigan Avenue"],
```
Source file in the repo: `godot/trackgen/data/chicago/drafts/route-i.json` (also has `landmarks`, `origin`, and a `draft` block). Re-generate with
`python3 godot/trackgen/data/chicago/build_drafts.py` (stdlib only; draft id `i`). Do not hand-edit coordinates; change `build_drafts.py` if the layout must change.

## Tasks
1. Registration: find how the `chicago` track is registered (grep `chicago` in `scripts/game.gd`, `scripts/front_end.gd`,
   `scripts/proving/track_drive.gd`, `tests/v2/*.gd`, `tools/gates.json`). Add a sibling track id (for example `chicago_grid`,
   label "Chicago — Loop Grid") that builds from `route-i.json`. Prefer parameterising `trackgen/chicago.gd`
   (`DATA`, `CORNERS`, cache key) over copying the 1000-line file.
2. `CORNERS` (named corners by point index) must be remapped for the new point list. Current names -> Route I indices:
   Jackson Turn 8, Lakefront Turn 11, Lake Shore Drive 12, Navy Pier View 15, Harbor Connector 16, Lower Wacker Portal 18,
   Michigan Crossing 21, River Bend 24, Wacker West Bend 27, South Connector 30, Upper Wacker Portal 33, Upper River Bend 41,
   Michigan Turn 44. "Willis Tower View" and "Upper Wacker Bend" had points that Route I removes: add a point on S Wacker Dr
   between indices 33 and 34 (around lat 41.8795, lon -87.6370, height 8) for Willis Tower View, and drop or re-place the bend.
3. Cache: bump or key `CACHE_REVISION` so the variant's cached TrackAsset does not collide with the original.
4. Records: lap records are keyed by track geometry identity. Give the variant its own identity, and record fresh baselines with
   `tests/v2/laps.gd -- --track=<id> --record` (all cars and handling modes) into `docs/rebuild/laps-v2-baseline.json`. Do not touch the
   original Chicago baselines.
5. Export: every runtime-read file must be in `export_presets.cfg` `include_filter` and in `check_exported_v2_assets()`. Add
   `trackgen/data/chicago/drafts/route-i.json` (or copy it to a runtime path). Do not export `osm-*.json`, `pois.json` or `index.html`.
6. Geometry checks (from CLAUDE.md): road width 16 m, RoadPath bank change under 0.20 deg/m, tapered under-road terrain drop,
   max grade under 10% (Route I peaks at 3.8%), no surface queries outside `_physics_process`.
7. Likely trouble spots to inspect with `tests/v2/chicago.gd` and `tests/visual/clip_scan.gd --track=<id>`, and the
   windowed screenshot test: the 90-degree corners at 140 m blocks (fillet is 55 m max, `route_curve()`), clearance against
   buildings in `city.json` along Madison/Wabash/Monroe/Adams and Washington/State, the State St / Upper Wacker junction (block
   after the turn is about 120 m), and parked cars / street walls / lamps generated along the new road.
8. Preserve everything else: scenery, landmarks, night details, water, bridges. Do not delete or reformat `tracks/`, `setups/`, `ghosts/`.

## Verify (from `godot/`; Windows shown, macOS binary is `tools/Godot.app/Contents/MacOS/Godot`)
```
tools/Godot.exe --headless --path . --script scripts/game.gd --check-only
gdformat -l 110 scripts tests
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All -Features
```
Also run `tests/v2/chicago.gd` and `tests/v2/laps.gd -- --track=<id>` for the new track, then drive it
(`-- --v2-track=<id>`) and report anything that clips, floats, or looks wrong. State plainly what you could not run.

## Known unknowns (not verified by the author)
- Route I has never been loaded in Godot; geometry tests have not run on it.
- OSM geometry came from Overpass on 2026-09-28; the Lake Shore Dr -> Monroe Dr exit is taken from the OSM road graph without a ramp survey.
- Building overlap along the new streets is unchecked.
