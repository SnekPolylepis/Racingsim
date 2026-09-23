# Rebuild plan: 3D chassis, authored tracks, no in-game editor

Status: **planning** (written 2026-09-22). This document is the single source of truth for the rebuild. Several AI models (Claude, Gemini, GPT) and the owner work on it in turn. Read **Working protocol** before touching code. The progress record lives in [REBUILD-LOG.md](REBUILD-LOG.md).

Where this plan conflicts with older docs (`LLM-GUIDE.md`, `ARCHITECTURE.md`, `PHYSICS.md`, `DATA-CONTRACTS.md`, `CLAUDE.md`), **this plan wins** for anything inside a rebuild task. Code a phase hasn't reached yet still follows the old docs.

---

## 1. Vision

A racing sim where the car is a real body in 3D space driving on real 3D surfaces, on a small number of hand-built, polished circuits. Less breadth, much more depth.

- **Remove:** the in-game circuit editor, outline import, user-drawn circuits.
- **Replace:** the flat car model (x/y/heading plus heave/pitch/roll corrections) with a full 6-DOF rigid-body chassis. Replace the centreline-plus-width track model with authored 3D road surfaces.
- **Keep:** the tyre model, drivetrain, aids, Simcade layer, retro renderer/PS2 presentation, front end, audio, the Ferrari 296 model, controls, timing/sectors, ghosts and setups. These are good and aren't the bottleneck.

## 2. Why: what's holding the project back

1. **The car is a flat model.** `car.gd` integrates x, y and heading on a plane. Height is a scalar field sampled at one point. Pitch and roll are clamped to ±0.12 rad (~7°) with small-angle suspension (`d = z + pitch*bx + roll*by`). Slopes enter as a gravity-force term, crests as a vertical-curvature term. The Karussell wall (37°), airborne flight (attitude follows the road), overpasses and 3D barriers each needed a special case. Barriers are 2D and ignore height.
2. **The track is a centreline with a width.** Every circuit is `points[] + width + bank + profile`. It's the shape a 2D editor can draw, so it's the only shape the format, renderer, physics and timing understand. Ditches and jumps were added afterwards as patches (`trackgen/karussell.gd`, `trackgen/jumps.gd`).
3. **The source data is too coarse.** Nordschleife/Spa elevation comes from 25–30 m DEMs (EU-DEM, SRTM), smoothed to an ~800 m vertical radius. That scale can't represent the compressions, cambers and crests that give those circuits their character.
4. **The editor locks all of this in.** As long as users can draw circuits, the format has to stay 2D-drawable.

## 3. Decisions

### Locked (owner approved 2026-09-22)

- **D1.** The in-game editor and outline importer are removed.
- **D2.** The car becomes a 6-DOF rigid body. The CLAUDE.md rule "don't replace the custom solver" is withdrawn. The approach below (D6) is a recommendation, not a constraint.
- **D3.** Tracks become authored 3D assets. Quality over quantity.
- **D4.** The old track format and old records/ghosts are not carried forward. User files in root `tracks/`, `setups/`, `ghosts/` are left on disk untouched. The game stops reading root `tracks/`. Setups still load.

### Open: owner to confirm (defaults in bold; work proceeds on the default unless told otherwise)

- **D5. Track authoring tool.** **(a) A `@tool` road plugin inside the Godot editor** vs (b) Blender + glTF. (a) keeps one toolchain and lets code agents build and modify the tool.
- **D6. Dynamics host.** **(A) Our own 6-DOF integrator, with Godot used only for geometry queries** vs (B) a Jolt `RigidBody3D` chassis with our tyre/suspension forces applied each tick.
  - (A) keeps determinism, lets headless tests step manually at full speed, and keeps the semi-implicit "need" clamps exact.
  - (B) gets wall/object collision for free but gives up manual stepping and adds a tick of force lag.
  - Spike task P2-00 confirms (A) before P2-03 commits to it.
  - **P2-00 done 2026-09-22: recommends (A)** (22/22 checks; see the log). Reviewed by GPT-6 Sol (GO). **Owner approved (A) on 2026-09-22; D6 is locked.**
