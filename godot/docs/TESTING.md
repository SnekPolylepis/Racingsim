# Native build, verification and troubleshooting

Mac setup, build commands and evidence: [MACOS.md](MACOS.md).

## Commands

Run these PowerShell commands from the `godot` directory. `tools/Godot.exe` and the x64 export templates already exist in this workspace. Paths in the preset are project-relative. A source checkout on another machine must supply a compatible Godot 4.6.2 editor and templates at those paths or update the preset.

```powershell
# Parse the root script and its preloaded dependencies.
& ./tools/Godot.exe --headless --path . --script scripts/game.gd --check-only
# Complete circuit laps.
& ./tools/Godot.exe --headless --path . --script tests/laps.gd
# Native-only handling layer, interpolation blend, checkpoint reasons, auto barriers and sectors.
& ./tools/Godot.exe --headless --path . --script tests/handling.gd
# Vehicle-dynamics targets: tyre peaks, 0-100, braking, skidpad, controller stability, track vertical curvature.
& ./tools/Godot.exe --headless --path . --script tests/dynamics.gd
# Real window/audio integration; do not add --headless.
& ./tools/Godot.exe --path . -- --features
# Build and verify the actual deliverable.
& ./tools/Godot.exe --headless --path . --export-release "Windows Desktop" build/RacingSim.exe
& ./build/RacingSim.exe -- --features
```

`--` separates engine options from game test arguments. `--smoke` is an alias for the current feature runner, not the historical smaller smoke test. Ordinary launch does not run tests. When scripting Windows GUI executables, use `Start-Process -Wait -PassThru` and redirected output to inspect completion/exit status. Always examine stderr as well as test output: a script error can occur outside an explicit test assertion.

## Which checks to run

| Change | Relevant checks |
|---|---|
| Pure explanatory comments/technical Markdown | Review facts, paths and code references; parser if scripts touched |
| In-game Help, UI, audio, storage/input | Source or exported feature runner; inspect screenshots and errors |
| Car, track queries, collisions, race rules | Handling + vehicle dynamics + four-circuit laps; feature runner for affected workflows |
| Export filters/resources or release delivery | Rebuild and run exported feature suite; source success alone is insufficient |
| Browser HTML changes | Follow root `docs/TESTING.md`; native tests do not cover browser DOM behavior |

## Tests and evidence

`tests/airborne.gd` drives a synthetic loop with a 3 m Gaussian crest at 40 m/s and again at 15 m/s. The fast run must leave the ground (recorded: 1.30 s airborne, 1.94 m clear), carry no tyre load in the air, land and compress the suspension; the slow control must never leave the ground. On the Nordschleife it asserts that Flugplatz, Sprunghügel and Pflanzgarten fly a car without downforce within 5% of their modelled takeoff speeds (160 / 150 / 150 km/h), and drives the roadster over Pflanzgarten: it leaves the ground at 175 km/h (recorded: a 0.27 s hop, 3 cm clear) and not at 120 km/h. `tests/dynamics.gd` bounds compression curvature below 0.004 1/m on every circuit, and crest curvature above -0.02 1/m only to catch survey spikes, since crests past -g/v² now fly by design.

`tests/karussell.gd` drives the Caracciola-Karussell and compares it against the same car on the Antoniusbuche straight. It asserts that per-wheel road deviation exceeds the old 12 cm clamp (measured peak 0.64 m), that the chassis rolls into the banking far beyond the flat control (6.9 deg against 1.2 deg), and that a corner unloads over the concrete where none unloads on the flat. It is the regression for the circuit looking three dimensional but driving flat.

`tests/track3d.gd` covers the 3-space ribbon geometry in `scripts/track3d.gd`: frame orthonormality, banking as a rotation rather than a cross-slope, the curvature split into lateral and vertical components, and overpass deck resolution both cold and while tracking a hint. It also loads all three bundled circuits through the ribbon model. It does not exercise the car, which still runs on `scripts/track.gd`.

