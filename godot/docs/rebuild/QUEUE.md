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
| M-TRAIN | Merge train into main: workflow-gates (P4-03 + workflow), F-P2-08 (P2-08), F-P3-02c (P3-02c), P3-03-terrain (F-P3-03), scenery-kit, P4-07-bot-laps, P6-01-spa, P4-01-game-port | owner (GitHub PR) | | review: owner | rb/merge-train; Claude reviewed all but its own; read "MERGE train" |
| R-P4-03 | Review P4-03 car-vs-wall contact (WallQuery, WallContact) | Sol | M-TRAIN | open | read "DONE P4-03"; merged before review (Sol out of usage) |
| R-WF | Review the workflow change: tools/run_gates.ps1, tools/gates.json, §9 rules 2/5/6/10/11, suite cuts | Sol | M-TRAIN | open | read "NOTE workflow" |
| R-P4-07 | Review P4-07 bot driver and laps gate | Sol | M-TRAIN | open | read "DONE P4-07" and "REVIEW P6-01" |
| F-P4-01 | P4-01 follow-ups (Claude's review): Esc on the v2 path quits the app instead of returning to the front end; WallContact not yet called after car.step(); game.gd and track_drive.gd preload trackgen/*.gd but export_presets.cfg excludes trackgen/* so an exported exe breaks | Sol | M-TRAIN | open | fold into P4-core |
| F-P6-01 | Spa v0 fixes per Claude's review: spread the 2.69 deg/m bank twist at 2398 m; get the committed scene under 5 MB; check width at s 6125 m (BotLine smoothing done in P4-07b: regenerate the committed spa.scn after merging it) | Gemini | | open | read "REVIEW P6-01" |
| P4-07b | Bot robustness: honest curvature (distance chord), recalibrated pace, yaw-aware braking, smooth Spa BotLine; all 3 cars × 2 models clean on proving ground and Spa; record Spa's lap baseline | Claude | | review: Sol | rb/P4-07b; read "DONE P4-07b" |
| F-terrain-perf | tests/v2/terrain.gd's "car step" timing check (300 µs budget) ignores GatesEnv.perf(): under the parallel runner it read 671 µs and failed (168 µs alone). Route it through GatesEnv.perf()/perf_note() like the other timing gates | Gemini | | open | small |

## Build

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| P2-08 | Debug scene to drive CarBody on the analytic test surfaces | Gemini | | done | rb/P2-08-test-surfaces 3b0143c |
| P3-02c | Variable road station density (dense ranges, zipper stitching); proving ground to coarse 9 + dense ditch | Gemini | | done | rb/P3-02c-road-density 01b1fe1; scene 8.95 → 3.87 MB compressed |
| scenery-kit | Trackside scenery kit (CatchFence, Grandstand, Gantry, Billboards, MarshalPost, PitBuilding) and proving ground placement | Gemini | | done | rb/scenery-kit; 34/34 gates pass (147 s), 11/11 scenery checks |
| P4-core | P4-01 game.gd loads a TrackAsset, CarBody replaces CarModel, §5.4 interpolation, WallContact after each step; P4-02 race.gd 3D gates and new ghost format; P4-06 front_end lists TrackAssets, loading screen, bake-on-load cache for generated tracks | Sol | | claimed: Sol (P4-01 merged in M-TRAIN; P4-02, P4-06 remain) | rb/P4-01-game-port; one task: these share the game loop (§9 rule 11) |
| P4-07 | Bot driver follows BotLine on TrackAssets; tests/v2/laps.gd (both handling models, valid laps, zero off-track, zero wall contacts, lap baseline) | Claude | | done (review R-P4-07) | merged in M-TRAIN |
| P4-vis | P4-04 visuals pose from Transform3D + per-wheel data, free attitude in flight; P4-05 cameras, instruments (minimap from the lap line, telemetry), audio surface ids, skid marks from contact_hits | Gemini | P2-08, P4-core | open | P2-08's pose adapter is the start |
| P5-04 | Owner playtest of the proving ground in the real game; record lap baselines | owner | P4-core, P4-vis | open | |
| CI | GitHub Actions: headless tools/run_gates.ps1 equivalent on Linux on every push (suites, not features) | Gemini | | open | saves reviewers re-running gates |

## Decisions and later

| ID | Task | Who | Needs | Status | Notes |
|---|---|---|---|---|---|
| D-kerb | Should Simcade kerbs feel softer than Simulation (car.gd's curb_scale 0.55 has no direct 3D equivalent)? | owner | | done: no (2026-09-23) | same kerbs in both handling models |
| D-compliance | Add tyre radial stiffness + unsprung mass so kerb strikes are realistic (changes ride height baselines) | owner | | done: yes (2026-09-23) | P2-comp |
| P2-comp | Tyre compliance / unsprung mass model | Claude | | review: Sol | rb/P2-comp; read "DONE P2-comp" |
| P2-comp-b | Kerb edge normals lean with the tyre (a kerb pushes the car back and up), now that compliance absorbs the climb rate; measure speed lost and loads on the proving-ground kerbs | Claude | P2-comp | open | read "DONE P2-comp" |
| P6-01 | Spa v0 authored TrackAsset and generic dev drive scene | Astra | P3-02c, P3-03, P2-08 | done | rb/P6-01-spa; owner explicitly authorized acquisition, minimal checks and branch-only push |
| P6-02 | Nordschleife in sections | Gemini, Claude review | P6-01 | open | |
| P6-03 | Monza (if still wanted) | owner | | needs owner | |
| props | Cones and other knock-over props as simple dynamic bodies (the rest of P4-03) | Claude | P6-01 | open | |
| P7 | Delete the legacy model and tracks, rewrite docs, Windows + macOS export | Sol, Gemini | P5-04, P6-01 | open | split when it's reached |
