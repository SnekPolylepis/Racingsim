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


### 2026-10-08 — Brooks physical trackside exterior

Brooks replaces generic w73766157 once at (-861.3,8,769.8), retaining the
five-vertex mapped foundation. Blender source and GLB:93044tri/ten materials.
Owner and City landmark photos inform five Franklin/eight Jackson bays,
three recessed panes per bay, ribbed piers, tiled spandrels, pale two-storey
retail base, green frieze/caps, projecting cornice and red Jackson awnings.
Twelve storeys follow the owner description; mapped57m height remains provisional.
Small cap/frieze reliefs are photo-fit silhouettes, not exact sculpted replicas.
Entrance bay, rear treatment and roof configuration remain unverified.
Cache175; original@v6/Grid@v4 and route geometry unchanged.

Mac Godot4.6.2 M4 Forward+ source checks: Brooks31, menu113, authoredcoverage23,
Franklin25 andparse pass (192assertions plusparse). First Brooks check caught
an incorrect17m test envelope around the north awnings (actual17.312m); the
explicit17.5m awning bound and unchanged other bounds pass on rerun1.8s.
No geometry reduced to satisfy the test. Preceding menu113 ran73.2s.

Remaining trackside exteriors, finer civic reliefs/seals and broader performance
review remain open; river bridges queued. No export or new driving-lap run:
route unchanged, preceding20 clean car/mode cases retained as dated evidence.

Both full native5m/five-offset clip scans pass: Grid107/original110 accepted
overhead hits, zero failures, exit0/empty stderr. Initial eight High source views
completed exit0/empty stderr; seven inspected views show the Brooks exterior.
The first Jackson camera was inside a neighbouring building; its image is not
appearance evidence. Corrected Jackson day view inspected; a full rerender
hit180s after three daylight images. Single corrected Jackson night review
follows separately. Frozen renders do not establish frame-time acceptance.

Corrected Jackson night single-view source capture completed exit0/empty stderr
and was inspected. Final eight High day/night corner/Franklin/Jackson/route
images reviewed in rebuild/screenshots/chicago-brooks-mac/. Original successful
set plus corrected Jackson captures supplies appearance evidence; timed-out
multi-view rerun remains recorded above. Next close candidate:300SouthWacker,
with primary architect/owner references in chicago/WACKER-300-REFERENCE.md.


### 2026-10-08 — 300 South Wacker exterior and mapped approach

Physical Wacker300 at(-1055.4,8,793.45) replaces generic w147350178 exactly
once. Retained nine-point foundation;92614tri/twelve materials; original Blender
source and GLB. Bronze mullions/spandrels frame individual recessed panes,
physical mechanical louvers, revised clear lobby with spaced granite columns,
ceiling/portal/stairs and correctly oriented extruded300 address. River core
has original physical map linework and red locator; low roof service cabinets.
Owner/architect/SEGD references in WACKER-300-SOURCES.md. Mapped133m differs
from architect440ft/134.112m; height, mural cartography, exact entrance/mechanical
levels and roof configuration remain provisional. No embedded reference photo.

First full Grid scan exposed two foundation overlaps atstations5885/5890:
the old racing straight was too far west beside the mapped13m South Wacker
road. Shared points() now follows mapped(-1038.4,747.8),(-1031.1,811.5), and
world(row) places the western South connector(-1028,887.1). Other connector
and ramp placements/elevations preserved; geographic-source rows unchanged.
Authored widths/grades/easing, not a road-survey claim. A trial879.3 control
made the final16m-wide corner too tight: two tarmac misses and low fence
intrusions. Removed that point; the larger corner now passes full-width tests.
No building displacement, shortened foundation or road-width reduction.
Original@v7/Grid@v5 separate altered drivable surfaces from prior saves;
cache180. NativeCurve3D lengths7859.992/8488.778m; not RoadBuilder station lengths.
Native1m foundation clearance11.509m both routes; finite and greater than10m.
Candidate CSV refreshed236 within50m from native5m samples:30011.6/Grid5895,
3117.7/Grid6170,Brooks14.8/Grid6160,garage14.6/Grid6135,22514.5/original6765.
Prior237 snapshot remains dated evidence. Candidate count is not completion.

