# Chicago source and verification notes

2026-09-30, `rb/monaco-formula-cars`. Reference evidence is separate from
completed visual verification in `CHICAGO-DONE.md`.

## Measured geometry

- USGS 3DEP Cook County 2017 acquisition, LAS 2019 publication:
  https://s3-us-west-2.amazonaws.com/usgs-lidar-public/USGS_LPC_IL_4County_Cook_2017_LAS_2019/ept.json
  `fetch_lidar.py` reads public Entwine tiles and produces one-metre DSM/DTM.
  The full-city request covers latitude 41.87177718289615–41.90905080848005,
  longitude -87.6490282886797–-87.59876760801352. Acquisition date matters:
  buildings constructed later need OSM parts or other dated source geometry.
  First-surface DSM includes vegetation; it is not automatically a surveyed roof.

Full-city acquisition completed: 382,913,295 non-noise points, 4,166 × 4,151
one-metre cells. Compressed source grid is 31,387,163 bytes, retained locally
under the ignored raw-source folder; `city.json` contains the derived roofs.
Regeneration produces 3,962 measured building entries plus four facade bands,
zero `u:1` flags, and retained OSM IDs. `lc` records each footprint's fraction
of two-metre roof cells with actual returns before median gap filling.
Four footprints need better evidence: `w1175801212` (60.42%), `w1175801219`
(75%), `w1361811949` (58.64%), `w1417040524` (8.33%, 0.5 m apparent height).
The last footprint is not proved to be a building roof by this acquisition.
Zero placeholder flags does not establish complete accurate roof coverage.
`test_lidar_massing.py` verifies measured two-height setbacks, coverage reporting
and rejection of a completely unmeasured footprint; passed on 2026-09-30.

## Lower Wacker

Additional primary reference: Brad Bacilek / CDOT presentation hosted by MWRD,
22 February 2013:
https://mwrd.org/sites/default/files/documents/seminar_series-02-22-2013_Wacker_Drive_Presentation.pdf
Pages 11–12 were rendered and inspected. They show Road E / Congress interchange
ramps with a 16 ft lane and unequal shoulders, including jet fans; these drawings
must not be applied to every two-lane Wacker bay. Retained OSM way 253716333 and
its continuation ways locate the southbound carriageway west of the old authored
midpoint. Full geographic section alignment remains open.

- Benesch / Chicago DOT engineers, *Wacker Drive*, ASPIRE Fall 2012:
  https://www.aspirebridge.com/magazine/2012Fall/WackerDrive.pdf
  Use the cross-sections and construction photographs to validate deck,
  clearance, girder and column layout.
- Existing race-route connectors are authored circuit geometry, as stated in
  `trackgen/data/chicago/route.json`; they must not be described as a survey.

Inspected the engineering PDF's first-page cross-section rendered with Poppler.
It shows 13 ft 9 in clearance (4.191 m), a 140 ft total viaduct width (42.672 m),
26 ft through-lane bays, and six column lines. The article specifies three-foot
round columns at approximately 32-foot longitudinal centres and concrete ribs.
The north–south model uses 0.9144 m diameter columns sampled at 9.7536 m along
the route. Six transverse axes were digitized from that drawing relative to the
southbound through-lane centre; this is a typical section, not a survey of every
column's geographic position. The 13-inch slab and two-inch overlay place the
lower road at world y=3.4288 beneath the upper road at y=8, giving 4.191 m clear
space at the lane centre. Four-foot-wide ribs have two-foot total depth; the
42.672 m side-bay floor follows the full section. The racing through bay is
7.9248 m wide. East–west variable bay widths, service-lane markings, docks and
intersection-specific layout still require source matching.
Ceiling/ribs reuse the existing CC0 Poly Haven damaged concrete maps, with
world-space three-metre triplanar tiling. Day/night `chi-lower-columns` captures
were inspected from 1.4 m driver-eye camera positions.

Lighting follow-up: `TrackLights.place` rejects masts beside another section of
road, which includes the overlapping upper/lower decks. Covered-road ceiling
placements now have a separate walk, with one shared list for fixture geometry,
halos, road streaks and actual pooled light positions. Generic street-lamp masts
are omitted for these placements. `chi-lower-lights2` south/west night images
were inspected; amber light reaches the concrete and wet road. Fixture height
now sits against the slab soffit. Fixture dimensions and longitudinal placements
remain authored and require reference matching.

