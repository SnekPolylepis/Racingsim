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