Mac Godot4.6.2/M4 Metal Forward+ final37 headless Chicago suites pass112.0s;
parse separately passes0.6s. Includes building38, menu115, both road geometry49,
Brooks31, Franklin25, authoredcoverage23 and all other Chicago exterior checks.
Both full native5m/five-offset clip scans pass after corner easing: Grid103,
original120 accepted overhead hits, zero failures, exit0/empty stderr.
Grid passed the stricter preceding rule. Scan now also recognizes Upper Wacker
fences only over a lower roadway with hitheight>=7.9m; low/street-level fences
and Wacker300 remain failures. Four explicit guardrail/building assertions pass.
No broad Wacker building exemption; wall probes remain active.

Sixteen final actual High source images inspected: eight Grid street/river/
entry/building-facing views and eight original/Grid approach/corner views,
each day/night. All eight final two-view jobs exit0/empty stderr, five awaited
frames plus frame_post_draw per image. Earlier combined8-view and4-view night
jobs hit180s; completed partial images informed revisions, not completion claims.
Final images in rebuild/screenshots/chicago-wacker300-mac/ and
chicago-wacker300-route-mac/. Frozen renders prove appearance, not frame time.

Remaining trackside exteriors and finer civic sculpture remain open. Next close
candidate311SouthWacker has primary architect/contractor references in
chicago/WACKER-311-REFERENCE.md; its octagonal tower and winter garden need
an authored exterior. River bridges stay queued. No export, manual wheel run,
Intel hardware, broad full-game or performance validation at this checkpoint.

Allfivecars/both handling modes on both layouts complete20cleanlap cases,
zerooff-road/wall/prop ticks, finite successful laps. Ten bounded per-car jobs,
max2concurrent, exit0/empty stderr; lap harness has0props. All16 stored timing
references remain within unchanged2% tolerance; four original Formula cases
still have no timing baseline. No baseline rewritten. Logs mac-civic/wacker300-*.
These runs validate the corrected route, not visual-only screenshots or manual
wheel driving. The full trackside-model objective remains active.

## 311 South Wacker integrated draft — 2026-10-08

`Scenery/Wacker311` at(-928,8,817), exact mapped fallback excluded once;
cache182, original@v7/Grid@v5 unchanged. Physical exterior and clear winter
garden integrated; explicit warm office/fixture emissions and pale fluorescent
crown replace the initially too-dim imported emission. Day extinguishes them.
Both packed-cache validators require the new node and13material surfaces.

Mac Godot4.6.2/M4 Metal Forward+: building37checks and parse pass; menu115
passes. Both full native5m/five-offset clip scans pass: Grid103/original120
accepted overhead hits, zero failures, exit0/empty stderr. 311 never receives a
building exemption. Native1m retained-foundation clearance7.599956original and
7.599406Grid. Eight final actual High source images inspected: Grid full tower
and winter garden day/night, both-layout driver-height facade views day/night.
All bounded two-view capture jobs exit0/empty stderr. Initial night crown was
too dim and re-rendered after correcting the emission colour. Images live in
`docs/rebuild/screenshots/chicago-wacker311-mac/`.

This is an integrated fidelity draft, not final architectural acceptance.
Crown framing/band calibration, base/entrance connections and sculpture remain.
No driving geometry or timing changed; prior lap runs remain dated evidence,
not a new lap claim. No app export, manual-wheel, Intel or frame-time claim.

Final broader run: all38headless Chicago suites pass148.8s, including both
road geometry49checks, menu115, building37 and authoredcoverage23. Parse passed
separately. Windowed clipping/capture evidence is recorded above. Full game
suites and lap baselines were not rerun for this scenery-only integration.

### Crown portal fidelity pass — 2026-10-08

Replaced asymmetric crown piers with physically open granite portals on the
outward faces of all four smaller cylinders and all four central-cylinder faces,
using the architect's exterior photo as shape reference. Physical architraves,
projecting piers and exposed glazing remain distinct geometry. Current original
Blender source and GLB:569,284triangles/13materials; cache183. Foundation, road
and record versions unchanged. Detailed crown proportions remain photo-fit.

Generation assertions/import pass. Mac Godot4.6.2/M4 Metal Forward+ building39
checks and parse pass; two new granite-only ray probes prove a projecting pier
and clear portal opening. Four actual final High production images inspected:
Grid full tower and close crown, day/night, under screenshots/chicago-wacker311-
crown-mac. Both two-view jobs exit0/empty stderr. Filenames ending river are
close crown cameras in this folder, not river-level views. Previous full38suite,
both-layout clip scans and driver-height images remain dated pre-portal evidence;
not rerun for this roof-only change. No export/manual-driving/performance claim.