- AlphaBeta135, *Lower Wacker Dr south at Randolph St exit*, 15 August 2024,
  CC BY 4.0:
  https://commons.wikimedia.org/wiki/File:Lower_Wacker_Dr_south_at_Randolph_St_exit_-_Chicago,_IL_-_August_2024.jpg
  Inspected the original photo in the browser. It shows a two-lane through road,
  dashed centre divider, concrete separation from an open service bay, round
  columns and compact ceiling fixtures. No catch fence or red/white racing kerb
  appears there. Chicago omits those two racing decorations on the north–south
  lower section; fixture shape and the photographed Randolph exit sign remain
  open items. Photo consulted as reference only, not redistributed as a texture.

- bradhoc, *Pillar on Lower Wacker*, 4 January 2012, CC BY 2.0:
  https://commons.wikimedia.org/wiki/File:Pillar_on_Lower_Wacker_(6639142183).jpg
  Original inspected in browser. Its east-end camera location (41.887901,
  -87.618613) and visible steel column/girder work need a separate structural
  source pass; do not infer the whole drive uses that photographed section.

## Buildings newer than the roof survey

- Related Midwest, exterior/crown completion announcement, 21 July 2026:
  https://www.related.com/press-releases/2026-07-21/related-midwest-completes-crown-installation-400-lake-shore-drive
  400 Lake Shore North Tower's exterior/crown is complete, 857 ft (261.2 m),
  72 stories, glass curtain wall and tiered setbacks. OSM footprint w1361811949
  therefore explicitly excludes the 2017 roof survey. `lr` records that reason
  in generated data; no old-surface `L` or `lc` measurement is claimed there.
  The current footprint extrusion preserves cited height/material only; tiered
  geometry and crown remain open, not invented from the announcement.
- Navy Pier's marina description confirms a two-storey amenity building:
  https://navypier.org/navy-pier-marina/
  Its 2025 opening postdates the survey; source geometry/height is still needed.
The fixed-view capture tool now updates the normal light pool at each camera
position; earlier frozen-camera images did not demonstrate local pooled lighting.

## Pritzker Pavilion

- Fabricator Zahner:
  https://azahner.com/projects/pritzker-pavilion/
  Documents 24 column covers, six feet in diameter, heights ranging from
  twelve to over twenty-four feet, heavy-gauge stainless steel. This supports
  column material and diameter, but does not establish individual coordinates.
  The retained `downtown-buildings.json` contains all 24 pillar footprints,
  ways 1278678874–1278678897. Their ring centres now locate the concrete cores.
  PBC records six-foot diameter and fifteen-foot concrete height (1.8288 m
  and 4.572 m). These are core dimensions, not the variable stainless cover
  heights. Covers and real pipe-to-column connections remain unfinished.
  Reference photographs are copyrighted; viewing them does not grant an asset licence.
- Public Building Commission:
  https://www.pbcchicago.com/projects/jay-pritzker-pavilion/
- Steel fabrication reference:
  https://www.cmrp.com/uploads/millennium_tour_brochure_lores.pdf
  Viewed the fabrication brochure's pavilion spread: round pipes in 12–20-inch
  sizes, curved arches with changing radii at joints. No reference-photo pixels
  are distributed. The current pipe mesh uses a published 12-inch diameter as
  an explicitly recorded proxy, not a claim that every member has that size.
