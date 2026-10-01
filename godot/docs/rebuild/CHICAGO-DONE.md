# Chicago completion checklist

Owner goal, 2026-09-30. Branch: `rb/monaco-formula-cars`.
Check an item only after inspecting an in-game screenshot proving it. Record the
image path and the source evidence beside each completed item. Partial coverage
does not prove the whole route. Defaults: keep map-derived details when no source
exists; retain fictional circuit connectors explicitly labelled in the route docs.
No Monza, car or physics changes. Heavy gates are skipped by owner direction.

## Building massing

- [ ] Inventory every route-visible building within approximately 400 m and skyline/landmark sightlines from Lake Shore Drive and the river.
- [ ] Fetch missing USGS LiDAR coverage for that full inventory.
- [ ] Apply measured roof shape and OSM building parts without overlapping parent/part geometry.
- [ ] Resolve every `u:1` two-storey placeholder from source data; list any still without usable evidence.
- [ ] Verify sourced crowns and setbacks; no invented height or roof feature.
- [ ] Inspect driver and skyline screenshots along the entire route; no remaining generic flat-box substitutions.

## Lower Wacker

- [x] Replace north–south square support posts with the sourced three-foot round section and approximately 32-foot spacing; inspected `chi-lower-columns-lower-south-day.png` and night counterpart. Heights, transverse placement and full service-lane section remain unverified below.

- [ ] Verify double-deck tunnel dimensions and alignment from cited real-world references.
- [ ] Verify structural columns, beams and ceilings from driver view.
- [ ] Verify sodium fixtures and lighting by day/night screenshots.
- [ ] Verify ramps and portals; distinguish real geometry from fictional race connectors.
- [ ] Verify sourced signage and placements.
- [ ] Verify wet concrete, grime and road/ceiling/wall material scale from driver view.

## Facades and storefronts

- [ ] Inventory route-facing storefronts/buildings along Wacker, State, Wabash, Lake Shore Drive and the Loop.
- [ ] Extend `landmarks.json` with cited source per building and supported materials/colours.
- [ ] Apply real business signs from `signs.json`; verify names and placement.
- [ ] Acquire licensed rectified Commons photos for key facades and record attribution.
- [ ] Verify facade bands, ground floors, windows and entrances against sourced counterparts.
- [ ] Inspect the full route in screenshots; no unverified coverage claim.

## Loose ends and screenshot findings

- [ ] Verify moored boats, mooring placement and waterline contact.
- [ ] Verify Pritzker pylons and pavilion structure.
- [ ] Verify road/river bridge structures and BP Bridge geometry.
- [ ] Verify L stations and track/platform/support alignment.
- [ ] Verify Wrigley clock faces and tower placement.
- [ ] Find and replace placeholder textures using licensed, sourced assets.
- [ ] Inspect for floating/misplaced objects, overlaps, missing surfaces and clipping; add individual findings below.

## Resource workflow and acceptance

- [ ] Inventory suitable assets in Desktop asset folders before acquiring new models/textures; preserve those folders.
- [ ] Follow local assets → signed-in Sketchfab CC0/CC-BY → Poly Haven/ambientCG/Commons → Blender order; record licence/source for every acquired asset.
- [x] Game launches, Chicago loads, and a drive completes without crashing; inspected `chi-drive-check-day.png` and night capture (user-data folder). Windowed capture exited 0, displacement 22.63 m, final speed 17.49 m/s. This is a short launch/drive check, not whole-route acceptance.
- [ ] Commit working milestones and push this branch periodically.
- [ ] Re-export and verify the final Windows executable after Chicago work.

## Final audit (perform after visual completion)

- [ ] Write `godot/docs/AUDIT-2026-09-30.md`: temp/debug files, UID orphans, duplicates, unused assets/source packs, stale worktrees, ignores, sizes/LFS, bake time, draw calls and texture sizes.
- [ ] Report the proposed deletion list and request owner approval before deleting; preserve all saves and Desktop assets and every unproven candidate.
- [ ] Apply only proved-safe, authorized cleanup/optimisations and verify the game again.
- [ ] Re-read this checklist and audit every requirement against current screenshots and source evidence before declaring completion.

## Evidence and newly discovered items

2026-09-30: short launch/drive capture verified; all city-wide visual requirements remain open.

