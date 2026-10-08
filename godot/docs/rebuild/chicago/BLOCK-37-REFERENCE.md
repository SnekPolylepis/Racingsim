# Block 37 candidate — 2026-10-08

Mapped w124865494 is the next unmodeled candidate under investigation:
TRACKSIDE-PRIORITY.csv gives 9.3 m horizontal boundary distance on Grid.
The mapped polygon spans approximately 102 by 119 m; city.json assigns
138.5 m height to the compound. Do not extrude the whole retail block to that
height: retail podium and later tower must be distinguished before authoring.
Editable Blender source is installed as a working production exterior;
foundation and full native clipping checks pass. Detailed fidelity remains open.

Primary project pages read:
- https://www.weoneil.com/project/block-37/
- https://www.gensler.com/projects/block-37
- https://scb.com/project/block-37/
- https://www.blockthirtyseven.com/

W.E. O’Neil describes a four-story retail podium surrounding a central atrium,
transparent ground/corner facades and horizontally woven steel exterior panels.
Its construction scope anticipated later towers. SCB identifies Marquee as the
later residential component. The operator confirms 108 North State Street.
Separate these components using actual photos and mapped building parts;
published project descriptions alone do not establish current roof geometry,
heights, bay counts or the exact tower footprint. W.E. O’Neil gallery exterior images1/3 and SCB’s full tower photograph were
visually inspected in this pass. Retain mapped footprint and validate route
clearance and native visibility before installing a replacement.

Next: refine podium entrance/glazing/strip coverage, atrium roof and tower
crown against closer primary photos; review each refinement from source.
No export, route change, rendering or lap-validation claim at this checkpoint.

## Editable draft and native evidence

Generator tools/blender/chicago_block_37.py exports block_37.glb and
editable tools/blender/authored/block_37.blend:189984tri/seven materials.
Retained compound foundation at(-357.2,8,104.25). Roof raster distinguishes
north tower x[-405,-317]/z[47,73], southern office x[-403,-336]/z[125,161]
and low retail podium. These simplified upper envelopes and130/80/26m heights
are provisional raster/photo fits, not surveyed dimensions. Four podium rows,
37 residential shaft rows and17 office rows give physical recessed panes,
mullions and rails.48 bowed strip rows approximate woven podium cladding;
coverage/module shape still needs refinement. No external photo is embedded.

Native Mac Godot4.6.2 Forward+ High Grid baseline and staged draft captures
completed exit0/empty stderr. Both draft day/night images actually inspected,
retained in screenshots/chicago-block37-draft-mac. The baseline confirms the
compound is excluded (city3794/authored route clearance). Draft is injected
only by ignored visual-review/block37-draft.gd at that checkpoint; production
was unchanged until the integration recorded below.
First capture exposed opaque upper backing over recessed panes; inset backing
fixed it, final day/night panes/night switching inspected. Blender regeneration
and native editor import exit0/empty stderr; Python syntax and diff checks pass.
Generator asserts polygon bounds, facade pitch, batched topology and backing
clearance. No whole-track clipping, new laps, performance or release claim.

Open: retained-foundation clearance, actual entrance portals/canopies/signage,
central atrium roof opening, podium module placement, asymmetric tower inset
shapes/crown, office roof services and wider measured proportions. This draft
is not a finished exterior. Route versions/cache remain v7/v5/cache188.

Additional operator page read2026-10-08:
https://www.blockthirtyseven.com/leasing . It calls the shopping center five
levels and Marquee38stories/690units; SCB calls the completed tower41stories/
691apartments and describes building above a four-story mall. Preserve these
source descriptions separately; do not settle counting conventions by guessing.
The draft’s floor spacing and130m roof are provisional and need calibration.

## Working integration — cache189

Scenery/Block37 installs seven-material exterior on both layouts. Both cache
validators require the fixture; mapped w124865494 is explicitly replaced once.
Dedicated23geometry/night assertions and parse pass. Retained foundation clears
full1m-sampled route centrelines278.572113m original/9.261011m Grid. Native full
clipping scans pass Grid104/original120 accepted overhead hits, empty stderr;
Block37 has no overhead exemption. Roads/timing remain original@v7/Grid@v5.
Entrance/crown/atrium and measured facade fidelity remain incomplete.

Full43selected CI suites (42Chicago plusparse) pass265.0s, serialized on Mac;
Grid menu115 assertions pass68.5s. This validates the current working integration,
not complete architectural fidelity. Four actual High native Grid production day/night frontage views (southeast
and northeast) inspected in screenshots/chicago-block37-mac. Both bounded
capture jobs load cache189 and finish exit0/empty stderr; native editor import
also clean. Northeast framing crops upper crown and daylight has direct sun
glare; these views establish frontage/night operation, not crown fidelity.
No new laps, manual drive, performance, Intel validation or app export claimed.

## Additional primary geometry evidence —2026-10-08

