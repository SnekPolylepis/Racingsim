# Bell and Morton buildings — next paired trackside exteriors

Primary source inspected2026-10-08: National Park Service, West Loop–LaSalle
Street Historic District nomination, PDF pages28–29 (printed26–27):
https://npgallery.nps.gov/GetAsset/d489a6ed-fbcc-41b5-8804-7351b2bbb6a4
The official PDF exceeds the web reader limit; downloaded and extracted locally.
No proposal renderings or real-estate summaries used as architectural authority.

212WestWashington, Bell Building,1912, Holabird & Roche:20storeys, steel frame,
Bedford limestone/brick/terra cotta. L-shaped plan, Washington frontage, extends
north to alley. Three-storey rusticated stone base with banded columns,13-storey
brick shaft, four-storey stone cap with fluted multi-storey pilasters and triglyph
architrave. East-end main entrance has two arches, bracket-supported balconies
and central festoons.1998residential conversion added balconies and replaced
windows/storefronts. A separate six-storey garage adjoins to the west; do not
replace the Bell footprint's L-shaped southern wing with a garage just because
it extends farther west than the northern stem.

208WestWashington, Morton Building,1927, Graham Anderson Probst & White:
21storeys, red brick with stone/terra-cotta detail, Washington and Wells primary
facades. Four-storey base, upper U-shaped shaft/light court above floor4.
Egyptian/classical base pilasters and banded end columns; retained carved cornice
above storefront wraps both frontages. Green terra-cotta shaft spandrel panels
and banding at central/end bays. Attic oculi/wreaths and Egyptian cornice.
1998residential conversion added hung balconies and doors replacing windows.

Mapped city.json: Bell w147095658six-point L footprint x[-872.4,-828.1],
z[108.6,164.8], maximum tag91.5m. Native2m raster dominant roof82m (114cells),
84(57),80(48),83(48),81(35); high maximum is not uniform wall height. Raster
shows tall roofs across the southern L wing, not a low garage replacement.
Proposed local origin(-850.25,8,136.7). Main roof82m provisional; roof services,
precise cornice/cap elevations and maximum-height outliers need visual fitting.

Morton w147095676seven-point footprint x[-829.5,-797.5],z[108.5,164.8],
height tag99.5m. Raster dominant91(80),92(61),84(56),86(52),85(29),80(17),
96(14). Footprint union does not establish the upper light-court geometry.
Both close candidates are8.9m from Grid station7085/7090 in current inventory.

Next: inspect actual facade/crown photographs, build distinct Bell tripartite
facade and recessed double portal in Blender, then Morton light court and green
panels. Preserve mapped foundations and added physical balconies. Integrate and
review native day/night on both layouts, footprint rays and full clip scans.
No model integrated yet, no cache/road/timing change, no app export. Full goal
continues; this reference closes ambiguity about identity, style and roof tags.

## Bell authored draft — Mac2026-10-08

Added `tools/blender/chicago_bell_building.py`, original editable
`tools/blender/authored/bell_building.blend` and `assets/chicago/landmarks/bell_building.glb`.
Nine materials/127,404 triangles. Retains the six-point L foundation;20 storeys
with82m main roof, rusticated stone base, brick shaft, fluted stone crown piers
and triglyph/cornice strips. Physical paired panes/reveals, recessed double
arches, bracket balconies and open iron residential balcony stacks. Generator
asserts finite vertices, envelope, floor height and batched box topology. Ground
stone bands/spandrels and intermediate piers stop before the entrance zone.

Inspected original photograph by Visviva,2020-01-10, CC0:
https://commons.wikimedia.org/wiki/File:212_West_Washington_southeast.jpg .
It shows dark continuous balcony stacks and pale upper piers with brick
spandrels; revised sparse draft balconies and solid stone cap accordingly.
Reference only: no external image embedded in the asset/repository.

Blender4.5.3 regeneration, Godot4.6.2 headless import and two native Metal
standalone daylight/low-light captures exited0 with empty stderr. Images in
`docs/rebuild/screenshots/chicago-bell-draft-mac/` were visually inspected.
These isolated views show the foundation below nominal pavement; they are
not production day/night review or track acceptance. Night emission still
uses draft imported material settings, not the game time-of-day contract.

Remaining: closer photo-fit balcony dimensions/coverage, facade bay counts,
true entrance recess/arch clearance, festoons, carved capitals/crown proportions
and surveyed rooftop services. Integration, material day/night switching,
production views on both layouts, foundation probes and clip scans still pending.
Original@v7/Grid@v5/cache184 unchanged. Morton remains next; full goal active.

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

## Morton authored draft — Mac2026-10-08

Inspected Visviva2020-01-06 original southeast photograph, CC0:
https://commons.wikimedia.org/wiki/File:208_West_Washington_southeast.jpg .
The photograph shows red brick, grouped green vertical/spandrel panels, dark
hung balcony stacks, a raised southern attic with circular ornament and a
recess along the Wells frontage. NPS establishes the U shaft above floor4;
court dimensions/orientation remain photo-fit rather than surveyed.
No reference photograph or third-party mesh embedded/redistributed.

Added original generator tools/blender/chicago_morton_building.py, editable
tools/blender/authored/morton_building.blend and assets/chicago/landmarks/morton_building.glb.
144,500tri/eight materials: retained seven-point mapped foundation, four-storey
stone base, open Wells-side court above17.4m,21level red-brick wings/green panels,
separate physical panes/sashes/sills, dark hung balconies and raised southern
attic with five modeled circular stone surrounds and projecting cornice.
Main roof91.5m/attic cornice99.5m are provisional fits to raster/photograph.
Generator asserts ring orientation, finite vertices, envelope and box topology.

Blender4.5.3 regeneration and Godot4.6.2 import pass. Two isolated native Metal
daylight/low-light views exit0/empty stderr and were visually inspected:
screenshots/chicago-morton-draft-mac/. These show below-pavement foundation
and use draft imported lighting; they do not establish production day/night
acceptance.

Still staged: storefront/entry geometry, precise panel grouping/window bay count,
balcony proportions, carved base capital/cornice relief, attic wreath/Egyptian
profile and roof services need refinement. Court width/depth/wing heights need
roof-reference confirmation. Integration, game material switching, source
production views and both-layout footprint/clip checks remain next.
Cache185/original@v7/Grid@v5 unchanged; no app export; full goal active.

## Morton curved balcony correction — Mac2026-10-08

Inspected original Visviva2020-01-10 street photo, CC0:
https://commons.wikimedia.org/wiki/File:208_West_Washington_south_jpg.jpg .
This closer reference shows two rounded reddish balcony stacks, inset rectangular
stone spandrel panels and fan-like base capital relief. Replaced draft straight
slabs/rails with half-ellipse slab noses, curved physical rails and25 uprights
per balcony. Original stylized fan relief and inset stone panel mouldings added.
166,938tri/eightmaterials, editable Blender/GLB regenerated. Balcony outline
assertions verify25points and2.45m maximum projection. Exact photographed
carving, dimensions and narrower central window/panel rhythm remain photo-fit.

Blender4.5.3 generation, Godot4.6.2 import, isolated daylight/low-light and close
balcony views pass exit0/empty stderr; all three images visually inspected in
chicago-morton-draft-mac. Ground entry is not sufficiently established by this
upward photograph. Further street-level reference/entrance authoring remains
before integration/material-contract and production track validation. The
reference changed the next action from integrating straight balconies to
correcting their photographed shape. Cache185/road versions unchanged.

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
