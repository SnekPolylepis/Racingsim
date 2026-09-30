# OPT-01: Ponytail audit and runtime optimization

Owner request, 2026-09-29: branch from the newest work and optimize the project. Base:
`rb/monaco-formula-cars` at `dd0a169`; branch: `codex/optimize-ponytail`.
`git fetch origin` confirmed the current branch was also the newest remote branch by commit date.
Work stays on this branch for review rather than following the queue's automatic merge-to-main loop.

## Complexity audit

The audit covered runtime call paths and resource references in the game loop, car builders,
timing/projection, lights, HUD, bot planning, contacts/props, particles, controls and persistence,
alongside the gate runner and source/export layout. Performance fixes were assessed separately
from the skill's complexity-only findings. User direction authorizes applying the fixes.

- `delete:` unused procedural Ferrari exterior, including its geometry/livery builders. Keep the existing procedural wheel helper and imported exterior. [scripts/ferrari_296.gd]
- `delete:` unused planar-track night furniture, its material/box helpers, unused preload and corona shader. Existing TrackAsset lights and sodium halo handle lighting. [scripts/night_style.gd, shaders/lamp_corona.gdshader, scripts/visuals.gd]
- `shrink:` constructing procedural wheels, deleting them, constructing kit wheels, then deleting those for imported cars. Build pivots once and only the wheel meshes that survive. [scripts/visuals.gd, scripts/cars/car_kit.gd, scripts/cars/f296gt3.gd, scripts/cars/glb_car.gd]

net: -795 lines of retired implementation/preload/UID metadata, -0 deps possible (applied).
Tests, documentation and optimization code add lines separately; this is not the final diff line count.

## Runtime changes

- Projection retains the exact candidate loop, comparison, segment bounds and hint window; only
  the winning segment builds its tangent, lateral vector, square root and result dictionary.
- Lamp selection uses native binary insertion into the bounded nearest list instead of sorting
  that list after each candidate. The extra nearest lamp still supplies the fade cutoff; energy,
  selection distance and visual range are preserved.
- Telemetry overwrites its oldest slot in a 600-element ring rather than shifting the array.
  Drawing reads from the oldest index, and reset clears both history and index.
- Each night toggle updates a shared facade material once and inspects each distinct shader's
  uniforms once. Deduplication is local to the toggle, so shader edits and different tracks cannot
  inherit stale results.
- Bot target-speed planning advances a single index through sorted distance stations instead of
  restarting its station search for every baked point.
- CarKit creates steering/spin nodes without temporary procedural geometry. Imported Ferrari and
  formula cars also omit temporary kit wheels; roadster and GT keep their final kit wheels.
- A deferred picker-focus callback now checks that its original button is still attached to the
  current picker. Rapid menu rebuilds previously called `grab_focus()` on detached controls and
  polluted the front-end gate's stderr.

No tyre/drivetrain tuning, simulation clock, collision geometry, timing metadata, track versions,
renderer quality settings or user-save schema changed. Historical evidence remains intact.

## Isolated measurements

Three sequential headless runs per revision on this Windows RTX 4080 workstation, with no gate
processes running concurrently. Baseline uses a detached checkout of `dd0a169` and the same
benchmark script as the optimized tree. Median microseconds per call:

| Work | Base | Optimized | Reduction |
|---|---:|---:|---:|
| Hinted projection, 1,200-segment elevated loop, 12,000 calls | 39.785 | 18.436 | 53.7% |
| Lamp pool, 1,000 heads, camera near the far end, 500 calls | 3450.386 | 804.090 | 76.7% |
| Telemetry sampling, 12,000 samples including repeated ring wrap | 0.798 | 0.598 | 25.1% |

These are synthetic CPU timings, not whole-game FPS or GPU measurements. The lamp case intentionally
encounters many progressively nearer candidates; savings depend on lamp count and camera position.
The normal gate run prints timings under CPU contention but does not gate them.
Raw isolated results: `tests/logs/optimization-baseline-{1,2,3}.out` and
`tests/logs/optimization-isolated-{1,2,3}.out` (ignored generated logs).

## Verification

`tests/v2/optimization.gd` checks native segment projection equivalence with no hint and wrapped
hints, chronological telemetry after many wraps/reset, pooled lamp positions/energy against a full
distance sort, daytime visibility, and shared facade shaders/materials across night toggles.
It is registered in `tools/gates.json`. The existing car-model gate additionally covers all four
F2004/RB19 wheels on real and ghost models.

The initial broad gate run passed 37 of 38 suites; front-end assertions passed but detached-button
focus errors made that suite fail. This triggered the focus fix above. That run overlapped early
edits and is not presented as a pristine baseline run.

Final run: `tools/run_gates.ps1 -All -Perf -Features -Jobs 6 -Timeout 600`:
**46/46 gates pass, 0 failed, 310 seconds**, including all 30 car/track/handling lap cases,
six serial timing suites, 21 optimization checks, 76 car-model checks and 77 windowed features.
Logs: `tests/logs/gates/20260929-172205/`. The front-end suite now has empty stderr.
The three original car models retain exactly their previous mesh triangle/draw counts:
roadster 25,658/23, GT 3,744/58, Ferrari 143,328/76.

Windows release export: `build/RacingSim-optimized.exe`; `--headless -- --v2-export-check`
prints **V2 EXPORT PASS**, with empty stderr. Exported `-- --v2-look --v2-track=monaco`
passes **72/72 presentation checks**, with empty stderr and 18 screenshots. Inspected native
day and SD night proving-ground captures and Monaco's native day capture. This short Monaco
presentation drive showed an off-track-invalidated attempt; it is not a clean exported-lap
claim. The separate headless lap gates pass on Monaco in both handling models for all three
gate cars. No macOS export/hardware validation was performed in this Windows session.

`gdformat --check -l 110` passes for all 13 changed GDScript files, and `git diff --check` is clean.

## Remaining limits

Performance figures do not establish macOS hardware behavior. Physics optimizations were confined
to projection and bot planning rather than changing the solver. The separately queued PHYS-IZZ
low-inertia rest instability remains a physics task. No global engine setting or art quality was
reduced to improve timings. Future large-track gains should be based on GPU frame profiles and
measured cache-load/bake costs; this pass does not claim every possible bottleneck is eliminated.
