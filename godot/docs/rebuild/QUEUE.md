# Rebuild task queue

The shared work list for the Racing Sim rebuild (REBUILD-PLAN.md §9, rule 2). Every model runs the same loop:

> **When idle:** `git fetch` and read this file on `origin/main`. Take the **first** task whose status is `open`, whose
> **Who** includes your model, and whose **Needs** are all `done`. Set its status to `claimed: <model>` in this file,
> commit that one line straight to `main`, push, and log `CLAIM` in REBUILD-LOG.md. Do the task per §9. Merge it yourself
> when `tools/run_gates.ps1 -All` passes (merge first, review after), then set it to `review: <reviewer>` and go back
> to the top. The reviewer sets `done`, or adds a `fix` task below with what's wrong. Ask the owner only for `owner`
> rows and decisions.

Statuses: `open`, `claimed: <model>`, `review: <model>`, `done`, `blocked: <reason>`, `needs owner`.
Models: **Claude** (Opus 5.5: physics, numerics, reviews), **Sol** (GPT-6 Sol: architecture, game integration, GitHub, reviews),
**Astra** (GPT-6 Astra: owner-assigned content/integration), **Gemini** (3.8 Flash: tools, mechanical ports, content, docs), **owner** (decisions, playtests, downloads).

## Review and fixes (take these first)

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| M-TRAIN | Merge train into main: workflow-gates (P4-03 + workflow), F-P2-08 (P2-08), F-P3-02c (P3-02c), P3-03-terrain (F-P3-03), scenery-kit, P4-07-bot-laps, P6-01-spa, P4-01-game-port | owner (GitHub PR) | | done | merged on main; read "MERGE train" |
| R-P4-03 | Review P4-03 car-vs-wall contact (WallQuery, WallContact) | Sol | M-TRAIN | done | corner-contact fix queued as F-P4-03-corners |
| F-P4-03-corners | WallQuery.contacts() assigns the first hit body's kind and one face normal to all collide_shape pairs; split simultaneous contacts by collider/face and test a two-wall corner | Claude | R-P4-03 | open | scripts/surface/wall_query.gd, tests/v2/barrier.gd |
| R-WF | Review the workflow change: tools/run_gates.ps1, tools/gates.json, §9 rules 2/5/6/10/11, suite cuts | Sol | M-TRAIN | done | reviewed on main; no fix row |
| R-P4-07 | Review P4-07 bot driver and laps gate, including P4-07b | Sol | M-TRAIN | done | reviewed on main; no fix row |
| F-P4-01 | P4-01 follow-ups (Claude's review): Esc on the v2 path quits the app instead of returning to the front end; WallContact not yet called after car.step(); game.gd and track_drive.gd preload trackgen/*.gd but export_presets.cfg excludes trackgen/* so an exported exe breaks | Sol | M-TRAIN | review: owner | folded into P4-core; branch `rb/P4-06-front-end` awaits owner merge; export checked |
| F-P6-01 | Spa v0 fixes per Claude's review (bank twist, scene size, s 6125) | Gemini | | done | Gemini's bank blend + scatter, Claude's terrain trench fix, landed as rb/F-P6-01b; read "REVIEW F-P6-01" |
| F-CI | CI tolerance scoped to the two legacy suites that differ on Linux, measured; obsolete Spa allowance removed | Claude | | review: Sol | rb/F-CI; read "DONE F-CI" |
| P4-07b | Bot robustness: honest curvature (distance chord), recalibrated pace, yaw-aware braking, smooth Spa BotLine; all 3 cars × 2 models clean on proving ground and Spa; record Spa's lap baseline | Claude | | done | reviewed on main; read "DONE P4-07b" |
| F-terrain-perf | tests/v2/terrain.gd's "car step" timing check (300 µs budget) ignores GatesEnv.perf(): under the parallel runner it read 671 µs and failed (168 µs alone). Route it through GatesEnv.perf()/perf_note() like the other timing gates | Claude | | review: Sol | small |

## Build

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| P2-08 | Debug scene to drive CarBody on the analytic test surfaces | Gemini | | done | rb/P2-08-test-surfaces 3b0143c |
| P3-02c | Variable road station density (dense ranges, zipper stitching); proving ground to coarse 9 + dense ditch | Gemini | | done | rb/P3-02c-road-density 01b1fe1; scene 8.95 → 3.87 MB compressed |
| scenery-kit | Trackside scenery kit (CatchFence, Grandstand, Gantry, Billboards, MarshalPost, PitBuilding) and proving ground placement | Gemini | | done | rb/scenery-kit; 34/34 gates pass (147 s), 11/11 scenery checks |
| P4-core | P4-01 game.gd loads a TrackAsset, CarBody replaces CarModel, §5.4 interpolation, WallContact after each step; P4-02 race.gd 3D gates and new ghost format; P4-06 front_end lists TrackAssets, loading screen, bake-on-load cache for generated tracks | Sol | | review: owner | P4-06 complete on `rb/P4-06-front-end`, branch awaits owner merge; 42/42 full gates, 212/0 features, export PASS |
| P4-02 | race.gd on TrackAssets: 3D gates, checkpoints in order, sectors, schema-2 ghosts (5.4 pose); live timing in the v2 game path | Claude | | done | reviewed on main; persistence is P4-06 |
| P4-07 | Bot driver follows BotLine on TrackAssets; tests/v2/laps.gd (both handling models, valid laps, zero off-track, zero wall contacts, lap baseline) | Claude | | done (review R-P4-07) | merged in M-TRAIN |
| P4-vis | P4-04 visuals pose from Transform3D + per-wheel data, free attitude in flight; P4-05 cameras, instruments (minimap from the lap line, telemetry), audio surface ids, skid marks from contact_hits | Claude | P4-02 | review: Sol | rb/P4-vis; read "DONE P4-04/P4-05"; left: night lamps from Lights/ (no track has them yet), wall-impact audio (needs F-P4-01's WallContact on the v2 path), menus (P4-06) |
| P4-menus | V2 settings, 42-field garage, named setups and pause menu; retro presentation settings persisted for the upcoming renderer port | Sol | Rebuild Preview 1 | review: owner | `rb/P4-menus`; [open PR](https://github.com/SnekPolylepis/Racingsim/pull/new/rb/P4-menus); read "DONE P4-menus" |
| Look-1 | PS2 surfaces on TrackAssets: palette-textured tarmac (road_v2 shader, amber night streaks), ground shader for grass/gravel/runoff and terrain, via scripts/track/ps2_materials.gd | Claude | | review: Sol | rb/look-1-surfaces; read "DONE Look-1". Owner art direction 2026-09-23: PS2-era, NFS Underground x GT4, amber nights |
| Look-2 | Amber nights: Lights/ lamps on proving ground and Spa (sodium floods along the track, pit and grandstand), night_style halos/streaks for TrackAssets, time of day on the v2 path (ps2_materials.set_afterhours), car headlights | Claude | Look-1 | open | |
| Look-3 | PS2 renderer on the v2 path: retro_renderer.gd (640x448, ordered dither, glow, motion persistence, console output), v2 HUD and menus in the Authentic UI viewport | Claude | P4-menus | review: Claude | rb/look-3-renderer (PR to main, owner merges); read "DONE Look-3" |
| Look-4 | Dress proving ground, Spa and Nordschleife per ART-DIRECTION.md: crowd cards, fences, painted tyre walls, billboards, marshal posts, lamp placement support for Look-2 | Gemini (content only), Claude review | Look-1 | done (reviewed by Claude 2026-09-24) | rb/look-4-dressing |
| Look-5 | Scenery kit and walls in PS2 materials (armco, tyre and concrete textures from assets/ps2; crowd cards; tree cards) | Claude | Look-1 | open | |
| P5-04 | Owner playtest of the proving ground in the real game; record lap baselines | owner | P4-core, P4-vis | open | |
| CI | GitHub Actions: headless tools/run_gates.ps1 equivalent on Linux on every push (suites, not features) | Gemini | | review: Sol | rb/CI; 39/39 gates pass locally, .github/workflows/gates.yml |

## Decisions and later

| ID | Task | Who | Needs | Status | Notes |
|---|---|---|---|---|---|
| D-kerb | Should Simcade kerbs feel softer than Simulation (car.gd's curb_scale 0.55 has no direct 3D equivalent)? | owner | | done: no (2026-09-23) | same kerbs in both handling models |
| D-compliance | Add tyre radial stiffness + unsprung mass so kerb strikes are realistic (changes ride height baselines) | owner | | done: yes (2026-09-23) | P2-comp |
| P2-comp | Tyre compliance / unsprung mass model | Claude | | done | reviewed on main |
| P2-comp-b | Kerb edge normals lean with the tyre (a kerb pushes the car back and up), now that compliance absorbs the climb rate | Claude | P2-comp | done | reviewed on main |
| P6-01 | Spa v0 authored TrackAsset and generic dev drive scene | Astra | P3-02c, P3-03, P2-08 | done | rb/P6-01-spa; owner explicitly authorized acquisition, minimal checks and branch-only push |
| P6-01-polish | Spa from measured data: widths and kerbs from SPW Orthophotos 2023, banking from SPW LiDAR cross-sections; authored runoffs halved on corner outsides | Claude | | review: Sol | rb/P6-01-polish; read "DONE P6-01-polish". Left: paved runoff and gravel extents (not measurable from the photos), Eau Rouge/Raidillon kerb profiles by hand |
| P6-02a | Nordschleife section 1 groundwork | Gemini (content/tools only), Claude review | P6-01 | review: Claude | rb/P6-02a; DGM1 + OSM + return road, BotLine, probe |
| P6-02b | Nordschleife remaining sections | Gemini (content/tools only), Claude review | P6-02a | open | |
| P6-03 | Monza (if still wanted) | owner | | done: no (2026-09-23) | not wanted |
| props | Cones and other knock-over props as simple dynamic bodies (the rest of P4-03) | Claude | P6-01 | done | reviewed on main; PropSet in P4-06 game loop |
| P7-02 | Docs rewritten for the v2 game: ARCHITECTURE, PHYSICS, LLM-GUIDE, TESTING, PLAYER-GUIDE, DATA-CONTRACTS; SOLVER-MATH and MACOS marked where they describe the legacy game | Claude | | review: Sol | rb/P7-02-docs; read "DONE P7-02" |
| P7-01a | Delete the legacy game: planar path in game.gd, circuit_world/collisions/interface/verification/showcase scripts, godot/tracks JSON, legacy tests and baselines; `--features` aliases `--v2-present`; Nordschleife S1 wired into menus, laps and export | Claude | P4-menus | done 2026-09-23 (`rb/P7-01-legacy`) | |
| P7-01b | Move the SURF table out of track3d.gd; fold car.gd into CarBody; rewrite aids_simcade and flat_equivalence without CarModel; delete track.gd, track3d.gd, tests/dynamics.gd and baseline.json | Claude | P7-01a | done 2026-09-23 (`rb/P7-01b-carmodel`) | |
| P7-03 | Release packaging (Windows + macOS exports, changelog): first done as v0.1.0-preview.1 | Claude | | done (preview) | re-run per release |