The browser-parity comparison (`tests/physics.gd` against `tests/reference.json`) has been retired along with its fixture. Native physics is authoritative and is no longer required to reproduce the browser solver, so there is no browser-reference check to run. `tests/handling.gd` and `tests/dynamics.gd` are the vehicle-model regression, and `tests/laps.gd` covers whole circuits.

`tests/handling.gd` runs native headless checks on a synthetic curbed circuit: wheels ride up curbs, the body tilts and ridges shake wheel load; tire surface heats and cools faster than the core; aligning torque opposes steering and the pneumatic trail collapses at large slip; suspension travel stops; speed-sensitive steering can be disabled; snapshot blending wraps wheel phase; a checkpoint passed far off the road invalidates the lap with a "missed CP n" reason, while a wide gate applies when off-track laps are allowed. It prints `HANDLING PASS` and exits nonzero on failure.

`tests/laps.gd` builds the auto barriers and also requires zero barrier contacts. It uses a conservative look-ahead controller and the Roadster. It advances up to 500 simulated seconds per track, requires a valid best lap, zero all-off-track ticks, finite physics and more than 100 ghost samples. Re-recorded Simulation baselines: Monza 261.50 s and Spa 325.17 s. They replace 260.30 / 323.00, recorded on the plan-view track model; the 3-space ribbon measures lap distance including elevation and derives curvature in 3-D, so both circuits are marginally longer and slower. Those in turn replaced 248.23 / 308.43, from before the roadster preset became the MX-5. The suite also covered Ridgeback (96.10 s) and Oval (42.78 s) until those circuits were removed on 2026-09-22. These are regression outcomes, not competitive benchmarks or proof of all handling conditions.

`scripts/verification.gd` uses explicit failure collection rather than GDScript asserts, which may be removed in release exports. It covers acceleration; nonzero captured audio and mute/pause silence; generated sound streams; garage/settings; input mapping; five cameras; track validation and safe naming; JSON writes/replacement; ghosts/record identity; layout and all cars/tracks. Some domain operations are invoked directly; key remapping uses synthetic input and audio capture uses the engine mixer. This does not replace physical-device or human usability testing.

Each run prints `FEATURE RESULTS` and exits nonzero on collected failures. Read the resulting `feature-results.json` for the current check count; documentation should not hard-code a count that changes when checks are added. Source runs save reports/images under `tests/`; exports use `user://native-tests/`. Reports copied into the project may use `release-feature-results.json`. Log/screenshots are evidence from a particular build, not source assets.

## Rebuild (v2) suites

The 6-DOF chassis rebuild adds a parallel gate runner and its own test suites under `tests/v2/`. The legacy suites above are still run (they prove the planar CarModel is untouched) but are skipped when only rebuild code changed.

### Gate runner: `tools/run_gates.ps1`

Run from `godot/`:

```powershell
./tools/run_gates.ps1              # suites affected by this branch's changes (vs origin/main)
./tools/run_gates.ps1 -All         # every gate — required before merging to main
./tools/run_gates.ps1 -All -Perf   # plus µs timing budgets, run alone (vehicle/surface/track changes)
./tools/run_gates.ps1 -All -Features   # plus the windowed feature suite (game/UI changes)
```

The runner reads `tools/gates.json`, launches suites in parallel Godot processes (16 by default), reads stderr and each suite's `RESULTS` JSON line or legacy baseline diff, and prints one summary. Exit 0 only when all selected gates pass. Parallel runs set the environment variable `RACINGSIM_PERF_GATES=0`, so timing budgets print but do not gate; `-Perf` re-runs the timing suites serially with budgets enforced. A timeout (default 600 s) counts as a failure. Long suites split for parallelism via `--car` and `--part` arguments (see `tests/v2/gates_env.gd` for the helpers).

`tools/gates.json` maps each suite to dependency-path groups (`vehicle`, `track`, `legacy`, `game`). The default (no `-All`) runs only suites whose paths the branch touched. Add a new suite as an entry in `gates.json` with its dependency paths.

### v2 test suites

All suites are headless (`--headless --path . --script tests/v2/<suite>.gd`). Each prints a `<NAME> RESULTS {json}` line.

