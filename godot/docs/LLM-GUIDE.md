# Native Windows and macOS game: guide for LLMs and maintainers

## Read first

This is a native Godot 4.6.2 game. `main.tscn` instantiates `scripts/main.gd`, which extends `scripts/game.gd`. The project uses the Forward+ renderer (Vulkan/D3D12 on Windows, Metal on macOS) with automatic fallback to OpenGL when a GPU lacks it, and custom vehicle equations, not Godot VehicleBody3D or RigidBody3D dynamics. There is no server, package manager, runtime download, plugin, or browser dependency.

The project began as a port of a single-file browser simulator (`racing-sim.html`), removed on 2026-09-22 and kept only in git history. It is not a compatibility target and not a physics reference.

Since the rebuild (REBUILD-PLAN.md, first release v0.1.0-preview.1), normal launch runs the **v2 game**:
- `CarBody` (`scripts/vehicle/car_body.gd`, the authoritative car) on authored 3-D TrackAssets;
- the v2 front end, records and presentation in `game.gd` (`*_v2` functions).

The **legacy game** (CarModel on JSON tracks, the old UI and its suites) was deleted in P7-01 (2026-09-23) and is in git history only.

Read these documents according to the task:

1. [PLAYER-GUIDE.md](PLAYER-GUIDE.md): actual player workflows; also packaged and displayed by in-game Help.
2. [ARCHITECTURE.md](ARCHITECTURE.md): ownership, frame order, coordinate conventions, state transitions and invariants.
3. [DATA-CONTRACTS.md](DATA-CONTRACTS.md): track/setup/ghost/settings schemas, persistence and compatibility.
4. [TESTING.md](TESTING.md): build commands, automated checks, evidence and known limits. For macOS, also read [MACOS.md](MACOS.md): tool setup, universal packaging and Apple M4 validation.
5. [Handling models](PHYSICS.md): native Simulation/Simcade selection, aids and tuning.
6. [PS2-REFERENCE.md](PS2-REFERENCE.md), [ART-DIRECTION.md](ART-DIRECTION.md) and [PS2-FOLLOWUP-REPORT.md](PS2-FOLLOWUP-REPORT.md): sourced console constraints, current rendering/frontend and acceptance evidence.
7. [SOLVER-MATH.md](SOLVER-MATH.md): the full vehicle-model derivation, every formula and why it is written that way. Written for the original implementation, so its function names are historical; `scripts/car.gd` remains authoritative for the native implementation.

## Source map

All paths below are relative to `godot/`.