Facade band calibration, base/entrance connections and winter-garden sculpture
remain open. Next close unmodeled named candidate:200SouthWacker w64888042,
8.5m from Grid station6445 in the current inventory; verify references, mapped
foundation and both-layout placement before modeling. Remaining whole-track
building objective is active, including unnamed trackside footprints.

## Paired roof and production integration — 2026-10-08

[Vincent Desjardins's actual roof-facing photograph,2010](https://commons.wikimedia.org/wiki/File:View_down_from_the_Sears-Willis_Tower_Skydeck.jpg), CC BY2.0, inspected in the browser. It confirms the two triangular masses meeting along a diagonal and the long enclosure on the taller roof. Revised the generic rooftop box into a diagonal enclosure with physical louvres; added three photo-fit lower-roof service cabinets. Exact join/corner/enclosure dimensions remain provisional rather than measured. Current original Blender source/GLB81,532triangles/sevenmaterials; no photo textures.

`Scenery/Wacker200` integrated at(-1076.05,8,641.75); mapped w64888042 fallback
excluded. Both packed-cache validators require the node/seven materials. Cache184,
original@v7/Grid@v5 unchanged; no road/timing changes. Clear lobby/canopy alpha.18,
explicit warm night fixtures/selected office panes and day-off toggles.

Mac Godot4.6.2/M4 Metal Forward+: building29checks and parse pass; all39headless
Chicago suites pass208.1s, including menu115, both roadway geometry49 and
all other authored exteriors. Both full native5m/five-offset clipping scans pass:
Grid103/original120 accepted overhead hits, zero failures, exit0/empty stderr.
Wacker200 is explicitly not exempt from building clipping. Native1m foundation
clearance12.808571original/8.469823Grid; roof/canopy ray probes pass.

Eight actual High source views inspected: Grid full tower and street entrance,
plus driver-height frontage on each layout, each day/night. Image filenames
ending river are street entrance cameras in this folder. Final evidence in
screenshots/chicago-wacker200-mac. Two-view jobs completed exit0; first night
job reported shared-cache load errors during concurrent rebuild and fell back
to source generation. Final night job ran alone, rebuilt the source cache and completed exit0/empty stderr; both resulting images inspected. This confirms clean source rendering, not a warm-cache-load guarantee.
No broad day/night acceptance based on neutral-light staged screenshots.

Fine lobby interior, river base, precise diagonal join/corners, entrance placement
and equipment remain fidelity work. The roof-facing photo resolves topology;
physical dimensions and published152.3m versus mapped155.5m discrepancy remain.
No app export or new lap/manual-wheel/Intel/performance claim. Prior laps remain
dated evidence; no baseline rewrite. Full trackside-building goal continues.

## Bell integration — Mac2026-10-08

Final authored Bell exterior148,776tri/nine materials at(-850.25,8,136.7).
Physical masonry now stays on stone piers/brick spandrels instead of crossing
glass. Paired panes have dark interior backing; portal glass has physical side
recess walls and dark interior. Generic mapped w147095658 excluded, BellBuilding
fixture added to both cache validators; cache185/original@v7/Grid@v5. Standard
Night flag switches warm occupied panes; clear entrance alpha.18/double-sided.
Road/timing unchanged.

Godot4.6.2 AppleM4 Metal source evidence: parse pass; all40 Chicago suites pass
(199.0s), including Bell28, menu115, both-layout geometry49 each. New Bell gate
checks mapped foundation/envelope, material/no-photo/night contract, L-wing roof,
stone-only entrance ray openings and physically recessed glass. Full-route1m
foundation clearance163.349991original/8.841562Grid. Initial gate's local search
region had no original-route samples; fixed to measure both complete routes.
Both native full clip scans pass:Grid103/original120 deliberate accepted hits,
zero failures; no Bell exemption.

Ten actual High source images viewed in screenshots/chicago-bell-mac:
shaft frontage and street entrance on both layouts/day/night, plus Grid full
exterior/day/night. Filenames containing river show Washington entrance, not
river frontage; street images are close shaft views, full images show roof/base.
Initial blocked camera was replaced; final bounded jobs ran serially and exited0
with empty stderr. Final reruns loaded native track caches successfully. These
frozen source captures do not establish manual-driving/performance validation.

Still open: precise balcony widths/floor coverage, facade bay counts, festoons,
carved capitals/crown proportions and measured roof equipment. Morton208 next;
no full-fidelity acceptance claim for Bell and no app export. Existing lap
evidence remains dated; no new lap/manual-wheel/Intel/performance claim.

## Morton working integration — Mac2026-10-08

Morton166,938tri/eight authored materials integrated at(-813.5,8,136.65),
retained mapped seven-point foundation, generic w147095676 excluded. Wall
fixture MortonBuilding has seven surfaces; isolated MortonBalconies one iron
surface. Both game cache validators require both nodes; cache187/original@v7/
Grid@v5. Warm occupied panes use normal Chicago night flag/color/energy.
Road geometry/timing unchanged; no per-building app export.

New gate28checks: materials/no photos/day-night, envelope, north-wing roof,
open court down to17.4m, curved projecting slab and balcony minimum height,
both complete route foundation distances206.250061original/8.842769Grid.
Initial roof ray hit the raised southern attic; moved it to north wing to test
the lower roof specifically. Initial Grid clip flagged a curved balcony at
worldy30.9m (22.9m above pavement). Preserve the photographed shape: isolate
only the balcony material into a separate mesh; overhead acceptance requires
exact MortonBalconies path, clearance>=22.8 and worldheight>=30.8. Main building
walls are never exempt. Low/lowered balcony cases remain rejected by tests.
Both final full native clip scans pass Grid104/original120 accepted overhead
hits, zero failures/empty stderr; warm cache loads confirmed.

Headless41Chicago suites passed in174.7s before the balcony split. After split,
parse/Morton28/Wacker20029 pass; concurrent menu/native rendering had a menu
timeout and a Metal fence timeout. Final serial menu115 passes in68.9s. Final
four High native Metal source day/night images on both layouts reviewed in
screenshots/chicago-morton-mac. Camera moved east of Morton after Bell occluded
initial west-camera views. Final renders load caches, exit0 and no Metal errors;
stderr retains ObjectDB exit warnings. Verbose run identifies AudioStreamWAV/
AudioStreamPlaybackWAV references (and RGB8-to-RGBA8 conversion warnings).
Stopping capture audio before scene disposal did not eliminate exit warnings.
This is recorded capture behavior, not a claim about interactive memory/performance.
Native editor import exits0/empty stderr.

Still work in progress: actual ground entrance/storefront authoring, narrower
central panel/window rhythm, measured upper court/balcony proportions, carved
base/crown/wreath profiles and roof services. These checks establish source
integration/clearance, not full architectural fidelity. No new lap/manual-wheel/
Intel/performance validation claimed; source-only full trackside goal continues.

## Morton entrance modeled — Mac2026-10-08

Inspected the property gallery image explicitly labeled Entrance for
Concord City Centre Lofts,208W Washington (photograph date/author unspecified):
https://www.apartmentfinder.com/Illinois/Chicago-Apartments/Concord-City-Centre-Lofts-Apartments
It shows a rectangular stone recess, projecting green metal cornice, glazed
doors/sidelights/transom, bronze framing, slim wall lights and two planters.
Image used only as visual reference; not downloaded, embedded or redistributed.
This is a visual shape reference, not architectural/date/dimension authority.

Authored those physical features in the editable Morton Blender generator/GLB;
167,226tri/eightmaterials retained. Ground backing now starts above floor1;
separate ground backing spans leave a true portal recess and retain masonry
behind surrounding window gaps. Door pulls/soffit/jambs, layered green cornice,
wall lamps and original planter leaves are physical geometry. Exact entrance
bay placement/size remains photo-fit pending a wider street reference, stated
in generator shortcut comment. No new whole-building fidelity claim.

Cache188, original@v7/Grid@v5; roads/timing unchanged. Final parse and Morton30
checks pass (2.8s combined), including stone-only portal opening and recessed
glass ray probes. Blender4.5.3 regeneration and Godot4.6.2 editor import exit0
with empty stderr. Two actual High native Grid entrance/day/night views inspected
in chicago-morton-mac/chicago_grid-entry-*.png: wall lights switch warm at night.
Bounded capture ran serially, exit0 with ObjectDB exit warning, no Metal error.
Existing audio-exit caveat remains; not performance/manual-driving validation.
Both final native full clipping scans pass Grid104/original120 accepted overhead
hits, zero failures/empty stderr; low entrance geometry/planters remain subject
to normal wall clipping rules. No new original-layout entrance-camera claim.

Still open: exact entrance placement and storefront proportions/signage, finer
central panel/window rhythm, measured court/balcony profiles, stone carving/
wreath/cornice and roof services. Full trackside objective remains active. No
app export/new laps/Intel/performance claim; previous runs remain dated evidence.

2026-10-08 Block37 working integration: Mac Godot4.6.2 AppleM4 Metal Forward+
High, cache189/original@v7/Grid@v5. All43selectedChicago/parse suites pass265.0s;
Block37 dedicated23 assertions, menu115 pass. Both native full clip scans pass
104Grid/120original accepted hits, empty stderr. Four current-cache production
Grid frontage day/night images actually inspected; two bounded capture jobs and
editor import exit0/empty stderr. Architectural entries/atrium/crown remain
incomplete; northeast image crops crown and day glare limits upper detail review.
No new laps, performance/Intel/manual-drive claim or app export. Evidence:
rebuild/chicago/BLOCK-37-REFERENCE.md and screenshots/chicago-block37-mac.

2026-10-08 Block37 storefront refinement/cache190:192936tri/eight materials.
Dedicated27/parse pass2.8s, final serial menu115 pass249.7s. Both full native
clip scans pass104Grid/120original accepted hits/empty stderr. Two actual High
Grid storefront day/night renders inspected/current cache loaded/exit0/empty
stderr; Blender regeneration/editor import clean. Race fence and cabinet limit
some storefront detail visibility. Actual mall portals/atrium/crown and exact
bay placement remain open. Roads/timing unchanged; no export/newlaps/performance
or Intel/manual-drive claim. Detailed evidence in BLOCK-37-REFERENCE.md.

2026-10-08 Block37 office spacing correction/cache191:184104tri/eight materials.
Dedicated28/parse pass2.9s; old-GLB physical probe fails where corrected pane
passes. Both full native clips pass104Grid/120original accepted hits/empty stderr.
Two current-cache High Grid office day/night source images actually inspected,
capture/import/Blender exit0/empty stderr. Roof fascia/equipment/atrium still
incomplete, height/base-floor calibration provisional. No full-suite/menu rerun,
new laps, export or performance/Intel/manual-drive claim at this revision.


2026-10-08 Block37 office fascia/cache192: broad dark projecting band/silver
coping authored from the previously inspected structural engineer photo.
184200tri/eight materials; dimensions/unseen faces remain photo-fit, roof
services/atrium/main entrances/crown remain open. Building29/parse pass2.9s,
including physical fascia projection ray. Both full native clipping scans pass
104Grid/120original accepted hits/empty stderr. Two actual High Grid elevated
fascia day/night source images inspected, current cache loaded, capture/Blender/
editor import exit0/empty stderr. Roads/timing remain original@v7/Grid@v5.
No current full-suite/menu/laps/performance/export/Intel validation claim.
See BLOCK-37-REFERENCE.md and chicago-block37-mac/chicago_grid-fascia-{day,night}.png.


2026-10-08 Block37 office rooftop service forms/cache193: public overhead
imagery inspected; eight circular housings/intakes/grilles and three rectangular
service volumes authored,188588tri/eight materials. Sizes/spacing/heights remain
photo-fit and mechanical function unconfirmed. Building30/parse pass2.8s, raised
intake ray included; Blender/editor import clean. Two actual High Grid elevated
roof day/night images inspected, cache193 saved, capture exit0/empty stderr.
Minor night roof speckling and western green roof remain open, along with atrium/
main mall portals/crown. Last full clips at192; no new road/timing changes or
full-suite/menu/lap/performance/export/Intel claim. See BLOCK-37-REFERENCE.md.


2026-10-08 Block37 western planted roof/cache194: overhead-photo-fit20x28m
raised bed/pale service borders/560 low clumps,199848tri/nine materials. Both
cache validators updated. Building32/parse pass2.7s, raised planting ray and
generator count assertion included; Blender/editor import clean. Two actual
High Grid elevated day/night source images inspected/cache194 saved/capture
exit0/empty stderr. Controlled night capture with directional shadows disabled
removes isolated roof dots, supporting shadow sampling as cause; production
shadows retained and lighting calibration remains open. Exact landscape plan,
atrium/main mall portals/crown remain open. No road/timing/export/newlaps or
current full-suite/performance/Intel claim; full clips last recorded at192.
Serial menu/cache115 checks pass67.3s, empty stderr. See BLOCK-37-REFERENCE.md.
