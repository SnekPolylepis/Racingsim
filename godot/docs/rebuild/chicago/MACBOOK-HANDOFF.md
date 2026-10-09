# MacBook continuation — owner pause2026-10-07

Repo: https://github.com/SnekPolylepis/Racingsim
Working branch: `codex/chicago-3d-buildings`. Fetch it; preserve any local
changes, switch safely and pull with `--ff-only`. Main does not contain these
latest drafts. Resume work on this branch; do not reset or force-push.

Read root AGENTS.md and CLAUDE.md, REBUILD-PLAN.md section9, latest REBUILD-LOG.md,
rebuild/QUEUE.md, LLM-GUIDE.md and MACOS.md. Use ponytail FULL: reuse current
helpers, no unnecessary abstractions/dependencies. Locate the local ponytail
skill on the Mac; the owner's Windows skill path is not a Mac path.

Objective remains replacing photo-on-block Chicago buildings with recognizable
authored 3D exteriors. Trackside buildings/scenery first; distant skyline later.
Generic physical windows and passing geometry tests do not establish full
building fidelity. Bridges over the river are queued after the building pass.

Current Mac checkpoint2026-10-08: Brooks and300SouthWacker physical exteriors
integrated; mapped South Wacker approach clears300foundation. Original@v7,
Grid@v5/cache197. See latest dated evidence below. Continue trackside building
work from236-candidate CSV;311SouthWacker tower/winter-garden and200SouthWacker paired tower/entrance drafts are integrated. Refine their remaining photo-fit details and continue close candidates; see both reference documents.
Finer City/County reliefs/seals remain open; court glazing and roof work have
later Mac evidence below. The original Windows handoff follows for history.

## Original Windows handoff — 2026-10-07

Latest work: City Hall west and County east paired exteriors, physical windows,
fluted columns, stylized capitals and three physical portals on each main face.
Doors/transoms have separate recessed panes and bronze frames/pulls. Shared
authoring: tools/blender/chicago_city_hall.py; County invocation adds --county.
Original .blend files are in tools/blender/authored; GLBs/SOURCES in
assets/chicago/landmarks. City190148tri/County190184tri, seven materials each.
Exact mapped rings, no rotation: City(-626,8,106.35),County(-579.65,8,106.8).
Both use HABS62.484m coping; WJE rounded60.96m discrepancy remains documented.
Cache154. Both routes load both models and exclude their generic shells.

Next: author the actual distinct City/County relief figures and County seals;
four entrance relief fields on each model are still empty. Then verify/model
court glazing, City roof garden and roof equipment. Use primary photos linked
in CITY-HALL-REFERENCE.md and each SOURCES file; do not invent acceptance from
occluded images or copy the County seal to City Hall. Mallers and Hyatt drafts
also retain fidelity gaps recorded in the log. Continue remaining recognizable
trackside buildings from TRACKSIDE-PRIORITY.csv after these refinements.

Final Windows checks20261007-233858: all seven targeted gates PASS98s,
County13/City12/menu107/coverage23/both clipping scans one each/parse
(157 checks plus parse). Original111/Grid101 baseline clipping hits unchanged.
Native County entrance day/night inspected; earlier City entrance too.
Current screenshots: rebuild/screenshots/chicago-civic-entrances/.
These are Windows evidence, not Mac validation or a driving benchmark.
No Godot/Blender processes remain running at the pause.

On Mac, use Godot4.6.2. If absent, packaging/fetch-macos.py fetches the official
runtime as described in MACOS.md. Review from source:

```sh
godot/tools/Godot.app/Contents/MacOS/Godot --path godot
```

Import assets before checks, use tools/gates.json for targeted suites and
arguments, and inspect actual day/night renders on Metal. Recreate review
scripts as needed: Windows tests/logs and visual-review are ignored scratch
folders, not portable deliverables. New geometry needs visual and meaningful
geometry/route checks; don't run the entire test matrix for every building.

Do not export a full executable/app for each building. Export only when the
owner requests a playable update/release; replace fixed current/backup slots,
remove temporary staging, preserve source assets and all user saves. No export
was performed during these refinements. Audio listening on the owner's device,
broader placement/lighting/performance and bridge work remain open; don't claim
the overall goal complete. Commit/push coherent progress to this branch.