- **D7. First track.** **A short proving-ground circuit (invented, ~2–3 km, with a bowl, crest, compression, off-camber and a ditch) → Spa → Nordschleife.** Monza is optional later.
- **D8. Handling models.** **Keep both Simulation and Simcade.** Simcade gets retuned after P2 because its targets were tuned on the old solver.
- **D9. Coordinates.** **Switch the simulation to Godot-native world space** (see §5.1). Rendering stops doing the `(x,y,h)→(x,h,y)` remap.
- **D10. Elevation data.** **Use 1 m open LiDAR DEMs where they exist.** Verified in P5-01: Rhineland-Palatinate DGM1 + laser point clouds + DOP20 orthophotos (dl-de/by-2.0), and Wallonia MNT 1 m 2021–22 + 2023 orthophotos (CC BY 4.0). Both are free downloads usable commercially with attribution. Both terrain models exclude bridges.

## 4. Target architecture

```
game.gd (orchestration, unchanged role)
 ├─ CarBody        scripts/vehicle/car_body.gd    6-DOF state + integrator
 │   ├─ Suspension scripts/vehicle/suspension.gd  per-corner spring/damper/bump stop/ARB along hardpoint axis
 │   ├─ Tyre       scripts/vehicle/tyre.gd        Pacejka, combined slip, temps, wear, need clamps (math moved, not changed)
 │   ├─ Drivetrain scripts/vehicle/drivetrain.gd  engine, clutch, gearbox, diffs (moved, not changed)
 │   └─ Aids       scripts/vehicle/aids.gd        TC, ABS, ASM, steering assist, Simcade layer
 ├─ Surface (interface)                          contact queries, see §5.2
 │   ├─ TestSurface  scripts/surface/test_surface.gd   analytic: flat, bowl, crest, ditch, wall, ramp
 │   └─ TrackSurface scripts/surface/track_surface.gd  queries a loaded TrackAsset
 ├─ TrackAsset     scripts/track/track_asset.gd   root script of an authored track scene, see §5.3
 ├─ Collisions     scripts/collisions.gd          rewritten: chassis hull vs wall geometry, 3D impulses
 ├─ RaceModel      scripts/race.gd                timing against TrackAsset timing line (3D gates)
 └─ presentation   visuals / ferrari_296 / retro_renderer / front_end / instruments / audio (adapted)
```

The old `track.gd`, `track3d.gd`, `circuit_world.gd`, `editor.gd` and `outline_import.gd` are deleted by the end (tasks in P1 and P7).

## 5. Contracts

**Freeze these before parallel work starts.** Changing a contract is its own task (log it as `CONTRACT` in the log, update this section, notify in the log). Never change one silently inside another task.

### 5.1 Coordinates and units

- SI units. World space is Godot-native: **+Y up**, right-handed, metres.
- Car local frame (matches the existing car meshes): **+X forward, +Y up, +Z right**.
- Wheel order **FL, FR, RL, RR**, always.
- Angular velocity is a `Vector3` in the **body frame**, right-hand rule. Positive `ω.y` is yaw to the **left**. Positive `ω.x` rolls the right side down. Positive `ω.z` pitches the nose up.
- Driver inputs keep their existing sign: `steer > 0` = steer right.
- Tyre `wear` grows from 0. Wheel `ellipse` is utilisation, not µ.
- **Precision (contract change 2026-09-22):** Godot's `Vector2`/`Vector3`/`Quaternion`/`Transform3D` are 32-bit in standard builds; GDScript `float` is 64-bit. Accumulated solver state that can be far from zero, above all **world position, must be stored in 64-bit floats**. At 5 km from the origin a float32 position cannot represent sub-0.5 mm steps (measured: a car drifting at 1 cm/s does not move at all at x = 5 km). Use vectors for relative/local quantities (offsets from the CG, normals, body-frame rates). Surface queries receive a float32 `Vector3`, so a track's query frame must keep coordinates small (P3-00).

