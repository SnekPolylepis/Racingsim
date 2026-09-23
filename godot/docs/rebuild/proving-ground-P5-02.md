# P5-02: proving-ground paper design

Status: **design target for P5-03, not a built or driven track.** This is an invented 2.51 km test circuit, with room for each rebuild feature and a straightforward normal racing line. The dimensions below are authoring targets; P5-03 must smooth the joins, drive the result and record measured speeds, loads and lap times. No DEM, imagery or third-party track geometry is needed.

## Closed plan

Use Godot world metres: +Y up. Start the `TimingLine` at `(x, y, z) = (0, 0, 0)` with the car heading +X. The driver's right is +Z, so a left turn initially moves toward −Z. Stations `s` are horizontal centreline distance in metres from the start line. Four main left corners close the loop; a right–left–right chicane on the southbound leg returns to the same heading and lateral line. The unblended line-and-circle scaffold closes at `(0, 0)` with a +X tangent and is **2506.16 m** long. Its XZ bounds are about `x = −427…280 m`, `z = −690…0 m`, comfortably within the §5.3 ±5 km limit. The final 3D lap length will be slightly longer and must come from `TrackAsset.prepare()`.

| Segment | Station (m) | Plan geometry | Feature / intended line |
|---|---:|---|---|
| Start straight, after line | 0–150 | +X straight | Level acceleration; road 14 m wide. |
| T1, Bowl | 150–354 | Left 90°, R 130 m | Continuous inward bank to 16°; aim ~69 km/h. |
| Ridge climb | 354–754 | Straight, 400 m | Climb from −2 m to +15 m. |
| T2, Camber Loss | 754–1006 | Left 90°, R 160 m | 4° adverse camber through the central arc; outside/right edge falls. |
| Crest straight | 1006–1416 | Straight, 410 m | Jump apex near s = 1115 m; long, wide landing and braking zone before T3. |
| T3, Concrete Ditch | 1416–1557 | Left 90°, R 90 m | Inner trough with 37° wall; outer road is a legal bypass. |
| Chicane run-in | 1557–1627 | Straight, 70 m | Settle the car before the kerbs. |
| T4a / T4b / T4c, Esses | 1627–1690 / 1690–1815 / 1815–1878 | Right 45° / left 90° / right 45°, each R 80 m | Low and ribbed kerbs; normal line stays on tarmac. |
| Compression approach | 1878–2052 | Straight, 174 m | Concave dip near s = 1970 m, then climb toward T5. |
| T5, Home Loop | 2052–2256 | Left 90°, R 130 m | Optional high kerb outside the normal line. |
| Start straight, before line | 2256–2506 | +X straight, 250 m | Level grid and timing area; joins station 0. |

Useful plan anchors after the major corners are T1 `(280, −130)`, T2 `(120, −690)`, T3 `(−380, −600)`, and T5 `(−250, 0)` in `(x, z)`. The chicane reaches about `x = −427 m` before returning to `x = −380 m`. These anchors and the listed radii make the scaffold close; P5-03 should use short, tangent-continuous easing at the joins and remeasure stations instead of preserving the sharp curvature changes of ideal circular arcs. Keep the crest's central curvature and the bowl's central bank when easing their entrances and exits.

## Centreline elevation profile

Positive `y` is above the start/finish level. These are **target keys**, not a claim that a spline or collision mesh already has these heights. The paired crest and compression keys describe local circular vertical arcs; ease the surrounding grades continuously. Avoid a mesh seam at either apex or at the closed lap joint.

| s (m) | Centreline y (m) | Purpose |
|---:|---:|---|
| 0, 150 | 0 | Level start and T1 entry. |
| 250 | −5 | Low point of the bowl. |
| 354 | −2 | Bowl exit. |
| 754, 1006 | +15, +18 | Climb, then mostly level through adverse-camber T2. |
| 1095, 1115, 1135 | +25.46, +27.00, +25.46 | Central 40 m of R ≈ 130 m convex crest. |
| 1250, 1416 | +16, +8 | Landing, then braking before the ditch. |
| 1557, 1878 | +6, +4 | Gentle fall through ditch and esses. |
| 1945, 1970, 1995 | +0.60, −2.00, +0.60 | Central 50 m of R ≈ 120 m concave compression. |
| 2052, 2256, 2506 | +5, 0, 0 | Recover through Home Loop; level grid and lap closure. |

