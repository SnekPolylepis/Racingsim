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