### 5.2 Surface query

```gdscript
# Returns {} on no hit.
func contact(origin: Vector3, direction: Vector3, max_dist: float, hint: int) -> Dictionary
# keys: point: Vector3, normal: Vector3 (unit, world), distance: float,
#       surface: int (index into the existing SURF table: tarmac, kerb, grass, gravel, runoff...),
#       hint: int (opaque; pass back next tick for locality)
```

- One ray per wheel, cast from the hardpoint along the chassis −Y, over travel plus tyre radius.
- **Kerb/edge smoothing:** the tyre is not a point. P2-06 adds a footprint filter, e.g. 3–5 rays across the contact patch, normals averaged and height taken as the max. Single-ray contact makes kerbs and seams harsh.
- `TestSurface` is analytic and needs no scene tree. `TrackSurface` may use `PhysicsServer3D` space queries or its own BVH (decided in P3-00).

### 5.3 Track asset (a Godot scene, `godot/tracks3d/<id>/<id>.tscn` or `.scn`)

Implemented in P3-01 (`scripts/track/track_asset.gd`, `track_loader.gd`, `scripts/surface/track_surface.gd`).

```
TrackAsset (Node3D, track_asset.gd) at the origin, identity transform
  exports: id, display_name, version:int, default_time_of_day, lighting (Dictionary)
  Road/        visual meshes (baked by the road tool)
  Surfaces/    StaticBody3D per surface type, metadata "surface" = int SURF index, collision layer 1
  Walls/       StaticBody3D barrier/wall collision, metadata "wall_kind", collision layer 2
  TimingLine   Path3D; its baked curve is the lap line, closed implicitly from the last point back to the
               first (don't repeat the first point). Metadata: start_offset_m, sector_offsets and
               checkpoint_offsets (metres after the start line, strictly increasing)
  Grid/        Marker3D slots in order (pole first); each marker's -Z points down the track
  BotLine      Path3D racing line with target speeds (for tests/bot)
  Scenery/     trees, stands, buildings, landmarks
  Lights/      night-style lamp placements
```

- **Record identity** = `record_key()` = `"<id>@v<version>"` + car/setup/handling (setup and handling as today). Bump `version` whenever the drivable surface or timing changes.
- **Defaults** when metadata is missing: start offset 0, sectors at thirds, a checkpoint every 90 m.
- **Timing gates** are vertical planes perpendicular to the lap line, bounded ±15 m laterally and ±3 m vertically, so a car on another deck does not trigger them. `gates()` returns start first, then all others sorted by lap offset.
- **Lap length** is measured along the lap line in 3D (including elevation). `project(pos, hint)` resolves the nearest point in true 3D distance, so stacked decks resolve by height.
- **Minimap** is computed on demand from the lap line (`minimap(count)`), not stored as a separate resource.
- **Precision:** `validate()` rejects lap lines or grid slots beyond ±5 km (§5.1).
- **Surface queries** go through `asset.surface()` (TrackSurface) and must run inside a physics frame (P3-00).

### 5.4 Pose snapshot (for interpolation, ghosts, replays)

`{ "xform": Transform3D, "wheels": [ {steer, phase, comp, contact_point}, ×4 ], "steer": float }`. Interpolation uses position lerp and basis slerp. Ghost files store position (3 floats), rotation (quaternion, 4 floats) and lap distance, at ~30 Hz. Old ghosts are dropped (D4).

## 6. Test strategy

**Baseline first (P0-03):** capture today's numbers into `docs/rebuild/baseline.json`: every `dynamics.gd` and `handling.gd` measurement, plus the lap times. They are the equivalence targets.

