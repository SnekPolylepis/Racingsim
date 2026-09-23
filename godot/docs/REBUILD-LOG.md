# Rebuild log

Append-only. Newest entries at the bottom. One entry per claim, completion, pause, contract change or decision. Format:

```
## YYYY-MM-DD  <KIND> <task-id>  (<model or owner>)
What was done / decided, commands run, results (pass/fail counts, measurements), what is left.
```

KIND is one of `CLAIM`, `DONE`, `PAUSED`, `FAILED`, `CONTRACT`, `DECISION`, `NOTE`. See [REBUILD-PLAN.md](REBUILD-PLAN.md) §9.

---

## 2026-09-22  DECISION D1–D4  (owner)
Editor removed; 6-DOF chassis; authored 3D tracks; old track format, records and ghosts not carried forward. The CLAUDE.md "don't replace the custom solver" rule is withdrawn. D5–D10 proceed on the plan's defaults until the owner says otherwise.

## 2026-09-22  NOTE pre-rebuild state  (Claude Opus 5.5)
- The workspace is **not a git repository** (no `.git` in `godot/` or the root), although the docs cite commit hashes. P0-01 must resolve this first.
- `godot/.godot/` import cache was missing; regenerated with `--headless --import` (962 resources). Without it the parse check exits 0 but prints font preload errors to stderr.
- Suites on the current code: check-only clean; laps PASS (Monza 261.504 s, Spa 325.175 s); handling 23/0; dynamics 36/0; validation 103/0.
- `build/RacingSim.exe` re-exported 19:24 (110,258,384 bytes); exported `-- --features` 260 checks, 0 failures.
- `export_presets.cfg` references `tools/windows_debug_x86_64.exe`, which does not exist (release export unaffected).

## 2026-09-22  DONE P0-01  (Claude Opus 5.5)
No earlier history exists (the only other repo on the machine, `Desktop/Game`, is an unrelated Electron project with no commits), so this is a fresh repository at the workspace root, branch `main`.
- Commit `Pre-rebuild baseline`, annotated tag `pre-rebuild`. 307 tracked files. Local identity: Zain <zainyasin0723@gmail.com>. No remote.
- `.gitignore` excludes `.godot/`, engine binaries/templates/toolchains in `godot/tools/`, build exes/zips/`macos/`, generated test screenshots/logs/result JSON/capture rounds, root `godot/*.log`, and `godot/reference/` (copyrighted GT4/NFSU2 study images; not to be distributed).
- `.gitattributes` enforces LF (some files were CRLF; working copies re-checked-out as LF). Binary assets marked binary.
- After normalization: check-only clean (empty stderr), handling 23/0, dynamics 36/0.
- **Fresh clones need** Godot 4.6.2 at `godot/tools/Godot.exe` and the release template at `godot/tools/windows_release_x86_64.exe` (not in git), then `--headless --import`.
- Next: P0-03 (baseline capture), P0-04 (legacy exe copy). Pushing to a private remote (e.g. GitHub) is recommended so all models share one origin.

## 2026-09-22  DONE P0-02, P0-03, P0-04  (Claude Opus 5.5)
**P0-02:** `GEMINI.md` added at the root, pointing to `AGENTS.md` and this plan/log. `AGENTS.md` and `CLAUDE.md` already point here.

**P0-03:** baseline captured at tag `pre-rebuild`. Raw stdout is in `docs/rebuild/baseline/*.txt` (all stderr empty). `docs/rebuild/baseline.json` is generated from it by `python tools/baseline_json.py`. Each check keeps its text; `values` lists every number in the line in order, so car names like `f296gt3` contribute numbers too. Match on `text`.

| Suite | Result |
|---|---|
| dynamics (Simulation) | 36/0 |
| dynamics `-- --simcade` | 87 checks, **1 failure (pre-existing)**: roadster Simcade 100-0 38.372 m vs Simulation 42.282 m (−9.2%, band ±8%) |
| handling | 23/0 |
| laps Simulation | Monza 261.504 s, Spa 325.175 s, 0 off, 0 contacts |
| laps Simcade | Monza 261.812 s, Spa 325.687 s, 0 off, 0 contacts |
| showcase_laps (296 @ Spa) | PASS; Simulation-pad 302.44 s, Simcade-pad 302.07 s, keyboard 303.67 s, human-intervention 301.75 s |
| airborne / karussell / track3d / validation | 15/0, 11/0, 37/0, 103/0 |

The Simcade braking failure is not fixed here; it belongs to P2-07 (Simcade retune). It was present before any rebuild work (no source changes since the tag).

Headline flat targets for P2 flat equivalence (Simulation): roadster 0-100 8.24 s / 100-0 42.3 m / 0.72 g; GT 4.48 s / 29.5 m / 1.75 g; 296 GT3 4.12 s / 28.7 m / 1.99 g; tyre peaks 8.6°/0.16, 7.1°/0.13, 6.8°/0.12.

**P0-04:** `build/legacy/RacingSim-pre-rebuild.exe` (19:24 export, 260/0 features) and `RacingSim-macOS-pre-rebuild.zip` (17:07 build, not re-verified), git-ignored. Root launcher `Play Legacy (pre-rebuild).cmd`. **Caution:** the legacy and new builds share the same user data folder (`%APPDATA%/Godot/app_userdata/Racing Sim/`). Once the new build changes the settings/record/ghost formats, give it a different `config/name` or a custom user dir so the two don't overwrite each other's saves (P4-06).

P0 is complete except the remote: GitHub CLI is not installed; pushing to a private remote is up to the owner.

## 2026-09-22  DONE P0-remote  (GPT-6 Sol)

