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
**Gemini** (3.8 Flash: tools, mechanical ports, content, docs), **owner** (decisions, playtests, downloads).

## Review and fixes (take these first)

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| R-P2-05 | Review P2-05 gates (tests only) | Sol | | open | on main after the Claude merge; read "DONE P2-05" |
| R-P2-07 | Review P2-07 aids/Simcade in 3D and the CarBody-only Simcade retune | Sol | | open | read "DONE P2-07" |
| R-P4-03 | Review P4-03 car-vs-wall contact (WallQuery, WallContact) | Sol | | open | read "DONE P4-03" |
| R-WF | Review the workflow change: tools/run_gates.ps1, tools/gates.json, §9 rules 2/5/6/10/11, suite cuts | Sol | | open | read "NOTE workflow" |
| F-P3-03 | Fix P3-03 terrain per Claude's review: REBUILD-LOG conflict marker; terrain.gd drive test never updates prev_pos; drop the unused track.gd preload; runoff via RoadBuilder.side()/profile() | Gemini | | open | rb/P3-03-terrain; then merge it (merge first) |
| R-P3-03 | Review merged P3-03 terrain | Claude | F-P3-03 | open | |

## Build

| ID | Task | Who | Needs | Status | Branch / notes |
|---|---|---|---|---|---|
| P2-08 | Debug scene to drive CarBody on the analytic test surfaces | Gemini | | claimed: Gemini | rb/P2-08-test-surfaces |
| P3-02c | Variable road station density (dense ranges, zipper stitching); proving ground to coarse 9 + dense ditch | Gemini | F-P3-03 | open | prompt in chat 2026-09-23 |
| P4-core | P4-01 game.gd loads a TrackAsset, CarBody replaces CarModel, §5.4 interpolation, WallContact after each step; P4-02 race.gd 3D gates and new ghost format; P4-06 front_end lists TrackAssets, loading screen, bake-on-load cache for generated tracks | Sol | | open | one task: these share the game loop (§9 rule 11) |
| P4-07 | Bot driver follows BotLine on TrackAssets; tests/v2/laps.gd (both handling models, valid laps, zero off-track, zero wall contacts, lap baseline) | Claude | | open | headless, independent of the game loop |
| P4-vis | P4-04 visuals pose from Transform3D + per-wheel data, free attitude in flight; P4-05 cameras, instruments (minimap from the lap line, telemetry), audio surface ids, skid marks from contact_hits | Gemini | P2-08, P4-core | open | P2-08's pose adapter is the start |
| P5-04 | Owner playtest of the proving ground in the real game; record lap baselines | owner | P4-core, P4-vis | open | |
| CI | GitHub Actions: headless tools/run_gates.ps1 equivalent on Linux on every push (suites, not features) | Sol | | open | saves reviewers re-running gates |

## Decisions and later

| ID | Task | Who | Needs | Status | Notes |
|---|---|---|---|---|---|
| D-kerb | Should Simcade kerbs feel softer than Simulation (car.gd's curb_scale 0.55 has no direct 3D equivalent)? | owner | | needs owner | see DONE P2-07 |
| D-compliance | Add tyre radial stiffness + unsprung mass so kerb strikes are realistic (changes ride height baselines) | owner | | needs owner | proposed in DONE P2-06; DeepSeek design notes pending |
| P2-comp | Tyre compliance / unsprung mass model | Claude | D-compliance | blocked: owner decision | |
| P6-01 | Spa on 1 m DEM (widths, cambers, kerbs from orthophotos) | Gemini, Claude review | P3-02c, P3-03, P4-core | open | data sources in docs/rebuild/data-sources-P5-01.md; downloads need the owner's OK |
| P6-02 | Nordschleife in sections | Gemini, Claude review | P6-01 | open | |
| P6-03 | Monza (if still wanted) | owner | | needs owner | |
| props | Cones and other knock-over props as simple dynamic bodies (the rest of P4-03) | Claude | P6-01 | open | |
| P7 | Delete the legacy model and tracks, rewrite docs, Windows + macOS export | Sol, Gemini | P5-04, P6-01 | open | split when it's reached |