| Gate | Test | Pass condition |
|---|---|---|
| Flat equivalence | `tests/v2/flat_equivalence.gd` on `TestSurface.flat` | Tyre peaks exact. 0–100, 100–0, 60 m skidpad and top speed within ±3% of baseline, per car, per handling model |
| Determinism | same 60 s scripted input, twice | bit-identical final state hash |
| Energy | flat, no aero, no rolling resistance, free-rolling coast 10 s | \|ΔKE\| < 0.5% |
| Banked bowl | radius R, bank θ, at v = √(gR·tanθ), steering to follow the circle (a turning car needs its kinematic steer angle even with zero lateral force) | path error < 1.5 m; tyre lateral force < 5% of mg; body roll = bank ± 1.5° |
| Crest | circular crest of radius R, no downforce | leaves the ground at v = √(gR) ± 3%; stays down at 0.9× that speed |
| Flight | airborne with initial spin, no contact | angular momentum conserved within 1% (tests the gyroscopic term) |
| Landing | 1 m drop at 50 km/h, in neutral (an automatic downshift while coasting would add an engine-braking pitch) | no NaN; settles within 2 s (heave within 1 cm, vertical speed and pitch/roll rates near zero) |
| Wall/ditch | 37° concrete wall, 150 km/h | the car rides it stably; roll follows the surface; no tunnelling |
| Barrier | 300 km/h head-on into a wall | no pass-through (port of the existing handling test) |
| Performance | car step on a TrackSurface | ≤ 0.3 ms mean per tick on the dev PC (RTX 4080 box) |
| Laps | bot on each shipped track, both handling models | valid lap, zero off-track, zero wall contacts; baseline recorded at first pass |
| Features | exported `-- --features` | 0 failures (editor checks removed in P1) |

Old suites that die with the old model (`laps.gd`, `airborne.gd`, `karussell.gd`, `track3d.gd`, `validation.gd`, `import.gd`, `showcase_laps.gd`) keep running unchanged until the task that removes their subject deletes them. Flat-equivalence tests replace the vehicle checks in `dynamics.gd`/`handling.gd`.

## 7. Phases and tasks

Task tags describe the kind of work, to help route it to a model: **[DEEP]** numerics/physics math, **[ARCH]** interface design and cross-module refactor, **[MECH]** mechanical deletion or porting, **[TOOL]** Godot editor tooling, **[CONTENT]** track building and art, **[DOC]** documentation. As a rule, the author of a [DEEP] or [ARCH] task should not be the model that reviews it.

Dependency outline: `P0 → (P1 ∥ P2) → P3 (may start after the 5.2/5.3 contracts freeze) → P4 → P5 → P6 → P7`.

### P0: Foundations (blocking everything)

- **P0-01 [MECH] Put the project under git.** Nothing is under version control right now, although the docs cite commit hashes. First ask the owner whether the old history exists elsewhere (another folder, GitHub). Otherwise `git init`, with a `.gitignore` for `.godot/`, `build/*.exe`, `build/*.zip`, `build/macos/`, `tests/logs/`, test screenshots/logs, `tools/Godot.app`, `tools/*.exe`, `tools/macos.zip`, `tools/python-packages/`. Commit the baseline and tag it `pre-rebuild`. **Done 2026-09-22** (see log); `godot/reference/` is also ignored.
- **P0-02 [DOC] Rebuild workflow rules.** Keep this plan and the log current; point `AGENTS.md`, `CLAUDE.md` (and `GEMINI.md` if Gemini CLI is used) at them. **Done 2026-09-22.**
- **P0-03 [MECH] Capture the baseline.** Run the current suites. Write `docs/rebuild/baseline.json` with every measurement (see §6). **Done 2026-09-22**: raw output in `docs/rebuild/baseline/*.txt`, JSON regenerated by `python tools/baseline_json.py`.
- **P0-04 [MECH] Release the old build.** Copy the current `build/RacingSim.exe` to `build/legacy/` (git-ignored) so the old game stays playable during the rebuild. **Done 2026-09-22**; launch with root `Play Legacy (pre-rebuild).cmd`.