Full-city USGS grid acquired and applied on 2026-09-30. Current generated data:
3,962 LiDAR buildings, four facade bands, zero `u:1` flags. Inspected
`chi-lidar-full-mich-aerial-day.png`, `chi-lidar-full-mich-north-day.png` and
`chi-lidar-full-river-air-day.png`; the river aerial camera is inside/behind a
building and needs relocation. Windowed capture exited 0. The broad massing
items remain open: four low-return roofs require source review, procedural
landmarks still bypass measured geometry, and the entire route is not inspected.

- [ ] Resolve low-return LiDAR footprints `w1175801212`, `w1175801219`, `w1361811949`, `w1417040524`; use `lc` in the generated data to distinguish measured cells from gap filling.
- [ ] Replace 400 Lake Shore's footprint extrusion with its actual tiered/crowned form. Related's July 2026 completion record gives 857 ft total height; the 2017 LiDAR predates construction and is now explicitly excluded for this building. Navy Pier's two-storey marina building also postdates that acquisition; its measured geometry remains unresolved.
- [x] Prevent 2017 roof returns from flattening the 2025 Navy Pier marina amenities building. Inspected `chi-marina-height-marina-boathouse-{day,night}.png` and south daylight: w1417040524 now uses the approved A-1 actual height of 21.97 feet (6.6965 m), with the older survey explicitly excluded. This verifies height restoration only; the generic extrusion is not accepted as real massing.
- [ ] Model the marina amenities building from approved sheets A-2/A-3/A-4: container wings, open breezeway, second-floor decks, exterior stairs, sloped roof and cladding/window layout. Reconcile approved plans with installed-building references and mapped footprint; preserve sourced heights. City PD527 PDF pages 3–6 provide the dimensions; builder confirms May 2025 installation.
- [ ] Correct marina pier/deck/shoreline surfaces and supports. `chi-marina-height-marina-boathouse-south-day.png` exposes lawn on the pier and absent amenities-building deck/stairs; north view exposes generic docking geometry. These need real mapped/plan-derived surfaces and waterline verification.
- [x] Prevent the old roof survey from flattening the cited 2026 400 Lake Shore tower to 4.5 m. Inspected `chi-400-roof-400-lake-shore-day.png`; data has cited 261.2 m height and an explicit exclusion reason. Actual tiered massing remains open above; the screenshot shows that remaining extrusion plainly.
- [x] Relocate the river aerial camera now occluded by newly restored building geometry. The new position lies inside mapped river water and no building footprint; inspected `chi-supported-pipes-river-air-day.png` and night counterpart. River and skyline are visible; facade and landmark accuracy remain open.
- [x] Rebuild the published north–south typical structural section: 4.191 m lane-centre clearance, six column/rib axes, 42.672 m slab/side-bay width and 7.9248 m racing bay. Inspected `chi-wacker-section3-lower-south-day.png` and driving night capture; the bounded geometry check measured 404 ceiling rays with zero clearance error. This proves the modelled typical section, not every intersection or service-lane detail.
- [x] Remove the north–south lower road's red/white racing kerbs and covered-road catch fences, and put the two-lane divider inside the narrowed road. Inspected `chi-wacker-section3-lower-south-day.png` against AlphaBeta135's 2024 Randolph exit photo; service bays are visible.
- [ ] Match east–west variable sections and intersection-specific column/deck layout; replace authored fixture dimensions and source the side-bay lanes/loading docks.
- [ ] Add the photographed Randolph exit sign at its verified position and inspect it in-game.
- [ ] Reconcile the typical north–south section with the actual mapped southbound carriageway centreline and service bays; the authored route previously followed the middle of the paired carriageways.
- [ ] Source east-end bridge/steelwork separately: bradhoc's 2012 east-end pillar photograph shows steel girders and steel columns, rather than the rebuilt north–south concrete section.
- [x] Align the actual Lower Wacker pooled light positions with ceiling fixtures; inspected `chi-lower-lights2-lower-{south,west}-night.png`. Housing, halos and pool positions share one covered-road placement list; no shortened mast is drawn beneath the deck. Final real-world fixture dimensions/clearance remain part of the open section verification.

