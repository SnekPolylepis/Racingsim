# Native data and persistence contracts

## Console presentation settings and completed laps

Additional recognized settings are `output_mode` (0 clean progressive, 1 interlaced), `crt_filter` (boolean), `framebuffer_colour` (0 24-bit, 1 RGB555), `screen_aspect` (0 4:3, 1 16:9), and `ui_mode` (0 Authentic, 1 Sharp). Defaults are progressive, no CRT filter, 24-bit, 16:9 and Authentic UI. These cosmetic choices are excluded from record identity. Frontend paint/rim choices and last-lap replay are session presentation state; existing setup/track/ghost schemas are unchanged.

Completed ghost sample arrays are immutable and shared by best-lap and last-lap replay consumers. Starting a lap assigns a new recording array; never clear or append to a completed one. `record_writer.gd` serializes record/sector saves on one worker with a private Storage instance, preserving submission order and temporary-file replacement. The destination identity is resolved when `load_record()` selects the configuration, not recomputed on the finish-line physics tick. Load/import/clear and shutdown flush earlier jobs. Sector jobs copy their three mutable times; worker code never accesses Nodes or live gameplay state.

## Paths and ownership

**The v2 game (normal launch).**
- **Settings:** `user://v2/settings.json`, with the same keys as the legacy settings. Unknown or
  mistyped keys keep their defaults.
- **Racing data:** Storage roots at `user://v2`, with `setups/`, `ghosts/` and `records/` beneath it.
  Records are schema-2 ghosts plus `.sectors.json` (see Ghosts and records).
- **Track bakes:** cached in `user://tracks3d/<id>.scn`. The cache key includes the generator's
  revision (scripts/proving/track_drive.gd), so a changed generator or data file rebuilds it on the
  next load. Deleting the folder is always safe.
- **Test and probe modes:** `--v2-smoke`, `--v2-present`, `--v2-export-check` and the front-end flow
  test use `user://native-tests/v2/`.
- **Separation:** the v2 game never reads or writes the legacy files below, and legacy records do not
  carry over.

**TrackAsset source data** lives in `trackgen/data/<id>/`: centreline, elevation, measured road
profile, licences, and the scripts that rebuild each file from its public source (see that folder's
README).
- **Committed:** only derived data plus the request records.
- **Git-ignored caches:** raw responses and downloaded images.
- **Exports:** they ship what the generator reads at runtime, via the export presets'
  `include_filter`. `check_exported_v2_assets()` in the exported build must list every such file.

**Legacy game** (`--features` and the other legacy modes, until P7-01):

`res://` is the Godot project/package root. Bundled `tracks/`, `data/`, scripts and documentation are resources, not save destinations. `user://` normally resolves on Windows to `%APPDATA%/Godot/app_userdata/Racing Sim/`, and on macOS to `~/Library/Application Support/Godot/app_userdata/Racing Sim/`.

Settings always use local `user://settings.json`. Racing data defaults to `user://` but can be redirected through Circuits → Choose folder. Storage initializes `tracks/`, `setups/`, `ghosts/` and `records/` beneath that selected root. Connecting a folder does not copy browser localStorage or automatically populate it with bundled circuits. Libraries combine protected bundled circuits and saved circuits.

`--features` / `--smoke` isolate settings and racing data under `user://native-tests/`. Do not change that isolation when extending tests. Browser root data folders are user-owned; native bundled copies under `godot/tracks/` are separate files.

## JSON I/O and validation

`read_json()` returns a Variant or null and updates `storage.error`. Validate its type before using fields. `write_json()` writes a sibling `.tmp`, flushes/closes it and renames it over the destination; failure returns false and an error. This avoids exposing a partially written destination in normal operation, but is not a complete power-loss durability guarantee. Parent folders must exist.

`safe_name()` validates filename characters, strips trailing dots/spaces, limits length to 80 and handles Windows reserved basenames. Apply it to user-chosen names. Unknown document fields generally survive track load/save; this is not strict schema-version migration. Validate required values before model construction. The importer allows drafts; drive/save validation is separate.

## Track, schema 1 (legacy JSON circuits, until P7-01)

The v2 game uses TrackAssets (REBUILD-PLAN.md §5.3, ARCHITECTURE.md). This schema describes the legacy
circuits under `godot/tracks/` and the root `tracks/` user folder, read only by the legacy path.

```json
{
  "schema": 1, "name": "Example", "savedAt": "2026-09-18T00:00:00Z",
  "points": [
    {"x": 0, "y": 0, "w": 12, "z": 0, "bank": 0},
    {"x": 100, "y": 0, "w": 12, "z": 3, "bank": 2},
    {"x": 50, "y": 100, "w": 12, "z": 0, "bank": 0}
  ],
  "curbAuto": true, "curbOverride": {"1": "off"},
  "paint": {"4,9": 2},
  "objects": [{"type": "cone", "x": 30, "y": 20, "ox": 30, "oy": 20}],
  "startS": 0, "gridS": null
}
```