| File | Owns | Common edits |
|---|---|---|
| `project.godot` | Main scene, 240 Hz clock, renderer, viewport | Engine configuration; keep native scope explicit |
| `scripts/game.gd` | Orchestration. v2: `setup_v2`, `load_v2_track`, `change_v2_car`, `start_v2_drive`, `return_v2_menu`, `physics_v2` (tick order in ARCHITECTURE.md), `render_v2`, v2 `record_path`, probe modes (`--v2-smoke`, `--v2-present`, `--v2-export-check`). Legacy: the planar game loop | New settings, mode transitions, application services. Keep v2 code off the legacy path |
| `scripts/main.gd` | Entry adapter | Usually leave as a one-line extension |
| `scripts/surface/surface_table.gd` | SURF: grip, rolling resistance, drag and bump per surface id (0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 runoff) | Surface tuning; CarBody, TrackAsset and the road tool read it |
| `scripts/race.gd` | Timing: `update_asset()` for TrackAssets (3-D gates, gates in order, sectors, schema-2 5.4 ghost samples, `ghost_xform()`) | Timing and ghost logic; `tests/v2/race.gd` |
| `scripts/controls.gd` | Bindings, held inputs, ramps, controller polling | Input behavior/remapping |
| `scripts/instruments.gd` | HUD, minimap, debug, 600-sample graph; `on_asset()` switches the minimap, ghost dot and checkpoint count to TrackAssets | Instrument presentation |
| `scripts/visuals.gd` | Procedural meshes/materials/scenery and model poses | 3D appearance without changing physics |
| `scripts/ferrari_296.gd` | Dedicated 296 GT3 body, aero, glazing, livery and racing wheels | Read [CAR-MODEL.md](CAR-MODEL.md) before changing body geometry |
| `scripts/audio.gd` | Recorded engine RPM/load bank, synthesized effects | Engine/tire/road/shift/impact sound; offline assets in `assets/audio/` |
| `scripts/storage.gd` | JSON validation, safe names, reads/writes | File handling without gameplay state |
| `data/cars.json` | Three presets, setup defaults and presentation keys (`body`, colours, `num`) | Add/change car constants or looks |
| `data/setup_fields.json` | 42 field definitions and seven garage groups | Garage field schema and ranges |
| `scripts/retro_renderer.gd` | World/UI, glow, GPU history and field-composition viewports | Authentic UI shares output filtering; Sharp UI optional |
| `scripts/front_end.gd`, `scripts/v2_panels.gd` | Console pages, car/TrackAsset choice, loading, drive/menu flow; settings, garage and pause panels | Menus and player-facing actions |
| `scripts/record_writer.gd` | Serial background atomic record/sector saves | Flush before read/import/delete/shutdown; immutable completed samples |
| `scripts/retro_assets.gd`, `scripts/retro_flare.gd` | Generated small art textures, painted sky, occluded flare | Procedural presentation |
| `data/simcade.json` | Shared Simcade and ASM constants; optional per-car `simcade` overrides | Handling tuning; dynamics targets required |
| `scripts/night_style.gd` | After-dark floodlights, depth-tested halos/streaks and pit accents | PS2-inspired circuit presentation only |
| `shaders/*.gdshader`, `assets/textures/` | Road, ground and painted-concrete shaders; CC0 texture sets | Surface look |
| `.github/workflows/gates.yml`, `tools/ci_gates.py` | CI on every push: gdformat check, parse check and the headless suites from `tools/gates.json` on Linux; exact baselines | Test automation |
| `tools/run_gates.ps1`, `tools/gates.json` | Local parallel gate runner: affected suites by default, `-All`, `-Perf`, `-Features` | Register every new suite in `gates.json` |
| `export_presets.cfg`, `tools/`, `packaging/` | Windows/macOS templates, local engines and reproducible Mac packaging | Packaging |
| `build/` | Executable, play instructions, engine notices | Generated deliverable plus notices |
| | | |
| **Rebuild: vehicle** | | |
| `scripts/vehicle/car_body.gd` | 6-DOF rigid-body chassis (CarBody): quaternion orientation, body-frame ω, semi-implicit Euler at 240 Hz, ray suspension, tyre compliance and unsprung mass, chassis-to-ground contact, 64-bit world position | Do not remove the `compliance` switch or the need clamps; do not store world position in a Vector3 (float32 precision loss at > 2 km) |
| `scripts/vehicle/tyre.gd` | Shared tyre model: Pacejka, combined slip, temps, wear, need clamps, static friction | Moved from `car.gd` in P2-01 |
| `scripts/vehicle/drivetrain.gd` | Shared drivetrain: engine, clutch, gearbox, diffs | Moved from `car.gd` in P2-01; both chassis paths call it |
| `scripts/vehicle/aids.gd` | Shared aids: TC, ABS, ASM, steering assist, Simcade layer | Moved from `car.gd` in P2-01; ASM uses body-frame yaw rate on CarBody |
| `scripts/vehicle/tyre_footprint.gd` | Rigid-tyre envelope: 9 fixed samples per wheel (5 on smooth ground) plus edge bisection; returns the centre ray bit-for-bit on smooth surfaces | Do not change `SMOOTH_TOL` or `FACE_COS` without re-running `footprint.gd` on real kerbs |
| `scripts/vehicle/wall_contact.gd` | WallContact: swept hull box on layer 2, 3D impulses with friction, Simcade arcade response | Call after `car.step()` inside the physics frame; the only wall response |
| `scripts/vehicle/bot_driver.gd` | BotDriver: drives CarBody along a TrackAsset's BotLine at a fraction of the car's grip, measured on a virtual skidpad (`grip_curve()`, cached). Banked-turn speed plan over a ±8 m curvature chord, friction-circle braking, pure pursuit, cross-track correction and yaw damping, slip-aware pedals | Re-record `laps-v2-baseline.json` after any change that moves laps; see REBUILD-LOG P4-07, P4-07b |
| `scripts/props/prop_body.gd`, `scripts/props/prop_set.gd` | Knock-over props (`data/props.json` kinds): small rigid bodies, sleeping until touched, with impulses against car hull, ground and walls | `PropSet.from_asset()` reads an asset's `Props/`; call `step()` after WallContact |
| `scripts/proving/track_drive.gd` | `load_asset(id)`: builds a TrackAsset from its generator or loads the bake cached in `user://tracks3d/`, keyed on the generator revision. Used by the v2 game; also a dev drive scene | Generator or data changes invalidate the cache by themselves |
| | | |
| **Rebuild: surface** | | |
| `scripts/surface/track_surface.gd` | TrackSurface: §5.2 contract on PhysicsServer3D rays (layer 1, GodotPhysics3D), normal always faces back along the ray | Must run inside a physics frame; errors once if called outside one |
| `scripts/surface/wall_query.gd` | WallQuery: hull sweep (`cast_motion`) then `intersect_shape`/`collide_shape` on layer 2 for wall contacts | One instance per car; used by `wall_contact.gd` |
| `scripts/surface/test_surface.gd` | TestSurface: analytic heightfields (flat, ramp, bowl, crest, ditch, step, block) implementing §5.2 contact; no physics frame needed | Do not change surface maths without re-running `surfaces.gd` (34 checks against analytic ground truth) |
| | | |
| **Rebuild: track** | | |
| `scripts/track/track_asset.gd` | TrackAsset root (§5.3): validation, timing line, gates, sectors, grid, minimap, record identity, `surface()` → TrackSurface | Do not change `record_key()` without understanding ghost/record compatibility; see REBUILD-PLAN §5.3 |
| `scripts/track/road_path.gd` | RoadPath (@tool Path3D): cross-section keys (RoadSection), elevation spline, `@export_tool_button` bake; bakes road/kerb/verge meshes and collision via RoadBuilder | Re-bake replaces only its own tagged output; do not delete foreign Grid children. See REBUILD-LOG P3-02 |
| `scripts/track/terrain.gd` | TerrainPatch (@tool Node3D): heightmap import (GeoTIFF/raw), chunked mesh with collision on layer 1 (surface = grass), road-stitch blending | Terrain under the road is buried `under_road_drop_m`, tapering to `EDGE_DROP_M` (5 cm) at the footprint's edge so no trench opens beside the road (REVIEW F-P6-01). Never raise it above the road |
| `scripts/track/road_builder.gd` | Pure baking code for RoadPath: tessellation, strip winding, UV, kerb types (ramp/sausage/ribbed), ditch profile, dense ranges | See REBUILD-LOG P3-02 for tessellation limits (≤ 1.5 m along, w/8 across) |
| `scripts/track/road_section.gd` | RoadSection resource: one cross-section key (width, bank, crown, kerbs, verge, runoff, ditch, surface ids) | |
| `scripts/track/wall_builder.gd` | Builds wall geometry for WallPath | |
| `scripts/track/wall_path.gd` | WallPath (@tool): armco/tyre/concrete walls, road-following or freehand, layer 2 collision with `wall_kind` metadata | |
| `scripts/track/scenery_builder.gd` | SceneryBuilder: procedural box/quad mesh builders, MultiMesh helpers, layer-2 collision generator | Shared by all scenery-kit components |
| `scripts/track/catch_fence.gd` | CatchFence: steel posts + mesh panels, road-following or along a WallPath; optional layer-2 armco collision | |
| `scripts/track/grandstand.gd` | Grandstand: stepped seating block with canopy, optional front concrete barrier on layer 2 | |
| `scripts/track/gantry.gd` | Gantry: start/finish gantry spanning the road (towers + beam + start lights), no road collision | |
| `scripts/track/billboards.gd` | Billboards: advertising boards on posts, seeded placement, single MultiMesh, no collision | |
| `scripts/track/marshal_post.gd` | MarshalPost: small cabins spaced behind barriers, single MultiMesh, no collision | |
| `scripts/track/pit_building.gd` | PitBuilding: garage block with recessed bays, front concrete pit wall on layer 2 | |
| `scripts/track/road_scatter.gd` | RoadScatter: seeded MultiMesh instances (default: conifers) in a band beyond the verge, no collision | |
| | | |
| **Rebuild: generators and scenes** | | |
| `trackgen/proving_ground.gd` | Deterministic generator for the ~2.5 km invented proving ground (bowl, crest, compression, ditch, kerbs, scenery); saves `tracks3d/proving_ground/proving_ground.scn` | Scene is > 5 MB so not committed; baked on demand. Do not change without re-running `proving_ground.gd` (25 checks) |
| `trackgen/spa.gd` | Spa-Francorchamps generator: OSM centreline, SPW LiDAR elevation, measured widths, kerbs and banking (`measured()` reads `trackgen/data/spa/road-profile.json`), authored runoffs and verges, terrain, barriers, scenery, BotLine | Data scripts and provenance are in `trackgen/data/spa/README.md`. Any file the generator reads must be in the export `include_filter` and `check_exported_v2_assets()` |
| `scenes/proving/test_surfaces.tscn` | Drive scene: CarBody on all 8 analytic TestSurface shapes with chase camera, car cycling, teleport, HUD telemetry | Launch with `Godot.exe --path . res://scenes/proving/test_surfaces.tscn` or from the main menu |
| `scenes/proving/track_drive.tscn` | Drive scene: CarBody on any TrackAsset (proving ground or Spa) with lap/sector HUD and free-fly camera | Launch with `Godot.exe --path . res://scenes/proving/track_drive.tscn` or from the main menu |

