# Native build, verification and troubleshooting

Mac setup, build commands and evidence: [MACOS.md](MACOS.md).

## Commands

Run these PowerShell commands from the `godot` directory. `tools/Godot.exe` and the x64 export templates already exist in this workspace. Paths in the preset are project-relative. A source checkout on another machine must supply a compatible Godot 4.6.2 editor.

```powershell
# Parse the root script and its preloaded dependencies.
& ./tools/Godot.exe --headless --path . --script scripts/game.gd --check-only
# Every headless suite in tools/gates.json, in parallel.
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All
# Plus the windowed feature check (the same as -- --v2-present); do not add --headless.
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All -Features
# Build and verify the actual deliverable.
& ./tools/Godot.exe --headless --path . --export-release "Windows Desktop" build/RacingSim.exe
& ./build/RacingSim.exe --headless -- --v2-export-check
```

`--` separates engine options from game arguments. Ordinary launch does not run tests. When scripting Windows GUI executables, use `Start-Process -Wait -PassThru`.

The pre-rebuild game and its suites (`tests/laps.gd`, `handling.gd`, `validation.gd`, `showcase_laps.gd`, `scripts/verification.gd`, the `--art-review`/`--compare` captures) were deleted in P7-01 (2026-09-23); they are in git history only. P7-01b merged `tests/dynamics.gd` into `tests/v2/aids_simcade.gd` and recorded the planar CarModel's figures for `flat_equivalence.gd`.

## Which checks to run

| Change | Relevant checks |
|---|---|
| Pure explanatory comments/technical Markdown | Review facts, paths and code references; parser if scripts touched |
| Menus, HUD, audio, storage/input | `front_end` gate plus `-Features`; inspect stderr |
| Car, surfaces, tracks, race rules | `run_gates.ps1 -All` (vehicle, track and lap gates) |
| Export filters/resources or release delivery | Export and run `--v2-export-check`; source success alone is insufficient |

## Rebuild (v2) suites

### Gate runner: `tools/run_gates.ps1`

Run from `godot/`:

```powershell
./tools/run_gates.ps1              # suites affected by this branch's changes (vs origin/main)
./tools/run_gates.ps1 -All         # every gate — required before merging to main
./tools/run_gates.ps1 -All -Perf   # plus µs timing budgets, run alone (vehicle/surface/track changes)
./tools/run_gates.ps1 -All -Features   # plus the windowed feature suite (game/UI changes)
```

The runner reads `tools/gates.json`, launches suites in parallel Godot processes (16 by default), reads stderr and each suite's `RESULTS` JSON line or legacy baseline diff, and prints one summary. Exit 0 only when all selected gates pass. Parallel runs set the environment variable `RACINGSIM_PERF_GATES=0`, so timing budgets print but do not gate; `-Perf` re-runs the timing suites serially with budgets enforced. A timeout (default 600 s) counts as a failure. Long suites split for parallelism via `--car` and `--part` arguments (see `tests/v2/gates_env.gd` for the helpers).

`tools/gates.json` maps each suite to dependency-path groups (`vehicle`, `track`, `game`). The default (no `-All`) runs only suites whose paths the branch touched. Add a new suite as an entry in `gates.json` with its dependency paths.

After a failed run, `python3 tools/gate_triage.py [log folder]` (default: the newest folder under `tests/logs/`) gives each failed suite a likely cause and next step: script error, regression, timing under parallel load (a suite that ignores `GatesEnv.perf()`), real slowdown in the `-Perf` pass, baseline drift, stderr warning, asset/import, environment. Script errors are read from the log; the other causes come from one TypeSafe Jev request, so it needs `TYPESAFE_API_KEY` (`--dry-run` prints the request without it). Answers below `--min-confidence` (0.6) say "needs a person". It writes `triage.json` beside the logs. It is advice only: whether a gate passed is still decided by the runner.

### v2 test suites

