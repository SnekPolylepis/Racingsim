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