- [x] Replace the Wrigley clock's blank square with sourced-diameter circular faces, numerals and hands on all four sides. Inspected `chi-clock-pass2-wrigley-clock-day.png`, `chi-clock-sides-wrigley-clock-{west,east,north}-day.png`, and the initial day/night dial views. Subsequent pass corrected stretched hands. Tower massing, clock surround, final placement and reference-faithful ornament remain under the open Wrigley verification item.
- [ ] Correct the dense, unsupported Pritzker trellis visible in `chi-goal-baseline-pritzker-day.png`, using source geometry for pipes and column coordinates.
- [x] Add the 24 OSM-located Pritzker concrete cores at PBC's published diameter/height; inspected `chi-pylon-cores-pritzker-day.png` and `chi-pylon-cores-pritzker-pylons-day.png`. This verifies core placement only: variable stainless covers and connections to the raster trellis remain open.
- [ ] Replace Pritzker raster neighbour links with actual pipe geometry and connect them through sourced variable-height column covers. The current screenshot still shows a gap above the concrete cores.
- [x] Correct Pritzker steel's local height datum and replace the dense raster-neighbour lattice with traced round segments. Inspected `chi-measured-pipes-pritzker-day.png` and the pylon close-up: measured lattice is distinct and lower, rather than a floating dense canopy. This is an intermediate one-metre inference, not full pavilion acceptance.
- [ ] Resolve Pritzker raster bends, stray/disconnected returns, missing/occluded pipes, per-member diameters and variable column-cover joints; `chi-measured-pipes-pritzker-day.png` shows these remaining limitations.
- [x] Replace the one-metre trellis sampling with quarter-metre data and suppress unanchored fragments/raster stair steps on long chains. Inspected `chi-supported-pipes-pritzker-day.png` and `chi-supported-pipes-pritzker-joint-day.png`; main arches are visibly smoother. Short hooks, support gaps, tree-return ambiguity and full geometry/material acceptance remain open above.

- [x] Correct false building clearance exclusions caused by testing a building centroid inside its own footprint. Inspected `chi-course-clearance-route-00800m-day.png`, `route-04200m-day.png`, `route-07600m-day.png` and both complete course atlases: 34 previously omitted footprints restored, including the Art Institute wing. Actual route containment/edge clearance still excludes intersecting footprints.
- [x] Capture a forward driver-height overview every 200 m around the actual 8,160.75 m course in daylight and at night (41 views per phase). Inspected `chi-course-clearance-route-overview-{day,night}.png`. This is sampling evidence, not acceptance of all facades or lateral sightlines.
- [ ] Reconcile the 13 remaining near-route clearance omissions and three separate-landmark omissions with real route alignment/building parts; preserve genuine road clearance.
- [ ] Replace hash-generated storefront/cornice and roof clutter with sourced geometry. Survey images show unsupported/floating details over stepped LiDAR roofs; retain source assets pending the final audit.

Route inventory now records all 3,962 non-band building entries, including 928
within approximately 400 m and 547 tall skyline candidates. Candidates are not
proof of visibility. Near-route records contain 90 OSM material tags, 48 colour
tags and 24 entries with direct cited landmark overrides. Zero unresolved flags
is a data result, not full visual acceptance. Current windowed survey exited 0,
with empty stderr and 25.39 m driven; broad building/facade items stay open.

- [x] Disable hash-selected generic shopfront/cornice and roof-clutter placement, retaining all source assets for final audit. Inspected `chi-sourced-details-route-00800m-day.png` and `route-07600m-day.png`: the floating trim/props are absent. Replacement sourced ground-floor detailing remains open; this does not accept generic facade shaders.

- [x] Replace default masonry with cited glass material on 191/155 North Wacker and 111/71 South Wacker, terra cotta on Reliance/35 East Wacker, and brick on Monadnock. Inspected `chi-wacker-materials-wacker-{191,155,111}-day.png`, Reliance, `chi-wacker-materials2-{wacker-35,monadnock}-day.png` and `chi-wacker-materials3-wacker-71-day.png`; source assignments only, not complete facade acceptance.
- [ ] Complete these eight buildings' actual window proportions, podiums, entrances, 191 Wacker lantern, 155 Wacker arcade, 111 Wacker mullions, Reliance Chicago windows, Monadnock oriels and terra-cotta ornament; replace shared facade-grid substitutions with reference-faithful details.
- [ ] Review overly bright repeated night windows and LiDAR cell seams/texture moire seen in the Wacker close-ups; preserve sourced material/colour distinctions.