All suites are headless (`--headless --path . --script tests/v2/<suite>.gd`). Each prints a `<NAME> RESULTS {json}` line.

| Suite | What it checks | Notes |
|---|---|---|
| `chassis_spike.gd` | Rest on flat, crest takeoff, bowl lateral demand, free-flight angular momentum, 1 m drop landing, determinism (60 s SHA-256 full-state hash), per-tick cost | Timing gates only with `-Perf` |
| `surfaces.gd` | Analytic TestSurface shapes (flat, ramp, bowl, crest, ditch, step, block): normals vs gradient, ray hits vs brute-force march, defining quantities, coasting on a grade vs g sin θ | 34 checks |
| `suspension.gd` | Cross-weight / warp vs rigid-body statics, roof drop, side drop, ditch weave max tilt and body penetration, close two-deck regression | 12 checks |
| `static_friction.gd` | Braked car on 8–37° slopes (creep < 0.004 mm/s), friction-limit slide on grass, unbraked rolling matches analytic rate, hold-release-rebrake cycle | 6 checks |
| `energy_wall.gd` | Energy conservation (free-rolling coast, ΔKE < 0.5%), 37° concrete wall at 150 km/h (all wheels down, body roll matches skidpad gradient × g sin 37°, path error < 1 m) | 4 checks |
| `flat_equivalence.gd` | CarBody vs the recorded CarModel figures (`docs/rebuild/carmodel-reference.json`): tyre peaks exact; 0–100, 100–0, 150 m skidpad and top speed within ±3% on the massless wheel, and within ±5% with tyre compliance, per car and handling model | Split by `--car` |
| `aids_simcade.gd` | Simulation dynamics bands and the full Simcade suite (ASM, keyboard lock, thermal grip, grass/gravel, differential, ARB) on CarBody over analytic flat roads, with the pre-rebuild `tests/dynamics.gd` thresholds | 114 checks; split by `--car` / `--part simulation\|simcade` |
| `footprint.gd` | Rigid-tyre envelope over a 5 cm step (within 0.5 mm of analytic), bit-identical to centre ray on smooth ground (1200 poses), TrackSurface kerb road cost < 300 µs | 10 checks; timing gate with `-Perf` |
| `barrier.gd` | Head-on 300 km/h into concrete/armco/tyre walls (no pass-through), glancing 150 km/h (energy-only loss), leaning on a wall 3 s, flying over a wall (0 contacts), oblique 300 km/h | 6 checks; timing gate with `-Perf` |
| `props.gd` | Cones, bollards and marker boards: rest on flat and on a ramp, 1 m tumbling drop, hits at 30/100/200 km/h (no pass-through of car or ground, car speed loss), momentum in free fall, wall bounce, determinism, proving-ground placement, cost | 13 checks; timing gate with `-Perf` |
| `race.gd` | `race.gd` `update_asset()` on the proving ground's gates: scripted lap and sector times against distance / speed, schema-2 ghost samples (9 numbers, ~30 Hz), delta and ghost pose, cut, off-track, reverse and reset, ghost-document validation, a bot lap matching the laps gate | 10 checks |
| `track_asset.gd` | TrackAsset validation (accepts fixture, rejects 8 broken variants), timing-gate crossing, deck resolution, TrackSurface contact, 296 integration lap, per-tick cost | 23 checks; timing gate with `-Perf` |
| `road_tool.gd` | RoadPath + RoadBuilder: analytic straight heights/bank, a proving loop built with the tool (idempotent re-bake, tessellation, kerb/surface ids, grid slots), 296 lap | 16 checks |
| `road_tool_v2.gd` | Sausage and ribbed kerbs, per-side verges and runoff, inset ditch (within 2 mm of TestSurface.ditch), elevation spline C2 continuity, grid configuration | 11 checks |
| `walls.gd` | WallPath (freehand/road-following): face hit on layer 2 only, road-following base within 0.15 mm of the analytic edge, whole-loop closure, validation rejects bad kinds/layers, scatter layout | 8 checks |
| `terrain.gd` | TerrainPatch: analytic heightmap within 1 cm, chunk-seam continuity, road-stitch (verge match within 2 cm, no terrain poke above road), 296 rest and drive on terrain, 8M-triangle bake performance | 7 checks; timing gate with `-Perf` |
| `road_density.gd` | Variable lateral road-station density: incompatible count falls back, analytic cross-section match, watertight collision mesh (0 boundary cracks), seam height-step < 1 mm, UV continuity, proving ground scene size | 6 checks |
| `scenery.gd` | Scenery kit components (CatchFence, Grandstand, Gantry, Billboards, MarshalPost, PitBuilding): layer-2 collision where required, validation, kerb paint, proving-ground integration | 11 checks |
| `proving_ground.gd` | Built proving ground on TrackSurface: crest takeoff speed, bowl lateral demand, compression load, ditch ride depth, BotLine laps (Simulation + Simcade), kerb crossings at 60/120 km/h | 25 checks |
| `laps.gd` | BotDriver on every shipped TrackAsset (proving ground, Spa), all three cars in both handling models: valid lap, zero off-track wheel-ticks, zero wall and prop contacts; records or compares against `docs/rebuild/laps-v2-baseline.json` | Split by `--car`; see below |
| `front_end.gd` | V2 menu car/TrackAsset choice, Spa bake-on-load cache, drive/menu return, schema-2 ghost and sector persistence, distinct track record keys | Runs with `-- --v2-flow-test`; uses `user://native-tests/v2` |
| `test_surfaces_scene.gd` | The `scenes/proving/test_surfaces.tscn` drive scene: car settles on each analytic shape, controls respond, visual adapter poses correctly | 14 checks |