### P1: Remove the editor (can run in parallel with P2)

- **P1-01 [MECH]** Delete `scripts/editor.gd`, `scripts/outline_import.gd` and `tests/import.gd`. Remove the editor from `interface.gd` (toolbar, F2, test drive, circuit import/export/rename/delete/copy/paste, Choose folder for tracks), `game.gd` (`editing` state, editor transitions) and `controls.gd` bindings.
- **P1-02 [MECH]** Remove the editor checks from `verification.gd` and `front_end` flows. Storage keeps settings/setups/ghosts/records and drops track writes.
- **P1-03 [DOC]** Remove the editor chapters from `PLAYER-GUIDE.md` and `build/PLAY.txt`, and update `LLM-GUIDE.md`'s source map.
- **Gate:** parse check, exported `--features` 0 failures, old lap/handling/dynamics suites unchanged.

### P2: 6-DOF chassis on analytic surfaces

- **P2-00 [DEEP] Spike.** Prototype `CarBody` (rigid body, quaternion, body-frame ω with gyroscopic term, semi-implicit Euler at 240 Hz) and four ray-suspension corners on `TestSurface.flat` and `.crest`. Confirm D6(A) is viable (stability at 240 Hz, cost per tick). Write findings in the log. Go/no-go for the owner.
- **P2-01 [ARCH] Extract without changing behaviour.** Move the tyre, drivetrain and aids code out of `car.gd` into `scripts/vehicle/*.gd`. The old `car.gd` calls them. **Every existing suite must produce byte-identical numbers.** This makes the physics reusable by the new body.
- **P2-02 [DEEP]** `TestSurface` with flat, bowl, crest, ditch, 37° wall, ramp and step shapes, each with an analytic ground truth. **Done 2026-09-22** (`tests/v2/surfaces.gd`).
- **P2-03 [DEEP]** `CarBody` + `Suspension`: hardpoints from `cars.json` (derive them from the existing `a`, `b`, track widths and CG height); spring/damper/bump stop along the hardpoint axis; ARBs; wheel load = suspension force (zero when extended). Tyre forces act at the contact point in the contact frame, built from the surface normal and the wheel's heading. Aero forces on the body. Gravity is a world −Y force, with no slope term.
  P2-03 must also: store world position (and velocity) in 64-bit scalars per §5.1; start each suspension ray above the mount (a ray that starts inside the ground currently reads distance 0 and fires the bump stop); keep ARBs acting when a wheel is off the ground; add chassis-to-ground contact (sills/roof) so a rolled car cannot fall through the surface (P2-02 probe).
- **P2-04 [DEEP]** Wheel spin states and the tyre "need" clamps, reworked for 3D contact velocity. **The clamps must stay:** they are what stops standstill jitter and drivetrain oscillation.
  P2-04 must also give the tyre low-speed stiffness (static friction): a braked car currently creeps 6–8 mm/s down an 8° ramp and 26–35 mm/s across a 37° side slope (P2-02 probes); the old model had the same flaw, hidden by its flat-only standstill hold.
- **P2-05 [DEEP]** Flat-equivalence, determinism, energy, bowl, crest, flight, landing and wall tests (§6). Tune only the new suspension parameters. **Don't touch tyre or drivetrain constants to pass tests.**
- **P2-06 [DEEP]** Tyre footprint smoothing (multi-ray) and kerb behaviour on `TestSurface.step`.
- **P2-07 [DEEP]** Aids and Simcade ported to 3D (ASM uses body-frame yaw rate and slip). Retune Simcade against its existing targets.
- **Gate:** every §6 row marked P2 passes. The owner drives it on a test-surface scene (P2-08).
- **P2-08 [MECH]** Debug scene `scenes/proving/test_surfaces.tscn`: drive the new car on all the analytic shapes with the existing camera and car model.