## County outer entrance relief draft — 2026-10-08 Mac continuation

Owner resumed on Mac. Godot4.6.2 and Blender4.5.3 are installed locally.
County outer standing-figure/oval-seal silhouettes and plaques drafted;
County233320tri/sevenmaterials/cache155, paired placement unchanged.
Source157assertions plusparse and72driving/presentation checks pass on M4/Metal.
Four actual day/night frontage/oblique images inspected; final capture has
ObjectDB exit warning. Fine sculpture and low-contrast shaded rendering remain
open. Inner County fields/City reliefs, courts and roofs still need work before
remaining trackside buildings. Bridges remain queued; no export.
Evidence: REBUILD-LOG2026-10-08 and screenshots/chicago-county-reliefs-mac/.

Local Mac authoring command (repo root):
```sh
~/.local/share/racingsim-tools/Blender.app/Contents/MacOS/Blender --background --python godot/tools/blender/chicago_city_hall.py -- "$PWD/godot/assets/chicago/landmarks" --county
```
Local capture script is ignored godot/visual-review/civic.gd. Logs in
ignored tests/logs/mac-civic/ and tests/logs/ci/. Original owner pause is
historical; owner resumed on2026-10-08. Continue on this same working branch.


## Current continuation checkpoint — 2026-10-08 City reliefs

City four distinct LaSalle physical figure drafts now integrated;215924tri,
sevenmaterials/cache156. County remains233320tri. City16/County15/menu107/
coverage23 plusparse pass on Mac; four actual High-quality day/night City views
inspected with empty stderr. Fine sculpture remains provisional. Next: finish
County inner fields, court glazing and roof details; City roof has a newly
inspected USGS/City photographer aerial linked in CITY-HALL-REFERENCE.md.
Then continue all remaining trackside exteriors. Goal stays active; no export.
Local ignored City capture: godot/visual-review/civic-city.gd; logs mac-civic/.

Final City checkpoint source Grid driving/presentation:72/72PASS,exit0,
empty stderr (city-drive logs). No export or full-lap/performance acceptance.


## Current continuation checkpoint — County inner seated drafts

County inner Clark fields now have two physical seated draft figures;
240024tri/sevenmaterials/cache157. Actual High-quality Grid day/night frontage
and oblique views inspected,exit0,empty stderr. Fine sculpture and unresolved
held attributes remain open. Next court glazing and roof garden/equipment from
recorded primary references, then all remaining trackside buildings. No export.
Ignored local capture: visual-review/civic-county-inner.gd; logs mac-civic/.


## Current continuation checkpoint — City roof draft

City436344tri/tenmaterials/cache159: physical garden, curving service paths,
rooms, louvered equipment, ducts and rails from recorded USGS/City aerial.
Actual final High Grid day/night roof/equipment renders inspected after
refining sparse planting/stepped paths. Mac168assertions plusparse pass71.3s;
import/render exit0/empty stderr. County remains240024tri/sevenmaterials.
Next: court glazing, County roof, finer sculpture/garden fidelity, then
remaining trackside buildings. Photo-fit equipment/layout remain provisional.
No export/performance claim. Ignored capture visual-review/civic-roof.gd,
logs mac-civic/; committed screenshots/chicago-city-roof-mac/.


## Current continuation checkpoint — paired light-court draft

City477312tri/elevenmaterials,County284156tri/eightmaterials/cache161.
Physical pale masonry with recessed sash panes, frames and sills replaces
blank court walls; scaled concave backing removed because it filled recesses.
Second actually inspected USGS/City paired aerial linked in reference doc.
Final Mac172assertions plusparse pass70.6s; import/court review exit0,empty
stderr. Six actual High Grid court day/night views inspected. Bay/floor/sill
dimensions are photo-fit draft; exact fenestration/services unresolved.
Next County roof equipment from paired aerial, finer civic details, then all
remaining trackside buildings. No export/performance claim. Ignored captures
visual-review/civic-courts.gd and civic-courts-public.gd, logs mac-civic/.
Committed evidence screenshots/chicago-civic-courts-mac/.

Final cache161 also retains three recessed public-only backing strips; actual
street review caught/closed holes above portal roofs. Ten final High court
and public day/night images inspected,combined review exit0/empty stderr.
Public header transitions and fine relief shading remain simplified.