| Suite | What it checks | Notes |
|---|---|---|
| `chassis_spike.gd` | Rest on flat, crest takeoff, bowl lateral demand, free-flight angular momentum, 1 m drop landing, determinism (60 s SHA-256 full-state hash), per-tick cost | Timing gates only with `-Perf` |
| `surfaces.gd` | Analytic TestSurface shapes (flat, ramp, bowl, crest, ditch, step, block): normals vs gradient, ray hits vs brute-force march, defining quantities, coasting on a grade vs g sin θ | 34 checks |
| `suspension.gd` | Cross-weight / warp vs rigid-body statics, roof drop, side drop, ditch weave max tilt and body penetration, close two-deck regression | 12 checks |
| `static_friction.gd` | Braked car on 8–37° slopes (creep < 0.004 mm/s), friction-limit slide on grass, unbraked rolling matches analytic rate, hold-release-rebrake cycle | 6 checks |
| `energy_wall.gd` | Energy conservation (free-rolling coast, ΔKE < 0.5%), 37° concrete wall at 150 km/h (all wheels down, body roll matches skidpad gradient × g sin 37°, path error < 1 m) | 4 checks |
| `flat_equivalence.gd` | CarBody vs CarModel: tyre peaks exact; 0–100, 100–0, 150 m skidpad and top speed within ±3% of baseline, per car, per handling model | Split by `--car` |
| `aids_simcade.gd` | Simulation dynamics bands and the full Simcade suite (ASM, keyboard lock, thermal grip, grass/gravel, differential, ARB) on CarBody, inheriting thresholds from `tests/dynamics.gd` | 114 checks; split by `--car` / `--part simulation\|simcade` |
| `footprint.gd` | Rigid-tyre envelope over a 5 cm step (within 0.5 mm of analytic), bit-identical to centre ray on smooth ground (1200 poses), TrackSurface kerb road cost < 300 µs | 10 checks; timing gate with `-Perf` |
| `barrier.gd` | Head-on 300 km/h into concrete/armco/tyre walls (no pass-through), glancing 150 km/h (energy-only loss), leaning on a wall 3 s, flying over a wall (0 contacts), oblique 300 km/h | 6 checks; timing gate with `-Perf` |
| `track_asset.gd` | TrackAsset validation (accepts fixture, rejects 8 broken variants), timing-gate crossing, deck resolution, TrackSurface contact, 296 integration lap, per-tick cost | 23 checks; timing gate with `-Perf` |
| `road_tool.gd` | RoadPath + RoadBuilder: analytic straight heights/bank, a proving loop built with the tool (idempotent re-bake, tessellation, kerb/surface ids, grid slots), 296 lap | 16 checks |
| `road_tool_v2.gd` | Sausage and ribbed kerbs, per-side verges and runoff, inset ditch (within 2 mm of TestSurface.ditch), elevation spline C2 continuity, grid configuration | 11 checks |
| `walls.gd` | WallPath (freehand/road-following): face hit on layer 2 only, road-following base within 0.15 mm of the analytic edge, whole-loop closure, validation rejects bad kinds/layers, scatter layout | 8 checks |
| `terrain.gd` | TerrainPatch: analytic heightmap within 1 cm, chunk-seam continuity, road-stitch (verge match within 2 cm, no terrain poke above road), 296 rest and drive on terrain, 8M-triangle bake performance | 7 checks; timing gate with `-Perf` |
| `road_density.gd` | Variable lateral road-station density: incompatible count falls back, analytic cross-section match, watertight collision mesh (0 boundary cracks), seam height-step < 1 mm, UV continuity, proving ground scene size | 6 checks |
| `scenery.gd` | Scenery kit components (CatchFence, Grandstand, Gantry, Billboards, MarshalPost, PitBuilding): layer-2 collision where required, validation, kerb paint, proving-ground integration | 11 checks |
| `proving_ground.gd` | Built proving ground on TrackSurface: crest takeoff speed, bowl lateral demand, compression load, ditch ride depth, BotLine laps (Simulation + Simcade), kerb crossings at 60/120 km/h | 25 checks |
| `laps.gd` | BotDriver on every shipped TrackAsset: valid lap, zero off-track wheel-ticks, zero wall contacts; records or compares against `docs/rebuild/laps-v2-baseline.json` | Split by `--car`; see below |
| `test_surfaces_scene.gd` | The `scenes/proving/test_surfaces.tscn` drive scene: car settles on each analytic shape, controls respond, visual adapter poses correctly | 14 checks |

