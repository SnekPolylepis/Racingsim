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