## Current continuation checkpoint — County roof draft

County286800tri/ninematerials/cache164,City477312tri/elevenmaterials.
Physical service rooms, twin central/single wing fans, louvers, pipes and
guardrails; deck remains unplanted. Actual render iteration reduced repeated
fan units; footprint check corrected tower overhang and is now asserted.
Four final High Grid day/night roof/equipment renders inspected,exit0/empty
stderr. Mac175assertions plusparse pass69.1s; import exit0/empty stderr.
Exact equipment/court layout, fine civic reliefs and header transitions stay
provisional. Next225WestWacker, inventory0.2m from Grid boundary; actual
visibility/clearance must be checked. Primary owner www.225westwacker.org,
KPF renovation and Valerio Dewalt Train225W Wacker pages found this pass.
Continue remaining trackside buildings; bridges later. No export/performance
claim. Ignored capture visual-review/civic-county-roof.gd, logs mac-civic/.
Committed evidence screenshots/chicago-county-roof-mac/.

### Latest checkpoint — 225 West Wacker draft, 2026-10-08

w64391366 replaced exactly once at(-886,8,-164.75). Editable Blender/script
and GLB included;163756tri/eightmaterials/cache169. Physical individual panes,
granite piers/spandrels, paired recessed channels, four stepped turrets,
barrel vault/end ribs, north half-rotunda clear frontage and lobby details.
Primary photos/architect references and height discrepancy documented in
assets/chicago/landmarks/WACKER-225-SOURCES.md. All dimensions photo-fit;
mapped126.5m retained provisionally, no surveyed-height/final-fidelity claim.

Final Mac import exit0/empty stderr; building28 assertions plusparse pass1.5s.
Preceding menu109/coverage23/building28 plusparse pass68.5s; final small north
clear-glazing/address correction reran geometry/parse. Ten final actual High
Grid day/night captures inspected; render exit0/empty stderr. Ignored review
visual-review/wacker225.gd; logs tests/logs/mac-civic/wacker225-*.
Committed screenshots/chicago-wacker225-mac. No export/performance claim.

Next inspect Lower Wacker placement/clearance around BotLine4785: camera
(-901.8246,4.8288,-213.0615) is near the mapped foundation, direct view
wall-occluded and forward view partly occluded. Do not infer visibility or
safe vehicle clearance from inventory0.2m, or hide/shift the building to
make the problem disappear. Preserve geometry and inspect neighboring
stations/road envelope. Refine225 frontage/crown proportions, then continue
remaining trackside buildings (Franklin–Van Buren garage is next close
candidate). Fine civic detail remains open. Bridges stay queued.

### Latest checkpoint — 225 Wacker clearance fixed, 2026-10-08

Cache171, record identities original@v5/Grid@v3. Retained225 building geometry;
route now follows bend north of foundation via Lower(-919.3,-228.6),
Upper(-917.9,-225.3) controls. Sources in WACKER-225-SOURCES.md. Sampled minima
17.1m/Grid,14.4m/original; full-course clipping scans pass after correcting
broad Wacker overhead exemption. Ten actual source High day/night driving
views inspected in screenshots/chicago-wacker225-clearance-mac, exit0/empty
stderr. Lower deck still screens upper façade naturally. Prior occluded
screenshots remain dated evidence. No surveyed-clearance claim.

35 headless Chicago/parse suites passed (919 assertions plusparse),160.2s;
final menu109/building34/Grid formula4/parse pass131.0s, then final footprint
check building35/parse pass1.9s. All five cars/both modes completed clean on
both layouts; zero off-road/wall/prop ticks (no lap-harness props). Grid passes
existing timings. Original new bend changed road-car times beyond2%; compared
old GT route, then recorded six clean new original-layout references. Full original allfivecars/twomodes rerun passes10 assertions,
exit0/empty stderr; formula-original timings have no stored reference.
See REBUILD-LOG for new values;2% tolerance unchanged. Bounded Grid all-car timeout resolved with
individual completed runs. Saved old records/ghosts retained separately.

Refreshed TRACKSIDE-PRIORITY.csv:241 candidates within50m,225 now14.4m/original
6840. Candidate/exclusion status and actual views must be checked before each
model. Next refine225 frontage/crown proportions and remaining trackside
buildings, including Franklin–Van Buren garage after placement/visibility
inspection. Fine civic reliefs/configuration remain open. Bridges queued.
Ignored render script visual-review/wacker225-clearance-render.gd; logs
mac-civic/225-clearance-*. No export/performance/hardware acceptance claim.


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