### `tests/v2/laps.gd` arguments

```
--car <preset>        Run only this car (roadster, gt, f296gt3). The gate runner splits by car.
--record              Record new baselines into docs/rebuild/laps-v2-baseline.json instead of comparing.
--diag                Print per-tick diagnostics (position, speed, off-line distance).
```

The baseline file `docs/rebuild/laps-v2-baseline.json` stores one lap time per `<track> <car> <handling>` key. A change that moves a lap by more than 2% fails the gate; re-record deliberately with `--record`.

### Known acceptable failure (as of 2026-09-23)

The three `laps` rows' stderr carries Spa's RoadPath bake warning **"bank changes 2.69 deg/m"** at station 2398 m. This is a road-authoring artefact, not a physics bug; it is being smoothed as task **F-P6-01**. The `run_gates.ps1` summary reports it; the laps themselves pass (zero off-track, zero wall contacts) for all car × model combinations on both tracks.

## Continuous integration and formatting

`.github/workflows/native-tests.yml` runs on every push once the folder is a GitHub repository: `gdformat --check`, script parsing, handling, bot laps and the rendered feature suite. The feature suite runs on Mesa's software OpenGL under Xvfb, using the renderer's OpenGL fallback; the workflow switches off anisotropic texture filtering for that run only, because software anisotropic sampling takes minutes per frame. The same trick applies to any local software-rendered run (Vulkan lavapipe or llvmpipe). Format before committing with `gdformat -l 110 scripts tests` (`pip install "gdtoolkit==4.*"`).

Old run logs live in `tests/logs/` (git-ignored).

The separate `.github/workflows/macos-native.yml` workflow downloads the pinned Mac editor/templates, builds and verifies a universal ad-hoc signed app, runs headless native suites, and uploads the ZIP. It does not run the graphical feature suite. This workflow has not yet been executed on GitHub; local Mac results are recorded in [MACOS.md](MACOS.md).

## Manual smoke checklist

1. Launch the executable normally; drive, brake, shift, change camera and reset. Confirm engine pitch and tire/surface effects are sensible.
2. Open Help, select chapters and scroll. Open garage/settings/library, including at a smaller window size. Check all buttons/fields are reachable.
3. Open garage and adjust settings; verify changes apply and persist across sessions.
4. Connect an existing racing data folder via Circuits → Choose folder; verify portable setups, ghosts and records load.
5. Import a setup/ghost from a temporary folder. Confirm the selected save folder and avoid overwriting real user files during validation.
6. If a real controller is available, exercise triggers, signed steering, remapping, disconnection and pause/reset. Synthetic events do not establish hardware compatibility.

## Common failure modes

- **Could not resolve class:** check the directly named/preloaded script with `--script ... --check-only`; it often exposes the underlying parse error.
- **No test output or app hangs:** inspect stderr for errors before the runner's quit. Do not count a launched process as a pass.
- **Export cannot save screenshots:** tests must use `user://` in exports. `OS.has_feature("editor")` selects source output; do not rely on a `standalone` feature flag.
- **No sound:** check mute/levels, blocked state, engine/player setup and system output device. Headless runs cannot validate audible playback.
- **Sandbox certificate/save errors:** the host may restrict Windows certificate-store or user-data access. Report the environment condition distinctly from application failures and rerun with an authorized native environment.
- **Stale executable:** source edits do not patch `build/RacingSim.exe`; export again. Close a running executable if Windows prevents replacement.

## Release boundary

