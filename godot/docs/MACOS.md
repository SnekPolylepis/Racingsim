# macOS build and validation

## Preview 10 local build — 2026-10-01

Universal app built with Godot 4.6.2 on Apple M4 from d0620a3 plus release
version/notice changes. macOS signature and ZIP integrity passed. Packaged
export contract loaded all five tracks; headless exit reported one DummyShader
RID leak. Chicago rendered driving/presentation passed 72 checks with no errors
on Metal. Full gates, Intel hardware and physical wheel validation not rerun.

## Preview 9 cross-export — 2026-09-30

Preview 9 combines the latest Chicago/Spa/Monaco work with Gemini's Miata light,
Green Hell, audio, low-inertia physics, controller-rumble and gate-runner changes.
Godot 4.6.2 exported the universal Mac ZIP on Windows with its built-in ad-hoc signer.
ZIP integrity, executable permissions, arm64/x86_64 Mach-O slices and code-signature
load commands were checked. These structural checks do not establish signature
validity under macOS policy or hardware compatibility. This exact build was not
launched on a Mac, checked with `codesign --verify`, or notarized. Earlier Mac runs
below remain evidence for their recorded revisions only. Windows runtime checks
for this release are recorded in REBUILD-LOG.md.

> **Rebuild note (2026-09-23):** the macOS preset exports the rebuilt game. `tools/macos.zip` is the template, and the release zip keeps the app binary executable. The legacy game (Circuits, Choose folder, the old feature suite) was deleted in P7-01a; the "Recorded validation" section below is historical.

The native Godot game has a universal macOS export containing arm64 (Apple Silicon) and x86_64 (Intel). It uses Forward+ with Metal and retains the project's OpenGL fallback. The browser game is separate and unchanged.

## Play

Open `godot/build/macos/Racing Sim.app`, or double-click `Play Racing Sim.command` in the workspace root. The distributable is `godot/build/RacingSim-macOS.zip`; it includes the app and engine/asset notices. The exported app runs offline without Python, Godot or Xcode installed.

Control shortcuts work across dialogs and menus. Apple keyboards may need Fn/Globe for F11 (fullscreen); fullscreen is also available in Settings.

Saves default to `~/Library/Application Support/Godot/app_userdata/Racing Sim/`. The game saves under `user://v2`. The app bundle is read-only game content, never a save destination. Verification uses `native-tests` beneath the same application data directory, separate from normal saves.

## Rebuild

From the workspace root, with Python 3 installed:

```sh
python3 godot/packaging/fetch-macos.py
bash godot/packaging/build-macos.sh
```

The fetcher downloads the official Godot 4.6.2 universal editor into `godot/tools/Godot.app` and extracts only `templates/macos.zip` from that release's export-template archive into `godot/tools/macos.zip`. It leaves existing tools in place. No system installation or Python packages are required. The build script checks the editor version, imports assets, exports, verifies the ad-hoc signature and packages the app with notices. `GODOT_BIN` can override the editor executable.

Without Python, download the macOS universal editor and export templates from the [official 4.6.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.6.2-stable). Extract `Godot.app` into `godot/tools/`; extract the template archive's `templates/macos.zip` into `godot/tools/` without unpacking that inner ZIP. Then run the build command above. Xcode developer tools are not needed for Godot's built-in ad-hoc signer.