## Bell draft checkpoint2026-10-08

Bell212WestWashington editable Blender/GLB draft staged,127,404tri/nine
materials; source import and isolated native day/low-light views checked.
Not integrated/accepted: photo-fit balconies/entry/crown, production day/night
materials and both-layout checks remain next. See WASHINGTON-208-212-REFERENCE.md.
Morton208 next; cache184 and road versions unchanged; no app export.

## Bell integrated checkpoint2026-10-08

Bell mapped physical exterior integrated/cache185,148,776tri/nine materials.
Parse/all40Chicago suites and both full clip scans pass; ten actual High source
day/night images reviewed. See WASHINGTON-208-212-REFERENCE.md for recorded
checks and remaining ornament/balcony/crown calibration. Morton208 next.
Road versions/timing unchanged; source-only, full trackside goal continues.

## Morton staged checkpoint2026-10-08

Morton208 original editable Blender/GLB144500tri/eightmaterials staged.
Upper court and green-panel/red-brick facade with raised attic modeled from
NPS/Visviva photo. Two native isolated views checked, not production acceptance.
Refine storefront/entry and ornament/court/bay/balcony proportions, then integrate
and validate materials/footprint/production day-night/clip scans. Cache185 unchanged.
Details in WASHINGTON-208-212-REFERENCE.md; full trackside goal active.

Morton refinement2026-10-08: closer south photo corrected balconies to curved
reddish stacks; inset stone panels and stylized capital fans added.166938tri/
eight materials, isolated day/low-light and close balcony review passes. Still
staged; establish entrance then integrate/material/production/clip checks.

## Morton working integration2026-10-08

Morton exterior integrated/cache187,166938tri/eightmaterials, wall7/balcony1
fixtures. Dedicated28/parse/Wacker20029/serialmenu115 and both full clip scans
pass; four native production day/night views inspected. Balcony overhead
acceptance is exact isolated-node and >=22.8m clearance/>=30.8worldheight,
never building walls or low balconies. Serial rendering avoids observed Metal
fence timeout under concurrent validation; capture exits retain audio ObjectDB
warnings, documented in WASHINGTON-208-212-REFERENCE.md. Entrance/storefront,
central bay rhythm, measured court/balconies and carving remain next. Full goal
active; roads unchanged; no export.

## Morton entrance refinement2026-10-08

Recessed entrance/green cornice/doors-transom/lamps/planters now modeled from
labeled property photo;167226tri/eightmaterials/cache188. Exact bay placement/
dimensions remain provisional. Morton30/parse and both full native clip scans
pass; two actual High Grid entrance day/night views reviewed (known audio
ObjectDB exit warning persists). See WASHINGTON-208-212-REFERENCE.md. Remaining
measured/detail refinement and other trackside models continue; no app export.

Latest Block37 working integration2026-10-08/cache189: retained compound base
clears both routes, installed podium/separate towers,189984tri/seven materials.
All43selectedChicago/parse suites and both full native clips pass; four actual
High Grid production frontage day/night views reviewed/current cache loaded.
Detailed evidence in BLOCK-37-REFERENCE.md. Next refine actual entrance portals/
canopies/signage, atrium glazing/roof, asymmetric warm tower inset shapes/crown
and podium strip coverage against primary photos. Keep remaining City/County
reliefs and other trackside fidelity work open. No route change/export/newlaps.

Block37 State Street storefront refined/cache190:192936tri/eight materials,
physical clear paired doors/showcases/transoms/pulls, ventilation fascia and
night soffit fixtures.27/parse/menu115 and both full native clips pass; two
current-cache storefront day/night images reviewed. Actual mall portals/signage,
other ground faces and exact tenant-door bays remain open. Primary Gensler
atrium photo and operator2022level1/3 floor plans now inspected; use these
relationships plus roof photos to author the atrium glazing, not a guessed
rectangular hole. Source links/evidence in BLOCK-37-REFERENCE.md. No export.