### P3: Track asset format and road tool

- **P3-00 [ARCH]** Decide the `TrackSurface` query backend (PhysicsServer3D direct space state vs our own BVH over baked triangles). Check determinism, headless use and cost against the §6 performance gate. **Done 2026-09-22: recommends PhysicsServer3D rays against a baked triangle mesh, engine pinned to GodotPhysics3D** (see the log). Consequences: surface queries run inside a physics frame (`_physics_process`), including in headless tests; tessellate roads at ≤ 1.5 m along and ≤ w/8 across; keep track coordinates within ±5 km of the origin (§5.1).
- **P3-01 [ARCH]** `track_asset.gd` + loader: timing line, gates, sectors, grid, minimap bake, record identity. **Done 2026-09-22** (`tests/v2/track_asset.gd`).
- **P3-02 [TOOL]** Road plugin (`addons/road_tool/`, editor-only, excluded from export).
  - A `RoadPath` (Path3D) with cross-section keys along its length: left/right width, camber, crown, left/right kerb type and width, verge width and slope, surface type.
  - It bakes the road, kerbs and verges into render meshes plus per-surface collision.
  - Junctions/pit lane: out of scope for v1. Hand-model them.
- **P3-03 [TOOL]** Terrain: import a DEM GeoTIFF/heightmap into chunked mesh terrain with collision, stitched to the verge edges of the road. No third-party GDExtension unless the owner approves it.
- **P3-04 [TOOL]** Wall/barrier tool (armco, tyre wall, concrete) along paths with collision; scenery scatter brush (trees, fences) with MultiMesh.
- **Gate:** a tiny test loop built entirely with the tools loads in game, times a lap and passes the Laps/Barrier/Performance rows.

### P4: Port the game to the new model

- **P4-01 [ARCH]** `game.gd`: load a TrackAsset; `CarBody` replaces `CarModel`; delete the coordinate remap; interpolation from the §5.4 snapshot.
- **P4-02 [MECH]** `race.gd`: 3D gates; ghosts in the new format; sectors unchanged.
- **P4-03 [DEEP]** `collisions.gd`: chassis box/hull against the `Walls/` geometry, 3D impulses with friction, no tunnelling at 300 km/h (use swept tests or substeps). Cones become simple dynamic props.
- **P4-04 [MECH]** `visuals.gd`/`ferrari_296.gd`: pose from `Transform3D` plus per-wheel data; free attitude in flight. Scenery building moves out to the track asset.
- **P4-05 [MECH]** Cameras, `instruments.gd` (minimap from the baked polyline, telemetry graph), audio (surface ids from contact), skids (contact points), `night_style.gd` (lamps from `Lights/`).
- **P4-06 [MECH]** `front_end.gd`: the circuit picker lists TrackAssets; loading screen; record identity per §5.3.
- **P4-07 [MECH]** Bot driver (`showcase_driver.gd`) follows `BotLine`; new `tests/v2/laps.gd`.
- **Gate:** the proving ground plays end to end in the exported build; `--features` has 0 failures.

### P5: Proving ground, the first polished track

- **P5-01 [CONTENT]** Verify the DEM/orthophoto sources and licences for Spa and the Nordschleife (D10). Record them in `THIRD-PARTY.md`. No data is committed before this. **Licences verified 2026-09-22** (`docs/rebuild/data-sources-P5-01.md`): Nordschleife dl-de/by-2.0, Spa CC BY 4.0; both allow commercial derived works with attribution. Verified sources and licence terms are recorded in `THIRD-PARTY.md`; add acquisition details and in-game credits when derived data first ships (P6).
- **P5-02 [CONTENT]** Design the proving ground on paper: corner list, elevation profile, the features to test (bowl, crest to take off at ~150 km/h, compression, off-camber, concrete ditch, kerbs of each type). **Designed 2026-09-22** in `docs/rebuild/proving-ground-P5-02.md`; P5-03 builds and measures it.
- **P5-03 [CONTENT]** Build it with the P3 tools; scenery; night lighting.
- **P5-04** Owner playtest and iterate. Record the lap baselines.

