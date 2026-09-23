# Native Windows and macOS game: guide for LLMs and maintainers

## Read first

This is a native Godot 4.6.2 game. `main.tscn` instantiates `scripts/main.gd`, which extends `scripts/game.gd`. The project uses the Forward+ renderer (Vulkan/D3D12 on Windows, Metal on macOS) with automatic fallback to OpenGL when a GPU lacks it, and custom vehicle equations, not Godot VehicleBody3D or RigidBody3D dynamics. There is no server, package manager, runtime download, plugin, or browser dependency.

The project began as a port of a single-file browser simulator (`racing-sim.html`), which was removed on 2026-09-22 and survives only in git history. It is not a compatibility target and not a physics reference. `scripts/car.gd` is authoritative for native physics, and the native model is free to evolve on its own terms.

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
| `scripts/game.gd` | Models, modes, physics/render orchestration, camera, file workflows, records | New settings, mode transitions, application services |
| `scripts/main.gd` | Entry adapter | Usually leave as a one-line extension |
| `scripts/car.gd` | Vehicle state, tire forces, chassis, drivetrain | Vehicle behavior; preserve solver clamps |
| `scripts/track.gd` | Superseded plan-view model, retained only for `tests/validation.gd` | Do not extend; the game runs on `track3d.gd` |
| `scripts/track3d.gd` | The circuit: 3-space ribbon geometry, frames, true banking, cross-section profiles, 3-D projection, barriers, validation | Geometry/query behaviour. This is the live model |
| `scripts/collisions.gd` | Planar contact response and moving cones | Barrier/cone physics |
| `scripts/race.gd` | Start/checkpoints, validity, time, ghost recording/playback/delta | Timing and ghost logic |
| `scripts/controls.gd` | Bindings, held inputs, ramps, controller polling | Input behavior/remapping |
| `scripts/interface.gd` | Modal screens, dialogs, Help | Menus/layout and player-facing actions |
| `scripts/instruments.gd` | HUD, minimap, debug, 600-sample graph | Instrument presentation |
| `scripts/visuals.gd` | Procedural meshes/materials/scenery and model poses | 3D appearance without changing physics |
| `scripts/ferrari_296.gd` | Dedicated 296 GT3 body, aero, glazing, livery and racing wheels | Read [CAR-MODEL.md](CAR-MODEL.md) before changing body geometry |
| `scripts/audio.gd`, `scripts/audio_review.gd` | Recorded engine RPM/load bank, synthesized effects and focused mixer checks | Engine/tire/road/shift/impact sound; offline assets in `assets/audio/` |
| `scripts/storage.gd` | JSON validation, safe names, reads/writes | File handling without gameplay state |
| `scripts/verification.gd` | Rendered source/export integration runner | Native functional regression coverage |
| `data/cars.json` | Three presets, setup defaults and presentation keys (`body`, colours, `num`) | Add/change car constants or looks |
| `data/setup_fields.json` | 42 field definitions and seven garage groups | Garage field schema and ranges |
| `tracks/*.json` | Three bundled circuit documents | Shipped circuit geometry |
| `tests/laps.gd` | Roadster bot laps on Monza and Spa | Track/physics regression |
| `tests/handling.gd` | Native-only handling layer, interpolation blend, checkpoint reasons, auto barriers, sectors | Curb/tire-temp/aligning-torque/steering/barrier/timing changes |
| `tests/track3d.gd` | Ribbon frames, rotational banking, curvature split, overpass decks, cross-section profiles and plan-view parity | Ribbon geometry changes |
| `tests/airborne.gd` | Takeoff, zero tyre load in flight and landing compression over a synthetic crest; reports Nordschleife crest sharpness | Airborne state, vertical curvature or normal-force changes |
| `tests/karussell.gd` | Drives the Caracciola-Karussell against a flat control: road deviation, chassis roll and corner unloading | Suspension travel, cross-section or profile changes |
| `tests/validation.gd`, `tests/showcase_laps.gd` | Spatial validation equivalence and 296/Spa laps, including digital intervention | Track validation and showcase regression |
| `scripts/retro_renderer.gd` | World/UI, glow, GPU history and field-composition viewports | Authentic UI shares output filtering; Sharp UI optional |
| `scripts/front_end.gd` | Boot/title/attract, race/car/circuit/loading/grid, pause/results/replay | Console screen flow and input focus |
| `scripts/showcase_driver.gd`, `scripts/showcase_benchmark.gd`, `scripts/showcase_review.gd` | Input-only driving, full flow/performance and repeatable comparison captures | Isolated source/export acceptance |
| `scripts/record_writer.gd` | Serial background atomic record/sector saves | Flush before read/import/delete/shutdown; immutable completed samples |
| `scripts/retro_assets.gd`, `scripts/retro_flare.gd` | Generated small art textures, painted sky, occluded flare | Procedural presentation |
| `data/simcade.json` | Shared Simcade and ASM constants; optional per-car `simcade` overrides | Handling tuning; dynamics targets required |
| `scripts/night_style.gd` | After-dark floodlights, depth-tested halos/streaks and pit accents | PS2-inspired circuit presentation only |
| `scripts/circuit_world.gd` | Heightfield terrain, textured road/verge/curb meshes, gravel mask, barriers, furniture and named landmarks | Circuit look |
| `shaders/*.gdshader`, `assets/textures/` | Road, ground and painted-concrete shaders; CC0 texture sets | Surface look |
| `.github/workflows/macos-native.yml` | CI: macOS universal export, headless regressions and ZIP artifact | Mac packaging/test automation |
| `.github/workflows/native-tests.yml` | CI: formatting, headless suites and the rendered feature suite on Linux | Test automation |
| `export_presets.cfg`, `tools/`, `packaging/` | Windows/macOS templates, local engines and reproducible Mac packaging | Packaging |
| `build/` | Executable, play instructions, engine notices | Generated deliverable plus notices |
| | | |
| **Rebuild: vehicle** | | |
| `scripts/vehicle/car_body.gd` | 6-DOF rigid-body chassis (CarBody): quaternion orientation, body-frame ω, semi-implicit Euler at 240 Hz, ray suspension, tyre compliance and unsprung mass, chassis-to-ground contact, 64-bit world position | Do not remove the `compliance` switch or the need clamps; do not store world position in a Vector3 (float32 precision loss at > 2 km) |
| `scripts/vehicle/tyre.gd` | Shared tyre model: Pacejka, combined slip, temps, wear, need clamps, static friction | Moved from `car.gd` in P2-01; both CarModel and CarBody call it. Do not change the clamp logic without re-running flat equivalence |
| `scripts/vehicle/drivetrain.gd` | Shared drivetrain: engine, clutch, gearbox, diffs | Moved from `car.gd` in P2-01; both chassis paths call it |
| `scripts/vehicle/aids.gd` | Shared aids: TC, ABS, ASM, steering assist, Simcade layer | Moved from `car.gd` in P2-01; ASM uses body-frame yaw rate on CarBody |
| `scripts/vehicle/tyre_footprint.gd` | Rigid-tyre envelope: 9 fixed samples per wheel (5 on smooth ground) plus edge bisection; returns the centre ray bit-for-bit on smooth surfaces | Do not change `SMOOTH_TOL` or `FACE_COS` without re-running `footprint.gd` on real kerbs |
| `scripts/vehicle/wall_contact.gd` | WallContact: swept hull box on layer 2, 3D impulses with friction, Simcade arcade response | Call after `car.step()` inside the physics frame; the planar `collisions.gd` is kept for CarModel until P7 |
| `scripts/vehicle/bot_driver.gd` | BotDriver: drives CarBody along a TrackAsset's BotLine at a fraction of grip with a banked-turn speed plan, pure-pursuit steering and cross-track correction | Do not change the `pace` constant (0.85) without re-recording `laps-v2-baseline.json`; see REBUILD-LOG P4-07 |
| | | |
| **Rebuild: surface** | | |
| `scripts/surface/track_surface.gd` | TrackSurface: §5.2 contract on PhysicsServer3D rays (layer 1, GodotPhysics3D), normal always faces back along the ray | Must run inside a physics frame; errors once if called outside one |
| `scripts/surface/wall_query.gd` | WallQuery: hull sweep (`cast_motion`) then `intersect_shape`/`collide_shape` on layer 2 for wall contacts | One instance per car; used by `wall_contact.gd` |
| `scripts/surface/test_surface.gd` | TestSurface: analytic heightfields (flat, ramp, bowl, crest, ditch, step, block) implementing §5.2 contact; no physics frame needed | Do not change surface maths without re-running `surfaces.gd` (34 checks against analytic ground truth) |
| | | |
| **Rebuild: track** | | |
| `scripts/track/track_asset.gd` | TrackAsset root (§5.3): validation, timing line, gates, sectors, grid, minimap, record identity, `surface()` → TrackSurface | Do not change `record_key()` without understanding ghost/record compatibility; see REBUILD-PLAN §5.3 |
| `scripts/track/road_path.gd` | RoadPath (@tool Path3D): cross-section keys (RoadSection), elevation spline, `@export_tool_button` bake; bakes road/kerb/verge meshes and collision via RoadBuilder | Re-bake replaces only its own tagged output; do not delete foreign Grid children. See REBUILD-LOG P3-02 |
| `scripts/track/terrain.gd` | TerrainPatch (@tool Node3D): heightmap import (GeoTIFF/raw), chunked mesh with collision on layer 1 (surface = grass), road-stitch blending | Terrain vertices under the road are dropped 0.3 m; do not raise them above the road surface |
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
| `trackgen/spa.gd` | Spa-Francorchamps generator from OSM/LiDAR data: road, terrain, barriers, scenery, BotLine; saves `tracks3d/spa/spa.scn` | The bank-twist warning at s 2398 m is a known issue (F-P6-01). See REBUILD-LOG P6-01 for data sources |
| `scenes/proving/test_surfaces.tscn` | Drive scene: CarBody on all 8 analytic TestSurface shapes with chase camera, car cycling, teleport, HUD telemetry | Launch with `Godot.exe --path . res://scenes/proving/test_surfaces.tscn` or from the main menu |
| `scenes/proving/track_drive.tscn` | Drive scene: CarBody on any TrackAsset (proving ground or Spa) with lap/sector HUD and free-fly camera | Launch with `Godot.exe --path . res://scenes/proving/track_drive.tscn` or from the main menu |