## Change recipes

**New setup field:** add a row `[group,key,label,min,max,step,unit]` to `setup_fields.json`; add the corresponding numeric default to every preset's `setup`; consume it in `car_body.gd` or the `scripts/vehicle/` modules. The garage builds itself from the rows. Import bounds come from those same definitions. Setup changes affect record identity. Update any tests that deliberately check field count.

**New setting:** add a correctly typed entry to `game.gd::DEFAULT_SETTINGS`; add its control in `v2_panels.gd` and apply it in the relevant consumer. Startup only restores recognized defaults plus key/pad dictionaries. Settings that change competition conditions should reset the run and be represented in record identity. Do not silently mix best laps from incompatible configurations.

**New graphics:** road, verge, terrain and trackside materials come from the TrackAsset builders (`scripts/track/`, `ps2_materials.gd`); cars from `visuals.gd` and `ferrari_296.gd`. Follow [ART-DIRECTION.md](ART-DIRECTION.md).

**New TrackAsset (v2):** write a generator in `trackgen/<id>.gd` with a static `build_asset()` returning a validated TrackAsset (§5.3: Surfaces on layer 1, Walls on layer 2, TimingLine, Grid, BotLine with smooth handles, optional Props/Scenery/Lights). Keep the RoadPath bank change under 0.20°/m (it warns above that) and leave the terrain's under-road drop tapered. Commit source data under `trackgen/data/<id>/` with its licence and rebuild scripts, and cache raw downloads outside git. Add the id to `tests/v2/laps.gd` TRACKS, record its baseline (`-- --record`) and add a probe like Spa's: racing line on tarmac, no trenches beside the road. Add it to the v2 front end's track list, the export presets' `include_filter` and `check_exported_v2_assets()`, and attribute its data in `THIRD-PARTY.md` and `build/THIRD-PARTY.md`.

