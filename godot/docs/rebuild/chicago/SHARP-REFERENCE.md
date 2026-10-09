# Sharp / Champlain Building candidate

37 South Wabash, mapped w147478374, footprint approximately53m east/west
by24m north/south with a small north-side notch; centre(-105,423).
Mapped71.5m is unverified. CVU records61.3m/12floors; owner SAIC records
13stories plus basement. Dates conflict: CVU1902; restoration page1902
header/1909 body; SAIC2014 accreditation report1906. Do not resolve by guessing.

Primary owner photo actually inspected2026-10-04:
https://www.saic.edu/irfm/campus-buildings
Shows monumental dark metal second-floor windows, tan masonry/ornamental
bands, broad ground storefront and elevated railway across the view.
Restoration architect photo actually inspected:
https://www.brusharchitects.com/pr-champlain/
Four upper bays on narrow facade, grouped tripartite windows, brick piers
and repeated projecting cornice/corbels. Long side window counts and entrance
need closer inspection before authoring. Restoration describes18ft structural
bays, salvaged second-floor cast-iron frames and rebuilt monumental parapet.
https://www.skyscrapercenter.com/building/sharp-building/35029

Native Grid source review PID102152 completed, CITY REVIEW PASS/empty stderr.
Metadata explicitly excludes city index381/w147478374 for authored route
clearance. Nearest chosen camera(-77.16336,9.3,443.2538). Three daylight
captures inspected: surrounding generic skyline; offset corner/entry cameras
land inside neighboring geometry. These are not proof of Sharp frontage.
No model authored or integrated; defer to a legitimate placement/route pass.
No EXE. Frozen27.206ms/69.077M primitives is not controlled drive performance.


## Placement recheck and staged Blender draft —2026-10-08

Previous deferral above is historical. Current original@v7/Grid@v5 full1m
centerline-to-retained-footprint samples clear78.199997m original/9.157592m
Grid (nearest Grid station589 at(-133.1187,8,443.9592)); above8m foundation
criterion. Generic metadata still excludes index381; no production placement
change has been made. Full physical clipping after integration remains required.

Restoration architect page reread and its original facade photograph actually
inspected in browser:
https://www.brusharchitects.com/pr-champlain/
https://www.brusharchitects.com/wp-content/uploads/2018/11/champlain-960x630.jpg
Four narrow-face upper bays show tripartite dark frames, tan brick piers,
projecting sills and two tiers of small arched cornice openings. Long face
partially visible; ground floor cropped. Capture date unspecified. Reference
pixels are not used in game assets. Text identifies salvaged second-story
cast-iron frames and18ft structural belt-course bays. Conflicting dates/heights
above remain unresolved.

Original working draft generator chicago_sharp_building.py exports editable
sharp_building.blend and sharp_building.glb:61392tri/six materials. Retained
nine-vertex foundation/north notch, provisional71.5m mapped height,13modeled
stories (two base/eleven upper), physical separate tripartite panes/dark frames,
brick piers/spandrels, projecting terracotta sills/heads/belts and corbels.
Long/rear bay counts and exact floor heights are provisional. Two-tier arched
parapet openings, actual recessed entrance, monumental base and roof/skylight
still need authoring; current cornice is an incomplete draft.

Blender/editor import exit0/empty stderr. Standalone draft geometry12 checks
pass (material/bounds/height/west physical pane), generator batching assertions
pass. Two actual High Grid staged day/night source images inspected at
(-155,17,465) looking(-108,40,425), FOV75. Elevated railway screens base;
crown cropped, so not entrance/crown acceptance. Capture exit0/empty stderr.
Files screenshots/chicago-sharp-draft-mac/chicago_grid-full-{day,night}.png.
No integration/cache revision/road identity/export/lap/performance/full-suite
claim. Next refine masonry/window proportions and arched parapet, inspect
uncropped crown/base, integrate only after both full clipping scans.


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


## Working integration and west base —2026-10-08/cache195