## Change recipes

**New setup field:** add a row `[group,key,label,min,max,step,unit]` to `setup_fields.json`; add the corresponding numeric default to every preset's `setup`; consume it in `car.gd`. The garage builds itself from the rows. Import bounds come from those same definitions. Setup changes affect record identity. Update any tests that deliberately check field count.

**New setting:** add a correctly typed entry to `game.gd::DEFAULT_SETTINGS`; connect it in `interface.gd`; apply it in `apply_settings()` or the relevant consumer. Startup only restores recognized defaults plus key/pad dictionaries. Settings that change competition conditions should reset the run and be represented in record identity. Do not silently mix best laps from incompatible configurations.

**New geometry rule:** edit `track3d.gd` and rebuild all derived samples after relevant mutations. Rendering, surface queries and lap checkpoints depend on these samples. Reset cached wheel sample hints through a car reset when changing live circuits.

**New graphics:** ground, road, verges, curbs, barriers and trackside furniture are built by `circuit_world.gd`; cars, trees, labels and user objects by `visuals.gd`. Place anything on the ground with `world.ground_height(x,y)` (road plane on the road, verge blend, then terrain). Camera/environment and lighting presets live in `game.gd`; world rendering and glow/dither/history live in `retro_renderer.gd`. The same screen shaders run under OpenGL. Medium and High quality enable directional shadows; Native alone can opt into MSAA. SSAO/SSR/FXAA are disabled. Textures live in `assets/textures` (CC0, see its README) and are sampled by the shaders in `shaders/`. Use MultiMesh for anything repeated per metre of track. In a rotated `Basis`, scale with `basis*Basis.from_scale(v)`; `Basis.scaled(v)` scales in the parent frame and shears rotated shapes. Keep asset generation outside the physics step.