**Car behaviour (v2):** change `car_body.gd` or the shared `scripts/vehicle/` modules. Run `run_gates.ps1 -All`: suspension statics, flat equivalence, aids and Simcade bands, footprint, walls, props, proving ground and laps all gate it. If laps move deliberately, re-record `laps-v2-baseline.json` and say why in the log.

**Player documentation:** edit `docs/PLAYER-GUIDE.md`. In-game Help reads its `##` chapters directly; keep chapters plain paragraphs and readable bullet text. This small reader does not implement general Markdown tables, links or code fences. Other technical documents can use full Markdown normally. `export_presets.cfg` must continue to include `docs/*.md`.

## High-risk assumptions to avoid

- CarBody has no `car.z`: use `pos_y` and each wheel's `roadZ` (contact height). `car.elev` is the road altitude under the CG.
- TrackSurface queries only work inside a physics frame (`_physics_process`). In `_process`, use values sampled in the last physics tick (see `camera_ground`).
- Bank convention: positive lowers the right side (RoadSection, measured road data, the bot's `bank_right`).
- `car.parity` is retired. The browser-parity path is no longer a project constraint and is no longer gated by a test; the current car model has no parity property. Native physics is authoritative and may evolve freely. New vehicle behaviour goes on the normal native path and is covered by the `tests/v2/` vehicle suites (`aids_simcade`, `flat_equivalence`, `suspension`, ...).
- The car contact-patch shadow (`shaders/blob_shadow.gdshader`) renders in the opaque pass with an ordered dither. A transparent material on that mesh is never composited by the world SubViewport, so switching it back to alpha blending silently removes the shadow instead of failing loudly.
- The game poses the car model from `snapshot_v2()`/`blend_v2()`; add new animated state there, or it will not interpolate.
- Control-point bank is degrees; sampled bank and car heading are radians.
- Body lateral/right is positive. Do not flip all signs to match a generic 3D tutorial.
- Tire `wear` starts at zero and grows; it is not remaining tread fraction.
- Wheel `ellipse` is combined-force utilization, not a friction coefficient.
- A successful JSON parse is not gameplay validation. Draft tracks may be structurally valid but undriveable.
- `reset_car()` and `load_record()` are distinct operations. Resetting position alone does not select a new configuration's record.
- `blocked()` gates custom simulation. The whole SceneTree is not paused; UI, camera and audio fades continue.
- `res://` in an exported executable is read-only. Never save beside packaged resources through that URI.
- Godot parses JSON numbers as floats. Use finite numeric comparisons rather than relying on strict Array membership against integer literals.
- Code is formatted with gdtoolkit: run `gdformat -l 110 scripts tests` after edits (CI checks it). Make targeted changes to named functions; do not regenerate modules from a prose summary.
- `track.barriers` (auto armco/tire walls) are derived, never saved, rebuilt by `game.rebuild_world()` and collided through a 40 m grid with one-sided contact. Test harnesses that load a track directly must call `track.build_barriers()` themselves.

## Known boundaries

Exports target Windows x64 and macOS universal. See [MACOS.md](MACOS.md) for Mac validation evidence and remaining limits. Physical controller hardware, force-feedback wheels, other GPUs, online multiplayer and AI racing opponents have not been validated or implemented as applicable. The lap bot is a test controller, not an in-game opponent. The 296 has dedicated reference-built procedural geometry (`ferrari_296.gd`); other cars use generic lofts in `visuals.gd::BODIES`. These are not licensed manufacturer models. On the v2 path the 6-DOF car flies with free attitude, lands into its tyres and suspension, and contacts 3-D walls and props. The legacy game's planar barriers ignore elevation. Source comments and tests explain deliberate simplifications; do not casually replace them with generic engine physics.

## PS2-era art direction (2026-09-21)

Start with [ART-DIRECTION.md](ART-DIRECTION.md) for the shared world/UI output chain, resolution modes, palettes, materials, body winding and screenshot/timing matrix. Startup defaults are Spa-Francorchamps and f296gt3; maintain UI picker consistency if changing them. `--compare --round=N` captures the full matrix; `--features` includes both input-driven full laps; `--performance` measures all six lighting/resolution cases for the selected backend.

`car.simcade_enabled` selects the handling model. Models instantiated by historical headless tests default to Simulation; game settings default to Simcade. Always set the intended model explicitly in new harnesses. Handling enters record identity; time of day and renderer settings do not.