Eight new material provenance records raise direct cited near-route coverage
from 24 to 32 entries, still far below 928 candidates. No broad facade item
is checked by this material pass.

- [x] Preserve source RGB facade colours beyond the old six-level palette and stop replacing tagged glass with a uniform blue pane. Inspected `chi-source-colour-wacker-333-day.png`, `wacker-35-day.png`, `reliance-day.png`, plus 333 night and untagged 155/Monadnock daylight. Source colour distinctions now survive; reference-faithful windows, ornament, calibrated photographic colour and ground floors remain open.

- [ ] Correct existing photo-panel orientation, width/height attachment and LiDAR wall overlap. `chi-photo-check-rx-day.png` shows reversed lettering on the neighbouring photographed facade; CAA/University Club panels cover only strips above generic walls. Verify `ChicagoCrowns.photo_facade` left/right edge orientation against actual outward normals before changing geometry.
- [x] Move Symphony detail camera away from trees and onto its mapped facade centre; inspected `chi-photo-letters-sym-day.png` and `chi-photo-footprint-sym-day.png`. Camera visibility only, not full building acceptance.


- [x] Correct shared photo-panel left/right orientation for exterior viewing. Inspected readable Symphony lettering in `chi-photo-letters-sym-sign-day.png` and the street-height `chi-photo-footprint-sym-day.png`; bounded geometry check covers four directions and both footprint windings. The banner is historical 2011/12 content in the credited source photo, not a current programme claim.
- [x] Clip the five existing photographed buildings' LiDAR cells to their actual OSM footprints and attach panels to the median measured street-front roof height. Inspected `chi-photo-footprint-{sym,caa,uc,rx}-day.png` and Symphony night: photographed masonry/ornament is no longer buried inside generic raster walls. Retains all measured roof levels, including rear steps; does not accept every roof return as correct.
- [ ] Reconcile photo crop fractions, width/aspect and ground-floor coverage with source photographs. UC/Railway Exchange photos omit lower floors; screenshots still show generic walls beneath them. CAA upper cornice needs a complete framing view; Cultural Center also needs a fresh inspection.
- [ ] Resolve photographed transient people, vehicles, vegetation and historical banners, and add reference-faithful nighttime treatment; these existing photos are intermediate licensed facade coverage, not final material acceptance.


- [x] Replace University Club's cropped upper-wall panel with licensed 2018 coverage down to its entrance. Inspected `chi-photo-ground-mips-uc-ground-{day,night}.png` and `chi-photo-ground-uc-full-day.png`: lower windows, arch and door reach street level without a generic lower-floor band. Only entrance coverage is accepted; the photographed foliage, historic shop tenancy, gable and dimensional fidelity remain open.
- [x] Inspect CAA's full photographed cornice-to-ground framing in `chi-photo-ground-caa-full-day.png`. This verifies panel visibility, not the raster roof returns or adjacent building architecture.
- [ ] Replace generic night-only business neon/font/colour and hash-selected sign heights with source-faithful sign geometry and placement. UC night screenshot exposes these unsupported appearance choices. OSM names/positions are evidence of mapped businesses, not evidence that their signs glow in the generated colours. Amorino's official listing confirms 38 S Michigan; historical photographic shop labels also require reconciliation.

- [x] Disable unsupported category-coloured neon labels and hash-selected sign heights; retain mapped business records and old assets for the final audit. Inspected `chi-theatre-photo-uc-ground-night.png`: generated Amorino/Bye Bye labels and coloured bars are absent; sourced photo lettering remains. This does not complete real business-sign coverage.
- [x] Attach licensed Chicago Theatre architectural facade coverage to its actual State Street footprint edge. Inspected `chi-theatre-framing-theatre-full-{day,night}.png`: the arch, ornament and entrance appear on OSM w124873919 edge 2, rather than its longer recessed auditorium wall. Projecting signs and source artifacts remain open below.
- [ ] Give Chicago Theatre its actual projecting blade and marquee geometry, readable complete lettering and sourced night lighting; the current flat photograph clips the left of CHICAGO, includes 2009 programme listings/scaffolding/people, and cannot represent sign depth. Resolve its roof returns and the adjacent Page Brothers facade separately.