This is a local ad-hoc signed build, not a Developer ID/notarized public release. A downloaded copy may require System Settings → Privacy & Security → Open Anyway. See [Godot's macOS distribution documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html). Public notarization requires the owner's Apple signing credentials and is a separate release step.

## Verify

From `godot/`:

```sh
GODOT_BIN="$PWD/tools/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script scripts/game.gd --check-only
for s in tests/v2/*.gd; do "$GODOT_BIN" --headless --path . --script "$s"; done  # see tools/gates.json for arguments
"$GODOT_BIN" --path . -- --features
"build/macos/Racing Sim.app/Contents/MacOS/Racing Sim" --headless -- --v2-export-check
```

`--features` (the same as `--v2-present`) requires a graphical login session; do not add `--headless`. `tools/gates.json` lists each suite's arguments (the lap suite runs once per car).

## Recorded validation — 2026-09-22

Host: Apple M4, macOS 27.2 (26B5086k), Godot 4.6.2 stable. Rendered tests used Metal 4.0 / Forward+. These are results from this machine, not cross-hardware guarantees.

| Check | Recorded result |
|---|---|
| Export and signature | Universal arm64 + x86_64; `codesign --verify --deep --strict` passed |
| Exported feature suite | 261 checks, zero failures; no engine/script errors in the log |
| Exported fresh-default title review | 7 checks, zero failures |
| Source script parsing | Passed |
| Native handling | 23 checks, zero failures |
| Simulation vehicle dynamics | 34 checks, zero failures |
| Circuit import | 9 checks, zero failures |
| Geometry validation | 103 checks, zero failures |
| Four-circuit Simulation laps | All passed; zero off-track steps and barrier contacts |
| Changed GDScript formatting | Passed gdformat 4.5.0, line length 110 |
| Root Mac launcher | Opened the exported app successfully |

Simulation laps were Ridgeback 96.12 s, Oval 42.78 s, Monza 260.31 s and Spa 323.00 s. These are automated regression laps, not competitive benchmarks. The handling suite initially failed because it wrote the removed `car.parity` property; the stale setup/comparison was removed and native assertions passed on rerun.

The separate extended `showcase_laps.gd` run was stopped before completion. It recorded valid Simulation-pad and Simcade-pad laps, but this is not a pass for the full suite. The separate headless Simcade dynamics and four-circuit lap commands were not reached. The exported feature suite completed its own frontend driving flows. The commands above describe how to run all suites; they do not claim every listed command completed in this session.

Exported JSON reports and screenshots are under `~/Library/Application Support/Godot/app_userdata/Racing Sim/native-tests/`, including `feature-results.json` and `title-results.json`. Local logs are `/tmp/racingsim-macos-*.log`; temporary logs may disappear and subsequent runs replace reports. The app was rebuilt after formatting and documentation updates; the full feature suite was not repeated after those nonbehavioral changes.

## Remaining validation and release limits

- The macOS CI workflow has not yet run on GitHub. CI covers export and headless tests, not rendered acceptance.
- Intel hardware and the Mac OpenGL fallback have not been exercised. Both architectures are packaged; only Apple Silicon / Metal was run locally.
- Physical controller behavior, trackpad feel and subjective audible output quality remain untested. Audio PCM checks do not establish those results.
- No complete Mac performance matrix was measured. Existing Windows RTX 4080 timing reports remain Windows-only evidence.
- The app is ad-hoc signed; Developer ID signing and public notarization have not been performed.

## Recorded branch preview — 2026-09-30 Chicago / Spa polish

On Apple M4, macOS, Godot 4.6.2 / Metal Forward+, branch `codex/chicago-spa-polish`: universal export (`arm64 x86_64`) and `codesign --verify --deep --strict` passed. Both exported Chicago and Spa `--v2-look --v2-flow-test` runs passed 72 presentation checks with no failures or script errors. Final windowed Chicago geometry suite passed 40 checks, including actual MultiMesh rotated-box readback. Full headless suite passed 43/43 before the last visual fixes; the final five affected suites passed afterward.

Evidence is in `rebuild/screenshots/chicago-spa-polish/logs/`. The export contract passed but the Dummy renderer printed one shader RID leak at shutdown; screenshot tools retain an ObjectDB cleanup warning. Intel hardware, Windows export, physical controls and a new performance matrix were not tested by this branch. The universal binary is ad-hoc signed, as before.

### 2026-09-30 Chicago/Spa close-up continuation

`codex/chicago-spa-polish`: universal export and strict signature verification pass after the wheel/plaza/paving/transporter follow-up. Exported Apple M4 Metal Chicago and Spa presentation drives each pass 72 checks with no script errors. Spa reports an ObjectDB cleanup warning on exit. Logs: `docs/rebuild/screenshots/chicago-spa-polish/detail-pass/`. No Intel or Windows hardware run.

### 2026-10-08 Chicago buildings source continuation

On Apple M4, Godot4.6.2/Metal Forward+: City12/County15/menu107/coverage23
and source parsing pass (157assertions plusparse). County outer relief draft
frontage/oblique day/night captures inspected; low contrast and fine sculpture
remain open. Capture exits0 with an ObjectDB cleanup warning, no script errors.
Source Chicago Grid --v2-look driving/presentation passes72checks,zero failures,
exit0,empty stderr. These concurrent runs are not a performance benchmark.
No export/full gate matrix/Intel validation. Detailed evidence in REBUILD-LOG.

### 2026-10-08 City LaSalle sculpture continuation

Source City16/County15/menu107/coverage23 plusparse pass on Apple M4/Metal
(161assertions). Four High-quality Grid day/night views inspected; source Grid
--v2-look driving/presentation72/72PASS,exit0,empty stderr. Figures remain
photo-fit drafts; courts/roofs and full trackside fidelity are unfinished.
No export/full-lap benchmark/Intel hardware run. See REBUILD-LOG for scope.

### 2026-10-08 County inner relief continuation

Source County17/City16/menu107/coverage23 plusparse pass on Apple M4/Metal
(163assertions). Four actual High-quality Grid day/night views inspected;
capture/import exit0,empty stderr. Fine sculpture remains draft. No new
export, driving/presentation repeat, full gate matrix or Intel validation.


### 2026-10-08 City Hall roof continuation

Mac M4/Metal Godot4.6.2 source review: City436344tri/tenmaterials/cache159,
physical garden and equipment draft. Import and four final High Grid day/night
roof/equipment captures exit0,empty stderr; images actually inspected after
plant/path refinement. Five targeted suites pass71.3s,168assertions plusparse.
No export/full-lap/performance validation; courtyard/County roof fidelity open.
Evidence: REBUILD-LOG and rebuild/screenshots/chicago-city-roof-mac/.


### 2026-10-08 paired light-court continuation

Mac M4/Metal Godot4.6.2 source: City477312tri/elevenmaterials and
County284156tri/eightmaterials/cache161. Import and actual High Grid court
day/night captures exit0/empty stderr; six images inspected. Five targeted
suites pass70.6s,172assertions plusparse, including physical pane/pier recess
on both halves. No export/full-lap/performance acceptance. Exact court details
and County roof remain provisional. REBUILD-LOG records evidence.


### 2026-10-08 County roof continuation

Mac M4/Metal Godot4.6.2 source County286800tri/ninematerials/cache164.
Import and final four actual High Grid day/night roof/equipment captures exit0,
empty stderr; images inspected after wing-fan/tower placement refinement.
Five targeted suites pass69.1s,175assertions plusparse. Coping, raised fans,
unplanted deck and existing court/entry checks pass. No export/full-lap or
performance acceptance; roof dimensions/configuration remain photo-fit draft.
Evidence REBUILD-LOG/screenshots/chicago-county-roof-mac/.

## 225 West Wacker exterior source review — 2026-10-08

Official Godot4.6.2, Apple M4/Metal/Forward+, High Grid, cache169.
Original Blender4.5.3LTS model163756tri/eightmaterials, mapped footprint retained.
Final import exit0/empty stderr; final building28 assertions andparse pass1.5s.
Preceding full targeted pass (cache168) menu109/coverage23/building28,
160assertions plusparse,68.5s. Final north clear-glazing/address correction
reran affected geometry/parse and rendered ten actual day/night captures:
street, tower, crown, exact BotLine4785 toward-building and forward views.
All inspected, render exit0/empty stderr; screenshots/chicago-wacker225-mac.
Lower camera(-901.8246,4.8288,-213.0615) is foundation-occluded; forward view
partly occluded. This records an open route/clearance issue, not proven
visibility or vehicle clearance. Model dimensions/current frontage remain
photo-fit; owner375ft/mapped126.5m/photographer433ft unresolved.
No exported app, full gates, full lap, clips, performance, Intel or wheel run.

## 225 Wacker bend clearance — 2026-10-08

Official Godot4.6.2/M4/Metal, cache171. Added mapped/authored bend controls
north of the retained225 foundation. Originalchicago@v5/Gridchicago_grid@v3
separate records from earlier layouts. No user laps/ghost files deleted.
Full-course windowed5m/five-lateral clipping scans pass107/114 accepted hits,
zero failures after narrowing Wacker overhead exemptions to deck structures.
Ten actual High day/night views inspected, render exit0/empty stderr;
screenshots/chicago-wacker225-clearance-mac. Lower approach/corner/exit
carriageway now clear; original Upper driving/frontage also reviewed.

35 selected headless Chicago/parse suites passed160.2s before identity bump
(919 assertions plusparse). Cache171 menu109, building34, Grid formula4 and
parse passed131.0s; final footprint-present guard gives building35/parse,
1.9s. All five cars completed both handling modes on both layouts with zero
off-road/wall/prop ticks; prop count0 in lap harness. Original six road-car
old timing references exceeded2% after corrected bend; before-route GT still
passed, isolating geometry effect. Updated only those six original references
from clean new-layout laps; Grid's ten existing references still passed.
Combined Grid all-car invocation timed out180s; completed per-car runs supply
the evidence. Full original allfivecars/twomodes verification rerun passes10 assertions,
exit0/empty stderr; original formula timings have no stored references.
Original road-car references only updated;2% tolerance unchanged.

These are sampled/native automated results and frozen captures. No manual
wheel driving, performance/Intel validation, complete game gates or app export.
Bend is authored from mapped road geometry; building fidelity remains open.


### 2026-10-08 — 225 West Wacker crown refinement, native Mac source

Refined the four pale painted stepped turret shoulders, four-sided fins and
circular caps against Michael Davis's 2009 aerial exterior reference
(https://www.flickr.com/photos/perspectivephotography/3935592473).
Added enclosed recessed side glazing beneath the barrel vault, end ties and
crossed braces, raised service terraces with guardrails and photo-fit cabinets.
These are authored estimates, not surveyed roof dimensions or equipment IDs.
Retained mapped foundation, provisional height and cleared route geometry;
records remain original@v5/Grid@v3. Cache172; Blender168016 triangles/nine
materials. Restrained silver specular response follows the existing material path.

Bounded Godot4.6.2/M4 source import exits0. Building38 assertions and parse pass;
menu109 passes. Initial side-pane ray hit a mullion gap; moved the sample
inside a pane and reran the complete building test,38/38 pass.
Six actual High day/night street/tower/crown captures inspected in
`docs/rebuild/screenshots/chicago-wacker225-crown-mac/`, exit0/empty stderr.
Frozen captures establish appearance only, not driving or frame-time acceptance.
Fine facade/crown proportions, published height discrepancy, civic sculpture
and remaining trackside buildings remain open. River bridges stay queued.
No app export, repeat lap timing, full-game/performance, Intel or wheel checks
for this exterior-only refinement; previous clearance/lap evidence is retained.

Final bounded windowed full-course 5m/five-offset clip scans pass on both
layouts, Grid107/original114 accepted overhead hits, zero failures; exit0,
empty stderr. Building38 plus parse rerun passes after correcting pane probe.


### 2026-10-08 — Franklin / Van Buren garage draft and connector audit

Built mapped w74268219 exterior in Blender:35484tri/seven materials,
open parking bays/slabs, concrete piers, recessed retail panes, rounded slotted
corner core, roof guardrails/stall markings. Historical PTI/Desman brochure
reference differs from neighboring Wells Traders structure; use
assets/chicago/landmarks/FRANKLIN-GARAGE-SOURCES.md for provenance/limits.
Fourteen levels/finite vertices/height authoring assertions and native17
geometry/night checks plusparse pass. Six staged High native day/night views
inspected; these expose existing route/foundation conflict, not production fit.
Both current routes excludegarage andcrossBrooks. Twelve pre-model native
captures completed; eight reviewed/retained in chicago-franklin-placement-mac.

Candidate connector follows mapped VanBuren/Franklin corridor: both South
controls z887.1, secondx-896.5, rampx-898.0, heights/othercontrols retained.
Bounded2m native local audit of38 footprints: no candidatecentreline crossings;
garage/Brooks each about14.6m clear. Initial broad scratch audit timedout120s;
optimized local audit completed0.4s. Original/Grid length reduces76.18/82.32m.
Local audit does not establish full-course rendered/driving acceptance.

Production integration and route change remain next work: commit draft assets,
then correct connector with new record identities, integrategarage, both full
clip scans and all-car/mode driving checks. Inspect restoredBrooks frontage
next. Cache172/original@v5/Grid@v3 remain unchanged at this checkpoint.
No app export, full-game/performance, Intel or manual wheel validation.

Final roof stripe/wheel-stop mesh reimport exits0,17 geometry/night checks
plusparse pass0.7s. Six final staged day/night views rerendered and inspected,
exit0/empty stderr. No production placement acceptance at this checkpoint.


### 2026-10-08 — Franklin garage integrated; both connectors clear retained buildings

Integrated FranklinGarage at(-859.5,8,844.05), mapped foundation unchanged,
35484tri/seven materials; generic w74268219 excluded exactly once. Night
fixtures use the existing Chicago material toggle, restrained specular response.
Shared world(row) places both South connector controls on z887.1, secondx-896.5,
rampx-898.0; corner aliases and roadside generators share the correction.
Mapped VanBuren/Franklin reference, authored widths/grades/easing; no road-survey
claim. Cache174; original@v6/Grid@v4 preserve older saved record/ghost identities.

Native1m samples clear garage14.558m andBrooks14.682m on both layouts.
Brooks generic frontage is now visible; replace it next from retained primary
references. Production foundation geometry is not shortened or lifted to fit.
Refreshed native5m candidate CSV:237 within50m (prior241 snapshot retained as
dated evidence). Garage14.6/Grid6135; Brooks14.7/Grid6160;22514.4/original6765.
Candidate distances remain neither a visibility guarantee nor completion tally.

36 headless Chicago/parse suites passed185.8s during integration. After shared
coordinate/caching refinement, final scoped six suites pass119.3s: garage25,
menu111, Gridroute49, authoredcoverage23,225Wacker38, plusparse (246assertions).
Both full windowed5m/five-offset clip scans pass: Grid107/original110 accepted
overhead hits, zero failures, exit0/empty stderr. Grid rerun after shared
coordinate change also passes107. Original scan already used final placement.

Allfivecars/both handling modes on both layouts completed20 clean lap cases,
zerooff-road/wall/prop ticks; lap harness has0props. Ten bounded per-car runs,
max2 concurrent, exit0/empty stderr. All16 stored timing references stay inside
unchanged2% tolerance; original formula modes have no timing baseline. No
baseline fixture rewritten for this shorter connector. Logs mac-civic/franklin-*.

Original eight High source day/night approach/corner/exit/building captures
completed and inspected. Combined review hit180s; split Grid30-frame-wait
review also hit180s after two views. Completed Grid capture uses five awaited
frames plus RenderingServer.frame_post_draw for each image; results recorded
only after exit0/empty stderr. Allsixteen final views inspected. Final captures live in
rebuild/screenshots/chicago-franklin-production-mac/. Frozen captures establish
appearance, not frame-time acceptance. Broader building fidelity, finer civic
sculpture and remaining trackside exteriors remain open. River bridges queued.
No app export, manual wheel driving, full-game/performance or Intel validation.

Final finite-clearance guard rerun: garage25 andparse pass1.6s.