### P6: Real circuits

- **P6-01 [CONTENT] Spa** on 1 m DEM. Author widths, cambers and kerbs from orthophotos by hand; Eau Rouge/Raidillon as the showcase.
- **P6-02 [CONTENT] Nordschleife** in sections (e.g. five ~4 km sections, each playable as a loop with a return road for testing). Karussells get a real concrete-slab mesh; Flugplatz, Pflanzgarten and Sprunghügel come from the survey data, not Gaussian bumps.
- **P6-03** Monza if still wanted.

### P7: Cleanup and release

- **P7-01 [MECH]** Delete `track.gd`, `track3d.gd`, `circuit_world.gd`, `trackgen/` (keep the licence notes), old JSON tracks under `godot/tracks/` and the dead tests.
- **P7-02 [DOC]** Rewrite `ARCHITECTURE.md`, `PHYSICS.md`, `DATA-CONTRACTS.md`, `LLM-GUIDE.md`, `TESTING.md` and `PLAYER-GUIDE.md` to the new model; mark `SOLVER-MATH.md` sections as historical or rewrite them.
- **P7-03 [MECH]** Windows + macOS export, exported feature suite, `CHANGELOG.md` entry with dated evidence.

## 8. Risks

| Risk | Mitigation |
|---|---|
| The rewrite changes how the car feels in unwanted ways | Flat equivalence against the baseline; tyre/drivetrain code moved byte-for-byte in P2-01 before any change |
| Stiff springs/tyres at 240 Hz go unstable in 6-DOF | P2-00 spike; keep the need clamps; substep the suspension only if the spike demands it |
| Harsh kerbs/seams from ray contact | P2-06 footprint filter |
| Content is the real bottleneck (building tracks is slow) | Proving ground first; build the Nordschleife in sections; tools before content |
| Models drift from each other's conventions | §5 contracts frozen; the log; cross-model review; the tests are the referee |
| Doc drift (a recurring problem in this repo) | Each task updates the docs it touches; P7-02 full pass |
| DEM licensing | P5-01 before any download is committed |
| No version control today | P0-01 first; nothing else starts until it's done |

## 9. Working protocol (every model, every task)

1. Read this plan, the latest entries in [REBUILD-LOG.md](REBUILD-LOG.md), and the old docs the task touches.
2. **Claim** the task: add a log entry `CLAIM <task-id> <model> <date>`. Don't start a task someone else has claimed and not released.
3. Work on branch `rb/<task-id>-<slug>`. Small commits. Edit only the files the task names, plus the docs describing them. If you need to go outside that scope, stop and log it.
4. Don't rewrite whole files from memory; edit specific functions. Don't change §5 contracts inside a feature task.
5. Before declaring done, from `godot/` on Windows:
   ```
   ./tools/Godot.exe --headless --path . --import            # after fresh checkout / asset changes
   ./tools/Godot.exe --headless --path . --script scripts/game.gd --check-only
   ./tools/Godot.exe --headless --path . --script <each suite the task affects>
   gdformat -l 110 scripts tests
   ```
   Godot.exe is a GUI-subsystem binary: run it via `Start-Process -Wait -PassThru` with redirected stdout/stderr, and **read stderr**. Exit code 0 with script errors in stderr is a failure.
6. **Log the result:** `DONE <task-id>` with the commands run, pass/fail counts, measurements and anything left undone. Report failures as failures.
7. Hand-off: if you stop midway, log `PAUSED <task-id>` with the exact state and next step.