**Player documentation:** edit `docs/PLAYER-GUIDE.md`. In-game Help reads its `##` chapters directly; keep chapters plain paragraphs and readable bullet text. This small reader does not implement general Markdown tables, links or code fences. Other technical documents can use full Markdown normally. `export_presets.cfg` must continue to include `docs/*.md`.

## High-risk assumptions to avoid

- `car.z` is suspension heave, not track altitude. `car.elev` is terrain elevation.
- `car.parity` is retired. The browser-parity path is no longer a project constraint and is no longer gated by a test; the current car model has no parity property. Native physics is authoritative and may evolve freely. New vehicle behaviour goes on the normal native path and is covered by `tests/handling.gd` and `tests/dynamics.gd`.
- The car contact-patch shadow (`shaders/blob_shadow.gdshader`) renders in the opaque pass with an ordered dither. A transparent material on that mesh is never composited by the world SubViewport, so switching it back to alpha blending silently removes the shadow instead of failing loudly.
- `visuals.pose_car()` takes a `CarModel.snapshot()` dictionary, not the live car. Add any new animated state to `snapshot()`/`blend()` or it will not interpolate.
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

Exports target Windows x64 and macOS universal. See [MACOS.md](MACOS.md) for Mac validation evidence and remaining limits. Physical controller hardware, force-feedback wheels, other GPUs, online multiplayer and AI racing opponents have not been validated or implemented as applicable. The lap bot is a test controller, not an in-game opponent. The 296 has dedicated reference-built procedural geometry (`ferrari_296.gd`); other cars use generic lofts in `visuals.gd::BODIES`. These are not licensed manufacturer models. The car leaves the ground when a crest demands a negative normal force, flies ballistically with no tyre force, and lands into its suspension; in flight the rendered attitude still follows the road beneath rather than rotating freely. Planar barriers ignore elevation. Source comments and tests explain deliberate simplifications; do not casually replace them with generic engine physics.

## PS2-era art direction (2026-09-21)

Start with [ART-DIRECTION.md](ART-DIRECTION.md) for the shared world/UI output chain, resolution modes, palettes, materials, body winding and screenshot/timing matrix. Startup defaults are Spa-Francorchamps and f296gt3; maintain UI picker consistency if changing them. `--compare --round=N` captures the full matrix; `--features` includes both input-driven full laps; `--performance` measures all six lighting/resolution cases for the selected backend.

`car.simcade_enabled` selects the handling model. Models instantiated by historical headless tests default to Simulation; game settings default to Simcade. Always set the intended model explicitly in new harnesses. Handling enters record identity; time of day and renderer settings do not.