The preset embeds resources in one Windows x64 executable. Keep the Godot license and third-party notices beside it, plus `PLAY.txt`. `tests/*`, `tools/*`, `packaging/*` and `build/*` are excluded from game resources; the runtime verification script is included so the exported product can be exercised. JSON data/tracks and Markdown docs must be explicitly included. The macOS preset creates a universal ad-hoc signed app; see MACOS.md. Public notarization, installers, multiplayer, steering-wheel FFB and nonlocal GPU validation are not established by local delivery.

## Graphics review

`-- --audio-review` is a bounded source/export check for the recorded engine bank and amber circuit lighting. It captures actual mixer PCM at five RPMs, full load/coast, mute, pause, zero engine volume and all three car voices, checks finite unclipped output and eight looping assets, then captures Grid/Eau Rouge/Kemmel at night. Repeat with `--rendering-method gl_compatibility`. Output is isolated under `tests/audio-study/<backend>` or exported `user://native-tests/audio-review/<backend>`. It does not replace a subjective listening review or the full performance benchmark.

Rebuild the bank with `--headless --path . --script tools/decode_engine_recordings.gd`, then `python tools/build_engine_audio.py` using the pinned existing NumPy runtime. Sources/edits/hashes are recorded alongside the assets and in THIRD-PARTY.md. No build-time download is needed when the vendored sources are present.

Use `-- --art-review` for the lighting/resolution/view matrix described below and in [ART-DIRECTION.md](ART-DIRECTION.md). Test storage is isolated as in the feature suite. It works in source and exported builds, including `--rendering-method gl_compatibility`. The feature runner checks Spa/296 startup, picker consistency, an exterior-facing hull normal and the night-light nodes. It also checks wheel steering/phase/suspension, body heave/roll, brake emission and ghost transparency/hidden labels/absence of headlights. Native Simulation remains the reference handling model; the separate Simcade path has its own explicit targets.

## 2026-09-21 PS2 / Simcade verification

Run `tests/dynamics.gd` and `tests/laps.gd` once without extra arguments (Simulation) and once with `-- --simcade`. The default application model differs from the historical headless constructors. Do not change the Simulation test bands to accommodate Simcade.

Simcade targets are explicit failure checks: acceleration/stopping/skidpad within ±8% of fresh Simulation, 5–13° lateral plateau ≥95%, large-slip floor 85–88%, full keyboard lock at 80/120/160 km/h <15° body slip, mid-corner lift/brake/power at 90% of measured 60 m skidpad limit ≤8° with ASM 3 or ≤25° aids off, <3° after two seconds of neutral input, measurable lift/trail-brake rotation, one-minute thermal grip ≥0.95, and clean four-circuit bot laps within ±4% of the recorded baseline. Additional checks exercise ASM 1, longitudinal plateau, grass/gravel coasting, dissipative glancing contacts, differential torque distribution and ARB load-transfer balance. The straight-braking yaw reference is symmetric zero yaw; it is not a human trail-braking assessment.

`--features` now exercises all three resolutions, camera-coordinate mapping, actual editor point selection after each switch, daytime/night lamps with unchanged record identity, handling namespace separation, numbered aid controls, old-setup off states and effective-aid save/reload identity. The editor draws near-degenerate OSM strips as finite triangles to avoid renderer triangulation errors.

`--art-review` covers both times of day × 480p/Native × front/rear/profile/Eau Rouge/title/moving HUD. Repeat with `--rendering-method gl_compatibility`. Timing cases include all shadow qualities, 720p, High blur and Native MSAA 2×. Each records 180 unthrottled wall-frame intervals with normal physics/render updates enabled, plus measured GPU time for the world, glow and active history target (excluding native UI). Median/p95 are samples on this PC, not guarantees for every circuit/camera/GPU. GPU sums are not total system latency. Source reports/images live in tests/ps2-forward and tests/ps2-gl; exports write only user://native-tests.

Final measured results, baseline comparison and exact evidence paths are in [PS2-SIMCADE-REPORT.md](PS2-SIMCADE-REPORT.md). Check stderr even when a suite reports zero failed assertions. Run `gdformat -l 110 scripts tests`, parse, rebuild, and run the exported feature suite after final changes. Ordinary launch must reach the title screen; title review uses isolated saves to verify fresh-install defaults.