The default 296 GT3 has mass 1300 kg and `clAF + clAR = 4.1`; the current solver uses air density 1.22 kg/m³. For a circular crest, a first estimate of wheel unload solves `v²(1/R − ρ(clAF + clAR)/(2m)) = g`. With R = 130 m, that gives **148.5 km/h**; without aero the geometric threshold is 128.6 km/h. Suspension motion, pitch, actual spline curvature and speed at the apex will shift the observed threshold. P5-03 should tune the built crest so the default 296 GT3 takes off at roughly **150 km/h**, remains planted on a slower pass and lands before the T3 braking zone. This is a content target, separate from §6's no-aero analytic crest test.

The T1 banking gives `sqrt(g R tan(16°)) ≈ 69 km/h` for low lateral tyre demand at its central radius. The compression's R ≈ 120 m adds about **0.66 g** of vertical load at 100 km/h before suspension and aero effects. P5-03 should measure both in Simulation and Simcade and soften the profile if normal racing produces bottoming or unstable contacts.

## Cross-sections and surfaces

- Road is 12 m wide except the 14 m start straight. Transition widths over at least 25 m. Bank T1 inward (inside/left edge lower); bank T2 outward by 4° (outside/right edge lower), both eased on tangent approaches. Keep the crest and compression cross-section smooth across all wheel paths.
- T3's **concrete ditch** is an optional inner line: 3.0 m flat floor, a 1.1 m horizontal run at 37° on each wall, and 0.5 m fillets into floor and outer road. Its nominal depth is about 1.21 m (`tan 37° × (1.1 + 0.5)`). Offset the trough about 2 m toward the inside of T3, with 15 m tapered entry/exit. Leave at least 4 m of ordinary tarmac outside it so the bot can bypass; an alternate challenge line should put one side of the car on the inclined concrete. Use the existing tarmac surface ID 0 for the concrete's grip until a separately approved surface-contract change says otherwise.
- Give P3's road tool three physical kerb examples: **low bevel** (about 40 mm rise, 0.6 m width) at the T2 exit; **ribbed** (about 45 mm base with 8 mm ridges, 0.8 m width) at the esses; and a **high sausage** (about 90 mm rise, 0.6 m width) at the T5 inside, outside the normal bot line. A flat painted strip on the start straight is the zero-height control. Physical kerbs use existing surface ID 1; paint alone does not add a step. These are P5 content variants, not a new §5.2 contract.
- Put tarmac runoff (surface ID 4) around the crest landing and compression, with at least 10 m beyond the road edge before a barrier. Use grass ID 2 and gravel ID 3 at slower corners so off-track transitions are visible. Keep walls outside the normal line and landing envelope. P5-03 must drive both edges with the P2-06 footprint filter before signing off kerb heights or collision placement.

## TrackAsset hand-off and acceptance

Author `tracks3d/proving_ground/proving_ground.tscn` with `id = "proving_ground"`, `version = 1`, `TimingLine` at the start line and a closed-implicitly lap path (do not repeat its first point). Put sector offsets near **700 m** and **1600 m**, on stable sections; place checkpoints away from the airborne crest and ditch ramps. Four grid slots fit on the level 250 m approach to the start line, about 35, 75, 115 and 155 m behind it, with each marker's −Z down the track per §5.3. Make a BotLine that bypasses the ditch and high kerb, and a separate optional ditch challenge line. No scene, mesh or test output is part of P5-02.

P5-03 should record the final plan/3D lap lengths and grade/bank/kerb values, then verify: the scene validates and loads; four grid slots are on tarmac; the default 296 GT3 has a valid bot lap in both handling models with zero off-track steps and wall contacts; the bank, adverse camber, jump, compression, ditch challenge and all three physical kerbs have reproducible contact traces. The observed jump speed and compression load must be measured on the built mesh; the figures above are design estimates, not test results. Bump `version` whenever the drivable surface or timing changes after records exist.