- Focused USGS Cook 2017 survey, generated 2026-09-30:
  `python trackgen/data/chicago/fetch_lidar.py pavilion 41.88165 41.88391 -87.62272 -87.62102`
  Acquired 75 tiles / 1,554,915 non-noise points, 143 × 253 one-metre grid.
  Median ground over the measured Great Lawn patch is 186.860 m in the survey
  datum. Using the full-city 180.750 m median previously raised the steel about
  6.11 m above the flattened game lawn. Pavilion steel now uses its local datum.
  The initial one-metre pass gave 2,574 centreline nodes and 2,527 links;
  native cylinders replaced the dense neighbour lattice. Its close-up exposed
  severe raster bends and disconnected returns.
  The diagnostic classes-1/6/17 surface excludes some actual trellis returns;
  therefore the centreline uses the full DSM with published height bounds,
  rather than assuming those survey classes distinguish steel from vegetation.
  Architect gallery drawing access required an account; no access restriction
  was bypassed. Signed-in Sketchfab downloadable search for `pritzker pavilion`
  returned no model. Broad pavilion acceptance remains open.
  A second pass uses the same points at quarter-metre resolution:
  `python trackgen/data/chicago/fetch_lidar.py pavilion-fine 41.88165 41.88391 -87.62272 -87.62102 .25`
  The 566 × 1,008 grid supplies the trellis separately; building roofs retain
  their one-metre grid indexing. One-cell gaps are closed, unsupported leaf
  paths/components are omitted, and sufficiently long chains are fitted to a
  one-metre window of measured samples. The current result has 8,759 nodes and
  8,672 links. Inspected `chi-supported-pipes-pritzker-day.png` and the joint
  close-up: main arches are smoother and many hanging fragments disappear.
  Support proximity and the existing stage boundary are inference limits;
  tree returns near supports, short hooks, cover gaps, actual diameters and
  occluded member/joint geometry remain unresolved. This is not a surveyed
  fabrication model or proof that every remaining segment is structural steel.

## Wrigley clock faces

- BLDG.51 museum's salvaged-building record:
  https://bldg51.com/2017/06/07/original-cream-colored-wrigley-building-ornamental-terra-cotta-fragment-joins-bldg-51-museum-collection/
  Records four dials with diameter 19 feet 7 inches. Generated dials use
  5.969 metres; their current attachment follows the existing tower walls.
  Static displayed time is 10:10, not a claim about a historical photograph.
- Ken Lund's 2013 building photograph and metadata:
  https://commons.wikimedia.org/wiki/File:Wrigley_Building,_Chicago,_Illinois_(9179449469).jpg
  Reference only; no photograph pixels have been incorporated into assets.
  The photograph is CC BY-SA 2.0 if subsequently used as an asset.

## Baseline findings requiring fixes

The `chi-goal-baseline-*` images are in the game's user-data folder.
Inspected Michigan north day, river night, Pritzker day and Wrigley day.
The pavilion trellis lacks supports and its dense cell-neighbour links do not
prove the real pipe layout. The Wrigley view missed its clock; the capture tool
now points at the generated tower and provides a separate clock close-up.
The previous capture's throttle assignment was overwritten by the normal
controls update. Its stationary screenshots did not demonstrate driving.
The revised tool injects a held configured throttle key and fails below five
metres of displacement; car and physics source remain untouched.

## Actual-course building inventory and clearance (2026-09-30)

`chi_shot.gd -- --tag=course-clearance --route-survey` captures forward views
at 1.4 m eye height every 200 m and writes actual BotLine curve samples every
5 m to `user://chi-course-clearance-route.json`. `--assemble-survey` with the
same tag assembles existing day/night captures into six-column atlases; rows
advance 1,200 m. Run `python trackgen/data/chicago/inventory_route.py <survey-json>`
to regenerate `route-inventory.csv`, including OSM source links, tags, measured
coverage, direct landmark provenance and actual renderer omissions.

All 3,962 non-band entries remain in the catalog. 928 are near-route candidates
(402.5 m cutoff allows half the 5 m sampling interval); 547 at least 80 m tall
are skyline candidates, not a visibility determination. Near-route entries
have 90 material tags, 48 colour tags and 24 direct cited landmark overrides.
The corrected renderer tests actual route points inside a footprint, rather
than its own centroid, and removes the additional six-metre building margin.
34 previously omitted footprints return; 13 near-route clearance omissions and
three separate-landmark omissions still require alignment/part review.

Inspected all 82 views in day/night atlases and individual 800/4,200/7,600 m
views. The restored Art Institute wing and Wacker neighbours fill missing
masses; generic facades and unsourced/floating cornices/roof props remain.
The 8,160.75 m course survey exited 0, empty stderr, 25.39 m drive. A bounded
headless clearance check passed nearby-preservation, enclosing-footprint and
edge-clearance cases. No whole-city facade acceptance follows from this pass.

Random Downtown MegaKit shopfront/cornice assignments and roof clutter are now
disabled in the city builder: their hash selection had no building provenance,
and roof placement used maximum building height above lower measured wings.
No asset files were deleted. Inspected sourced-details 800/7,600 m daylight
captures; unsourced floating additions disappear. The remaining facade and
real ground-floor geometry tasks are still open. Capture exited 0, stderr
empty, 23.45 m drive; day/night captures exist for both selected stations.