## Console frontend / Spa acceptance follow-up

The current presentation acceptance record is [PS2-FOLLOWUP-REPORT.md](PS2-FOLLOWUP-REPORT.md). The older report and short `--art-review` timings remain historical evidence, not substitutes for these complete-lap measurements.

```powershell
& ./tools/Godot.exe --headless --path . --script tests/validation.gd
& ./tools/Godot.exe --headless --path . --script tests/showcase_laps.gd
& ./tools/Godot.exe --path . -- --flow-benchmark
& ./tools/Godot.exe --path . -- --compare --round=8
& ./tools/Godot.exe --path . --rendering-method gl_compatibility -- --compare --round=8
python ./tools/build_comparison_sheets.py --round 8 --backend forward
python ./tools/build_comparison_sheets.py --round 8 --backend gl
& ./tools/Godot.exe --path . -- --performance
& ./tools/Godot.exe --path . --rendering-method gl_compatibility -- --performance
& ./build/RacingSim.exe -- --features
& ./build/RacingSim.exe --rendering-method gl_compatibility -- --features
& ./build/RacingSim.exe -- --title-review
```

`validation.gd` requires exact agreement with the old exhaustive crossing detector on 103 cases. `showcase_laps.gd` drives the 296 at Spa in Simulation and Simcade, then repeats with digital keyboard inputs and a scripted late-braking/full-throttle intervention. It records lap time, Kemmel speed, maximum body slip, off-track steps and barrier contacts. It is a conservative regression driver, not a racing-line or car-performance claim.

`--features` includes `ShowcaseBenchmark.flow()` automatically. Controller events on device 31 and keyboard events traverse boot/title/main/mode/car/circuit/loading/grid, complete valid laps through Controls, then reach pause/results/main. Secondary menus, tab navigation, mouse Race/Pause, loading cancellation, attract return, ghost shader preparation and immutable background record writes are checked too. The test-owned Controls instance disables hardware polling and focus cancellation; this is not physical-device validation. The source suite recorded 247 checks after this change; read the current result JSON for future revisions. CI now includes both handling models, showcase laps and validation equivalence. The edited CI workflow has not been executed on GitHub as part of the local Windows benchmark. The preparation-stage 16.667 ms assertion applies on the target RTX 4080; other adapters record finite timing data without inheriting that hardware budget.

`--compare` produces 80 images per renderer: 32 Spa views, six showroom angles/lighting combinations, 38 UI captures and four output variants. `showcase_review.gd` stages camera poses and telemetry; only the independent lap runner establishes driving validity. All 19 pages are captured at both 1280×800 and 1920×1080. Round directories, reference images and derived before/current/reference sheets are ignored. Keep licensed runtime assets distinct from these study-only files.

`--performance` measures 18,104 presented frames per full lap, with four real 240 Hz solver ticks per frame. Vsync is off; 60 setup frames are excluded. The 1920×1080 window measures 640×448, 1280×720 and 1920×1080 world rasters, each in Afternoon/Afterhours. Run both renderers sequentially with other game/test processes closed. The pass threshold is a slowest-1%-mean frame time ≤16.667 ms; also inspect the maximum, individual over-budget frames and CPU/GPU trace to detect stalls hidden by averages. `--performance-case=0` through `5` isolates a diagnostic without replacing the full matrix. A measured frame-time budget on this RTX 4080 is not an all-hardware or Windows-scheduling guarantee. Loading-stage CPU times are recorded and checked separately by the flow suite.

Texture builds use Pillow pinned by `tools/requirements-ps2.txt`; run `tests/build_asset_sources.gd` followed by `tools/build_ps2_textures.py`. The latter refuses an unpinned Pillow version. It records quantization, dimensions and hashes in the committed texture manifest. Import generated assets before exporting. Copy THIRD-PARTY.md, the OFL/CC0 legal texts and PLAY.txt beside the new executable.