### `tests/v2/laps.gd` arguments

```
--car <preset>        Run only this car (roadster, gt, f296gt3). The gate runner splits by car.
--record              Record new baselines into docs/rebuild/laps-v2-baseline.json instead of comparing.
--diag                Print per-tick diagnostics (position, speed, off-line distance).
```

The baseline file `docs/rebuild/laps-v2-baseline.json` stores one lap time per `<track> <car> <handling>` key. A change that moves a lap by more than 2% fails the gate; re-record deliberately with `--record`.

The Spa bank warning recorded in earlier rebuild runs was resolved by F-P6-01b. The 2026-09-23 P4-06 `-All` run passed 42/42 gates with empty stderr. To check a Windows export's packaged generators and Spa heightmap, run the exported executable with `--headless -- --v2-export-check`; it prints `V2 EXPORT PASS` and exits.

### v2 game probes (windowed unless noted)

- `tools/Godot.exe --headless --path . -- --v2-smoke`: 120 ticks of the v2 game, pose and interpolation sanity.
- `tools/Godot.exe --path . -- --v2-visual-smoke`: the same, with rendering.
- `tools/Godot.exe --path . -- --v2-present`: the bot drives two proving-ground laps at 3x speed while the camera cycles all five modes. It checks a valid lap, the ghost on lap 2, the minimap, camera modes and engine audio, then runs the Look-3 presentation check (`scripts/presentation_check.gd`): six display modes (native + Sharp UI, 720p, 480p Authentic, 480p Sharp UI 4:3 RGB555, 480i CRT, night), each with raster/UI viewport sizes, frame time (`LOOK TIMINGS`), screenshots in `user://look-3/` and real mouse clicks, arrow keys and a pad A press that must reach the right menu control. It prints `V2 PRESENT PASS` and saves `user://v2-present.png` to look at. `-- --v2-look [--v2-track=spa]` runs only the presentation check. It also runs on an exported exe (`RacingSim.exe -- --v2-present`).
- `tools/Godot.exe --path . --script tests/v2/night_screenshots.gd -- --v2-flow-test` (Look-2, windowed): Afterhours captures of the proving ground, Spa and the Nordschleife start into `docs/rebuild/screenshots/look-2/`, each view's draw calls and GPU time with the lamps shown and hidden, and a whole-lap Spa frame-time sweep. Prints `NIGHT SHOTS RESULTS`; look at the images.
- `RacingSim.exe --headless -- --v2-export-check` (exported builds): `V2 EXPORT PASS` when the generators and every data file they read are inside the package.