Block37 office story rhythm corrected/cache191: structural engineer records17
total office stories, so draft now has13shaft/fourbase rows rather than21total.
184104tri/eight materials.28/parse/old-GLB regression and both full native clips
pass; two current-cache High Grid office day/night images reviewed. Next author
the photographed dark projecting office roof fascia/services, then resolve
atrium outside roof geometry; raster peaks alone are not glazing proof. Exact
base-floor heights remain provisional. Source/photo/evidence links in
BLOCK-37-REFERENCE.md; no export/newlaps/full-suite claim at191.


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


2026-10-08 Sharp/Champlain staged Blender draft: retained footprint rechecked
against current original@v7/Grid@v5 at1m intervals,78.199997/9.157592m clearance.
Earlier generic exclusion still present, not a current integration blocker.
61392tri/six materials, provisional mapped71.5m height; physical tripartite
panes/frames/masonry/sills/belts/corbels. Standalone geometry12 checks and
generator assertions pass, Blender/import clean. Two actual High Grid staged
day/night views inspected/capture exit0/empty stderr; base screened by elevated
rail and crown cropped. Arched parapet/monumental base/entrance/roof remain,
not integrated. No cache/road/timing/export/newlaps/performance claim.
See chicago/SHARP-REFERENCE.md; continue refinement and full integration clips.


2026-10-08 Sharp staged parapet refinement: replaced simple corbels with two
rows of original physical terracotta arch rings/jambs/sills and dark recessed
openings, following the previously inspected restoration-architect photograph.
135456tri/six materials, dimensions/spacing/unseen faces remain photo-fit.
Standalone draft14 geometry checks pass, including upper ring/recess rays;
generator pitch/batch assertions pass. Blender/editor import exit0/empty stderr.
Two actual High Grid close crown day/night source renders inspected at
(-150,78,461), looking(-118,77,427), FOV55; crown is now uncropped and
arch rows visible, though daylight glare and shadows affect readability.
Capture exit0/empty stderr. Files chicago-sharp-draft-mac/chicago_grid-crown-
{day,night}.png. Still staged; monumental base/entrance/roof/skylight, masonry
proportions/height and full placement/integration clipping remain open. No
cache revision/road/timing/export/newlaps/full-suite/performance/Intel claim.


2026-10-08 Sharp/Champlain working exterior integrated/cache195:135660tri/
six materials. Owner frontage image guides physical northern paired entrance,
transom/molded surround/plaque/pulls, separate storefront panes/rails and heavy
second-story frames. Exact ornament/height/dimensions remain photo-fit. Generic
mapped footprint explicitly replaced, both cache validators updated. Dedicated
19 geometry/placement checks plusparse pass2.4s; both full native clip scans
pass104Grid/120original accepted hits, empty stderr/no exemption. Serial menu
115 checks pass; recorded2543.9s is not performance acceptance. Actual production
High Grid frontage/crown day/night views inspected; frontage capture exit0 with
ObjectDB cleanup warning, crown capture exit0/empty stderr. Close entrance
review revealed lower door obstruction; removed bay spandrel/cache196,135648tri/
six materials. Dedicated20/parse pass2.6s and two actual cache196 close entry day/night
images inspected, clean capture exit0/empty stderr, leaves open to threshold.
Earlier clip/menu/crown evidence is cache195, not a current196 repeat. Roads/timing original@v7/Grid@v5 unchanged; no export/newlaps/
full-suite/performance/Intel claim. Roof/skylight/fine ornament and measured
height remain open. See SHARP-REFERENCE.md.

Windows resume2026-10-08: fetched Mac checkpoint9c6a950, corrected Sharp to
CVU61.3m architectural height/cache197.13story interpretation remains
provisional versus CVU12; roof/skylight/fine ornament still pending. Shared
TrackAsset.prepare disables unused TimingLine orientation baking, fixing
repeatable non-normalized-axis errors. Exact timing positions preserved.
Final193145 seven gates pass193checks plusparse; original120/Grid104 clips
unchanged, native runtime clean. See latest log and SHARP-REFERENCE.md.

Windows Sharp refinement2026-10-08/cache198: wider masonry piers and broad
centre/narrow side window proportions from Brush facade photograph. Six
gates160checks plusparse pass, original120/Grid104 clips unchanged; four
source day/night views inspected, clean runtime. No export. Roof/skylight,
fine carving, floor-count conflict and long/rear elevations remain open.