Gensler street-retail photograph actually inspected:
https://static2.gensler.com/uploads/hero_element/3910/thumb_desktop/thumbs/project_block-37_03_1025x576_1404850061_1024x576.jpg
Shows transparent storefronts, silver door/transom framing, continuous dark
horizontal ventilation fascia and projecting soffit. Capture date not stated;
asset upload timestamp is not evidence of capture date. Tenant branding is not
embedded in the model. Door placement/count remains photo-fit.

Gensler atrium photograph actually inspected:
https://static2.gensler.com/uploads/hero_element/3912/thumb_desktop/thumbs/project_block-37_05_1399481244_1024x576.jpg
Shows physical roof glazing/white cross beams and curved gallery edges. It does
not establish the exact outside roof plan or street alignment.

Operator/CIM leasing brochure read; level-one/level-three diagrams visually
inspected (PDF pages6/8, one-based):
https://cdn.placewise.com/CIM/block37/files/Block37LeasingBrochure8.5.22-compressed.pdf.pdf
Its street-labeled plans identify the southern22WestWashington office block,
northern residential lobby and branching central retail passages/atrium. The
upper lobby footprint is not proof of the tower footprint. Use the diagrams to
fit atrium relationships before authoring roof openings; confirm roof geometry
against overhead photos. Brochure filename indicates2022version; tenant layout
is historical evidence, not a current tenant guarantee. No brochure/photo
embedded or redistributed.

## State Street storefront refinement —cache190

192936tri/eight materials, editable Blender regenerated. Street-retail photo
guides separate clear showcase/door panes, paired1m door leaves, transoms,
silver frames/pulls, continuous shallow soffit and16physical dark ventilation
slats. Ground storefront lights share the existing Night material/switching.
Only the State Street face is refined here. Exact tenant-door bay positions
and fascia dimensions remain photo-fit; actual main mall entries/signage,
other ground faces, atrium roof and crown remain open.

Dedicated27checks and parse pass2.8s: eight-material contract/clear alpha.18,
night switching, roof tiers/retained foundation and two physical door rays
confirm panes are recessed and exposed rather than blocked by opaque backing.
Native editor import/Blender exit0/empty stderr. Both full native clipping scans
pass104Grid/120original accepted hits/empty stderr. No Block37 exemption.
Two actual High Grid storefront day/night source renders inspected at
(-294,10.3,100), current cache loaded, exit0/empty stderr; race fence partially
screens glazing/pulls and existing cabinet screens right showcase. Files:
screenshots/chicago-block37-mac/chicago_grid-storefront-{day,night}.png.
This is exterior/recess evidence, not a modeled retail-interior acceptance.
Roads/timing remain original@v7/Grid@v5; no new laps/performance/export claim.
Earlier all43suite result is cache189 evidence; final current menu115 checks
pass249.7s, serialized. No current full43 rerun claimed.

## Office count correction and roof evidence —2026-10-08

Structural engineer’s primary project description explicitly records a17-story
media office tower (one basement separately). Source actually read:
https://www.thorntontomasetti.com/project/redevelopment-block-37
The draft incorrectly had17shaft rows above four base rows. Corrected to13shaft
rows above four modeled base rows, retaining provisional80m roof/footprint.
This fixes the total row count; exact office base floor heights remain unmeasured.
Generator now exports184104tri/eight materials, cache191. Dedicated28/parse
pass2.9s, including a physical lower-shaft pane ray distinguishing the prior
compressed spacing. No exterior-envelope or road/timing change.

Engineer’s original compound photo actually inspected (Christopher Barrett):
https://www.thorntontomasetti.com/sites/default/files/styles/paragraph_slideshow/public/block37_1.jpg?itok=DeFbNJBf
Shows southwestern office’s blue curtain wall/dark broad projecting crown
fascia and roof equipment. That fascia/services remain to author. The site’s
newer hero photograph is Marquee residential tower, not the media office; do
not use its floor rhythm as the office reference. Capture date unspecified.

Committed roof raster has central raised cells up to34m amongst24–31m roof
heights; these alone do not distinguish glass from mechanical/elevator volumes.
Atrium interior photograph confirms glazing, operator floor plans confirm
branching passages, but neither gives an outside roof plan. Obtain overhead
photo/plan evidence before assigning those peaks to a guessed skylight.

Final cache191 native full clipping scans pass104Grid/120original accepted hits,
empty stderr. Two actual High Grid office day/night renders inspected, current
cache loaded, exit0/empty stderr; files chicago_grid-office-{day,night}.png.
Blender regeneration/editor import clean. Controlled regression loads the prior
committed GLB and returns no pane at the new probe, confirming old compressed
spacing fails where the corrected fixture passes. That scratch check exits0/
empty stderr. Current building28/parse results above; last full43suite/menu115
evidence remains at earlier revisions, no new full-suite claim. No export,
new laps/performance/manual-drive/Intel validation. Office fascia/roof services
and atrium geometry still open; next refine the directly photographed fascia
while obtaining outside skylight plan evidence.