- [x] Add reference-photo coverage to Page Brothers' mapped State Street west wall. Inspected `chi-page-facade-page-{state,ground}-day.png` and `chi-page-lake-page-state-night.png`: actual window bays, cornice and ground-floor openings replace the uniform grid on that face. Reuses the licensed 2009 theatre photo; this is architectural coverage only.
- [ ] Complete Page Brothers' distinct Lake Street cast-iron front, sourced cornice/window depth, roof details and night treatment. City landmark record distinguishes the 1902 west brick facade from the north iron front. Corrected Lake Street capture `chi-page-lake-page-lake-day.png` still shows a generic facade; no completion claim. Resolve photographic lamps, car/people, historic shop content and theatre-sign overlap on the west panel.

Final Page Brothers confirmation: inspected `chi-page-final-page-state-{day,night}.png` and `chi-page-final-page-lake-day.png`. Only west architectural photo coverage is accepted; north iron front and all listed artifacts remain open.

- [x] Replace the marina single extrusion with approved-plan container wings, the 12.5-foot ground breezeway, upper deck and west sloping canopy. Inspected `chi-marina-plan-final-marina-breezeway-day.png`, `marina-plan-air-day.png` and north night. A-2/A-3 provide 8-foot widths and 20/40-foot lengths; A-4 vertical proportions are traced against A-1 total height, and A-3 labels the roof 2:12. This verifies partial plan-derived massing only, not installed architecture.
- [ ] Reconcile marina plan massing with installed geometry and finish its sourced corrugated-metal/wood walls, openings, container doors, stairs, railings and structural supports. Current shared stone/window shader is visibly wrong; partial canopy tracing and OSM-centred registration require as-built comparison. Ground deck/pier and waterline remain open above.

- [x] Stop rendering closed OSM pier areas as thick outline bars; render their mapped deck polygons and omit fully covered footway centre lines. Inspected `chi-marina-mapped-parks-marina-plan-air-day.png` and breezeway night. Seventy-one area records propagated from the staged harbor extract; this does not verify all 71 visually. Existing vertical envelope and default materials remain unaccepted.
- [x] Remove invented 150-metre lake-distance lawn and stop 20-metre shore tiles spilling into mapped water. Inspected `chi-marina-mapped-parks-marina-plan-air-day.png` and `marina-breezeway-night.png`: the marina deck has no lawn. Imported missing Grant Park relation 19511979 (eighteen clipped outer rings); inspected `harbor-day.png`, `lake-lsd-day.png` and `park-air-day.png`, confirming mapped park greenery remains. Full shoreline/park surfaces and grades remain unaccepted.
- [ ] Replace marina wood-tagged dock default concrete material with a suitable sourced wood surface; source floating/fixed dock freeboard, thickness and supports. Pier metadata now preserves IDs, area, surface and floating tags. Existing line-width defaults are still unverified.
- [ ] Correct park path batching: current path vertices are appended after flat chunks commit, so native meshes omit those paths. Reconcile the new Grant Park boundaries with source footpaths, real widths and paved areas; verify coastal ground clipping beyond these sample views.

- [x] Emit mapped park paths before flat chunk commit and lift their rendering layer above park polygons. Inspected `chi-mapped-paths-final-lakefront-path-air-day.png`, `harbor-day.png` and `park-air-night.png`: Lakefront Trail and inland/park walkways now appear. 1,367 source records include all 920 previous geometries and 447 selected by added mapped park boundaries. OSM width/surface tags preserved, with explicit unverified default-width provenance. This closes the batching/burial defect only.
- [ ] Complete park path joins, route/water clipping, terrain grade, actual materials and 1,350 unverified default widths. Resolve path/tree overlaps and coarse centre-tested park edges/grey triangular gaps visible in `chi-mapped-paths-final-lakefront-path-air-day.png`. Full park surfaces remain unaccepted.

- [x] Replace centre-tested grass tiles with intersections against actual crossed-park polygons, and retain land corners of shore tiles whose centres are water. Inspected `chi-park-boundaries-lakefront-path-air-day.png`: grey triangular gaps beside Lakefront Trail are gone; `harbor-day.png`, `marina-plan-air-day.png` and `park-air-night.png` confirm sampled park/water/deck distinctions remain. This verifies sampled boundary rendering, not surveyed terrain, every shoreline segment or final park materials.