## Continuous integration and formatting

`.github/workflows/gates.yml` runs on every push (not on pull requests; the branch is already tested by its pushes) on ubuntu-latest (`tools/ci_gates.py`): `gdformat --check`, the script parse check and every headless suite in `tools/gates.json`, with timing gates off (`RACINGSIM_PERF_GATES=0`).

- **Numbers:** suites compare against their recorded baselines on Linux exactly as on Windows (`ci_gates.py` `PLATFORM_TOLERANCE` is empty).
- **Windowed and export jobs:** `.github/workflows/gates.yml` also runs `features` (`--v2-present` under xvfb with Mesa software GL; fails on any failed check or any stderr) and `export-check` (a Linux export through the "Linux Check" preset, which shares the Windows and macOS file filters, then `--v2-export-check` on the packaged binary; the job also fails if the presets' filters differ). Windows and macOS exports and real-GPU timing still run locally before a release.

Format before committing with `gdformat -l 110 scripts tests` (`pip install "gdtoolkit==4.*"`).

Old run logs live in `tests/logs/` (git-ignored).

There is no macOS CI workflow; macOS exports are built locally from the macOS preset (`tools/macos.zip` template). See [MACOS.md](MACOS.md).

## Manual smoke checklist

1. Launch the executable normally; drive, brake, shift, change camera and reset. Confirm engine pitch and tire/surface effects are sensible.
2. Open garage, settings and pause at a smaller window size. Check all buttons/fields are reachable.
3. Open garage and adjust settings; verify changes apply and persist across sessions.
4. Drive a lap on each circuit; confirm the record, ghost and sectors persist after a restart (`user://v2`).
5. If a real controller is available, exercise triggers, signed steering, remapping, disconnection and pause/reset. Synthetic events do not establish hardware compatibility.

## Common failure modes

- **Could not resolve class:** check the directly named/preloaded script with `--script ... --check-only`; it often exposes the underlying parse error.
- **No test output or app hangs:** inspect stderr for errors before the runner's quit. Do not count a launched process as a pass.
- **Export cannot save screenshots:** tests must use `user://` in exports. `OS.has_feature("editor")` selects source output; do not rely on a `standalone` feature flag.
- **No sound:** check mute/levels, blocked state, engine/player setup and system output device. Headless runs cannot validate audible playback.
- **Sandbox certificate/save errors:** the host may restrict Windows certificate-store or user-data access. Report the environment condition distinctly from application failures and rerun with an authorized native environment.
- **Stale executable:** source edits do not patch `build/RacingSim.exe`; export again. Close a running executable if Windows prevents replacement.

## Release boundary

The preset embeds resources in one Windows x64 executable. Keep the Godot license and third-party notices beside it, plus `PLAY.txt`. `tests/*`, `tools/*`, `packaging/*` and `build/*` are excluded from game resources; the runtime verification script is included so the exported product can be exercised. JSON data/tracks and Markdown docs must be explicitly included. The macOS preset creates a universal ad-hoc signed app; see MACOS.md. Public notarization, installers, multiplayer, steering-wheel FFB and nonlocal GPU validation are not established by local delivery.

Historical PS2/Simcade and console-frontend acceptance records for the deleted game are in [PS2-SIMCADE-REPORT.md](PS2-SIMCADE-REPORT.md) and [PS2-FOLLOWUP-REPORT.md](PS2-FOLLOWUP-REPORT.md).