| Field | Contract |
|---|---|
| `points` | Closed loop in driving order; numeric x/y/w; missing z/bank default zero |
| `w` | Full road width in meters, validated 4–40 |
| `z`, `bank` | Meters and degrees respectively; editor ranges ±60 m and ±20° |
| `curbOverride` | String segment index → `on` or `off`; absent means automatic |
| `paint` | String `floor(x/2),floor(y/2)` grid key; 1 grass, 2 gravel, 3 tarmac runoff (native; the frozen browser build treats 3 as grass) |
| `objects` | Cone x/y; wall or tire x1/y1/x2/y2. Cone ox/oy are rest positions |
| `startS`, `gridS` | Arc distances in meters, nullable; default grid is start minus 10 m |
| `presentation` | Optional theme/source/description, two curb colors and named x/y corner labels |

Structural validation currently caps points at 2,000 and x/y magnitude at 100,000 m. A structurally accepted draft may still lack three points or a start line. Geometry validation checks those before driving/saving. Optional presentation metadata is expected to follow the bundled format; current structural validation is not exhaustive for every optional field. Do not describe it as a hardened arbitrary-file parser.

Optional per-point `profile` is the road cross-section: an array of `[u, drop]` pairs where `u` is the fraction of half width (negative to the driver's left, so -1 is the left edge) and `drop` is metres below the banked plane. Pairs are resampled onto a fixed 33-station grid and interpolated between control points. An absent or all-zero profile is a flat cross-section and costs nothing. Only the ribbon model in `scripts/track3d.gd` reads it; `scripts/track.gd` ignores the key, so profiled circuits still load in the plan-view model as flat road. The bundled Nordschleife carries profiles on both Karussells, written by `trackgen/karussell.gd`.

Optional `presentation.scenery` = `{"trees": density multiplier (1 = default), "pines": conifer share 0–1, "treeline": metres from the road edge where woods start, "treeHeight": size multiplier, "clearings": [{"anchor": corner label name or "s": metres, "radius": metres, "side": "left"|"right"|"outside"|"inside"|"any"}]}`; presentation only.

Optional `presentation.landmarks` = array of landmark definitions built trackside by `circuit_world.gd`; presentation only. Schema: `{"kind": string ("grandstand"|"spectator_bank"|"building"|"bridge"|"footbridge"|"marshal_post"|"hedge"), "anchor": corner label name, {"x", "y"} or arc station s, "side": "left"|"right"|"outside"|"inside", "offset": metres from road edge (default 12), "length": metres along circuit, "scale": float multiplier (default 1.0), "variant": string (e.g. "mill", "tower", "monument", "gantry", "stone", "footbridge"), "name": string, "s_offset": float}`. Objects are purely decorative and carry no collision.

`autoBarriers` (bool, default true) enables the derived trackside armco/tire walls; when true it is omitted from record identity so older records still match. Runtime cone `vx`, `vy`, `hit` are removed by `to_json()`, which saves cones at ox/oy and adds schema/timestamp to a copy. Derived samples/checkpoints/spatial data are never serialized. Width/bank interpolation and elevation queries are rebuilt on load. Paint cannot change asphalt grip because road/curb tests precede paint lookup.

## Presets and setups

Preset keys are `roadster`, `gt`, `f296gt3`. `data/cars.json` contains fixed constants and a default `setup` for each. The garage definition rows are `[group,key,label,min,max,step,unit]`; currently 42 legacy fields grouped into Tires, Suspension, Aero, Brakes, Diff, Gearing and Aids. Presentation-only preset keys (no physics or record effect): `body` (`roadster`, `coupe` or `gt3`, the lofted body style in `visuals.gd::BODIES`), `color`, `rim`, `caliper` (hex colours), `wing` (bool) and `num` (livery number). Missing keys fall back to defaults.

Chassis keys read only by the 6-DOF `CarBody` (the planar CarModel ignores them): `treadWidth` (m, tyre footprint), `unsprungMass` (`[front, rear]` kg per corner; default 3 % of `mass`), `tyreRate` (radial tyre stiffness, N/m; default 260000) and `bodyClearance` (m, the chassis contact box's sill height above static ground; default 0.1). They are fixed constants, not garage fields.

Setup document: `{"schema":1,"savedAt":"...","car":"roadster","setup":{"tireMu":1.38,...}}`. Import verifies the car and values, starts with that preset's defaults, applies recognized fields within their bounds, switches car, resets and loads its record. Missing fields retain preset defaults. Optional `tcsLevel` and `asmLevel` (0–10) add numbered aids without replacing the legacy fields; old TC intensity maps to its equivalent level (fractional legacy values are preserved), old ABS remains unchanged, and missing ASM imports as off. Exports include effective levels and synchronized tcOn/tcIntensity. Garage changes also reset the run when applied. Native export remains compatible with the browser's schema-1 structure.

## Trackside props

`data/props.json` (read by `scripts/props/prop_body.gd`) defines the knock-over prop kinds a TrackAsset's `Props/` may name (`cone`, `bollard`, `marker_board`); a new kind is a new entry, no code. Frame: origin at the centre of the base on the ground, +Y up, +X forward. Keys: `shape` (`frustum` with `height` m and `radius` `[bottom, top]` m, or `box` with `size` `[x, y, z]` m, base on the ground), `mass` kg, `cg` (height of the centre of mass above the base, m; default half the height), optional `inertia` (`[x, y, z]` kg m² principal, about the centre of mass; default a uniform solid), `restitution` and `friction` (against the ground and walls; car contacts use `PropBody.CAR_FRICTION`), `drag_area` (drag coefficient × frontal area, m²), and presentation-only `name` and `color`. Changing a kind changes how props behave on every track that uses it but not record identity (props are off the racing line).

## Ghosts and records

Sector file: `records/<record hash>.sectors.json` = `{"schema":1,"savedAt":"...","best":[s1,s2,s3]}` (seconds, 0 = none yet). It is written whenever a new best sector is set and deleted by Clear best lap.

Ghost document: `{"schema":1,"savedAt":"...","track":"Example.json","car":"roadster","time":68.225,"samples":[[t,x,y,heading,steerAngle,lapDistance],...]}`. Time is seconds, heading/steering radians, distance meters since the start. The recorder samples about 30 times/second. Validation requires positive finite time, at least two samples, numeric values and nondecreasing sample times. It does not prove a lap's competitive legitimacy.

TrackAsset ghost document (P4-02, schema 2): `{"schema":2,"savedAt":"...","track":"<TrackAsset record_key(), e.g. proving_ground@v1>","car":"f296gt3","configuration":"...","time":60.425,"samples":[[t,x,y,z,qx,qy,qz,qw,lapDistance],...]}`: the 5.4 pose (world position in metres, body rotation quaternion) and metres since the start line, about 30 samples/second. `validate_ghost` requires 9 numbers per sample when `schema` is 2. Schema-1 ghosts are never loaded on TrackAssets (plan D4: old ghosts are dropped).

Native `configuration` is an optional extra string identifying the native record filename. Browser-compatible ghosts live at `ghosts/<safe track name>.ghost.json`; native records live at `records/<SHA256>.json`.

`record_path()` hashes JSON containing the track document, effective setup (including resolved aid levels), car key, handling model, wear setting and off-track/contact rules. Name and savedAt are removed; cone transient fields are removed and positions restored. Other track metadata remains part of this identity, so presentation changes can also select a different record. This is a hash of the implementation's serialization, not a canonical semantic JSON hash.

On the TrackAsset path, the same configuration hash uses `TrackAsset.record_key()` (`id@v<version>`) in place of the legacy track document, plus effective setup, car, handling, wear and off-track/contact rules. Schema-2 records and their `.sectors.json` companions live under the v2 storage root (`user://v2` by default). V2 settings live at `user://v2/settings.json`. Generated scenes are cached separately at `user://tracks3d/<id>.scn` with a generator-source revision; the cache is recreated when the source changes.

On the legacy path, loading first tries the current native record, then the per-track legacy ghost. Valid legacy data must match the car if supplied and the configuration if supplied. Unconfigured browser ghosts are adopted automatically only in Simulation for matching cars; Simcade requires explicit import. Original setup/rules still cannot be proved for unconfigured ghosts. Explicit import assigns a ghost to the current configuration. Saving updates the native record and updates the exchange ghost only if it is absent/invalid/slower. Clear best removes the current native record and that track's exchange ghost, not all configurations' native records.

## Settings and input

The authoritative keys/types/defaults are `game.gd::DEFAULT_SETTINGS`. They include display/camera, simulation aids/rules, input response (including `steer_assist_kb` / `steer_assist_pad`, speed-sensitive steering strength 0–2 where 1 halves lock at 14 m/s), volume/mute and data folder. Keyboard bindings are action → array of physical keycodes. Controller bindings are action → `{axis, sign?}` or `{button}` using Godot indices, not browser Gamepad indices. Keyboard steering uses separate left/right actions; controller steering is signed. Triggers use positive travel. Runtime held keys, ramp state and controller edge state are not save documents.

Changing handling model or wear/off-track/contact in Settings resets the current run and loads the corresponding record. Other settings update their consumer immediately. Key/pad mappings are added to the settings document on save. Never reuse browser numeric keycodes/gamepad button indices without explicit translation.
