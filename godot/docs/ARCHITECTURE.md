# Native architecture and invariants

The game runs on the rebuild (REBUILD-PLAN.md): a 6-DOF `CarBody` on authored 3-D `TrackAsset`s, in
Godot-native world space. The older planar game (CarModel on JSON tracks, the retro UI) was deleted
in P7-01 (2026-09-23); see the last section.

## Ownership and lifecycle

`game.gd` is the root. On the v2 path `setup_v2()`:

1. Loads `data/cars.json` and `data/setup_fields.json`, then settings from `user://v2/settings.json`
   (test and probe modes use `user://native-tests/v2/`). Unknown or mistyped keys keep their defaults.
   Storage is initialized at `user://v2` unless the settings name another folder. The legacy game's
   files are never read or written.
2. Builds the `CarBody` for the selected preset (handling model, grip assist, wear, auto clutch from
   settings), the `RecordWriter`, the environment (`setup_environment()`, `apply_time_of_day()`) and
   graphics quality.
3. Builds the presentation: the car and ghost models (`visuals.make_car`), a CanvasLayer holding the
   instruments (HUD) and the front end, audio (`audio.gd`), and skid marks.
4. Opens the front end at "main". Normal play builds no track until the player picks one. The smoke,
   presentation and export probes load the proving ground immediately.

The front end (`front_end.gd`, v2 pages: main → car → circuit → drive) calls:

- `change_v2_car(key)`: replaces the CarBody and its models, keeping the track, and reloads the
  matching record.
- `load_v2_track(id)`: `TrackDrive.load_asset(id)` (scripts/proving/track_drive.gd) builds the asset
  from its generator (`trackgen/<id>.gd`) or loads the bake cached in `user://tracks3d/<id>.scn`. The
  cache is keyed on the generator's revision, so a generator or data change rebuilds it. It then
  validates the asset, swaps it in, and rebuilds the per-track services: `TrackSurface`
  (`asset.surface()`), `WallQuery`, `PropSet.from_asset()`. It places the car on grid slot 1, loads the
  record and rebuilds the minimap.
- `start_v2_drive()`: fresh attempt on the grid, props reset, session timing kept.
- `return_v2_menu()` (Esc while driving): flushes records and returns to the menu.

Vehicle, track and race code have no scene dependencies beyond the asset, so every system runs
headless in tests.

## Fixed simulation order

`project.godot` runs 240 physics ticks per second (at most 32 per rendered frame). `physics_v2(dt)`,
while not in a menu or paused:

1. Controls → `car.input` (or the bot in `--v2-present`); reset and shift events.
2. `prev_pose = snapshot_v2()`, then `car.step(dt, surface, automatic)`.
3. `WallContact.step(car, walls)`; then `PropSet.step(dt, [car])`. A velocity change over 0.15 m/s
   in one tick plays an impact sound.
4. `race.update_asset(car, track, dt)`: on a new valid best, save the record; save dirty sectors.
5. Telemetry sample, simulation clock, skid marks every 35 ms.
6. One ray down under the camera, cached as `camera_ground` for the camera's ground clamp. Surface
   queries only work inside a physics frame (P3-00).

`render_v2()` (every frame):

- poses the car from `blend_v2(prev_pose, snapshot_v2(), interpolation fraction)` (position lerp,
  rotation slerp, per-wheel steer, spin and compression);
- lights the brakes from the pedal inputs;
- poses the ghost from `race.ghost_xform()`;
- then runs `update_camera()`, `sound.update()` and the instruments redraw.

Render delta never reaches the solver. A reset clears `prev_pose`, so a teleport never smears.

## Coordinates and units

SI throughout (metres, kg, s, N, rad inside the solver). World space is Godot-native (§5.1): +Y up,
lap direction whatever the asset authors, track coordinates within ±5 km of the origin.

- **CarBody body frame:** +X forward, +Y up, +Z right. Angular velocity is in the body frame
  (+y yaws left).
- **Wheels:** always `[FL, FR, RL, RR]`.
- **Precision:** world position and velocity are 64-bit scalars (`pos_x/y/z`, `vel_x/y/z`); `pos`
  and `vel` are Vector3 views.
- **Legacy mirror:** every tick CarBody copies the old plan-view fields (`x = pos_x`, `y = pos_z`,
  `h`, `vx`, `vy`, `r`, `speed`, `vbx`, `vby`, `ax`, `ay`), so the shared aids, drivetrain and HUD
  read what they always read.
- **Bank:** a positive bank lowers the right side, for road sections and measured data alike.
- **Surface ids:** the shared SURF table, 0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff. A
  wheel counts as off track on ids of 2 or more.
- **Heights:** `car.z` is not altitude on the new car. Use `pos_y` and each wheel's `roadZ` (its
  contact height).

## Vehicle

`scripts/vehicle/car_body.gd` holds the whole car: state, configuration and the 6-DOF step.
Tyre, drivetrain and aids are the shared modules in `scripts/vehicle/` (P2-01), evaluated in each
contact patch's frame. `step()` does, in order:

- the suspension rays and tyre footprint per wheel;
- spring, damper, bump stop and ARB forces;
- the tyre forces, with the need clamps and static friction;
- drivetrain, aero, body contact;
- semi-implicit integration;
- wheel travel for the compliant, unsprung wheel.

PHYSICS.md summarises the model, and the REBUILD-LOG DONE entries (P2-00 to P2-08, P2-comp) give the
reasoning and measurements.

Wall contact (`scripts/vehicle/wall_contact.gd`) and props (`scripts/props/`) apply impulses after the
step. The bot (`scripts/vehicle/bot_driver.gd`) drives any asset's BotLine for tests and the
presentation run.

## Tracks

A TrackAsset (`scripts/track/track_asset.gd`, contract §5.3) is a scene holding:

- **Road/, Surfaces/:** road meshes and collision on layer 1, each body tagged with its SURF id.
- **Walls/:** barriers on layer 2, tagged with their kind.
- **Other nodes:** TimingLine (lap line, start, sector and checkpoint offsets), Grid/, BotLine, Props/,
  Scenery/ and Lights/.

Assets are built by generators in `trackgen/`, using the road tool (`road_path.gd`, `road_section.gd`,
`road_builder.gd`), terrain (`terrain.gd`), walls and scatter (`wall_path.gd`, `road_scatter.gd`) and
the scenery kit:

- **Proving Ground:** `trackgen/proving_ground.gd`, an invented test circuit.
- **Spa:** `trackgen/spa.gd`, from the data in `trackgen/data/spa/`. OSM centreline, SPW LiDAR
  elevation and banking, widths and kerbs measured from SPW orthophotos. See that folder's README.

Baked scenes are not committed: generators run on first load and the result is cached.

- **Surface queries:** `TrackSurface.contact(origin, direction, max_dist, hint)` (§5.2), a physics ray
  against layer 1. It must be called inside a physics frame.
- **Walls:** `WallQuery` does swept hull tests against layer 2.
- **Timing:** `asset.gates()` returns vertical gate planes, start first, then sectors and checkpoints
  in lap order, each bounded ±15 m sideways and ±3 m vertically. `TrackAsset.crossed()` tests one;
  `project()` resolves lap distance in true 3-D.

## Records and saves

- **Record identity:** `record_path()` on the v2 path hashes the asset's `record_key()`
  (`"<id>@v<version>"`) with the effective setup, car, handling model, wear and the off-track and
  contact rules.
- **Ghosts:** schema-2 documents (DATA-CONTRACTS.md) of 5.4 pose samples recorded by `race.gd`
  `update_asset()`.
- **Sectors:** best sectors live beside each record in `.sectors.json`.
- **Writing:** `RecordWriter` is one serial worker thread. Completed ghost arrays are immutable and
  handed over, and each job carries its destination, so switching car or track never redirects a
  pending write. Reads, imports, deletes and shutdown flush it first.

## Presentation

- **Visuals:** `visuals.gd` `make_car()` returns `{root, body, pivots, spins, brakes, wheel_r}`. The
  v2 path poses `root` from the CG transform minus cgHeight along the body's up, so attitude is free
  in flight.
- **Cameras:** five modes (chase, high chase, bonnet riding with the body, overhead north, overhead
  car). V cycles them.
- **Instruments:** `instruments.gd` works on legacy tracks and assets alike (`on_asset()`). It draws
  timing, sectors, delta, the minimap from `asset.minimap()`, the ghost dot, tyre cards and the
  speedometer; Y toggles telemetry, B debug.
- **Audio:** `audio.gd` reads CarBody's inherited fields: engine bands, gears, tyre slip by surface id,
  and impacts.
- **Skid marks:** a 1600-instance MultiMesh at wheel contact points along the ground normal. On the v2
  path a tyre marks only past its slip peak.
- **Sky:** sky, fog, sun and ambient light come from `apply_time_of_day()`. Night lamps from
  `Lights/` are not wired yet.

## Probe and test modes (v2)

- `--v2-smoke`: headless, 120 ticks, pose and interpolation sanity.
- `--v2-visual-smoke`: the same, windowed.
- `--v2-present`: windowed. The bot drives two proving-ground laps at 3x speed while cameras cycle.
  It checks timing, ghost, minimap and audio, and saves `user://v2-present.png`.
- `--v2-export-check`: in an exported build, verifies that every generator and its data are inside
  the PCK and load.
- `tests/v2/front_end.gd`: the menu flow, the record round trip and returning to the menu.

## Retired legacy code (P7-01)

P7-01a (2026-09-23) deleted the pre-rebuild game: JSON tracks, planar collisions, the old interface and
feature suite. `--features` is an alias for `--v2-present`. P7-01b folded the planar CarModel
(`scripts/car.gd`) into CarBody, moved the surface table to `scripts/surface/surface_table.gd`, and
deleted `track.gd`, `track3d.gd` and `tests/dynamics.gd`. `retro_renderer.gd` and `night_style.gd`
remain for the PS2 look work (Look-2, Look-3).