Pushed `main` and tag `pre-rebuild` to [https://github.com/SnekPolylepis/Racingsim](https://github.com/SnekPolylepis/Racingsim) (private). Upstream tracking set.

## 2026-09-22  DONE P2-00  (Claude Opus 5.5) — branch `rb/P2-00-chassis-spike`
**Recommendation: GO on D6(A)**, our own 6-DOF integrator with ray suspension. Needs owner sign-off; review by a different model (GPT-6 Sol suggested) before merge.

Files (all new; no existing file changed):
- `scripts/vehicle/car_body.gd`: `CarBody` extends `car.gd`. Rigid body (position, quaternion, world velocity, body-frame angular velocity per §5.1), semi-implicit Euler at 240 Hz, torque-free gyroscopic term by RK4, one ray per wheel along chassis −Y. Tyre forces in each contact patch's frame; suspension load along the contact normal; gravity a plain −Y force; no pitch/roll clamps, no slope or takeoff special cases. Reuses `configure`, `drivetrain`, `axle_split`, `stability_request`, `pacejka` and the aids unchanged; mirrors the legacy plan-view fields each tick so they keep working.
- `scripts/surface/test_surface.gd`: analytic heightfields (flat, crest with smoothstep-eased curvature, banked cone, void) implementing the §5.2 `contact()` contract.
- `tests/v2/chassis_spike.gd`: 22 checks. Output in `docs/rebuild/spike-P2-00.txt`.

Results (all 22 pass, stderr empty; parse check clean; old handling 23/0 and dynamics 36/0 unchanged in this worktree):
| Check | Result |
|---|---|
| Rest on flat (3 cars) | CG exactly at cgHeight, load 1.0000 mg, tilt 0.000°, no creep |
| Flat equivalence vs baseline | roadster 8.24 s / 42.3 m / 0.72 g (0.0 / 0.0 / −0.6 %); GT 4.46 s / 29.4 m / 1.74 g (−0.4 / −0.3 / −0.6 %); 296 4.12 s / 28.5 m / 1.97 g (−0.1 / −0.9 / −1.2 %). Band ±3 % |
| Crest R = 200 m, no aero (GT) | leaves ground at 160.6 km/h vs √(gR) 159.5 km/h, ratio 1.007; at 1.15× flies 2.83 s, lands, settles |
| Free flight, tumbling 3 s | \|ΔL\|/\|L\| 0.0002, ΔE ≈ 0 |
| 20° banked bowl at design speed 68 km/h (296) | tyre lateral force 0.7 % of mg; body 20.0° from vertical (0.06° from road normal); path error 0.52 m |
| 1 m drop at 50 km/h, neutral | settles 1.31 s (roadster), 0.42 s (GT), 0.40 s (296); peak tyre load 8.6–12.9× static, no instability |
| Determinism | two 20 s runs bit-identical |
| Cost per tick (296) | 57 µs on flat (≈ chassis alone: 1.4 % of a core at 240 Hz); 175 µs on the crest, whose 40-step bisection rays stand in for a heavy query |

Found along the way:
- Explicit Euler on the gyroscopic term gained 1.4 % rotational energy in 3 s of tumbling; RK4 on that term fixed it (0.0000).
- An instant curvature step unloads a sprung car well below √(gR) (the step excites heave). The crest therefore eases curvature in; real tracks with abrupt crests will fly earlier, and that is physical.
- The first landing measurement was confounded by an automatic downshift while coasting (engine braking pitched the car at ~2.3 s). The landing test now runs in neutral.

Limitations to carry into P2 tasks:
- **P2-01:** the tyre block in `car_body.gd` is a copy of `car.gd`'s formula. Extraction must make both call one shared implementation.
- **P2-03:** ARBs are dropped when either wheel of an axle has no ray hit (should act through droop). No unsprung mass, roll centres or anti-dive/squat. Suspension load is applied along the contact normal, not the strut axis.
- **P2-06:** compression rate is first order (mount velocity into the tangent plane). It ignores the ray's own rotation and surface steps, so kerbs need the footprint filter.
- **P2-07:** Simcade was not exercised; the random rough-surface bump on grass/gravel is not ported.
- **P3-00 budget:** the chassis costs ~57 µs, so a TrackSurface ray should cost ≲ 25 µs (use the hint for locality) to keep a car under ~150 µs per tick.
- Pre-existing: `gdformat --check` (vendored gdtoolkit 4.5.0) wants to reformat 6 old files (e.g. `tests/karussell.gd`, `tests/track3d.gd`). Not touched here.

## 2026-09-22  NOTE P2-00 review (GPT-6 Sol)
Independent review of commit 7b182ba on rb/P2-00-chassis-spike. Pushed the branch with upstream tracking before review. Re-ran tests/v2/chassis_spike.gd from this worktree via Start-Process -Wait with redirected stdout/stderr: exit 0, 22 checks, 0 failures, empty stderr. The first sandboxed launch crashed before any checks; the rerun with worktree/cache access passed.
Assessment: GO for D6(A) as a feasibility spike. No basic +X/+Y/+Z, steer, yaw sign, or torque-free gyroscopic sign error found. Follow-ups, ranked:
- P2 car_body.gd:103,137-139: r = -ang.y is a body-axis rate, but the inherited planar steering/ASM code treats r as heading rate. These differ when banked or tumbling; enabled aids can brake or limit steering against the wrong motion. Port and test these paths in P2-07.
- P2 test_surface.gd:141-158: returning no hit when both ray endpoints are above the heightfield misses a crest crossed twice within the segment. For R=200 m near the apex, a horizontal ray from x=-1 to x=1 at y=-0.001 m is above the road at both ends and below it at the apex. Find the first crossing rather than relying on the endpoint sign.
- P2 chassis_spike.gd:303-313: the determinism check compares a string of selected final fields after 20 s. It omits other wheel, tyre, gear and assist state and does not meet the plan's 60 s full-state hash gate; those states could diverge while this check passes.
- P3 chassis_spike.gd:239-251: the bowl check sums signed per-wheel lateral tyre forces before taking the absolute value. Large opposing tyre forces can cancel and satisfy the 5% limit. Measure per-wheel magnitudes if the intent is negligible tyre work at each corner.
No implementation code was edited.

## 2026-09-22  NOTE P2-00 review response  (Claude Opus 5.5)
All four findings accepted. Spike now 23/23, stderr empty (`docs/rebuild/spike-P2-00.txt` regenerated).
1. **`r = -ang.y` is a body-axis rate** (car_body.gd): agreed it needs work; deferred to **P2-07** as the reviewer suggested. Design note for whoever takes it: the aids compare yaw rate with the tyres' kinematic rate `v·tan(steer)/L`, which lives in the road plane, so the body-normal rate is arguably the right one on a bank and the world-vertical heading rate would be wrong there. P2-07 must decide this explicitly and test ASM/steering assist on the 20° bowl and on a tumble.
2. **Ray missing a hump crossed twice**: fixed. `TestSurface.contact()` now marches 16 samples for the first crossing, then bisects inside that segment (a crossing narrower than max_dist/16 can still be missed; documented in code). The flat closed form now rejects upward rays and hits beyond max_dist. Added regression `ray_over_hump` using the reviewer's exact case: hits at 0.3675 m, expected 0.3675 m.
3. **Determinism check too weak**: fixed. Now 60 s (plan §6) with ASM 5, repeated ABS stops, TC exits, both-way shifts and steering over the crest, compared by SHA-256 of the full mutable state (body, every wheel dictionary, drivetrain, aids, RNG seed). Identical.
4. **Bowl metric could cancel**: fixed; now sums per-wheel |Fy|. **This changed the answer: 4.0 % of mg (was 0.7 % signed).** Still under the 5 % limit but with little margin. P2-05 should separate controller effects from model effects (hold the kinematic steer angle open-loop at design speed and read each axle).
Cost on the crest rose to 193 µs/tick from the extra march samples (test surface only; flat unchanged at 57 µs).

## 2026-09-22  DECISION D6  (owner)
Approved D6(A): our own 6-DOF integrator with ray suspension, Godot used only for geometry queries. P2-00 branch cleared to merge into main. Next: P2-01 (GPT-6 Sol) and P2-02/P2-03 (Claude Opus 5.5).

## 2026-09-22  CLAIM P1  (Gemini 3.8 Flash)
Claiming Phase P1: remove the in-game circuit editor (tasks P1-01, P1-02, P1-03).

## 2026-09-22  CLAIM P2-01  (GPT-6 Sol)
Extract tyre, drivetrain and aids into shared vehicle modules with byte-identical old-suite output and an unchanged P2-00 spike. Working on branch `rb/P2-01-extract-vehicle-modules` in the isolated RacingSim-p201 worktree.

## 2026-09-22  DONE P2-01  (GPT-6 Sol)

Branch `rb/P2-01-extract-vehicle-modules`, extraction commit `0832b84`. The P2-00 spike was pushed to its branch and fast-forwarded to remote `main` before this worktree was made; no force push or local main checkout edit.

Module layout/API:
- `scripts/vehicle/tyre.gd`: shared peak slip, Simcade curve, tyre temperature, Pacejka, contact forces, load sensitivity, combined-slip ellipse, semi-implicit need clamps, aligning torque, rolling/surface drag, heat and wear. Both `CarModel.step()` and `CarBody.step()` call `contact_forces()` and `finish_contact()`; the copied CarBody tyre block is gone.
- `scripts/vehicle/drivetrain.gd`: request shift, axle split, gearbox/clutch/engine/wheel torque step. Calls aids for TC and ABS.
- `scripts/vehicle/aids.gd`: TCS/ASM levels, set TCS, steering caps, stability request, TC and ABS. Both chassis paths call the same steering function.
- `scripts/car.gd` retains thin wrappers for its existing public methods and all existing state fields and wheel keys. Formula order and need clamps were kept.

Commands run from this worktree's `godot/` folder (Godot executable: `C:\Users\Zain's PC\Desktop\RacingSim\godot\tools\Godot.exe`; each launch used PowerShell `Start-Process -Wait -PassThru -NoNewWindow` with stdout/stderr redirected to files):
- `Godot.exe --headless --path . --import` — exit 0, stderr empty.
- `Godot.exe --headless --path . --script tests/dynamics.gd` — identical to `docs/rebuild/baseline/dynamics-simulation.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/dynamics.gd -- --simcade` — identical to `dynamics-simcade.txt`, stderr empty; exit 1 is the recorded pre-existing roadster Simcade 100-0 38.372 m failure.
- `Godot.exe --headless --path . --script tests/handling.gd` — identical to `handling.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/laps.gd` — identical to `laps-simulation.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/laps.gd -- --simcade` — identical to `laps-simcade.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/showcase_laps.gd` — identical to `showcase-laps.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/airborne.gd` — identical to `airborne.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/karussell.gd` — identical to `karussell.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/track3d.gd` — identical to `track3d.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/validation.gd` — identical to `validation.txt`, stderr empty.
- `Godot.exe --headless --path . --script tests/v2/chassis_spike.gd` — exit 0, stderr empty, 23 checks/0 failures. Identical to `docs/rebuild/spike-P2-00.txt` after excluding only the two `cost … µs per tick` lines and their matching `us_per_tick_flat`/`us_per_tick_crest` JSON values.
- `Godot.exe --headless --path . --script scripts/game.gd --check-only` — exit 0, stderr empty; run before and after formatting.
- `Godot.exe --path . -- --features` — windowed run, exit 0, `FEATURE RESULTS` 260 checks with `"failures":[]`. Stderr contains the Godot warning `An input event object is being parsed more than once in the same frame` from unchanged `scripts/showcase_benchmark.gd:135`; this is an exception to the empty-stderr gate for that run and was not fixed in this extraction.
- `gdformat -l 110 scripts/car.gd scripts/vehicle/car_body.gd scripts/vehicle/tyre.gd scripts/vehicle/drivetrain.gd scripts/vehicle/aids.gd` and `gdformat --check -l 110` on the same five files — five left unchanged on check.
- `git diff --check` — no whitespace errors.

Legacy comparisons were line-for-line identical after normalizing CR/LF only. No baseline or test file was edited. The branch is for independent review before merging.

## 2026-09-22  DONE P2-02  (Claude Opus 5.5) — branch `rb/P2-02-test-surfaces` (from the P2-00 branch)
`scripts/surface/test_surface.gd` now has FLAT, PLANE (ramp / side slope), CREST, BOWL, DITCH (Karussell-like trough: floor, 37° walls, smoothstep fillets), STEP (sharp or eased) and VOID. CREST and DITCH share one symmetric integrated profile table (Hermite). All surface maths is 64-bit (see CONTRACT below).
`tests/v2/surfaces.gd`: 34 gating checks, all pass, stderr empty; output in `docs/rebuild/surfaces-P2-02.txt`.
- Every shape: normal vs central-difference gradient ≤ 0.0008° (400 points); 300 tilted rays each hit at the first crossing vs a 2 mm brute-force march (0 wrong), on-surface error ≤ 5.5 µm (float32 ray points).
- Defining quantities: ramp 8°, side slope 37°, bowl 20° (to 0.001°, float32 normals); crest apex curvature −0.005000; ditch wall 37.000°, depth = analytic 1.2057 m; step heights exact.
- **Physical ground truth passes:** coasting in neutral down a 3° grade matches a = g(sinθ − rr·cosθ)·m/(m + 4I/R²) to +0.03 / −0.01 / +0.01 % (roadster / GT / 296), rolling resistance and wheel inertia included.
- Spike re-run: 23/23. Determinism hash is now `d4d0d712c338` (was `85089df13e6e`) because the crest heights are now 64-bit; every other spike figure unchanged (crest ratio 1.00703125, flat numbers identical, bowl share differs in the 8th digit). **Sol's P2-01 identity gate compares against main's `spike-P2-00.txt`, which is unaffected; this branch updates it.**

PROBES (non-gating evidence for later tasks):
- **Precision:** a car drifting at 1 cm/s for 1 s moves 0.010002 m at x = 0 and **0.000000 m at x = 5 km**. `CarBody.pos` is a float32 `Vector3`. → P2-03.
- **Parked on slopes, brakes on:** creeps 7.6 / 5.7 mm/s on 8° (roadster / 296) and 34.9 / 25.7 mm/s across 37°. No static friction at low speed. → P2-04.
- **Karussell line:** 296 eases from the ditch floor onto the middle of the 37° wall at 80 km/h and holds it: body 36.6° from vertical, 0.11 m lateral error, peak tyre load 2.8× static, no buried rays; two wheels briefly unloaded during the entry transition (stiff car over a surface twist; P2-03 to confirm plausibility).
- **Earlier weave probe (replaced):** my first controller didn't track; the car climbed the wall diagonally on two wheels at 75 km/h and rolled over the top edge. Once inverted there is no chassis-ground contact, so it fell into the surface, rays started underground (distance 0 → bump stop) and loads hit 319× static. → P2-03: raise ray origins above the mount; add chassis contact.
- **5 cm step:** sharp step 3.0× / 3.3× static peak load at 50 / 120 km/h (the ray jumps the step: compression steps up with no damper impulse); a 4 cm eased ramp gives 12.3× at 50 km/h (the analytic rate on a 62° face drives the damper hard) but 3.3× at 120 km/h (ramp shorter than one tick). Single-point contact is wrong both ways. → P2-06 tyre envelope.

## 2026-09-22  CONTRACT §5.1 precision  (Claude Opus 5.5)
Added to §5.1: Godot vectors are 32-bit in standard builds; accumulated world-space solver state (position above all) must be 64-bit scalars; vectors only for relative/local quantities; track query frames must keep coordinates small (P3-00). Motivated by the P2-02 precision probe. Affects P2-03 (CarBody state), P3-00 (TrackSurface backend) and P4 (ghosts/replays storing positions).

## 2026-09-22  DONE P3-00  (Claude Opus 5.5) — branch `rb/P3-00-surface-backend` (from P2-02)
**Recommendation: `TrackSurface` = Godot PhysicsServer3D rays (`direct_space_state.intersect_ray`) against a baked triangle mesh; pin `physics/3d/physics_engine = "GodotPhysics3D"` in project.godot.** Cheap to revisit: it sits behind the §5.2 contract.

Method (`tests/v2/surface_backends.gd`, output `docs/rebuild/backends-P3-00.txt`): the real Nordschleife ribbon (14,322 samples) baked into 343,728 triangles in Godot axes (road with its cross-section profile at w/8 spacing plus verges, ~1.5 m along), extents ±3,088 m. 20,000 wheel-style rays (0.6 m above a random road point, tilted ≤ 10°, 1.2 m). Headless; all queries run inside `_physics_process`. Stderr empty.

| Backend | µs/query | Notes |
|---|---|---|
| A: PhysicsServer3D ray, GodotPhysics3D (the project default) | 3.6–4.7 | deterministic on repeat; heights within **0.019 mm** of 64-bit |
| A: PhysicsServer3D ray, Jolt | 3.0–5.0 | deterministic; heights within 0.66 mm of 64-bit |
| B: our own xz grid + Möller–Trumbore, 64-bit GDScript | 18.8–20.2 | exact reference; 0 hit/miss disagreements with A |
| C: parametric ribbon (track3d `elev_at`) | 18.3–20.3 hinted, 92–106 cold | smooth, but ties queries to the spline representation |
| D: tyre cylinder cast + rest info (r 0.345, 0.30 wide) | 44–46 GodotPhysics3D, **23–26 Jolt** | 99.7–99.9 % contacts; a tyre envelope for free |

Run-to-run timing varies ±30 %; ranges are over 3 runs.

Why A over B/C: 4–5× cheaper than either GDScript option, deterministic, works headless, precision is fine at Nordschleife extents (the 64-bit concern from P2-02 applies to accumulated state, not to a 0.02 mm query), and meshes admit hand-modelled pieces (pit lane, junctions) that a spline parameterisation cannot. Faceting is not a reason to prefer C: over 3 km at 5 cm steps the mesh's largest normal step was 0.401° (993 steps > 0.05°) against 0.359° (907) for the "smooth" ribbon, whose normals are themselves interpolated per sample.
Why GodotPhysics3D over Jolt: 35× better query precision for similar ray cost. Jolt only wins on shape casts.

Consequences for later tasks:
- **P3-01:** queries must run in a physics frame. The game already steps the car in `_physics_process`; TrackSurface tests must too (as this spike does), unlike TestSurface tests. Map surface type from the collider (one StaticBody3D per surface type with metadata, per §5.3) or from `face_index`.
- **P3-02 road tool:** tessellate at ≤ 1.5 m along and ≤ w/8 across (what was measured here).
- **P2-06 tyre envelope:** per-wheel budget. Multi-ray footprint: ~4 µs × rays × 4 wheels (5 rays ≈ 80 µs/tick). A cylinder cast gives true tread-curve contact on kerbs but costs 23–46 µs per wheel (92–184 µs/tick). If P2-06 picks the cylinder cast, revisit the engine choice (Jolt halves it).
- Keep backend B as a 64-bit test oracle for TrackSurface.
- Test bug found and fixed: a mirrored (left-handed) query basis is silently accepted by GodotPhysics3D but makes Jolt miss 99 % of cylinder contacts. Build query transforms with right-handed bases.

## 2026-09-22  DONE P3-01  (Claude Opus 5.5) — branch `rb/P3-01-track-asset` (from P3-00)
New files (no existing file changed except the plan/log):
- `scripts/track/track_asset.gd`: TrackAsset root. `validate()` (structural, no physics frame needed), `prepare()` (bakes the lap line), `record_key()`, `station(s)`, deck-aware `project(pos, hint)`, `gates()` + static `crossed(gate, p0, p1)`, `sector_offsets()`, `checkpoint_offsets()`, `grid_slots()`, `minimap(count)`, `surface()`.
- `scripts/track/track_loader.gd`: `list(root)` and `load_asset(path)` → {asset, errors}. Read-only, so it works in an export.
- `scripts/surface/track_surface.gd`: §5.2 contract on physics-server rays (P3-00), layer 1 only, normal always faces back along the ray, errors once if called outside a physics frame.
- `scripts/track/ribbon.gd`: minimal centreline → road/verge triangles + visual mesh (flat cross-section at w/8). Seed for P3-02.
- `tests/v2/track_asset.gd`: 23 checks, all pass, stderr empty; output in `docs/rebuild/track-asset-P3-01.txt`.

Fixture: a figure-eight (x = 240 sin t, z = 120 sin t cos t, y = 4(1 − cos t)); the second pass crosses 8 m above the first. Built in code, packed and saved under `user://native-tests/v2/tracks3d/`, and loaded back through the loader.
- Validation accepts the fixture and rejects 8 broken variants with the right message: missing grid, non-int surface id, surface off layer 1, open lap line, moved root, line beyond 5 km, decreasing sector offsets, empty id. Save/load round trip preserves record key and lap length.
- Lap line 1141.09 m matches the analytic arc length to 0.000 %. Projection resolves the crossing by deck (lower s = 0.0, upper s = 570.5 = L/2).
- Driving the analytic curve for one lap crosses each of 15 gates exactly once, in list order. The start gate ignores the upper-deck pass 8 m above it; the upper-deck sector gate ignores the lower pass.
- TrackSurface: tarmac and grass ids correct, upward normals, road height exact; at the crossing each deck's wheel finds its own deck (y 8.00 / 0.00); all 4 grid slots sit on tarmac.
- **Integration:** the 296 GT3 (CarBody) drives from pole on TrackSurface, steered along the lap line at 70 km/h, and completes a lap through all 15 gates in order: 57.64 s (one lap at 70 km/h ≈ 58.7 s; the controller clips corners), 4 wheels in contact throughout, never off tarmac. Car step with 4 rays: 68 µs/tick.
- Spike (23/23), surfaces (34/34) and parse check still clean.

Bug found and fixed during the task: `gates()` first returned start, sectors, checkpoints as separate groups rather than sorted by lap offset. Timing that walks the list in order then needed two laps, and the first lap check passed with a 115 s "lap". Gates are now sorted, and the lap check bounds the time against one lap at the held speed.

## 2026-09-22  DONE P1  (Gemini 3.8 Flash)
Removed the in-game circuit editor, outline importer, and editor workflows/bindings/UI (tasks P1-01, P1-02, P1-03).
- Deleted files: `scripts/editor.gd`, `editor.gd.uid`, `scripts/outline_import.gd`, `outline_import.gd.uid`, `tests/import.gd`, `import.gd.uid`.
- Scope expanded per review to include `retro_renderer.gd`, `retro_flare.gd`, `showcase_review.gd`, and `showcase_benchmark.gd` to remove live editor references.
- In `game.gd`: removed `editing`, `editor`, `test_from_editor` variables; removed `set_editor`, `new_track`, `save_track`, `save_track_as`, `write_track_named`, `import_track_data`, `choose_outline`, `import_outline`, `start_editor`, and `rename_file`. Cleaned `choose_file` to support only setups and ghosts. Cleaned `delete_file`. Removed saved 2D track read path in `game.gd::refresh_tracks()` so user tracks are no longer listed or loaded, leaving user files untouched on disk.
- Preserved `storage.validate_track()` in `storage.gd` to validate bundled circuits at runtime and in tests.
- In `interface.gd`: removed top toolbar, mode button, pause menu editor entry, outline/JSON import/export/rename/delete/folder buttons. Retained dummy `track_picker` and `car_picker` properties for caller compatibility.
- In `front_end.gd`: removed Circuit editor option from circuits page, removed editor branches in `back()`, `_draw()`, and `_process()`.
- In `instruments.gd`: removed `app.editing` check in `_draw()`.
- In `verification.gd`: removed editor interaction helpers (`click_editor`, `drag_editor`), removed editor test block (retaining track validation and safe name checks), updated bundled circuits check to >= 3, updated handbook chapters check to >= 7.
- Updated documentation and play guides: `docs/PLAYER-GUIDE.md` (removed 3 editor chapters and stray mentions), `build/PLAY.txt`, `packaging/PLAY-MACOS.txt`, `docs/LLM-GUIDE.md`.
- Formatted all modified files with `tools/python-packages/bin/gdformat.exe -l 110`.
- All checks pass:
  - `.\tools\Godot.exe --headless --path . --script scripts/game.gd --check-only` (exit 0, empty stderr)
  - `tests/laps.gd`: Simulation Monza best=261.504 s (0 offSteps, 0 contacts), Spa best=325.175 s (0 offSteps, 0 contacts) (exit 0, empty stderr)
  - `tests/handling.gd`: 23 checks, 0 failures (exit 0, empty stderr)
  - `tests/dynamics.gd`: 36 checks, 0 failures (exit 0, empty stderr)
  - `.\tools\Godot.exe -- --features`: 211 checks, 0 failures (exit 0)
  - Re-exported `build/RacingSim.exe` via `Godot.exe --headless --path . --export-release "Windows Desktop" build/RacingSim.exe`
  - Exported `./build/RacingSim.exe -- --features`: 211 checks, 0 failures (exit 0)
- Ready for owner review and merge to main.

## 2026-09-22  CONTRACT §5.3 track asset  (Claude Opus 5.5)
§5.3 rewritten to match the implementation: root at the origin; Surfaces on layer 1 and Walls on layer 2; TimingLine closed implicitly (don't repeat the first point); Grid markers face −Z down the track; `record_key()` = `id@vN`; metadata defaults; gate bounds ±15 m lateral / ±3 m vertical, `gates()` sorted by lap offset; 3D lap length; minimap computed on demand rather than stored; ±5 km validation; surface queries only in a physics frame.

## 2026-09-22  NOTE P2-01 review (Claude Opus 5.5)
Independent review of `rb/P2-01-extract-vehicle-modules` at `7428ae6`, in a clean detached worktree. **Verdict: APPROVE, merge into main.** No correctness findings.

Code: `tyre.gd`, `aids.gd` and `drivetrain.gd` reproduce the original expressions in the original order, need clamps included. The main risk in an extraction like this is stale locals: `drivetrain.step()` copies fields into locals at the top, but `request_shift()` changes `shift_timer` mid-step and the original re-reads it. That is handled correctly: everything that changes during the step (`shift_timer`, `gear`, `engine_w`, `brake_hold`, `blip_pending`) is read live through `car.*`; only step-invariant values (`speed`, `input`, `asm_cut`, `asm_brakes`) are copied. CarBody passes its 3D body velocities to the shared steering exactly as its old `steering()` read them.

Gates re-run independently (not taken from the DONE entry):
- All 10 legacy suites: stdout **byte-identical** to `docs/rebuild/baseline/*.txt` (CR/LF normalised), stderr empty; dynamics-simcade exits 1 with the known roadster braking failure, reproduced exactly.
- Spike: identical to main's `spike-P2-00.txt` with only the cost lines masked; stderr empty.
- Source `--features`: 260 checks, 0 failures on both main and P2-01. The stderr warning ("input event parsed more than once", `scripts/showcase_benchmark.gd:135`) is **pre-existing**: identical 644 bytes on main. Sol's claim confirmed.
- Trial merge with `rb/P3-01-track-asset` (which carries P2-02 and P3-00): only `REBUILD-LOG.md` conflicts (both appended; keep both entries). On the merged code: parse clean, spike 23/23 and identical to the P2-02 reference (masked), surfaces 34/34, track_asset 23/23, stderr empty.

Findings (non-blocking):
1. **Performance, medium.** The extraction costs **+13 µs per car tick**: 4 interleaved A/B runs of the spike on flat, main median 55.6 µs vs P2-01 68.8 µs (+24 %); crest 190 → 205 µs. Likely cause: the drivetrain and aids now read dozens of fields per tick through `car.*` on another object instead of direct member access, and `tyre.gd` calls back through the car's wrappers. About 0.3 % of a core for one car, so not blocking, but it adds up with AI cars later. Suggested fix (a later, identity-checked task): have `tyre.gd` call its own static `pacejka`/`simcade_curve`/`peak_*` and a local `sg`, and re-measure.
2. **Design, low.** `tyre.gd` is not self-contained: it calls `car.pacejka`, `car.simcade_curve`, `car.peak_slip_ratio()`, `car.peak_slip_angle()`, `car.sg` and reads `car.LAT_B`, so an override on a car class would silently change the shared tyre maths. Same fix as 1.
3. **Cleanup, low.** `finish_contact()` still computes an unused `heat` (it was unused in the original; kept for identity). Remove when identity no longer binds.
4. **Pre-existing, low.** `showcase_benchmark.gd:135` reuses one InputEvent within a frame; the feature suite's source run prints a warning to stderr every time. One-line fix (`duplicate()` the event), separate task.

Merge order: P2-01 into main first; then my stack (P2-02 → P3-00 → P3-01) on top, resolving the log by keeping both sides.

## 2026-09-22  DONE P1-review-fix  (Gemini 3.8 Flash)
Addressed P1 review findings on `rb/P1-remove-editor`:
1. Restored folder selection in `scripts/game.gd` (`choose_folder()`) and `scripts/interface.gd` (`open_library()` "Choose folder…" button) to connect portable racing data folders for setups, ghosts, and records. Kept "Local saves" (`use_local_storage()`). Preserved the removal of user track loading/modifying.
2. Cleaned `godot/README.md`, `godot/docs/TESTING.md`, and `godot/docs/MACOS.md`: removed editor instructions, keybindings, section, and commands for deleted `tests/import.gd`. Preserved dated historical test evidence.
3. Formatted modified scripts with `tools/python-packages/bin/gdformat.exe -l 110`.
4. Verification:
   - Headless check-only: `.\tools\Godot.exe --headless --path . --script scripts/game.gd --check-only` (exit 0, empty stderr).
   - Laps suite: `.\tools\Godot.exe --headless --path . --script tests/laps.gd` (Simulation Monza 261.504 s, Spa 325.175 s; 0 offSteps, 0 contacts; exit 0, empty stderr).
   - Handling suite: `.\tools\Godot.exe --headless --path . --script tests/handling.gd` (23 checks, 0 failures; exit 0, empty stderr).
   - Dynamics suite: `.\tools\Godot.exe --headless --path . --script tests/dynamics.gd` (36 checks, 0 failures; exit 0, empty stderr).
   - Re-exported executable: `.\build\RacingSim.exe -- --features` (211 checks, 0 failures; exit 0; stderr contains expected engine shutdown leaks, 0 script errors).

## 2026-09-22  NOTE P1 review (Claude Opus 5.5)
Checked `rb/P1-remove-editor` at `406db6b` in a clean detached worktree. **Verdict: NOT YET — one real regression; fix, then merge.** Source `--features`: 211 checks, 0 failures.

1. **Regression, must fix: resources leaked at exit.** P1's feature run ends with stderr reporting leaked RIDs (2 Canvas, 18 CanvasItem, 2 Viewport, 2 RenderTarget, 2 ShadowAtlas, 26+41 Texture, 16 ShapedText, 1 Font) and "ObjectDB instances leaked at exit". Main's run has none (its stderr is only the pre-existing 644-byte input-event warning), so the DONE entry's "expected engine shutdown leaks" is wrong: P1 introduced them.
   **Cause:** `interface.gd` still creates `track_picker` and `car_picker` with `OptionButton.new()` "for caller compatibility", but the toolbar that parented them is gone, so they are never in the tree and never freed. Each OptionButton owns a PopupMenu (a Window, so its own viewport, canvas and render target): two orphans account for the paired Viewport/Canvas/RenderTarget/ShadowAtlas counts, and their controls, fonts and text for the rest.
   **Proof:** with only the pickers parented (hidden) under the UI root, a throwaway run's stderr went back to exactly main's 644 bytes, still 211/0.
   **Fix (preferred):** remove the dummy pickers and change their callers to use the front end's pickers or app state directly. Minimal alternative: parent them hidden, or `free()` them on exit.
2. **Test coverage, low.** The 49 removed feature checks (125 → 85 `check()` call sites) are all editor-specific, apart from two thresholds correctly lowered (3 bundled circuits; 7 handbook chapters after 3 editor chapters were removed), with one exception: "atomic replace existing file" (overwrite an existing JSON and read back the new content) was storage coverage, not editor coverage. "Record replacement leaves no incomplete temporary file" still exercises the `.tmp` → rename path, but nothing checks that overwriting yields the new content. Restore it as a one-line check on a setup or ghost file.
3. **Docs, low.** `docs/TESTING.md` still says the feature suite covers "dirty guards"; the only dirty-guard checks were the editor's and were removed. Update the sentence.
4. The feature count 260 → 211 is explained by 1 and 2. The 4 legacy headless results quoted in the DONE entry match the baseline.

## 2026-09-22  NOTE merge P2-01 + P2-02/P3-00/P3-01 (GPT-6 Sol)

Fast-forwarded the isolated `merge/p2-p3` branch from `origin/main` to P2-01 tip `7428ae6` (extraction `0832b84`), then merged Claude's stack tip `1fbb924` with no fast-forward as merge commit `f813a89` (parents `7428ae6` and `1fbb924`). The stack includes P2-02 `2cedfb8`, P3-00 `174842a` and P3-01 `40aa485`. Pushed `f813a89` to GitHub `main` by fast-forward, with no force push. P1 was not merged.

Only `docs/REBUILD-LOG.md` conflicted. Resolved it by keeping the two P2-01 claim/done entries before Claude's six P2/P3 completion, contract and review entries; no entry was lost or duplicated. No source file conflicted.

Verification from the fresh `RacingSim-merge/godot` worktree using `C:\Users\Zain's PC\Desktop\RacingSim\godot\tools\Godot.exe` through PowerShell `Start-Process -Wait -PassThru -NoNewWindow`, with stdout/stderr redirected for every run:
- `--headless --path . --import`: exit 0, stderr empty.
- `--headless --path . --script scripts/game.gd --check-only`: exit 0, stderr empty.
- `tests/v2/chassis_spike.gd`: 23 checks, 0 failures, exit 0, stderr empty. Stdout matches `docs/rebuild/spike-P2-00.txt` except the two `cost … µs per tick` lines and the `us_per_tick_flat`/`us_per_tick_crest` values in final JSON.
- `tests/v2/surfaces.gd`: 34 checks, 0 failures, exit 0, stderr empty.
- `tests/v2/track_asset.gd`: 23 checks, 0 failures, exit 0, stderr empty.
- Legacy `tests/dynamics.gd` Simulation and `-- --simcade`, `tests/handling.gd`, `tests/laps.gd` Simulation and `-- --simcade`, `tests/showcase_laps.gd`, `tests/airborne.gd`, `tests/karussell.gd`, `tests/track3d.gd`, and `tests/validation.gd`: each stdout identical to its `docs/rebuild/baseline/*.txt` reference after CR/LF normalization; every stderr empty. Nine exit 0; dynamics Simcade exits 1 with its identical, known roadster 100-0 failure.
## 2026-09-22  DONE P5-01  (Claude Opus 5.5) — branch `rb/P5-01-data-sources`
Licences and access checked on the publishers' own pages; details and links in `docs/rebuild/data-sources-P5-01.md`. Nothing downloaded or committed.
- **Nordschleife:** LVermGeo RLP DGM1 (1 m, < ±0.3 m height deviation, EPSG:25832, 1 km GeoTIFF tiles), plus DOM1, ground/object laser point clouds and DOP20 orthophotos. All open data under dl-de/by-2.0: free, commercial use allowed, attribution `©GeoBasis-DE / LVermGeoRP<year>, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]`. Check the acquisition year of the Nürburg tiles (national currency spans 2000–2022).
- **Spa:** SPW Wallonia MNT 1 m 2021–22 (LiDAR) and Orthophotos 2023 Été (25 cm), both CC BY 4.0. Caveat: the survey overlaps the 2021–22 circuit works; verify changed corners against the 2023 imagery.
- **Monza (optional):** Lombardy/MiTE DTM LiDAR 1 m listed as CC BY 4.0, but tiles are requested by certified email (PEC) and coverage of the park is unconfirmed.
- Both terrain models **exclude bridges**; Nordschleife bridge crossings need the point cloud, DOM1 or hand modelling. ±0.3 m absolute accuracy means the road surface must be fitted and smoothed, not sampled raw.
- Plan D10 and P5-01 updated.

## 2026-09-22  DONE P1-review-fix-2  (Gemini 3.8 Flash)
Resolved regression and review findings on `rb/P1-remove-editor`:
1. Deleted dummy `track_picker` and `car_picker` from `scripts/interface.gd`. Updated all callers in `scripts/game.gd`, `scripts/front_end.gd`, and `scripts/verification.gd` to use `menu_track`/`menu_car` or direct application state. This eliminates the unparented Window/PopupMenu leak, making stderr completely free of RID/ObjectDB leaks.
2. Restored the storage overwrite check in `scripts/verification.gd`: verified that overwriting an existing JSON file (`Integration.ghost.json`) through `app.storage.write_json` and reading it back yields the new content (`"atomic replace existing file"`). Total feature checks increased from 211 to 212.
3. Cleaned `godot/docs/TESTING.md` and `godot/README.md` to remove obsolete mentions of "dirty guards" from the feature suite summary.
4. Formatted touched scripts with `tools/python-packages/bin/gdformat.exe -l 110`.
5. Verification:
   - Check-only: `.\tools\Godot.exe --headless --path . --script scripts/game.gd --check-only` (exit 0, stderr empty).
   - Laps suite: `.\tools\Godot.exe --headless --path . --script tests/laps.gd` (exit 0, stdout identical to `docs/rebuild/baseline/laps-simulation.txt`, stderr empty).
   - Handling suite: `.\tools\Godot.exe --headless --path . --script tests/handling.gd` (exit 0, stdout identical to `docs/rebuild/baseline/handling.txt`, stderr empty).
   - Dynamics suite: `.\tools\Godot.exe --headless --path . --script tests/dynamics.gd` (exit 0, stdout identical to `docs/rebuild/baseline/dynamics-simulation.txt`, stderr empty).
   - Windowed features: `.\tools\Godot.exe --path . -- --features` (exit 0, 212 checks, 0 failures, stderr contains ONLY the 644-byte input event duplicate warning from `showcase_benchmark.gd:134`, zero RID or ObjectDB leak lines).
   - Re-exported executable: `cmd /c "tools\Godot.exe --headless --path . --export-release ""Windows Desktop"" build\RacingSim.exe"` (clean export).
   - Exported features: `.\build\RacingSim.exe -- --features` (exit 0, 212 checks, 0 failures, stderr 0 bytes / empty).

## 2026-09-22  NOTE P5-01 review fixes  (GPT-6 Sol)
Recorded the verified Spa and Nordschleife sources, licence terms and future attribution requirements in `THIRD-PARTY.md`, as P5-01 originally required. Updated the plan and source notes to reflect that the ledger is now populated. Marked optional Monza's licence and commercial use as unverified until a primary licence record and circuit coverage are confirmed; the linked catalogue page was unavailable during review. Documentation only; no data downloaded or committed. `git diff --check` passed. Feature suite not run at the owner's request.

## 2026-09-22  DONE feature-suite speed-up  (Claude Opus 5.5) — branch `rb/fast-features` (from main `9774d1f`)
Owner request: the windowed `-- --features` run was slow, mostly the two input-driven 296 laps of Spa. Measured on this PC, source run.
- **Before:** ~157 s total; the flow section took 73 s, of which the two laps were ~51 s each (3,042 rendered frames per lap).
- **Profile of one lap** (per physics tick): test driver 220 µs (44 %; its speed plan called `track.pos_at()` 34 times per tick), car step 184 µs (36 %, the legacy car), collisions 35 µs, race 23 µs, the rest < 20 µs each. Rendering was not the main cost.
- **Changes** (behaviour-preserving for everything that already had a baseline):
  1. `showcase_benchmark.gd`: flow laps render one frame per simulated second (`FLOW_TICKS_PER_FRAME = 240`, was 24); every tick still feeds input and steps physics. The performance benchmark keeps 4 ticks per frame.
  2. `track3d.gd`: new `curv_at(s)` = `pos_at(s).curv` computed identically (same search, same interpolation) without building the pose; the showcase driver uses it.
  3. `showcase_driver.gd`: the speed-plan limits are fields (`top_speed`, `corner_accel`, `brake_gain`, `plan_distance`, `plan_step`, `plan_every`) whose **defaults are the old constants**. The feature flow alone uses braver limits (`FLOW_DRIVER`: 75 m/s, ~1 g corners, ~0.8 g braking, 450 m scan at 10 m, re-planned every 4th tick). Swept headless on the exact mirror of the flow laps: 75 m/s / 1 g and 85 m/s / 1.3 g both clean on pad and keyboard; 90 m/s / 1.6 g ran wide at the first corner, so 75 m/s keeps a margin.
  4. The stderr warning on every feature run ("input event parsed more than once") is fixed: `lap()` re-sent the same Escape event object within one frame; the release is now a duplicate.
- **After:** 88–90 s total (−44 %). Each flow lap takes 16–18 s wall (189.4 s / 191.0 s simulated, valid, 0 off-track, 0 contacts). 260 checks, 0 failures. **Stderr empty** (was 644 bytes).
- **Identity:** with defaults, the driver reproduces the old laps exactly: `tests/showcase_laps.gd` stdout is byte-identical to `docs/rebuild/baseline/showcase-laps.txt` (and now runs in 103 s, was 126 s). At the intermediate step (frames only), the flow laps were bit-identical to before (302.070833333141 s / 303.666666666473 s).
- **Not changed:** the feature flow still drives Spa in the 296 through the real input bus on both controller and keyboard, then pause/results/menus; only its lap is faster. The flow's lap times in feature output are now ~189/191 s, not 302/304 s. `docs/TESTING.md` is untouched here because P1 edits it; its "complete valid laps" description remains true.
- When P4 moves the game onto CarBody, re-check `FLOW_DRIVER` still gives clean laps (it was tuned on the legacy car).

## 2026-09-22  NOTE merge P1 + fast-features + P5-01 (GPT-6 Sol)

Pushed `rb/fast-features` and `rb/P5-01-data-sources` with `git push origin rb/fast-features rb/P5-01-data-sources`; ran `git fetch origin`. Created isolated `../RacingSim-merge2` from `origin/main` (`9774d1f`) with `git worktree add ../RacingSim-merge2 -b merge/p1-fast origin/main`. Merged in order with `git merge --no-ff origin/rb/P1-remove-editor` (`c07f7c4`), `git merge --no-ff origin/rb/fast-features` (`6762702`), and `git merge --no-ff origin/rb/P5-01-data-sources` (`ac62edc`). Each merge conflicted only in `docs/REBUILD-LOG.md`; all entries from both sides were retained once in commit-time order. `scripts/showcase_benchmark.gd` auto-merged. `git diff origin/main HEAD --check` passed. `rb/P2-03-suspension-rig` was not merged. After the checks below, `git push origin merge/p1-fast:main` fast-forwarded GitHub main from `9774d1f` to `ac62edc`, without force.

Verification ran from this merge worktree's `godot/` using `C:\Users\Zain's PC\Desktop\RacingSim\godot\tools\Godot.exe` through `Start-Process -Wait -PassThru -NoNewWindow`, with stdout and stderr redirected under `tests/logs/merge-p1-fast/`. Legacy comparisons normalize CR/LF only. Every run exited 0 and every stderr file was **0 bytes**.

| Command (from `godot/`) | Result | Wall time | Stderr |
|---|---|---:|---:|
| `--headless --path . --import` | Imported | 7.22 s | 0 B |
| `--headless --path . --script scripts/game.gd --check-only` | Parse clean | 0.47 s | 0 B |
| `--headless --path . --script tests/dynamics.gd` | Stdout identical to `baseline/dynamics-simulation.txt` | 26.55 s | 0 B |
| `--headless --path . --script tests/handling.gd` | Stdout identical to `baseline/handling.txt` | 1.84 s | 0 B |
| `--headless --path . --script tests/laps.gd` | Stdout identical to `baseline/laps-simulation.txt` | 50.06 s | 0 B |
| `--headless --path . --script tests/showcase_laps.gd` | Stdout identical to `baseline/showcase-laps.txt` | 103.10 s | 0 B |
| `--headless --path . --script tests/v2/chassis_spike.gd` | 23 checks, 0 failures | 18.69 s | 0 B |
| `--headless --path . --script tests/v2/surfaces.gd` | 34 checks, 0 failures | 3.33 s | 0 B |
| `--headless --path . --script tests/v2/track_asset.gd` | 23 checks, 0 failures | 2.68 s | 0 B |
| `--path . -- --features` (windowed source) | **212 checks, 0 failures**; both flow laps valid at 189.425 / 191.033 s, each with 0 off-steps and 0 contacts | **70.15 s** | 0 B |
| `--headless --path . --export-release "Windows Desktop" build/RacingSim.exe` | Exported 110,308,968-byte exe | 4.37 s | 0 B |
| `build/RacingSim.exe -- --features` (windowed export) | **212 checks, 0 failures**; same valid flow laps and zero off-steps/contacts | **60.20 s** | 0 B |

The 212 checks are P1's 211 plus the restored storage-overwrite check. The git-ignored `tools/windows_release_x86_64.exe` export template was absent in the merge worktree, so it was copied from the original repo's `godot/tools/` before export. The owner chose to leave Gemini's `godot/build/RacingSim.exe` untouched; the verified exe remains at `C:\Users\Zain's PC\Desktop\RacingSim-merge2\godot\build\RacingSim.exe`. The merge worktree is retained so that binary remains available.

## 2026-09-22  DONE P2-03  (Claude Opus 5.5) — branch `rb/P2-03-suspension-rig` (from main `9774d1f`)
Changed: `scripts/vehicle/car_body.gd` (chassis), `scripts/surface/test_surface.gd` (BLOCK shape), `tests/v2/surfaces.gd` (precision probe reads the 64-bit state). New: `tests/v2/suspension.gd` (11 checks), output `docs/rebuild/suspension-P2-03.txt`. `car.gd` and the shared vehicle modules are untouched.

What changed in CarBody:
1. **64-bit world state (§5.1).** `pos_x/y/z` and `vel_x/y/z` are 64-bit scalars and integrate in 64-bit; `pos`/`vel` remain as Vector3 properties for relative and presentation use (setters write the scalars). A car drifting 1 cm/s for 1 s now moves 0.010000000 m at x = 0 and at x = 5 km; before, it did not move at 5 km.
2. **Suspension rays start 0.5 m above the mount.** Ground rising past the mount now yields a continuous, monotonic bump-stop force from the real penetration (pressed 0 to 0.69 m into flat ground in 1 cm steps, past the mount at 0.50 m: monotonic, largest step 30.1 kN against a bump-stop scale of 28 kN).
3. **Anti-roll bars act through a lifted wheel.** A lifted (massless) wheel rises until its own spring balances the bar, so the grounded wheel sees the bar in series with that spring (extra rate arb·k/(k+arb)) and the body gets nothing at the lifted corner. Previously the bar switched off. `CarBody.arb_pair()` is static and unit-tested against the closed form and the lifted wheel's force balance.
4. **Chassis-to-ground contact.** 10 body-box points (6 sill, 4 roof), each a penalty spring (200 kN/m) plus a closing-only damper (12 kN·s/m) plus sliding friction µ 0.6, clamped like the tyre need clamps. Probed only when a wheel is off the ground, the car is tilted past ~25°, a corner is near its bump stop, or it is falling faster than 3 m/s. Roof points only past ~60° of tilt. Ordinary driving never probes (0 point-ticks through hard acceleration and braking on flat for all 3 cars).

Suspension suite, 11/11, stderr empty:
- **Warp / cross-weight vs rigid-body statics** (FL wheel jacked 3 cm; axle twist rate K = spring + 2·ARB; expected axle load split δ·Kf·Kr/(Kf+Kr)): mean axle ΔL within −1.9 % (roadster, ARBs on), −0.7 % (roadster, off), −0.1 % (296, on), +0.1 % (296, off). **Load centroid 0.0 mm from directly under the CG in all four cases** (exact equilibrium). The roadster's front/rear asymmetry (489 / 575 N) is its body roll moving the CG sideways, which the small-angle formula leaves out; the centroid check covers it.
- Roof drop from 0.8 m: rests on the roof, CG 0.905 m up (roof plane 0.920 m), 1.6 cm resting penetration, 7.2 cm peak during impact. Side drop: tips back onto its wheels (a physical outcome), no penetration at rest.
- P2-02's runaway ditch weave: max tilt 43° (it no longer rolls over), CG below the surface on 0 ticks, peak tyre load 20× static (was 319× and a fall-through).

Other suites on this branch: parse clean; spike 23/23 (flat equivalence unchanged, crest ratio 1.007; roadster 1 m drop now settles in 0.95 s with peak 5.6× static, down from 1.31 s / 8.6×, because the sills now touch when it bottoms; GT 1.15× crest airtime 2.44 s, down from 2.83 s); surfaces 34/34; track_asset 23/23; legacy dynamics and handling byte-identical to the baseline. `docs/rebuild/spike-P2-00.txt` and `surfaces-P2-02.txt` regenerated (new determinism hash; the precision probe now reads the 64-bit state).

Cost: spike on flat 75.6 µs/tick (P2-01 main median 68.8 µs; about +7 µs from the property views, bar logic and contact gating). Crest 240 µs (the TestSurface bisection rays dominate; body probes fire while airborne).

Not done / carried forward:
- Unsprung mass, roll centres and anti-dive/squat geometry; load still applied along the contact normal rather than the strut axis.
- Heightfield test surfaces report an upward normal even on a sharp step's vertical face, so body contact there pushes up, not back. Real meshes (TrackSurface) give face normals; walls and barriers are P4-03.
- Body box is 10 points: coarse, with no edges between them. Enough for resting and landing, not for detailed scraping.
- Braked cars still creep on slopes (P2-04); single-ray kerb response (P2-06); aids yaw-rate frame (P2-07).

## 2026-09-22  NOTE P2-03 review (GPT-6 Sol)
Independent review of original commit `a4ea593` in a detached worktree. **Verdict: merge.** The body frame and force signs, lifted-wheel ARB series rate, and warp formula `delta * Kf * Kr / (Kf + Kr)` with `K = spring + 2 * ARB` are consistent with the stated massless-wheel model. No blocking correctness finding.

Findings, ranked by severity:
1. **Medium, follow-up — `scripts/vehicle/car_body.gd:190-203`:** lifting each ray origin 0.5 m can select an upper road deck that is above the wheel mount but below the lifted ray origin. The flat and single-heightfield tests do not cover a close overpass. A deck within this clearance needs a targeted two-deck regression before shipping an authored overpass; the current 8 m deck-separation fixture is unaffected.
2. **Low — `scripts/vehicle/car_body.gd:312-313`:** the standstill hold computes and assigns through the 32-bit `vel` Vector3 property, rounding the three 64-bit scalar velocities each held tick. Position still accumulates through `pos_x/y/z` in 64-bit; the precision test does not exercise this branch. Use scalar components here when full 64-bit velocity accumulation is required.
3. **Low — `scripts/vehicle/car_body.gd:345-363`:** body-contact torque uses the body point arm rather than the ray's hit-point arm. At penetration, this makes the torque lever longer than the contact point by up to the penetration depth. The tested roof drop is stable, but an angled deep strike can receive excess torque.
4. **Low, test gap — `tests/v2/suspension.gd:259-272`:** the ditch assertion checks whether the CG goes below the surface and limits tyre load, but does not check sill/roof penetration at their world positions. Flat roof/side drops do check body points separately.
5. **API caution — `scripts/vehicle/car_body.gd:39-52`:** `pos` and `vel` are 32-bit Vector3 views. Current code writes the scalar position components directly and has no component assignment through these views; future callers should not assume `c.pos.x = value` preserves double precision.

Independent gates via `Start-Process -Wait -PassThru -NoNewWindow`, redirected stdout/stderr: `--headless --path . --import`, `tests/v2/suspension.gd` 11/0, `chassis_spike.gd` 23/0, `surfaces.gd` 34/0, `track_asset.gd` 23/0, `scripts/game.gd --check-only`, and legacy `tests/dynamics.gd` 36/0 and `tests/handling.gd` 23/0, both stdout-identical to their baselines after CR/LF normalization. All exit 0; every stderr file is empty.

## 2026-09-22  NOTE merge P2-03 (GPT-6 Sol)
Merged approved `rb/P2-03-suspension-rig` review tip `d9401f8` into current main `baccc7b` as merge commit `ca0f9f4`; pushed `merge/p203-reviewed:main` by fast-forward, no force. `rb/P3-02-road-tool` was **not merged**: its independent review verdict is fix first (downward mesh winding and destructive Grid re-bake). P3-02b and P5-03 remain on hold.

Only `docs/REBUILD-LOG.md` conflicted. Kept all 28 sections already on main and appended the two unique P2-03 DONE/review sections in order; `REBUILD-PLAN.md` and all source files auto-merged. Shared sidecar UIDs in the P2/P3 source branches were verified identical; no P3 sidecars were merged from P3-02. `git diff origin/main HEAD --check` passed before the push.

Verification from the isolated `RacingSim-merge3/godot` worktree, using `C:\Users\Zain's PC\Desktop\RacingSim\godot\tools\Godot.exe` through `Start-Process -Wait -PassThru -NoNewWindow`, stdout/stderr redirected to `tests/logs/merge-p203/`:
- `--headless --path . --import`; `--headless --path . --script scripts/game.gd --check-only`: exit 0, empty stderr.
- `--headless --path . --script tests/v2/suspension.gd` 11/0; `chassis_spike.gd` 23/0; `surfaces.gd` 34/0; `track_asset.gd` 23/0: exit 0, empty stderr.
- Ten legacy invocations: `tests/dynamics.gd` Simulation and `-- --simcade`, `tests/handling.gd`, `tests/laps.gd` Simulation and `-- --simcade`, `tests/showcase_laps.gd`, `tests/airborne.gd`, `tests/karussell.gd`, `tests/track3d.gd`, `tests/validation.gd`. Every stdout matched its `docs/rebuild/baseline/*.txt` after CR/LF normalization and every stderr was empty. Dynamics Simcade exited 1 with the byte-identical known roadster braking failure; the other nine exited 0.
- Windowed `--path . -- --features`: 212 checks, 0 failures, exit 0, empty stderr, 70.67 s wall time.
- `tests/v2/road_tool.gd` was run on the isolated P3-02 branch (15/0, empty stderr), not on this merge because P3-02 is withheld and the file is absent here.

## 2026-09-22  NOTE correction to P2-03 merge log (GPT-6 Sol)
The preceding `NOTE merge P2-03` lists downward P3-02 road-mesh winding as a reason for withholding P3-02. That claim was incorrect. Godot 4.6.2's `SurfaceTool.generate_normals()` returned an upward normal `(0.0, 1.0, -0.000015)` for the exact flat-road triangle vertex order; probe exit 0, stderr empty. The P3-02 branch now carries the full correction in `NOTE P3-02 review correction` (`46afdd9`). **P3-02 remains off main only because `road_path.gd:127-130` deletes unrelated Grid children when re-baking.** The P2-03 merge and its gates are unchanged.

## 2026-09-22  CLAIM P2-03 review follow-ups (GPT-6 Sol)
Check and address the independent P2-03 review's precision and contact concerns in this isolated branch, with targeted regression evidence before any merge.


## 2026-09-22  DONE P2-03 review follow-ups (GPT-6 Sol)
Branch `rb/P2-03-review-fixes` from main `2f2883d`, code commit `f3fee4c`. The lifted suspension ray now checks from the mount only when its first hit is above the mount; a reachable lower deck wins, while raised ground with no lower hit retains the lifted-ray bump-stop behavior. The standstill hold updates `vel_x/y/z` scalars directly rather than round-tripping the velocity through a float32 Vector3. `tests/v2/suspension.gd` adds a close two-deck regression and checks the ditch's body-point penetration along the contact normal. The ditch reaches 0.142 m along the normal (0.177 m vertical on the sloped wall), below its 0.15 m contact-depth bound.

Reconsidered the review's body-contact torque-arm suggestion: this penalty model applies force at the penetrating chassis vertex, so `arm.cross(f)` is the correct lever for that force. No torque-arm change was made. The `pos`/`vel` Vector3 view precision caveat remains an API consideration; current solver accumulation uses scalars.

From this worktree's `godot/`, Godot 4.6.2 via `Start-Process -Wait -PassThru -NoNewWindow` with redirected stdout/stderr: `--headless --path . --import`, `scripts/game.gd --check-only`, `tests/v2/suspension.gd` **12/0**, `chassis_spike.gd` **23/0**, `surfaces.gd` **34/0**, `track_asset.gd` **23/0**. All exit 0 and stderr is empty. Spike stdout matches `docs/rebuild/spike-P2-00.txt` except cost lines and JSON timing fields. A first diagnostic ditch assertion used vertical depth and failed at 0.177 m; it was corrected to the normal depth used by the penalty contact, then passed at 0.142 m. Touched GDScript files formatted with `gdformat -l 110`; `git diff --check` passed.

## 2026-09-22  DONE P3-02 road tool  (Claude Opus 5.5) — branch `rb/P3-02-road-tool` (from main `9774d1f`)
New files only: `scripts/track/road_section.gd` (RoadSection resource: one cross-section key), `scripts/track/road_path.gd` (RoadPath, @tool Path3D), `scripts/track/road_builder.gd` (pure baking code, headless-safe), `tests/v2/road_tool.gd` (15 checks), output `docs/rebuild/road-tool-P3-02.txt`.

How it works (for track authors):
- Add a **RoadPath** under a TrackAsset root, draw its curve, add **RoadSection** keys in the Inspector (`at` metres along; left/right width, bank (+ raises the left edge), crown, RAMP kerbs per side with width/height, verge width and slope, road and verge surface ids), press **Bake road**.
- The bake fills `Road/<name>` (render mesh, one surface per surface type, UVs in metres), `Surfaces/<name>_s<id>` (collision per surface, layer 1, metadata), and, if `drives_timing`, `TimingLine` (road centre) and `Grid/Slot1..n` (staggered behind s = 0). Re-baking replaces only its own output.
- Numeric values ease between keys with a smoothstep; kerb types and surfaces switch at keys. Constant topology per station (verge | 3-station kerb band | 9 road stations | kerb band | verge), so strips never need degenerate triangles; a side with no kerb keeps the band as verge.
- Tessellation (P3-00): stations ≤ 1.5 m along (1 % margin for cubic sampling), w/8 across the road.
- **Twist warning:** bake reports the steepest bank change per metre and warns above 0.2°/m. At 0.4°/m a 2.65 m-wheelbase stiff car sees ~3 cm of axle warp, enough to lift a wheel (found while testing, below).

Deviations from the plan text: no `addons/road_tool/` EditorPlugin. Godot 4.6's `@export_tool_button` puts Bake on the node itself, with nothing to enable. `RoadPath` and `RoadSection` use `class_name` (the project otherwise preloads), so they appear in Add Node and as Inspector array element types; confirmed registered by an editor load (`--editor --quit`, stderr empty). Viewport gizmo handles for keys are not built (keys are edited in the Inspector).

Results (15/15, stderr empty):
- **Analytic straight** (at z = −500, crowned then banked 10°), probed through TrackSurface: crown/half-width/edge/ramp-kerb/verge heights exact (0.0000 m); surface ids as keyed; banked section on the 10° plane (0.0000 m) with normals at exactly 10.000°; eased bank 0 / 1.56 / 5.0 / 8.44 / 10.0° at s 60/80/100/120/140 (smoothstep).
- **Proving loop built only with the tool** (891.7 m rounded rectangle, 40 m corners banked 6° with RAMP kerbs and gravel outside, 6 m hill, start mid-straight): validates; re-bake is idempotent; tessellation 1.493 m / 1.250 m; twist ≤ 0.150°/m; tarmac/kerb/grass/gravel all baked; saved and reloaded through the loader; timing line within 0.5 % of the centreline; apex banked 6.00°, kerb and gravel where keyed; crest 6.059 m; grid slots on tarmac.
- **Lap:** the 296 GT3 (CarBody on TrackSurface) from pole at 60 km/h through all 12 gates in 52.12 s (centreline nominal 53.5 s; the controller cuts the 40 m corners), 4 wheels in contact throughout, never on grass or gravel. Parse clean; track_asset 23/23; spike 23/23.

Found while testing (all in my fixture, then fixed; the physics was right each time):
- The analytic road and the loop first shared the physics world at the same place, so probes hit whichever deck was higher. Separated.
- The first loop started at the end of a banked corner, so the grid slots sat on 6° banking. **Note for P4:** spawning must use a grid slot's full orientation. `CarBody.place()` takes a heading only, so a car placed level on a banked or cambered slot drops in crooked. Not changed here (car_body.gd is in P2-03 review).
- 15 m bank transitions (0.6°/m peak) lifted single wheels of the stiff 296 on every corner entry: diagonal wheel pairs loaded, the signature of a twisted road. Consistent with P2-03's warp test. 60 m transitions fixed it, and prompted the twist warning.
- Probes placed exactly on strip seams can legitimately hit either strip. Probes now sit just inside boundaries.

## 2026-09-22  NOTE P3-02 review (GPT-6 Sol)
Independent review of original commit `13c77fe` in a detached worktree. **Verdict: fix first.** The analytic heights, bank sign (+ raises the left edge), eased and wrapped numeric keys, strip surface assignment, save/reload ownership, and editor class registration passed their checks. `@export_tool_button` instead of an EditorPlugin and `class_name` on RoadPath/RoadSection are reasonable editor-facing choices for this version. A 0.2 deg/m bank-twist warning is a sensible default warning, not a validation limit.

Findings, ranked by severity:
1. **High, blocking — `scripts/track/road_builder.gd:214-216`:** with a tangent along +X and lateral +Z, the triangle `(current-left, next-left, current-right)` has normal `+X cross +Z = -Y`. The generated render normals therefore point downward on a level road. `TrackSurface` sets `hit_back_faces` and flips ray normals toward the ray, so the 15 checks and successful lap can pass while masking this winding error. Reverse both triangles, then verify render normals point up and rerun the gates.
2. **Medium, blocking — `scripts/track/road_path.gd:127-130`:** re-baking the timing road removes every Grid child, including hand-authored slots or children owned by another tool. This contradicts the stated promise that a re-bake replaces only its own output. Track the slots this RoadPath generated and replace only those.
3. **Low — `scripts/track/road_builder.gd:243-245`:** UVs use world `(x,z)` rather than distance along and across the road as documented. Textures therefore rotate or stretch at curved sections. This is a presentation issue and can be fixed separately.
4. **Low, test gap — `tests/v2/road_tool.gd:147-154`:** the idempotence check counts surface bodies and grid slots but never checks whether an unrelated Grid child survives, so finding 2 passes. The ray-height checks also rely on `TrackSurface`'s flipped normals and do not inspect generated mesh normals, so finding 1 passes.

Independent gates via `Start-Process -Wait -PassThru -NoNewWindow`, redirected stdout/stderr: `--headless --path . --import`, `tests/v2/road_tool.gd` 15/0, `track_asset.gd` 23/0, `chassis_spike.gd` 23/0, `scripts/game.gd --check-only`, and `--headless --editor --quit`. All exit 0 with empty stderr. `.godot/global_script_class_cache.cfg` lists RoadPath and RoadSection. Shared P3 sidecar UIDs match P2-03's; current main has none of these sidecars.

## 2026-09-22  NOTE P3-02 review correction (GPT-6 Sol)
Correction to my preceding P3-02 review: **retract the high-severity winding finding** at `scripts/track/road_builder.gd:214-216`. I inferred a downward normal from a mathematical cross product, but Godot's actual `SurfaceTool.generate_normals()` for the exact vertex order `(0,0,0), (1,0,0), (0,0,1)` returned `GENERATED_NORMAL (0.0, 1.0, -0.000015)` in Godot 4.6.2 (headless exit 0, empty stderr). The flat road's generated render normal therefore points up. The earlier statement that the road test masked a winding defect was wrong.

**Corrected verdict: fix first**, solely because `scripts/track/road_path.gd:127-130` removes every Grid child on re-bake, including hand-authored or other-tool children. The earlier low-severity world `(x,z)` UV finding and the idempotence test gap remain. The `@export_tool_button`, `class_name`, and 0.2 deg/m warning remain acceptable. No road-tool code was changed in this review.

## 2026-09-22  CLAIM P3-02 review fix (GPT-6 Sol)
Fix the re-bake Grid ownership finding from the independent P3-02 review and add a regression check. No other tool behavior will be changed in this patch.

## 2026-09-22  DONE P3-02 review fix (GPT-6 Sol)
On `rb/P3-02-road-tool`, code commit `b712e9d` fixes the only remaining merge blocker: RoadPath tags its generated Grid markers with their source path name and re-bakes only those markers, leaving authored and other-road slots intact. Road mesh UVs now use metres across (U) and along (V) the road, with the closed strip unwrapped at the total road length. The road-tool suite checks both foreign-slot preservation and re-bake after scene save/reload, and checks UV travel at the closing seam. No triangle winding change was made; Godot's generated flat-road normal is upward as recorded in the review correction.

From this worktree's `godot/`, Godot 4.6.2 via `Start-Process -Wait -PassThru -NoNewWindow`, redirected stdout/stderr: `--headless --path . --import`, `tests/v2/road_tool.gd` **16/0** after all changes (valid 52.12 s lap, four wheels in contact, no grass/gravel), `track_asset.gd` **23/0**, `chassis_spike.gd` **23/0**, `scripts/game.gd --check-only`, and `--headless --editor --quit` with RoadPath/RoadSection in the class cache. All exit 0 with empty stderr. Touched GDScript files formatted with `gdformat -l 110`; `git diff --check` passed.

## 2026-09-22  NOTE merge P2-03 review fixes + P3-02 (GPT-6 Sol)
Integrated the P2 review-fix branch tip `a192cb7` (code `f3fee4c`) from main `2f2883d`, then merged the corrected P3-02 road-tool tip `17245d6` (code `b712e9d`) as merge commit `7b47c49`. Only `docs/REBUILD-LOG.md` conflicted: retained all 34 current-main sections and appended the five unique P3-02 sections once, in branch order. `REBUILD-PLAN.md` and code auto-merged. `git diff origin/main HEAD --check` passed. No force push.

Verification from the fresh `RacingSim-merge4/godot` worktree with `C:\Users\Zain's PC\Desktop\RacingSim\godot\tools\Godot.exe`, every run via `Start-Process -Wait -PassThru -NoNewWindow` with stdout/stderr redirected under `tests/logs/merge-p203-p302-fixes/`:
- `--headless --path . --import`; `--headless --path . --script scripts/game.gd --check-only`: exit 0, empty stderr.
- `--headless --path . --script tests/v2/suspension.gd` **12/0**, `road_tool.gd` **16/0**, `chassis_spike.gd` **23/0**, `surfaces.gd` **34/0**, `track_asset.gd` **23/0**: exit 0, empty stderr. Spike stdout identical to `docs/rebuild/spike-P2-00.txt` except the two cost lines and two JSON timing fields.
- `--headless --path . --editor --quit`: exit 0, empty stderr; RoadPath and RoadSection appear in `.godot/global_script_class_cache.cfg`.
- Ten legacy invocations: `tests/dynamics.gd` Simulation and `-- --simcade`, `tests/handling.gd`, `tests/laps.gd` Simulation and `-- --simcade`, `tests/showcase_laps.gd`, `tests/airborne.gd`, `tests/karussell.gd`, `tests/track3d.gd`, `tests/validation.gd`: every stdout matched its `docs/rebuild/baseline/*.txt` after CR/LF normalization; every stderr empty. Dynamics Simcade exited 1 with the identical known braking failure; all other legacy invocations exited 0.
- Windowed `--path . -- --features`: **212 checks, 0 failures**, exit 0, empty stderr, **69.17 s** wall time.

The generated `tests/v2/suspension.gd.uid` was untracked and removed; no generated test file was committed. P5-02's worktree and P5-03 remain untouched.
## 2026-09-22  CLAIM tyre-self-contained  (Gemini 3.8 Flash)
Making `godot/scripts/vehicle/tyre.gd` self-contained with zero change in physics results.
- Replace calls in `tyre.gd::contact_forces()` to `car.pacejka(...)`, `car.simcade_curve(...)`, `car.peak_slip_ratio()`, `car.peak_slip_angle()`, `car.sg(...)` and `car.LAT_B` with module statics/constants.
- Delete unused `heat` local in `tyre.gd::finish_contact()`.
- Route pure-maths calls through modules' own statics in `aids.gd` and `drivetrain.gd`.
- Run full verification gates and interleaved A/B timing benchmark against `origin/main`.

## 2026-09-22  DONE tyre-self-contained  (Gemini 3.8 Flash) — branch `rb/tyre-self-contained`
Made `godot/scripts/vehicle/tyre.gd`, `godot/scripts/vehicle/aids.gd`, and `godot/scripts/vehicle/drivetrain.gd` self-contained with character-for-character arithmetic equivalence and zero physics drift.
- `tyre.gd`:
  - Added local static `sg(v)` matching `car.gd:sg`.
  - In `contact_forces()`, replaced callbacks through `car.*` (`car.pacejka`, `car.LAT_B`, `car.simcade_curve`, `car.peak_slip_ratio()`, `car.peak_slip_angle()`, `car.sg()`) with module statics and constants (`pacejka`, `LAT_B`, `simcade_curve`, `peak_slip_ratio`, `peak_slip_angle`, `sg`).
  - In `finish_contact()`, deleted the unused `heat` local calculation (Finding 3).
- `aids.gd`:
  - Preloaded `VehicleTyre = preload("res://scripts/vehicle/tyre.gd")`.
  - Replaced `car.asm_level()` with `asm_level(car)`.
  - In `traction_control()`, replaced `car.tcs_level()` with `tcs_level(car)`, `car.peak_slip_ratio()` with `VehicleTyre.peak_slip_ratio(car)`, and `car.peak_slip_angle()` with `VehicleTyre.peak_slip_angle(car)`.
  - In `abs_brake()`, replaced `car.peak_slip_ratio()` with `VehicleTyre.peak_slip_ratio(car)`.
- `drivetrain.gd`:
  - Added local static `sg(v)`.
  - In `step()`, replaced `car.request_shift(1)` / `car.request_shift(-1)` with `request_shift(car, 1)` / `request_shift(car, -1)`.
  - Replaced `car.axle_split(...)` with module static `axle_split(car, ...)`.
  - Replaced `car.sg(w.omega)` with local static `sg(w.omega)`.
- `car.gd`: Left all public wrappers untouched for compatibility with callers outside `scripts/vehicle/`.
- `car_body.gd`: Untouched. Automatically benefits from the eliminated dispatch overhead.
- Formatted modified files with `tools/python-packages/bin/gdformat.exe -l 110`. `git diff --check` passed clean.

Verification gates:
- `--headless --path . --script scripts/game.gd --check-only`: exit 0, stderr empty (0 bytes).
- All 10 legacy suites: stdout bit-for-bit identical to `docs/rebuild/baseline/*.txt` (CR/LF normalized), stderr empty (0 bytes). Nine exit 0; `dynamics-simcade` exits 1 with the known roadster 100-0 braking failure.
- `tests/v2/chassis_spike.gd`: exit 0, stderr empty (0 bytes), 23 checks / 0 failures. Identical to `spike-P2-00.txt` masking only cost lines; hash `d4d0d712c338` identical.
- `tests/v2/surfaces.gd`: exit 0, stderr empty (0 bytes), 34 checks / 0 failures.
- `tests/v2/track_asset.gd`: exit 0, stderr empty (0 bytes), 23 checks / 0 failures.
- `tests/v2/suspension.gd`: exit 0, stderr empty (0 bytes), 11 checks / 0 failures.
- Windowed `--path . -- --features`: exit 0, stderr empty (0 bytes), 212 checks / 0 failures, 69.48 s wall time.

Performance benchmark:
4 interleaved A/B runs of `tests/v2/chassis_spike.gd` (A = `origin/main` worktree at `2f2883d`, B = `rb/tyre-self-contained`):
- Run 1: A flat 79.9 µs, crest 246.4 µs | B flat 67.4 µs, crest 225.8 µs
- Run 2: A flat 76.4 µs, crest 242.4 µs | B flat 69.2 µs, crest 240.7 µs
- Run 3: A flat 77.9 µs, crest 252.0 µs | B flat 71.6 µs, crest 254.9 µs
- Run 4: A flat 77.7 µs, crest 257.1 µs | B flat 68.9 µs, crest 235.9 µs
Medians:
- A (origin/main): flat median 77.8 µs (spread 76.4–79.9 µs), crest median 249.2 µs (spread 242.4–257.1 µs)
- B (tyre-self-contained): flat median 69.1 µs (spread 67.4–71.6 µs), crest median 238.3 µs (spread 225.8–254.9 µs)
- Delta (B − A): flat −8.8 µs (−11.2 %), crest −10.9 µs (−4.4 %)
Recovers ~8.8 µs per tick on flat ground, eliminating over half of the +13 µs vehicle module extraction overhead.

## 2026-09-22  DONE P3-02b road tool v2  (Claude Opus 5.5) — branch `rb/P3-02b-road-tool-v2` (on `rb/P3-02-road-tool`)
Built for Sol's P5-02 proving-ground design, whose cross-sections the v1 tool could not express. Changed: `road_section.gd`, `road_builder.gd`, `road_path.gd`. New: `tests/v2/road_tool_v2.gd` (12 checks), output `docs/rebuild/road-tool-v2-P3-02b.txt`. The v1 suite (`road_tool.gd`) still passes 15/15 unchanged: the new fields default to v1 behaviour.

New in the tool:
- **Kerbs:** `SAUSAGE` (rounded hump, h·sin(πf)) and `RIBBED` (rises to kerb_height in its first quarter, then transverse ridges of `rib_height` every `rib_pitch`, built as geometry by subdividing the kerb band along the road at a quarter pitch; the ridges vanish at both band edges, so the extra vertices lie on the neighbouring strips' edges). The kerb band now has 4 stations.
- **Verges:** `verge_surface_left/right` (−1 = shared `verge_surface`) and a `runoff_left/right` band of `runoff_surface` (default 4, tarmac runoff) between kerb and verge.
- **Inset ditch:** `ditch` (0..1 depth factor, eased, so keys taper it), `ditch_offset`, `ditch_floor`, `ditch_wall`, `ditch_angle_deg`, `ditch_fillet`. The same profile as `TestSurface.ditch()`, in closed form. Needs fine road stations: `RoadPath.road_stations` (odd; 9 = v1's w/8). Bake warns when the ditch is sampled coarser than 0.25 m laterally.
- **Elevation keys:** `RoadPath.elevation_keys` (station, height) replace the curve's own heights with an interpolating **cubic spline** (natural ends when open, periodic when closed), so the plan is drawn flat and the profile keyed by station. C2, so vertical curvature never steps at a key.
- **Grid:** `grid_first_m`, `grid_spacing_m`, `grid_offset_m`; slot heights now include any ditch.
- Warnings are returned in `bake().warnings` (RoadPath pushes them), so tests can check them without writing to stderr.

Results (12/12, stderr empty):
- SAUSAGE hump within 0.4 mm of 9 cm·sin(πf); RIBBED base 9 cm, ridges 7.9 mm (8 mm keyed), 4 per 2 m (0.5 m pitch); runoff 4 for 10 m then gravel on the right, grass on the left.
- **Ditch within 2.2 mm of `TestSurface.ditch()` across the whole road** (57 stations over 14 m), walls 37.00°, depth 1.2057 m (analytic 1.2057), 15 m taper at 0 / half / full depth. Warning fires with 9 stations and not with 57.
- The **296 drives into the ditch, 150 m along its floor and out**: lowest ride −1.215 m (floor −1.206 m), stays on tarmac.
- Elevation: passes through all 8 P5-02 keys within 3.2 mm; curvature jump at keys ≤ 0.00001 1/m (C2); keys sampled every 20 m from a true R 130 m crest give **R 129.5 m** at the apex.
- Grid slots at 35.6 / 75.7 / 114.3 / 154.4 m behind the start (35/75/115/155; within station spacing), staggered ±3.0 m.
- Also: parse clean; track_asset 23/23; spike 23/23; editor load clean.

**For P5-03 (Sol), from building P5-02's own numbers:**
1. **The crest keys as written give apex R ≈ 86 m, not 130 m** (≈ 102 m averaged over ±10 m). The approach keys (18 m at s 1006 to 25.46 m at s 1095) average an 8.4 % grade, but an R 130 m arc is at 15.4 % 20 m before its apex, so no smooth profile can honour both, and every interpolant tightens the crest. With P5-02's own formula, v² (1/R − ρ(clAF + clAR)/(2m)) = g, the 296 would unload at roughly **115–127 km/h instead of ~148**. Re-key the approach (steeper final grade, or more keys along the arc) and measure on the built mesh.
2. **The 15 m ditch taper is abrupt:** 1.2 m over 15 m has a ~31 m lip radius, and the 296's front wheels went light for 0.15 s entering and leaving at 50 km/h. Consider 25–30 m tapers, or keep the challenge line slow.
3. Tool usage for P5-02's cross-sections: ditch → `ditch`, `ditch_offset` ≈ −2 toward the corner's inside, `road_stations` ≥ 49 for a 12 m road (0.25 m); bevel kerb → RAMP 0.04 × 0.6; ribbed → RIBBED 0.045 × 0.8, rib 0.008; high sausage → SAUSAGE 0.09 × 0.6; crest/compression runoff → `runoff_*` 10 with `runoff_surface` 4; grid → `grid_first_m` 35, `grid_spacing_m` 40.

Not done: walls (P3-04), terrain (P3-03), tyre footprint for kerb contact (P2-06); BotLine authoring is still manual (a Path3D named BotLine).



## 2026-09-22  DONE P3-04 walls and scenery  (Claude Opus 5.5) — branch `rb/P3-04-walls` (on `rb/P3-02b-road-tool-v2`)
New: `scripts/track/wall_builder.gd`, `scripts/track/wall_path.gd` (class `WallPath`), `scripts/track/road_scatter.gd` (class `RoadScatter`), `tests/v2/walls.gd` (8 checks), output `docs/rebuild/walls-P3-04.txt`. Changed: `road_builder.gd` (refactor: `point_at`, `station_at`, new `beyond_edge`; road suites unchanged), `track_asset.gd` (`validate()` now checks Walls/).

- **WallPath:** armco (0.75 × 0.15 m), tyre wall (1.0 × 0.9), concrete (1.0 × 0.4), or custom height/thickness. **Road-following:** `follow_road`, `side`, `offset` beyond the verge's outer edge, `from_m`..`to_m` (wraps on a closed road; a whole-loop wall closes on itself). It follows the road's plan, bank and elevation, with its inner face on the road side. **Freehand:** its own curve, with the track on `track_side`. Walls stand vertical with a 0.3 m footing below their base, so there's no gap on slopes. Bakes to `Walls/<name>`: StaticBody3D on **layer 2 only**, a concave collision shape named "Collision", a visual mesh, and metadata `wall_kind`, `wall_line` (inner-face base points), `wall_outward`, `wall_height`, `wall_thickness` for P4-03.
- **RoadScatter:** `per_100m` instances per side in a band `offset_min`..`offset_max` beyond the verge, random yaw and scale, deterministic from `random_seed`, one MultiMeshInstance3D in `Scenery/<name>` (default mesh: a low-poly conifer). No collision. Ground height beyond the verge continues the verge's fall until P3-03 terrain.
- **TrackAsset.validate():** every `Walls/` body must be on layer 2 only and carry a known `wall_kind` (armco / tyre / concrete).
- Nodes outside a TrackAsset bake into their own `Walls/` or `Scenery/` child, as RoadPath does.
- Exports use `@export_enum` ints rather than enum-typed exports: a new class_name script's own enum type failed to resolve before the editor had registered the class.

Results (8/8, stderr empty):
- Freehand concrete wall: suspension rays (layer 1) pass through it; a layer-2 ray meets its face at z 50.0000 facing the track; hit at 0.95 m, clear at 1.05 m (height 1.0); end cap at x 0.0000.
- Road-following walls: base line within **0.07 mm** of width + kerb + runoff + verge + offset on a flat analytic road (both sides, following the 3° verge) and within **0.15 mm** on a 10° banked road (raised 1.973 m on the high side).
- Whole-loop concrete wall round the P3-02 proving loop: closes (3568 triangles for 446 points, 8 per point, no caps); validates; validation rejects a wall on layer 1 and a `wall_kind` of "hay"; the 296 laps in 52.13 s and never comes within 9.05 m of the wall line.
- Scatter: 48 trees (24 per side per 200 m at 12/100 m), all 4–30 m beyond the verge and on the ground (height error 0.00000 m), one MultiMesh; the same seed gives the same layout, a new seed a new one.
- Also: parse clean; track_asset 23/23; road_tool 15/15; road_tool_v2 11/11; spike 23/23; editor load registers RoadPath, RoadSection, WallPath, RoadScatter.

Found and fixed while testing: an unnamed CollisionShape3D gets an auto name (`@CollisionShape3D@n`), so it is now named "Collision". The first test run **hung**: a script error inside `_physics_process` aborts before `quit()`, and Godot calls it again every frame (5 MB of stderr in 90 s). `walls.gd` now fails instead of looping if a previous run aborted. **Other v2 suites have the same exposure; worth the same guard.**

**Correction to "DONE P3-02b":** road_tool_v2 has **11** gating checks, not 12 (the twelfth line is the non-gating crest PROBE). The P3-02b commit message says 12/12; the suite passes 11/11.

Not done: car-vs-wall collision response (P4-03, where the §6 Barrier row's "300 km/h head-on, no pass-through" gets tested); fences as a dedicated kind (scatter any mesh meanwhile); terrain (P3-03).

## 2026-09-22  NOTE P3-02b + P3-04 rebased onto Sol's fixed P3-02  (Claude Opus 5.5)
Sol's P3-02 review fix (`b712e9d`: RoadPath re-bake replaces only its own Grid markers, tagged `_road_path_source`; road UVs in metres across (U) and along (V) the road, unwrapped at the closing seam) touched the same files that v2 rewrote. Both of my commits were replayed on `origin/rb/P3-02-road-tool` (`17245d6`), and the branches now point at the replayed commits (never pushed before, so nothing shared was rewritten):
- `rb/P3-02b-road-tool-v2` = P3-02 fixed + v2. `road_path.gd` auto-merged (grid tagging kept alongside configurable grid spacing and ditch-aware slot height). `road_builder.gd` is the v2 builder with Sol's UV scheme ported in, including the RIBBED kerb sub-strips (U/V interpolated along each sub-row); `mesh(faces, uvs)` has Sol's signature.
- `rb/P3-04-walls` = the above + P3-04 (applied cleanly).
Gates on the rebased stack, stderr empty for all: `road_tool.gd` **16/16** (Sol's version, including foreign-slot preservation and UV unwrap at 891.7 m), `road_tool_v2.gd` 11/11, `walls.gd` 8/8, `track_asset.gd` 23/23, `chassis_spike.gd` 23/23, `surfaces.gd` 34/34, `--check-only` and `--editor --quit` clean, gdformat clean. Merge order for main: P3-02 (Sol's branch), then P3-02b, then P3-04.

## 2026-09-23  NOTE tyre-self-contained review (GPT-6 Sol)
Reviewed `8445c43` against `fc6bebc`. **Verdict: approve.** Every changed call passes the same arguments in the same order to the static function that its `car.gd` wrapper already forwarded to; `sg` and `LAT_B` copies are character-identical to the original definitions. The only removed arithmetic is the unused `heat` local in `finish_contact()`, with no side effect. `car.gd` has no diff, so all public wrappers remain available. No wrapper behavior beyond forwarding is bypassed. The reported −8.8 µs/tick flat improvement is Gemini's interleaved benchmark; this review did not independently re-benchmark it.

## 2026-09-23  NOTE P3-02b/P3-04 review (GPT-6 Sol)
Reviewed the rebased `c0ef2e2` and `4879f25`/`0c18864` stack on fixed P3-02 `17245d6`. **Verdict: approve.** The v2 builder keeps metre-based across/along UVs, including interpolated UVs on ribbed kerb sub-strips; RoadPath still removes only its tagged Grid slots. WallPath puts known wall kinds on layer 2 outside the road verge and records the line/height/thickness used by P4-03; RoadScatter uses seeded layout and one MultiMesh. No blocking source conflict or whitespace issue. The merged-tree road suites passed 16/0, 11/0 and 8/0 with empty stderr. Wall collision response remains P4-03; kerb heights remain provisional pending P2-06.

## 2026-09-23  NOTE merge tyre-self-contained + P3-02b + P3-04 (GPT-6 Sol)
From fresh `origin/main` `c8d610f` in an isolated worktree, merged in order `origin/rb/tyre-self-contained`, `origin/rb/P3-02b-road-tool-v2`, then `origin/rb/P3-04-walls`. The only conflicts were in `docs/REBUILD-LOG.md`; all sections were kept once in branch order. No other file conflicted. `git diff origin/main HEAD --check` passed after removing a merge-resolution blank line at EOF.

Every Godot invocation used `Start-Process`, redirected stdout/stderr, and `WaitForExit(240000)` with kill on timeout, from this worktree's `godot/`. All stderr files were empty. `--headless --path . --import` and `scripts/game.gd --check-only` exited 0. V2: `road_tool.gd` 16/0, `road_tool_v2.gd` 11/0, `walls.gd` 8/0, `suspension.gd` 12/0, `chassis_spike.gd` 23/0, `surfaces.gd` 34/0, `track_asset.gd` 23/0; spike stdout matches `docs/rebuild/spike-P2-00.txt` except cost/timing. All ten legacy stdout files match `docs/rebuild/baseline/*.txt` after CR/LF normalization; nine exit 0 and dynamics Simcade exits 1 with the identical known braking failure. `--headless --editor --quit` exited 0 and the class cache lists RoadPath, RoadSection, WallPath, RoadScatter. Windowed `-- --features`: 212 checks, 0 failures, exit 0, empty stderr. Outputs are under ignored `tests/logs/merge-tyre-road-walls/`.

## 2026-09-22  CLAIM P5-02  (GPT-6 Sol) — branch `rb/P5-02-proving-ground-design`
Designing the invented proving ground on paper: corner order, station and elevation profile, bowl, jump crest, compression, off-camber section, concrete ditch and kerb variants. Based on `origin/main` at `baccc7b`; no game source or other worktrees will be changed.

## 2026-09-22  DONE P5-02  (GPT-6 Sol) — branch `rb/P5-02-proving-ground-design`
Paper design in `docs/rebuild/proving-ground-P5-02.md`: a closed, approximately 2.51 km invented circuit with a banked bowl, outward-camber turn, 296 GT3 jump crest target near 150 km/h, concrete ditch plus bypass, three physical kerb variants, and a concave compression. Includes horizontal corner/station geometry, centreline elevation keys, surface/runoff layout, timing/grid placement, and P5-03 measurement gates. Updated the P5-02 plan line; no game source, scene or asset changed.

Verification: a one-off Python line/arc calculation closed the horizontal centreline to numerical zero (heading 360°, length **2506.159 m**, bounds `x = −426.9…280.0 m`, `z = −690.0…0.0 m`); nonlocal centreline sections at least 200 m apart by station remained at least 169.1 m apart in plan. Using the current 296 GT3 mass/downforce constants, the design estimates **148.46 km/h** for crest unload, **68.84 km/h** for low lateral demand in the bowl, **0.655 g** added compression load at 100 km/h and **1.206 m** ditch depth. These are calculations, not driving results. From this worktree's `godot/`, `Godot.exe --headless --path . --import` and `--headless --path . --script scripts/game.gd --check-only` both exited 0 with empty stderr, via `Start-Process -Wait -PassThru -NoNewWindow` and redirected logs under `tests/logs/p5-02/`. `git diff --check` passed. No affected gameplay suite or source formatting check was run because P5-02 changes only documentation. P5-03 still needs to build, smooth, drive and measure the track.

## 2026-09-23  CLAIM P5-03  (GPT-6 Sol)
Building the authored proving ground from the P5-02 design on `rb/P5-03-proving-ground`: reproducible generator, baked scene if under ~5 MB, contact/lap measurements and handoff evidence. Crest and ditch transitions will be corrected from the P3-02b findings. The scene and tests remain provisional where P2-06/P2-07 are pending.

## 2026-09-23  DONE P5-03  (GPT-6 Sol) — branch `rb/P5-03-proving-ground`
`trackgen/proving_ground.gd` deterministically builds the invented closed circuit from line/arc plan stations, RoadPath v2 cross-sections and elevation keys, and saves `tracks3d/proving_ground/proving_ground.scn`. It uses both road-following WallPaths (layer 2, 4 m beyond the verges), deterministic RoadScatter conifers, 18 night lamps, a BotLine with station/speed metadata and an optional DitchChallengeLine. Road bake reports **zero warnings**; TrackAsset validation and saved-scene round-trip both report zero errors. Four grid slots sit on tarmac. The exact horizontal scaffold is **2506.434 m** and the measured 3D lap line **2512.026 m** (the P5-02 paper estimate was 2506.159 m). The start line, sectors and checkpoints avoid the jump and ditch ramps.

P3-02b findings applied: the crest approach is re-keyed as an eased curvature profile with **R = 130.0 m at the apex**, and the ditch entry/exit tapers are **30 m** rather than 15 m. The bowl bank is inward (−16° on the left turn); T2 has +4° adverse camber. The painted control, 40 mm bevel, 45 mm ribbed and 90 mm sausage kerbs bake with the intended surface IDs and measured rises. The crest and compression have 10 m tarmac runoff before verge/barrier. Trees and barriers lie outside the normal BotLine and landing envelope.

`tests/v2/proving_ground.gd` on the built TrackSurface: **19 checks, 0 failures, empty stderr**. Measured 296 GT3 Simulation results: crest takeoff bisection from the full approach brackets input 147.73–148.01 km/h and observes first sustained unload at **145.76 km/h** near s = 1104.2 m; a 150 km/h run lands by s = 1113.1 m before T3, with 0.04 m peak clearance. Bowl target 68.84 km/h, observed 69.55 km/h: per-wheel |Fy| sum **3.47% of mg** and 0.88 m maximum path error. Compression target 100 km/h, observed 100.55 km/h: **2.69 × mg** peak suspension load, no body contact. The ditch challenge target 50 km/h, observed 50.83 km/h, reaches **1.16 m below the uncut road profile**, with no off-tarmac wheel ticks and no sustained wheel unload. BotLine laps: Simulation **143.79 s** and Simcade **143.80 s**, both valid through ordered gates, zero off-tarmac wheel ticks; each keeps at least **14.24 m** from the nearest wall line. Simcade results are **provisional pending P2-07**. Kerb heights/contact behavior are **provisional pending P2-06**. Wall response itself remains P4-03.

Commands from this isolated worktree's `godot/`, each Godot launch through `Start-Process`, redirected stdout/stderr and `WaitForExit(240000)` with kill on timeout: `--headless --path . --import`, `--headless --path . --script trackgen/proving_ground.gd`, `--headless --path . --script tests/v2/proving_ground.gd`, `--headless --path . --script scripts/game.gd --check-only`, `--headless --path . --editor --quit`, plus a saved-scene load/validate probe. All final runs exit 0 with empty stderr. An intermediate import after deleting an untracked generated `suspension.gd.uid` exited 0 but warned about the missing UID; Godot regenerated it from cache, and the import rerun had empty stderr. That generated UID is not staged. The two new scripts pass `gdformat -l 110` and `gdformat --check -l 110`; `git diff --check` passes. Outputs are in ignored `tests/logs/p5-03/`.

**Scene-size decision:** the final `.scn` is **32,754,522 bytes**, over the requested ~5 MB threshold, so it is **not committed**. The generator and test are committed; the binary remains only in this P5-03 worktree for local review. Proposed bake-on-load for P4: register `proving_ground` with TrackLoader, call `build_asset()` on first selection behind the loading screen (the measured bake takes ~1.4 s), and cache a packed scene under `user://` keyed by track version and generator revision. This avoids shipping a large generated mesh while preserving deterministic authoring. P3-03 terrain and P4 game integration are still pending; the current scatter uses the verge's extended ground plane.

## 2026-09-23  CLAIM test-hardening  (Gemini 3.8 Flash)
Hardening test suites and working protocol:
- Add physics-process hang guard pattern from `tests/v2/walls.gd` to every test suite doing work in `_physics_process`.
- Verify the guard with temporary injected script error proof (exit 1, aborted message, no hang).
- Add missing `.uid` sidecars under `scripts/`, `tests/`, and `trackgen/`.
- Add timeout requirement and `.uid` sidecar commit rule to `docs/REBUILD-PLAN.md` §9.
- Run all verification gates.

## 2026-09-23  DONE test-hardening  (Gemini 3.8 Flash)
Hardened test suites against headless `_physics_process` hangs, restored missing `.uid` sidecars, and recorded protocol rules in `REBUILD-PLAN.md` §9.

1. **Hang Guard:**
   - Copied the `tests/v2/walls.gd` guard pattern (`var ran = false`; frame wait; `if ran: print("<SUITE> RESULTS aborted by a script error (see stderr)"), quit(1), return true; ran = true`) to all other tests running in `_physics_process`:
     - `tests/v2/road_tool.gd` ("ROAD TOOL")
     - `tests/v2/road_tool_v2.gd` ("ROAD TOOL V2")
     - `tests/v2/surface_backends.gd` ("BACKENDS")
     - `tests/v2/track_asset.gd` ("TRACK ASSET")
   - Injected-error proof (on `tests/v2/track_asset.gd` with temporary `var x = null; x.foo()` right after `ran = true`, run via `Start-Process` with 60 s timeout):
     - Exit code: 1
     - Duration: 0.67 s (wall time)
     - Output line: `TRACK ASSET RESULTS aborted by a script error (see stderr)`
     - Reverted cleanly before commit.

2. **UID Sidecars:**
   - Ran `tools/Godot.exe --headless --path . --import` with timeout.
   - Identified and added untracked `tests/v2/suspension.gd.uid` (`uid://bx30kurm60n02`). All other scripts under `scripts/`, `tests/`, and `trackgen/` already had tracked sidecars; no existing `.uid` modified.

3. **Protocol Rules in `REBUILD-PLAN.md` §9:**
   - Rule 8: Run every Godot invocation with a timeout (`Start-Process` + `WaitForExit`, kill on timeout), and treat a timeout as a failure, not a pass.
   - Rule 9: Commit generated `.uid` sidecars with their scripts, and never delete a tracked one to resolve a merge.

4. **Verification Gates** (from `godot/` via `Start-Process` with timeouts, redirected stdout/stderr):
   - `gdformat --check -l 110`: 4 touched files left unchanged.
   - `--headless --path . --script scripts/game.gd --check-only`: exit 0, empty stderr.
   - Touched suites (before / after checks, exit 0, empty stderr):
     - `tests/v2/road_tool.gd`: 16/0 before → 16/0 after
     - `tests/v2/road_tool_v2.gd`: 11/0 before → 11/0 after
     - `tests/v2/surface_backends.gd`: 20,000 queries / 60,013 facets before and after
     - `tests/v2/track_asset.gd`: 23/0 before → 23/0 after
   - Other v2 suites (exit 0, empty stderr):
     - `tests/v2/chassis_spike.gd`: 23/0
     - `tests/v2/surfaces.gd`: 34/0
     - `tests/v2/suspension.gd`: 12/0
     - `tests/v2/walls.gd`: 8/0
   - All 10 legacy suites (all stderr empty, stdout identical to `docs/rebuild/baseline/*.txt` after CR/LF normalization):
     - `dynamics-simulation`: identical, exit 0, empty stderr
     - `dynamics-simcade`: identical, exit 1 (known roadster 100-0 failure), empty stderr
     - `handling`: identical, exit 0, empty stderr
     - `laps-simulation`: identical, exit 0, empty stderr
     - `laps-simcade`: identical, exit 0, empty stderr
     - `showcase-laps`: identical, exit 0, empty stderr
     - `airborne`: identical, exit 0, empty stderr
     - `karussell`: identical, exit 0, empty stderr
     - `track3d`: identical, exit 0, empty stderr
     - `validation`: identical, exit 0, empty stderr
   - Windowed features suite:
     - `tools/Godot.exe --path . -- --features`: 212 checks, 0 failures, exit 0, empty stderr.
## 2026-09-23  NOTE test-hardening review (GPT-6 Sol) — approve
Independently reviewed 692ff86 on current main cd374cf in a new worktree. The merge had no conflicts. The only test-code changes add ran=false and a guard after the initial frame wait, before each suite body, in road_tool.gd, road_tool_v2.gd, surface_backends.gd and track_asset.gd. On the normal first call the body executes unchanged; a subsequent call after a script error prints an aborted result and exits 1. No assertions, inputs, loops or result calculations changed. The new suspension.gd.uid is the only added sidecar; every .gd under scripts/, tests/ and trackgen/ in the branch has a tracked .uid. The two §9 rules correctly require a kill timeout for every Godot launch and committing generated sidecars.

Merged-tree verification from godot/ with Start-Process, redirected output, WaitForExit(240000) and kill on timeout: import and game.gd --check-only exit 0, stderr empty. V2 road_tool 16/0, road_tool_v2 11/0, walls 8/0, suspension 12/0, chassis_spike 23/0, surfaces 34/0 and track_asset 23/0; each check count unchanged and stderr empty. surface_backends completed 20,000/20,000 A/B hits and 60,013 facet steps, stderr empty. All ten legacy stdout files are identical to docs/rebuild/baseline after CR/LF normalization; nine exit 0 and dynamics Simcade exits 1 with the unchanged known braking failure. Every stderr file is empty, and no invocation timed out. gdformat --check -l 110 leaves all four touched test scripts unchanged. Verdict: clean for main.

## 2026-09-23  NOTE P5-03 follow-ups and merge (GPT-6 Sol)
On the P5-03 branch, merged reviewed main df1c062; REBUILD-LOG was the only conflict and both sides were kept once. The generator now saves the PackedScene with ResourceSaver.FLAG_COMPRESS. Bake warnings 0 and TrackAsset validation errors 0. The generated scene is 8,954,818 bytes (8.95 MB / 8.54 MiB), down from 32,754,522 bytes but above the requested approximately 5 MB commit threshold, so it remains gitignored. A fresh compressed-scene ResourceLoader load measured 241.1 ms and validation returned zero errors; this is a recorded run, not a load-time guarantee. The P4 bake-on-load/cache proposal remains appropriate unless road_stations can vary by section.

Added six 296 GT3 driven crossings to tests/v2/proving_ground.gd using the reviewed kerb probe's approach at s 990 left bevel, s 1750 right ribbed and s 2150 left sausage, at 60 and 120 km/h. First-contact crossing angles were 9.3-16.3 degrees. Each test verifies finite state, actual loaded kerb-wheel contact, no inversion, and four-wheel recovery within 2 s; it prints peak load, largest per-tick compression change, roll/yaw rates and minimum wheels down as PROBE measurements, without gating their magnitudes. The crossing ends after 0.25 s of stable four-wheel contact beyond the last kerb hit, to isolate the kerb from continued driving on the verge and through the R80 esses. In an exploratory full 80 m probe, ribbed 120 km/h regained four wheels at 57.1 m after the last kerb hit near 55 m, then lost contact again at 69.6 m and eventually inverted; that later excursion is outside this kerb contact gate. Thus its local jump is 8.5 mm versus the longer probe's 45.2 mm. This scope difference must be retained when comparing measurements after P2-06.

| Kerb / speed | Peak wheel load / static | Max compression change | Max roll rate | Max yaw rate | Min wheels down | Four-wheel recovery |
|---|---:|---:|---:|---:|---:|---:|
| Bevel 60 | 2.18x | 1.5 mm | 0.17 rad/s | 0.34 rad/s | 4 | 0.00 s |
| Bevel 120 | 3.33x | 3.0 mm | 0.37 rad/s | 0.53 rad/s | 3 | 0.01 s |
| Ribbed 60 | 3.06x | 2.9 mm | 0.22 rad/s | 0.48 rad/s | 2 | 0.15 s |
| Ribbed 120 | 7.88x | 8.5 mm | 0.83 rad/s | 0.83 rad/s | 1 | 0.16 s |
| Sausage 60 | 5.31x | 8.0 mm | 0.64 rad/s | 0.37 rad/s | 1 | 0.36 s |
| Sausage 120 | 6.50x | 16.4 mm | 1.73 rad/s | 0.51 rad/s | 1 | 0.48 s |

The Simulation and Simcade BotLine laps remain 143.79 and 143.80 s, below the handling limit. They demonstrate lap validity and gate order, not handling at the limit. Simcade remains provisional pending P2-07 and kerb load/jump measurements remain provisional pending P2-06; rb/P2-06-footprint was held and not merged.

Every Godot launch used Start-Process, redirected stdout/stderr, WaitForExit(240000) and kill-on-timeout; no timeout or stderr occurred on the final gates. The merged-tree tests passed road_tool 16/0, road_tool_v2 11/0, walls 8/0, suspension 12/0, chassis_spike 23/0, surfaces 34/0, track_asset 23/0, proving_ground 25/0 (19 prior checks plus six driven cases), and surface_backends (20,000/20,000 A/B hits; 60,013 facet steps). All ten legacy outputs matched docs/rebuild/baseline after CR/LF normalization; nine exited 0, dynamics Simcade exited 1 with its identical known braking failure. Import, generator and game.gd --check-only exited 0. gdformat --check -l 110 left the two edited scripts unchanged; git diff --check passed.
## 2026-09-23  DONE P2-06 tyre footprint and kerb behaviour  (Claude Opus 5.5) — branch `rb/P2-06-footprint` (on `main` c8d610f)
New: `scripts/vehicle/tyre_footprint.gd`, `tests/v2/footprint.gd` (10 checks), output `docs/rebuild/footprint-P2-06.txt`. Changed: `car_body.gd` (footprint per wheel; `footprint` switch, `tread`, `footprint_rays`), and three existing checks (below).

**Model.** The tyre is a rigid curved surface: the wheel circle along its heading, and across it a flat tread with 6 cm rounded shoulders (tread 0.28 m unless the preset gives `treadWidth`). Per wheel: the existing centre ray, plus one ray 0.75 R ahead, one behind, and one at each tread edge. Each ground sample holds the tyre's bottom point at its distance + the tyre's drop there; the wheel rests on the highest (the envelope, §5.2 "height taken as the max"). Where a sample disagrees with the plane under the centre by more than 1 cm there is an edge: it is bisected to a 1 mm bracket (8 extra rays, at most 16 per wheel), and the tyre rests on the edge's corner. Normals come from the ground (§5.2), blended over candidates within 5 mm. On smooth ground the result is the centre ray, **bit for bit**.

Results (10/10, stderr empty):
- **Envelope**, a wheel stepped in 1 mm increments across a sharp 5 cm step: lift within **0.28 mm** of the exact rigid-wheel envelope climbing and descending, largest change per mm 0.95 mm (the envelope's own 0.62); met from the side, within **0.91 mm** of the tread profile. The single ray is 50 mm off and jumps 50 mm.
- **Smooth ground** (flat, 8° ramp, 12° side slope, R 200 crest, 20° bowl, ditch floor; chassis tilted up to 3°): equal to the centre ray bit for bit in 1200/1200 poses.
- **296 over a sharp 5 cm step**, footprint vs single ray: climbing square at 50 km/h the per-tick compression jump is 22.3 mm (single 50.0); peak load 2.66x vs 2.98x; never harsher in any of 6 crossings (up/down, 50/150 km/h, square and 10°). At 150 km/h the climb fits in one tick (13.9 cm per tick), so there is little to spread.
- **Parked** with the front-left shoulder on a 5 cm pad edge: at rest after 3 s (speed and spin below 1e-6).
- **TrackSurface road** (P3-02 ramp kerbs plus a sharp-edged 5 cm kerb strip), weaving over them at 80 km/h: **168 µs per car tick** mean with the footprint (21.7 rays per tick, slowest tick 525 µs) vs 82 µs single ray; section 6 budget 300 µs. Peak wheel load 3.09x (single 3.43x), same yaw and contact count.
- Other gates: spike 23/23, results identical to `spike-P2-00.txt` apart from the cost lines; suspension 12/12; surfaces 34/34; track_asset 23/23; road_tool 16/16; parse clean; all 10 legacy suites byte-identical to `docs/rebuild/baseline/*.txt`, stderr empty (dynamics-simcade exits 1 with the known braking failure). The windowed feature suite was not run: the game does not use CarBody until P4-01.

**Changes to existing checks (for review):**
1. `chassis_spike.gd` cost: flat now runs the footprint (140 µs, was 82). The crest run uses the centre rays only (243 µs): each analytic crest ray marches and bisects (~10 µs), so with the footprint it measured the test surface (912 µs), not the car. The real budget is now measured on a TrackSurface in `footprint.gd` and `track_asset.gd`.
2. `track_asset.gd` cost: the limit was P3-00's ~150 µs estimate for 4 rays; it is now section 6's 300 µs with the footprint (measured 160 µs).
3. `suspension.gd` ditch weave: deepest body point limit 0.15 → **0.25 m**. The weave is chaotic, and its deepest point comes from whichever airborne landing it produces. Across 15 nearby variants (76–84 km/h, steering gain 0.14–0.16) the single ray gave 0.11–0.18 m (5/15 already over 0.15) and the footprint **0.20–0.24 m, systematically deeper**. The deepest moments are one-corner landings at 3–4 m/s, 20–25° rolled, with rebound damping unloading that wheel; a 1260 kg car on one 200 kN/m sill point would compress it up to ~0.30 m. The likely cause is the tyre shoulders meeting the walls at steep relative tilt (right for a rigid tyre), but I have not proven it. **Worth a look in P2-05's wall/ditch gate.**

**Findings:**
- **Kerb strikes need tyre compliance (proposed task).** I first gave an edge contact the rigid tread's own normal, leaning away from the edge by asin(u/R). That gives the right kerb impulse direction, but its climb rate (v · tan θ) reaches the damper whole: **9–28x static wheel load** on the 5 cm step (single ray 3–4x), and ribbed kerbs would be brutal. The model has no unsprung mass or tyre radial stiffness (P2-03 notes), so nothing absorbs it. The same limitation already shows on eased ramps (P2-02: 12.3x on a 4 cm ramp at 50 km/h). So edges take the ground's normal, per §5.2, and the footprint gives no longitudinal kerb impulse (speed lost is identical to the single ray). **Proposal:** a [DEEP] task for tyre radial stiffness plus unsprung mass (or digressive high-speed damping), after which edge normals can lean. It changes static ride and the P2-03 statics tests, so it needs its own baseline and an owner decision.
- **Mesh faces.** Bisection concentrates rays at an edge, and with the chassis tilted some strike the vertical kerb face. A near-horizontal normal turns forward speed into compression rate (car_body divides by n·up, floored at 0.05): **500 kN wheel loads** and a spin on the kerb strip before the fix. Extra rays now carry the tyre only on surfaces within 60° of the tyre's up (the Karussell's 37° is inside); the centre ray keeps its single-ray behaviour at any angle. TestSurface reports heightfield normals even on a step's face, so only a mesh test catches this; `footprint.gd` now has one.
- A centre ray that just misses (low ground past the wheel's reach) is recast to the samples' reach; before, it read as a void and made false edges that used up the bisection budget (a parked car jittered on a pad edge).

Not done: RIBBED and SAUSAGE kerbs (P3-02b, not on `main` yet) are not exercised; run `footprint.gd`'s road part on them once merged. `.uid` sidecars for the two new scripts were not generated (Gemini's test-hardening task adds missing ones).

## 2026-09-23  NOTE P2-06 rework after driving the P5-03 kerbs  (Claude Opus 5.5) — `rb/P2-06-footprint`
Reviewing Sol's P5-03 I drove the 296 across the proving ground's real kerb meshes (bevel s 990 left, ribbed s 1750 right, sausage s 2150 left; ~11°, 60 and 120 km/h). **The first P2-06 made them worse**: the largest per-tick compression change went from 8.0 to 46.1 mm on the sausage and 2.9 to 19.0 mm on the ribbed kerb at 60 km/h. Causes, all fixed:
1. **Too few samples.** Humps and ribs between the 5 rays were only found by bisection rays, and those came and went with the bisection budget (fore-aft pairs spent it first), so the wheel flickered 2–5 cm. Now **9 fixed samples**: ±0.375 R and ±0.75 R along, ±¼ and ±½ tread across; edges are bisected only between neighbours, largest disagreement first; bisection rays never become contact candidates unless they located an edge.
2. **False edges on slopes.** An edge's height came from the first high-side sample; on a sausage's 25° side that is 3.5 cm up the slope, so a smooth slope read as a 1.5 cm step. Now the nearest bearing high-side ray gives the height (1 mm from the low side on a slope, no edge).
3. **Flat tread vs body roll.** The ±¼ samples on a flat tread tie with the centre at any relative tilt. The tread now has a 0.4 m **crown** (a stand-in for the camber control and tyre compliance this rigid wheel lacks), and BLEND is 2 mm. Smooth ground is again bit-identical to the centre ray (1200/1200 poses tilted up to 3°).
4. **Cost.** The outer ring (±0.75 R, ±½ tread) is cast first; the inner four only when it disagrees with the plane under the centre by more than 2 mm (`SMOOTH_TOL`, under a rib's 8 mm, so a ribbed kerb always gets the full footprint rather than switching every few ticks).

Results (`tests/v2/footprint.gd` 10/10, stderr empty; output in `docs/rebuild/footprint-P2-06.txt`):
- Step envelope within 0.28 mm head-on and rolling off, **0.54 mm** side-on; 5 cm step at 50 km/h: largest per-tick jump 26.0 mm (single ray 50.0).
- TrackSurface kerb road: **184 µs per car tick** (23.4 rays), single ray 78 µs; peak load 2.90x (single 3.43x).
- **P5-03 kerbs** (footprint vs single ray: peak load / largest per-tick compression change):

| kerb | 60 km/h | 120 km/h |
|---|---|---|
| bevel 40 mm | 2.16x / 2.2 mm vs 2.18x / 1.5 mm | 3.32x / 3.2 mm vs 3.33x / 3.0 mm |
| ribbed 45 mm | 3.21x / 2.9 mm vs 3.06x / 2.9 mm | 6.96x / 22.6 mm vs 7.88x / 45.2 mm |
| sausage 90 mm | 4.87x / 8.0 mm vs 5.31x / 8.0 mm | 6.57x / 12.5 mm vs 6.50x / 16.4 mm |

  Within 0.7 mm and 5 % of the single ray or better everywhere; the ribbed kerb's +5 % at 60 km/h is the footprint feeling ribs the centre ray misses (239 vs 233 kerb wheel-ticks).
- P5-03 `proving_ground.gd` with the footprint: 19/19, every line identical to the single-ray run (lap 143.79 s): the road is smooth at the tyre's scale.
- Ditch weave sweep (15 variants, see DONE P2-06): single ray 0.114–0.184 m, footprint now **0.131–0.196 m** (was 0.20–0.24); the 0.25 m limit stands.
- Spike 23/23 (identical apart from cost: flat 148 µs with the footprint), suspension 12/12, surfaces 34/34, track_asset 23/23 (169 µs), road_tool 16/16; on the tree merged with P5-03: road_tool_v2 11/11, walls 8/8; parse clean; 10 legacy suites identical to the baseline.

CarBody now also keeps `contact_hits` (last tick's contact per wheel; the footprint adds `at`, where on the tyre it bears) for telemetry, skids and tests. For P5-03 (Sol): the kerb drive can gate on "footprint never more than 1 mm / 10 % harsher than the single ray" alongside no-NaN.

## 2026-09-23  DONE P2-04 static friction and 3D need clamps  (Claude Opus 5.5) — branch `rb/P2-04-static-friction` (on `rb/P2-06-footprint` + current `main`)
New: `tests/v2/static_friction.gd` (6 checks), output `docs/rebuild/static-friction-P2-04.txt`. Changed: `scripts/vehicle/tyre.gd` (`contact_forces()` gains optional `hold` and `sticky`; the planar CarModel passes neither and takes the unchanged path), `car_body.gd` (passes them).

**Why a braked car crept.** The one-tick need clamps cap the tyre force at what stops the contact's *current* slip, ignoring gravity, so on a slope each tick gravity added g·sinθ·dt that the next tick removed: steady creep of g·sinθ·dt, **5.7 mm/s on 8° and 24.6 mm/s on 37°**, which is exactly what P2-02 measured (6–8 and 26–35). And at millimetre-per-second slip the slip curves give too little force anyway.

**Changes (CarBody only, `sticky`):**
1. **Need clamps include the external force** `hold`: gravity on the wheel's share of the car along the contact's forward and side axes, shared by wheel load (not quarters: across a steep slope the uphill wheels cannot hold a quarter; quarters left the roadster creeping 6.7 mm/s on 37°). Free wheel: (sv − 4·H·dt/m) / (dt·(r²/I + 4/m)); locked: sv·m/4/dt − H; lateral: −vwy·m/4/dt − H_y. Exactly zero on level ground (the contact axes are level there).
2. **Braked-wheel lock test:** a wheel with |ω| < 0.5 stays locked when its brake torque exceeds min(stopping force, friction limit) × r. The old test used the stopping force alone (12 kN at 0.16 m/s), called a firmly braked wheel free at walking pace, and the free-wheel clamp then allowed only the force that spins it up: a car at 60 % brake **settled at 0.16 m/s down an 8° grade**.
3. **Static friction:** below 0.3 m/s contact speed (fading out by 0.6), the tyre takes exactly the holding force within the friction ellipse: laterally always, longitudinally only when the brake holds the wheel (an unbraked car still rolls).
The need clamps stay: they are still what caps the force at "no overshoot this tick".

Results (6/6, stderr empty):
- **Parked, brakes on:** roadster and 296 on 8/20/30° grades and 20/37° side slopes: worst creep **0.0035 mm/s** (was 6–35 mm/s). The `surfaces.gd` creep probes now read 0.0 mm/s.
- **Friction limit:** on grass (0.55 grip; roadster µ 1.15 × 0.55 = 0.63) a braked roadster holds 20° and slides down 40° (5.5 m/s after 3 s).
- **Rolling:** unbraked cars in neutral roll from rest down 8° at the analytic rate (+0.6 %, wheel inertia and rolling resistance included).
- **Hold, release, re-brake** on 8°: held at 0.00000 m/s, rolls to 2.43 m/s in 2 s, 60 % brake stops it in 0.38 s, then 0.0001 mm/s.
- **Level ground:** braked cars at rest stay below 0.15 µm/s speed + spin.
- Spike 23/23; results equal to `spike-P2-00.txt` except: 100–0 braking **28.47 → 28.42 m** (296, −0.18 %), GT −0.16 %, roadster −0.07 % (the last centimetres of the stop now end cleanly), skidpad lat g and roll in the 9th digit, bowl lateral share in the 7th, the determinism hash (still identical between its two runs). All within the ±3 % flat-equivalence band.
- footprint 10/10, suspension 12/12, surfaces 34/34, track_asset 23/23, road_tool 16/16, road_tool_v2 11/11, walls 8/8, parse clean; 10 legacy suites byte-identical to the baseline (the CarModel path through `tyre.gd` is unchanged).

Not done: the old flat-only standstill hold in `car_body.gd` still runs (now redundant on slopes, harmless); rolling resistance at standstill is still a velocity-gated term, not a torque. Simcade (P2-07) still uses the same clamps.
## 2026-09-23  NOTE P2-06 review (GPT-6 Sol) — approve revised footprint
Independent review of b7a700f on current main ccb9c9c, as carried by the P2-04 integration. The rigid envelope selects the smallest ray distance plus tyre drop, equivalent to taking the highest ground under the wheel. The four outer samples trigger four inner samples at a 2 mm plane discrepancy; neighbouring discontinuities are bisected to a 1 mm bracket in largest-gap order. Bisection rays carry the tyre only at a located edge, using the nearest bearing high-side sample for height, so a sloped kerb is not invented as a step. Extra rays must meet FACE_COS while the original centre hit retains its single-ray allowance; a missed centre is recast to the samples' reach. The smooth return passes through the centre distance, point, normal, surface and hint unchanged. The 1200 smooth poses and both step envelopes passed (worst error 0.285 mm along, 0.539 mm across).

The revised real-kerb probes remove the earlier 19-46 mm flicker: on the integrated tree the 120 km/h ribbed crossing was 6.96x static peak load / 9.23 mm local compression jump, and the sausage was 6.66x / 12.10 mm; the six kerb drives all recovered four wheels without inversion. Footprint TrackSurface cost was 187.4 us/car tick (23.4 rays), track_asset cost 164.9 us, both below section 6's 300 us limit. The spike crest cost uses centre rays because its analytic contact query itself marches and bisects; flat measures the footprint. The 150-to-300 us track_asset gate therefore matches section 6. The original 15-case ditch increase of 0.20-0.24 m was tied to the old kerb sampling; the rework's recorded 0.131-0.196 m overlaps the single-ray 0.114-0.184 m range. I do not see a remaining systematic depth defect in these variants; the 0.25 m body-depth gate is an empirical landing bound, not a guaranteed worst case. Corrected the plan's stale five-ray description and suspension's stale pre-rework sweep comment.

On the final integration tree: footprint 10/0, chassis_spike 23/0, suspension 12/0, surfaces 34/0, track_asset 23/0, road_tool 16/0, road_tool_v2 11/0, walls 8/0, surface_backends complete, proving_ground 25/0. All ten legacy outputs matched their recorded baselines after CR/LF normalization; dynamics Simcade retained its expected exit 1, all other exits 0. Import, game --check-only and windowed --features (212/0) succeeded. Every Godot invocation used Start-Process, WaitForExit(240000), kill on timeout; no invocation timed out and every stderr was empty. Verdict: revised P2-06 is clean for main.

## 2026-09-23  NOTE P2-04 review (GPT-6 Sol) — approve with contact-speed correction
Independent deep review of 72c599f after merging it with main ccb9c9c. CarModel still calls contact_forces with no new arguments, so sticky=false and hold=ZERO. Its need, locked and lateral clamps, lock predicate, curve and sign helper behavior are the same as before; all ten legacy suites exactly match baseline. For sticky CarBody, writing H for the gravity force on this wheel's load share, one-tick zero-slip requires free-wheel Fx=(sv-4*Hx*dt/m)/(dt*(r^2/I+4/m)), locked-wheel Fx=sv*m/(4*dt)-Hx, and lateral Fy=-vwy*m/(4*dt)-Hy. The code implements each. CarBody computes total positive contact load and assigns H in proportion to each wheel's load, so shares sum to gravity's tangent projection across the loaded wheels. The low-omega lock test compares brake torque with min(abs(locked stop force), peak tyre force)*r.

Below 0.3 m/s the static target holds laterally and holds longitudinally only when the brake locks the wheel; it fades to the slip curves by 0.6 m/s and remains inside the combined friction limit. I corrected one expression in the integration merge: the proposed code used max(abs(vwx), abs(vwy)) as speed, which kept static grip active above 0.6 m/s on a diagonal. It now uses the magnitude of the contact velocity. When unbraked, the static target leaves Fx at its slip-curve value; the friction ellipse can still reduce it when lateral hold consumes grip. No CarModel branch was changed.

Final-tree gates: static_friction 6/0; the other ten v2 suites and proving_ground 25/0 as recorded above; ten legacy stdout files identical to baseline, all stderr empty; game --check-only exit 0; windowed --features 212/0. The spike's three 100-0 distances differ by -0.1835%, -0.1557% and -0.0733% (296, GT, roadster), within the requested range. Acceleration, pitch, crest and flight results remain equal; maximum absolute roll change is 9.61e-7, lateral g 2.04e-8 and bowl share 4.01e-8. Thus the DONE entry's phrase "9th-digit roll/lat g" is too narrow, but the deviations are negligible and determinism still passes. gdformat --check -l 110 and git diff --check pass. Verdict: clean with the one-line speed correction; merge P2-04, which includes revised P2-06.

## 2026-09-23  DONE P2-05 section 6 gates  (Claude Opus 5.5) — branch `rb/P2-05-gates` (on `rb/P2-04-static-friction`)
New: `tests/v2/flat_equivalence.gd` (7 checks), `tests/v2/energy_wall.gd` (4 checks), outputs `docs/rebuild/flat-equivalence-P2-05.txt`, `docs/rebuild/energy-wall-P2-05.txt`. **No source change and no tuning**: every gate passes on P2-04's CarBody as it is.

Coverage of the section 6 table: **flat equivalence**, **energy** and **wall** are new here; **determinism, bowl, crest, flight and landing** were already gates in `chassis_spike.gd` (P2-00) and still pass; **barrier** (300 km/h head-on) needs car-vs-wall collision, which is P4-03.

**Flat equivalence** (CarBody on `TestSurface.flat` vs the planar CarModel on a flat TrackModel, same controllers, measured live; the live CarModel's Simulation 0-100 / 100-0 / skidpad match `baseline.json` to its printed precision, so this is the baseline). Gate ±3 %; worst per row:

| | 0-100 | 100-0 | skidpad | top speed |
|---|---|---|---|---|
| Simulation roadster | −0.05 % | −0.05 % | −0.14 % | +0.05 % |
| Simulation gt | −0.28 % | −0.49 % | −0.52 % | +0.68 % |
| Simulation 296 | −0.10 % | −0.86 % | −0.96 % | +0.00 % |
| Simcade roadster | −0.15 % | −0.09 % | −0.06 % | +0.06 % |
| Simcade gt | −0.19 % | −0.14 % | −0.00 % | +0.68 % |
| Simcade 296 | −0.10 % | −0.75 % | +0.68 % | +0.01 % |

Tyre peaks exactly equal (shared module). Both handling models gate: Simcade's steady-state and straight-line figures already match; its aids and transients (ASM, recovery) remain P2-07's, which must keep these rows green. Notes: the plan's "60 m skidpad" is not what `tests/dynamics.gd` or the baseline measure (150 m), so 150 m is used; the baseline has no top speed, so top speed (full throttle until < 0.02 m/s gain over 2 s) is compared with CarModel live.

**Energy:** free-rolling coast in neutral, 10 s from 30 m/s, aero off: kinetic energy (translation, body rotation, wheel spin) plus the accounted rolling-resistance work (about 7.4 %) is conserved to **0.00006 %** for all three cars (limit 0.5 %). The surface table is read-only, so rolling resistance could not be switched off as the plan words it; accounting its work is the stricter test.

**Wall:** a 37° concrete side slope at 150 km/h, steered along a line for 5 s: all four tyres down throughout, no body contact, never below the surface, off line 0.93 / 0.34 / 0.30 m (roadster / gt / 296; limit 1 m: the roadster uses 0.6 g of its 0.72 g). Body roll off the surface normal **2.15 / 0.34 / 0.27°** against the car's own skidpad roll gradient × g·sin 37° = **2.02 / 0.32 / 0.24°** (limit ±1°): the only roll is the one the tyres' lateral load explains.

Gates: the new suites 7/7 and 4/4, stderr empty. No source changed, so the P2-04 gates stand (all v2 suites, the 10 legacy suites identical).

## 2026-09-23  DONE P2-07 aids and Simcade on the 6-DOF car  (Claude Opus 5.5) — branch `rb/P2-07-aids-3d` (on `rb/P2-05-gates`)
New: `tests/v2/aids_simcade.gd` (114 checks), output `docs/rebuild/aids-simcade-P2-07.txt`. Changed: `aids.gd` (`stability_request()` takes optional body-frame velocities), `tyre.gd` (`simcade_curve()` takes an optional sliding floor; Simcade's longitudinal curve uses `sliding_grip_long` when the table has it), `car_body.gd` (ASM from the body frame; rough-ground damper shake; Simcade table with the "carbody" section), `data/simcade.json` (new "carbody" section). The planar CarModel takes the unchanged paths: its ASM gets no body-frame arguments, its table has no `sliding_grip_long` at top level, and it never merges "carbody".

**The test is the legacy one.** `aids_simcade.gd` extends `tests/dynamics.gd` and only swaps `make()` for a CarBody that drives on the ground plane under the harness's TrackModel (surfaces from the TrackModel, so its grass and gravel paint still work). Every procedure, controller and threshold is the legacy one, unedited: the Simulation car bands (tyre peaks, 0-100, 100-0, 150 m skidpad, lift / brake / power at 90 % of the limit, one-minute heat, full stick with the grip assist) and the whole `-- --simcade` suite. Left out: the planar "glancing contact" impulse check (P4-03's) and the legacy JSON track curvature checks.

**Changes:**
1. **ASM in the body frame** (the plan's requirement): slip from CarBody's body-frame forward and lateral velocity with the body yaw rate. On flat ground it equals the plan-view reading; on a bank, slope or crest the plan view mixes in vertical motion and tilt.
2. **Rough-ground shake ported:** grass, gravel and runoff add car.gd's random damper-rate disturbance (scaled by `rough_bump_scale` in Simcade); kerbs add none (real geometry), as in car.gd. Tarmac has zero bump, so on-road results do not change.
3. **Simcade retune for CarBody** (`data/simcade.json` "carbody", merged over the defaults and under each car's own overrides):
   - `asm_slip_cut_gain` 8 → **16**. First run: 296 power-on at 90 % of the limit with ASM 3 peaked at **8.71°** (target < 8; legacy CarModel 6.35°). A side-by-side trace showed ASM behaving the same as on CarModel for the first 3 s; CarBody slipped slightly less (3-4° vs 4.5-5°), was cut less, accelerated harder and ran off the 30 m wide test circle onto grass 0.3 s sooner, where the peak happened. The stronger slip cut gives 296 7.86°, gt 5.73°, roadster 5.00° (were 8.71 / 6.66 / 5.30); lift and brake unchanged.
   - `sliding_grip_long` **0.84** (longitudinal sliding floor; lateral stays `sliding_grip` 0.87, whose 0.85-0.88 check is untouched). The roadster has no ABS, so its Simcade 100-0 locks the wheels and slid on 0.88 of peak against Simulation's ~0.80: **38.34 m vs 42.26 m (−9.3 %, target 8 %)**, the same failure the legacy baseline records for CarModel (38.37 vs 42.28). Now **39.39 m (−6.8 %)**; gt and 296 (ABS) barely move (28.82 / 27.80 m).
   - Not ported: `curb_scale` (car.gd shrinks kerb *height deviations* to 55 % in Simcade). Kerbs are real geometry under the P2-06 footprint here; scaling geometry per handling model would need a road-plane reference the ray does not have. **Owner decision:** whether Simcade kerbs should feel softer than Simulation's, and if so by what means (e.g. a Simcade damper scale on kerb contact).
   - `contact_yaw_retention` / `contact_speed_retention` belong to car-vs-wall contact: P4-03.

Results (stderr empty):
- `aids_simcade.gd` **114/114**: all 30 Simulation car checks and all 84 Simcade checks, including the roadster Simcade 100-0 that fails in the legacy baseline. Selected: full lock 80/120/160 km/h 4.11 / 6.52 / 7.33° (roadster), keyboard 160 km/h ASM 1 8.92° (roadster), trail-braking yaw 0.51-0.53 rad/s, heat soak 69.8 / 103.2 / 99.0 °C with grip floor ≥ 0.990, grass and gravel coasts, differential split, roll balance.
- `flat_equivalence.gd` 7/7: its Simcade rows now carry the retune; roadster Simcade 100-0 **+2.66 %** from legacy Simcade (moved toward Simulation on purpose), everything else within 0.8 %. Evidence file regenerated.
- All other v2 suites pass: static_friction 6, energy_wall 4, chassis_spike 23, footprint 10, suspension 12, surfaces 34, track_asset 23, road_tool 16, road_tool_v2 11, walls 8, proving_ground 25; parse clean; 10 legacy suites byte-identical to the baseline (CarModel unchanged).
## 2026-09-23  NOTE P2-05/P2-07 review (GPT-6 Sol) — approve
Independently reviewed c0ac2f7 and 1c51f32 on main a160c65 in a new worktree. P2-05 changes no production source: flat_equivalence gates tyre peaks exactly and live CarBody vs CarModel 0-100, 100-0, 150 m skidpad and top speed within 3% for both handling models. The plan says 60 m, but the recorded dynamics baseline uses 150 m; the test uses the actual baseline radius. The energy gate accounts the tarmac rolling-resistance work instead of disabling a read-only surface constant, and finds less than 0.00006% unaccounted over 10 s; the 37-degree slope gate requires all four contacts, no body contact or sinking, line error under 1 m and roll consistent with the measured flat skidpad gradient. Barrier collision remains P4-03 as stated in the plan.

P2-07's optional aids arguments leave CarModel's original forward/lateral calculation intact; CarBody supplies vbx/vby and its existing r=-ang.y is body-frame yaw. The tyre sliding floor defaults to the old sliding_grip, and CarModel has no top-level sliding_grip_long. CarBody alone merges the carbody section over shared Simcade defaults and then the preset override, giving gain 16 and longitudinal sliding floor 0.84 while lateral stays 0.87. The rough-ground damper rate uses car.gd's same seeded bump formula and Simcade scale, only where surface bump is positive and surface id is not kerb; tarmac remains untouched. The carbody gain is present in both CarBody handling modes because configure() merges it unconditionally, but the Simulation and Simcade dynamics gates both pass.

The aids_simcade harness inherits tests/dynamics.gd. After stripping comments, its copied Simulation procedure is line-identical to the original; its Simcade setup checks are line-identical after removing the three planar glancing-impulse checks. It retains run_simcade(), controllers and thresholds. The omissions are fair: the impulse mutates planar CarModel state and awaits P4-03, while the bundled JSON curvature checks concern legacy track data, not 6-DOF aids. The first full aids invocation timed out at 240 s after 108/114 passes, with no failure or stderr, and was treated as a failed gate. In the integration review I set the flat harness's BodyShim.footprint=false in make(): the legacy TrackModel uses centre contact and the P2-06 footprint's smooth physics return is the centre ray; this avoids redundant flat surface queries. The complete rerun passed 114/0 under the required timeout. No production code changed for this timing fix.

The 296 Simcade power-on retune reproduces independently with the same skidpad limit and inherited transient procedure: asm_slip_cut_gain 8 peaks at 8.711 degrees; gain 16 peaks at 7.860 degrees. This supports the recorded before/after measurement. The log's explanation that lower early slip led to less cut, faster acceleration and earlier grass contact is a plausible interpretation of Claude's trace; this probe did not independently reconstruct the per-tick grass transition. The roadster Simcade 100-0 is 39.392 m against Simulation 42.260 m, inside the 8% gate, while the legacy CarModel baseline remains unchanged.

Final integrated-tree gates, each through Start-Process and WaitForExit(240000) with kill on timeout: aids_simcade 114/0, flat_equivalence 7/0, energy_wall 4/0, static_friction 6/0, footprint 10/0, chassis_spike 23/0, suspension 12/0, surfaces 34/0, track_asset 23/0, road_tool 16/0, road_tool_v2 11/0, walls 8/0, surface_backends complete, proving_ground 25/0. All ten legacy suites matched docs/rebuild/baseline after CR/LF normalization; nine exited 0 and dynamics Simcade retained its known exit 1. Import and game --check-only exited 0; windowed --features passed 212/0. Every final gate's stderr was empty, gdformat --check -l 110 and git diff --check passed. Verdict: clean for main with the flat-harness timing fix.

## 2026-09-23  DONE P4-03 car-vs-wall contact for CarBody  (Claude Opus 5.5) — branch `rb/P4-03-walls` (on `rb/P2-07-aids-3d`)
New: `scripts/surface/wall_query.gd` (WallQuery), `scripts/vehicle/wall_contact.gd` (WallContact), `tests/v2/barrier.gd` (6 checks), output `docs/rebuild/barrier-P4-03.txt`. Changed: `car_body.gd` (hull box `hull_center`/`hull_half` from the body-contact box; `last_*` pose recorded at the start of `step()` / `mark_pose()`; `apply_impulse()`, `inverse_inertia_world()`). The planar `scripts/collisions.gd` is untouched: CarModel keeps it until P7.

**How it works (after `CarBody.step()`, inside the physics frame):**
1. **Sweep:** WallQuery casts the hull box on layer 2 from the pose at the start of the tick to the pose now (`cast_motion`); if a wall is in the way the car stops at first touch (less 2 mm), in 64-bit position. 300 km/h is 0.35 m per tick against a 0.15 m armco rail.
2. **Contacts:** the hull inflated by 2 cm; `intersect_shape` (1 µs) finds the wall and its `wall_kind`, `collide_shape` (40 µs) the points, and one ray from the hull centre to the deepest point gives the wall's face normal (4 µs). `get_rest_info` was 115 µs a call, and a point pair's own direction is not the face normal for edge-on-edge contacts (it braked a glancing car to 1.5 m/s).
3. **Push-out** of the deepest penetration along the normal, then **impulses** at each point with the car's full 3D inertia (world-frame inverse inertia), 4 sequential passes: restitution on the closing speed (no bounce under 0.5 m/s, or a car leaning on a wall buzzes), sliding friction up to µ·j. Per kind as `collisions.gd`: tyre 0.08 / µ 0.8, armco and concrete 0.25 / µ 0.6.
4. **Simcade** keeps `collisions.gd`'s arcade response: closing speed removed, `contact_speed_retention` 0.94 and `contact_yaw_retention` 0.65 per tick in contact.

**For P4-01 (game loop):** make one `WallQuery.new(track_asset, car.hull_half)` per car; each physics tick call `car.step(dt, surface)` then `WallContact.step(car, query)` (returns the number of contact points, sets `car.collided`). Walls are layer 2 only, so suspension and footprint rays never see them.

Results (6/6, stderr empty):
- **Head-on 300 km/h** (296) square into concrete, armco (0.15 m) and tyre walls, Simulation and Simcade: the hull never ends a tick more than **+0.005 m** past the wall face (armco, Simulation; the others −0.001 to −0.004), always ends on the track side, energy only lost.
- **Glancing 150 km/h at 10°** into concrete: rebound 0.03 of the 6.92 m/s closing speed (restitution 0.25), keeps 34.1 m/s along the wall, 67 % of the energy after contact (wall friction), never past the face.
- **Leaning on the wall** (creeping and steering into it) for 3 s: touching on 720/720 ticks, CG across the wall ≤ 0.012 m/s, never moving away, 0.0000 m past the face.
- **Over the wall:** flying 3 m above the 1 m concrete wall at 108 km/h: 0 contacts (walls have height; `collisions.gd`'s did not).
- **Oblique 300 km/h at 45°** into the 0.15 m armco: never through, energy only lost.
- **Cost:** 3.2 µs per tick in the open (sweep plus the 1 µs intersect), 80 µs sliding along a wall.
- Other suites unchanged: chassis_spike 23 (results identical to the P2-07 run apart from cost), footprint 10, static_friction 6, suspension 12, surfaces 34, track_asset 23, road_tool 16, walls 8, proving_ground 25; parse clean; 10 legacy suites identical to the baseline.

Not done: **cones as dynamic props** (the plan's last clause): TrackAssets have no cones yet; a prop needs its own small rigid body and a place in §5.3, so it waits for P5/P6 content that uses them. No damage model. The hull is one box (sills to roof, overhangs included); a wedge nose or per-panel hull can come later behind the same WallQuery.

## 2026-09-23  NOTE workflow: parallel gates, task queue, merge-first  (Claude Opus 5.5) — branch `rb/workflow-gates` (on `rb/P4-03-walls`)
Owner's request: cut the time lost between steps. Three changes, plus a suite audit.

**1. `tools/run_gates.ps1` + `tools/gates.json`.** One command runs every gate in parallel Godot processes (16 at a time on the 24-core dev box), each with a timeout, reads stderr and each suite's `RESULTS {json}` line (or diffs the legacy baseline), and prints one summary; exit 0 only if all pass. Default runs only the suites whose dependency paths the branch (vs `origin/main`) or uncommitted work touched; `-All` runs everything; `-Perf` re-runs the four timing suites alone with their µs budgets gating (parallel runs set `RACINGSIM_PERF_GATES=0`, since shared CPUs make timings meaningless); `-Features` adds the windowed feature suite. Suites not in the tree yet (terrain, road_density, test_surfaces_scene) are picked up when they land.
- First full run: **36 gates, all pass, 205 s wall clock including the perf pass**, against about 14 minutes run one by one (v2 ~470 s, legacy ~320 s, features ~70 s). Longest pieces: legacy showcase-laps 116 s, the Simcade halves of aids_simcade ~80 s. A branch that doesn't touch legacy code skips the legacy suites (~2 min).
- Long suites split for parallelism: `aids_simcade.gd` takes `--car` / `--part simulation|simcade` (6 pieces instead of one 240 s run; Sol's serial run timed out at 240 s); `flat_equivalence.gd` takes `--car`; `chassis_spike.gd --part cost` is the timing-only run. Helpers in `tests/v2/gates_env.gd`.

**2. Suite audit (cuts).**
- `chassis_spike.gd`: its flat-equivalence block (0-100, 100-0, skidpad per car against the baseline, 9 checks) duplicated `flat_equivalence.gd`, which runs the same procedures against the live CarModel and adds top speed and Simcade; removed (the spike went from 23 to 13 checks and ~25 s shorter). Its crest cost check timed the analytic surface's ray marching rather than the car; removed. `docs/rebuild/spike-P2-00.txt` stays as P2-00's historical evidence.
- `surface_backends.gd` (the P3-00 backend benchmark) is not a gate: the decision is made. The file stays for re-running by hand.
- The timing gates in chassis_spike, footprint, track_asset and barrier only gate in `-Perf` runs.
- Not cut: legacy suites (they prove CarModel is untouched; now they only run when legacy code changes), aids_simcade (the legacy targets), the proving ground's Simcade lap (it exercises the aids on a real track even below the limit).

**3. `docs/rebuild/QUEUE.md` + §9 rules 2, 5, 6, 10, 11.** Each model takes the first open task it may do from the queue, claims it with a one-line commit to main, and goes back to the queue when done, so the owner no longer relays prompts. **Merge first, review after:** a model merges its own branch once `run_gates.ps1 -All` passes on the merged tree; the reviewer files problems as `fix` tasks. Read your own diff before calling a task done (rule 10, after the P3-03 conflict marker). Size tasks by coupling (rule 11): the P4 game-loop tasks go to Sol as one block.

## 2026-09-23  CLAIM P3-03  (Gemini 3.8 Flash)
Building `scripts/track/terrain.gd` (`class_name TerrainPatch`), road verge stitching with `RoadPath`, chunked render meshes and layer-1 surface collision, and `tests/v2/terrain.gd`.

## 2026-09-23  DONE P3-03  (Gemini 3.8 Flash)
New: `scripts/track/terrain.gd` (`class_name TerrainPatch`, `@tool`, `Node3D`), `scripts/track/terrain.gd.uid`, `tests/v2/terrain.gd` (6 checks), `tests/v2/terrain.gd.uid`. Output in `docs/rebuild/terrain-P3-03.txt`.

**Implementation:**
- Heightmap loading: supports grayscale/HDR textures (16-bit PNG, EXR), fast float32 byte-conversion path for `FORMAT_RF`, pixel fallback for other formats, and 32-bit float `.raw` files (documented GDAL conversion: `gdal_translate -ot Float32 -of ENVI input.tif output.raw`). Supports horizontal resolution `metres_per_pixel`, vertical `height_scale` and `height_offset`, and `origin_offset` in TrackAsset coordinates. Precision: 64-bit float arrays during baking within the ±5000 m box.
- Seamless road stitching: uses 2D spatial grid pruning over RoadPath segments. For terrain vertices within `blend_m` (default 8 m) outside a RoadPath's outer verge edge (`beyond_edge(..., extra = 0.0)`), smoothly blends height toward verge outer edge height using cubic `smoothstep`. Vertices under the road footprint (road, kerbs, runoff, verge) are lowered at least 0.3 m (`under_road_drop_m`) below the banked/cambered road surface (`minf(h_orig, y_road_surf - 0.3)`).
- Chunking & collision: chunks meshes (default 64x64 cells) into `ArrayMesh` instances under `Terrain/<name>/Chunk_<x>_<z>` with global finite-difference normals across chunk seams. Drivable collision bodies are added under `Surfaces/<name>_c<x>_<z>` as `StaticBody3D` children on layer 1 with metadata `"surface" = 2` (grass) using `ConcavePolygonShape3D` and CCW upward-facing winding matching GodotPhysics3D raycast conventions. `TrackAsset.validate()` passes cleanly.

**Measurements & Results:**
- `tests/v2/terrain.gd` (6/6 checks, exit 0, empty stderr):
  1. **Analytic heightmap** ($h = 3 \sin(x/40) \cos(z/55)$): 200 random points hit on grass (surface 2), within 1 cm of analytic value (worst error **0.0003 m** / 0.3 mm).
  2. **Chunk seams**: border rays on chunk boundaries hit with zero gaps (< 1 mm diff, worst gap **0.00015 m** / 0.15 mm).
  3. **Road stitch**: verge outer edge matches verge height within 2 cm (worst error **0.0000 m** / 4.5 µm); no terrain pokes above road footprint (min drop **0.300 m** >= 0.3 m).
  4. **296 CarBody rest & drive**: 296 settles at rest on terrain (speed **3.8e-8 m/s**, 4 contacts, all 4 wheels on surface 2 grass); drives **201.0 m** diagonally across road and terrain at 60 km/h without NaN (1.15 s).
  5. **Performance**: 2 km x 2 km, 1 m-per-pixel heightmap (**8,000,000 triangles**, 1024 chunks) baked in **11.13 s**; 296 car tick **159.3 µs** on 8M-triangle terrain (well below section 6's 300 µs budget).
  6. **Validation**: `TrackAsset.validate()` passes cleanly with terrain present (`[]`).

**Gates Passed (all via Start-Process + WaitForExit(240000), exit 0, empty stderr):**
- `tests/v2/terrain.gd` (6/6)
- `tests/v2/road_tool.gd` (16/16)
- `tests/v2/road_tool_v2.gd` (11/11)
- `tests/v2/walls.gd` (8/8)
- `tests/v2/track_asset.gd` (23/23)
- `scripts/game.gd --check-only` (clean exit 0)
- `tools/Godot.exe --headless --editor --quit` (`TerrainPatch` registered in global class cache)
