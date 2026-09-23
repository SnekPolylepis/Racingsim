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
| R-P2-05 | Review P2-05 gates (tests only) | Sol | | done | NOTE P2-05/P2-07 review (Sol), merged d225af2 |
| R-P2-07 | Review P2-07 aids/Simcade in 3D and the CarBody-only Simcade retune | Sol | | done | same |
| M-WF | Merge rb/workflow-gates into main (contains P4-03 + the workflow change); Claude's gates: 36/36 in 138 s, features 212/0 | Sol | | open | the automated reviewer blocks Claude pushing main, so Sol merges |
| R-P4-03 | Review P4-03 car-vs-wall contact (WallQuery, WallContact) | Sol | M-WF | open | read "DONE P4-03" |
| R-WF | Review the workflow change: tools/run_gates.ps1, tools/gates.json, §9 rules 2/5/6/10/11, suite cuts | Sol | M-WF | open | read "NOTE workflow" |
| M-GEM | Merge rb/P2-08-test-surfaces and rb/P3-02c-road-density (Claude reviewed: approve; merged on top of rb/workflow-gates, run_gates -All -Features 36/36 with road_density passing once the proving ground is regenerated, see F-P3-02c) | Sol | M-WF | open | |
| F-P3-02c | road_density.gd's size check loads the git-ignored res://tracks3d/proving_ground/proving_ground.scn: stale on some machines (read 32.7 MB), missing on a fresh checkout. Build it with Generator.build_asset() in memory, pack, save with FLAG_COMPRESS under user://, measure that. (Regenerated, it is 3,872,078 bytes and passes.) | Gemini | | open | small; branch from main after M-GEM |
| F-P2-08 | Log a `CONTRACT §5.4` note: CarBody.snapshot() gained "comp" (per-wheel compression) in P2-08; add it to §5.4's snapshot list | Gemini | | review: Claude | rb/F-P2-08 |
| F-P3-02c | road_density.gd's size check loads the git-ignored res://tracks3d/proving_ground/proving_ground.scn: stale on some machines (read 32.7 MB), missing on a fresh checkout. Build it with Generator.build_asset() in memory, pack, save with FLAG_COMPRESS under user://, measure that. (Regenerated, it is 3,872,078 bytes and passes.) | Gemini | | review: Claude | rb/F-P3-02c |
| F-P2-08 | Log a `CONTRACT §5.4` note: CarBody.snapshot() gained "comp" (per-wheel compression) in P2-08; add it to §5.4's snapshot list | Gemini | | open | one-line doc fix |
| F-P3-03 | Fix P3-03 terrain per Claude's review: REBUILD-LOG conflict marker; terrain.gd drive test never updates prev_pos; drop the unused track.gd preload; runoff via RoadBuilder.side()/profile() | Gemini | | review: Claude | rb/P3-03-terrain |
| R-P3-03 | Review merged P3-03 terrain | Claude | F-P3-03 | open | |
| F-P6-01 | Spa v0 fixes per Claude's review: BotLine with smooth handles (not a polyline); spread the 2.69 deg/m bank twist at 2398 m over >= 20 m; get the committed scene under 5 MB; check width at s 6125 m | Astra or Gemini | | open | read "REVIEW P6-01"; land the BotLine change with P4-07b |
| P4-07b | Bot robustness: honest curvature (distance chord), recalibrated pace, yaw-aware braking; all 3 cars × 2 models clean on proving ground and Spa; record Spa's lap baseline | Claude | | open | read "REVIEW P6-01" |
| R-P6-01-C | P6-01 Spa v0 — review/bug-fix | Claude | P6-01 | open | rb/P6-01-spa; review 2.69 deg/m bank warning, bot off-road ticks, 6-DOF driving and timing; owner requested minimal checks only |
| R-P6-01-G | P6-01 Spa v0 — review/bug-fix | Gemini | P6-01 | open | rb/P6-01-spa; review track geometry, terrain, scenery and dev scene/menu |

## Build

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| P2-08 | Debug scene to drive CarBody on the analytic test surfaces | Gemini | | review: done (Claude approve), waits for M-GEM | rb/P2-08-test-surfaces 3b0143c |
| P3-02c | Variable road station density (dense ranges, zipper stitching); proving ground to coarse 9 + dense ditch | Gemini | | review: done (Claude approve + F-P3-02c), waits for M-GEM | rb/P3-02c-road-density 01b1fe1; scene 8.95 → 3.87 MB compressed |
| scenery-kit | Trackside scenery kit (CatchFence, Grandstand, Gantry, Billboards, MarshalPost, PitBuilding) and proving ground placement | Gemini | | done | rb/scenery-kit; 34/34 gates pass (147 s), 11/11 scenery checks |
| P4-core | P4-01 game.gd loads a TrackAsset, CarBody replaces CarModel, §5.4 interpolation, WallContact after each step; P4-02 race.gd 3D gates and new ghost format; P4-06 front_end lists TrackAssets, loading screen, bake-on-load cache for generated tracks | Sol | M-WF | claimed: Sol | rb/P4-01-game-port; one task: these share the game loop (§9 rule 11) |
| P4-07 | Bot driver follows BotLine on TrackAssets; tests/v2/laps.gd (both handling models, valid laps, zero off-track, zero wall contacts, lap baseline) | Claude | | review: Sol | rb/P4-07-bot-laps; read DONE P4-07 |
| P4-vis | P4-04 visuals pose from Transform3D + per-wheel data, free attitude in flight; P4-05 cameras, instruments (minimap from the lap line, telemetry), audio surface ids, skid marks from contact_hits | Gemini | P2-08, P4-core | open | P2-08's pose adapter is the start |
| P5-04 | Owner playtest of the proving ground in the real game; record lap baselines | owner | P4-core, P4-vis | open | |
| CI | GitHub Actions: headless tools/run_gates.ps1 equivalent on Linux on every push (suites, not features) | Sol | | open | saves reviewers re-running gates |

## Decisions and later

| ID | Task | Who | Needs | Status | Notes |
|---|---|---|---|---|---|
| D-kerb | Should Simcade kerbs feel softer than Simulation (car.gd's curb_scale 0.55 has no direct 3D equivalent)? | owner | | needs owner | see DONE P2-07 |
| D-compliance | Add tyre radial stiffness + unsprung mass so kerb strikes are realistic (changes ride height baselines) | owner | | needs owner | proposed in DONE P2-06; DeepSeek design notes pending |
| P2-comp | Tyre compliance / unsprung mass model | Claude | D-compliance | blocked: owner decision | |
| P6-01 | Spa v0 authored TrackAsset and generic dev drive scene | Astra | P3-02c, P3-03, P2-08 | done | rb/P6-01-spa; owner explicitly authorized acquisition, minimal checks and branch-only push |
| P6-02 | Nordschleife in sections | Gemini, Claude review | P6-01 | open | |
| P6-03 | Monza (if still wanted) | owner | | needs owner | |
| props | Cones and other knock-over props as simple dynamic bodies (the rest of P4-03) | Claude | P6-01 | open | |
| P7 | Delete the legacy model and tracks, rewrite docs, Windows + macOS export | Sol, Gemini | P5-04, P6-01 | open | split when it's reached |