Owner frontage photograph actually inspected in browser:
https://www.saic.edu/sites/default/files/styles/16_9_768x432/public/2023-06/00263_006_0.jpg.jpeg?itok=egq20wux
Shows northern west-face recessed entrance, molded surround/plaque/transom,
broad adjacent storefront panes and heavier monumental second-floor frames.
Elevated railway partly screens upper/lower facade. Photo date unspecified;
URL upload directory is not capture-date evidence.

Added original paired recessed door leaves/dark jambs/transom/door pulls,
projecting molded entrance surround/plaque, separate ground shopfront glazing/
frames/transoms, second-floor heavy outer frames/meeting rails. Bay order was
verified from mapped vertex orientation; northern entrance is bay0. Exact
ornament/sign lettering, opening dimensions and floor heights remain photo-fit.
135660tri/six materials. Installed Scenery/SharpBuilding at(-105,8,423),
explicit mapped generic replacement, both cache validators updated/cache195.
No Clear-material branch because the six-material asset has no transparent
material. Geometry19/parse pass2.4s, including mapped fixture, both1m retained
foundation clearances and physically recessed northern entrance ray. Blender/
editor import exit0/empty stderr. Both full native clipping scans pass104Grid/120original accepted hits, empty
stderr, no Sharp clipping exemption. Serial menu115 checks pass; runner records
2543.9s, not performance evidence. Six production day/night frontage/crown/
entrance views captured; close entry exposed a lower door obstruction from the generic bay spandrel;
removed in final cache196 refinement below. Frontage
capture exits0 with ObjectDB cleanup warning; crown/initial entry capture
exit0/empty stderr. Final source geometry unchanged after removing the unused
Clear-material branch.
Road/timing identities unchanged original@v7/Grid@v5. No export/newlaps/
performance/Intel/full-suite claim. Fine ornament, roof/skylight, measured
height and wider facade proportions remain open.


Final entrance exposure correction/cache196: removed only the northern entry
bay ground spandrel that blocked the bottom1m of the door leaves.135648tri/
six materials; no envelope expansion/placement/material contract change.
Dedicated20/parse pass2.6s, including first-hit lower-door exposure assertion;
Blender/import exit0/empty stderr. Earlier full native clips/menu/frontage/crown
are cache195 evidence; no repeat claimed for196. Two actual current-cache196 close door day/night
renders inspected: leaves exposed to threshold, recess/pulls/transom visible,
source capture exit0/empty stderr. Camera(-134.5,10.5,414.4), FOV110, inside
race fence; static architectural review, not a drivable camera claim. Production route/timing identities unchanged.

## Windows continuation: published height correction2026-10-08

Fetched/fast-forwarded Mac work through9c6a950. CVU primary record reread:
https://www.skyscrapercenter.com/building/sharp-building/35029
It explicitly defines61.3m as architectural height above the significant
entrance; no primary evidence supports the mapped71.5m previously retained.
Original Blender now chooses61.3m, keeping fixed base/entrance dimensions
and redistributing upper story spacing.135648tri/sixmaterials/cache197.
CVU12floors versus owner13stories remains unresolved;13 modeled rows remain
a provisional interpretation, not a proven count. Dates remain unresolved.
Roof/skylight/fine ornament and facade proportions remain open.
Geometry20 passes at revised coping/parapet, entrance exposure and retained
foundation clearances. Native Windows PID55956 terminalSHARP CITY REVIEW PASS/
empty stderr; four actual frontage/crown day/night images inspected. Elevated
rail screens base; these are not new entrance acceptance. Frozen20.97ms is
not driving performance. Files screenshots/chicago-sharp-windows/.

Final source gates20261008-193145 sevenPASS118s (193checks plusparse), both
full clips accepted original120/Grid104 unchanged. Initial original/menu
stderr failure reproduced serially and resolved in shared TimingLine position
preparation by disabling unused up-vector frame baking. TrackAsset33 checks
include exact baked position preservation and figure-eight drive. Final
native PID66772 terminalSHARP CITY REVIEW PASS/empty stderr; crown-night
inspected after fix. No export or complete Sharp fidelity claim.
