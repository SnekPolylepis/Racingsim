# 100 North LaSalle / Lawyers Building working reference

## Sources inspected on 2026-10-08

- [Council on Vertical Urbanism record](https://www.skyscrapercenter.com/building/100-north-lasalle-street/29256): architectural height 90 m, 25 aboveground floors, construction start 1928/completion 1929, Graven & Mayger with Lieberman & Hein. The mapped 144.5 m height is not used in the draft.
- [National Park Service LaSalle Street Historic District nomination](https://npgallery.nps.gov/GetAsset/d489a6ed-fbcc-41b5-8804-7351b2bbb6a4): PDF page 10, printed page 9, describes the 25-story Gothic Revival building, brick/terra cotta base and crown, continuous narrow piers framing recessed window groups, altered lower three floors with tile, and black granite at the original two-story LaSalle entrance arch. Masonry painted brown except granite; no western annex was built.
- NPS nomination full photograph views inspected: photo 0006/PDF page 82 (March 2012), photo 00020/page 96 (February 2011), photo 00021/page 97 (March 2012), credited to Danielle Euer. These show the brown base, horizontal third-floor band, portal and carved rectangular spandrel reliefs. Photo 00016/page 92 also inspected, naturally rotated in the PDF.
- [Explicitly named Lawyers Building exterior photo, Nathaniel Lindsey via CTBUH](https://images.skyscrapercenter.com/building/lawyers-building_nathaniel-lindsey1.jpg): continuous brown piers, recessed rectangular glazing and raised/fluted Gothic crown. Capture date unknown. The CVU default image filename refers to 2 North LaSalle and was not used as this building's reference.

External photos are references only; none is embedded as a facade texture.

## Draft and recorded checks

Mapped candidate w147095666 retains its exact concave six-vertex L footprint. Proposed origin (-695, 8, 148.95), no yaw. Original city street day/night review visibly showed a generic white block. Candidate CSV Grid distance 9.6 m is a priority estimate, not final mesh clearance.

Original Blender authoring: tools/blender/chicago_lasalle_100.py and authored/lasalle_100.blend. Final working GLB: 66,704 triangles/eight materials. Separate physical glass, sash rails, recessed opaque core, continuous piers, flat roof, provisional raised crown ribs and black granite pointed portal. Architectural tip 90 m; main body 87.5 m; lower three-floor interval 10.8 m is photo-fit, not measured.

The initial close view caught a horizontal band crossing the arch. Final bands stop outside the portal; both corrected entry day/night views inspected. Pier color brought closer to painted brown masonry. Final four front/crown day/night stage views inspected. Blender and headless editor import exited 0; final stage and entry native reviews exited 0, empty stderr, terminal LASALLE100 STAGED REVIEW PASS. Isolated stage lighting is not production night-material or graphics-mode acceptance.

Before native review exited 0/empty stderr, terminal LASALLE100 CITY REVIEW PASS, cache202. Frozen 13.59 ms is not driving performance evidence. Saved before/draft/entry images in ../screenshots/chicago-lasalle100-draft.

## Next work

Refine the connected Gothic crown and carved rectangular lower-floor spandrels using the inspected references. Entrance location, tile joints, storefronts, window/bay proportions, roof equipment and return facades remain provisional. Then integrate through the shared loader, replace the generic footprint once, run geometry/menu/coverage/full clipping checks and inspect production views on both routes.

This is a saved working draft, not installed or complete. Production cache202, Original@v7/Grid@v5 and baseline clips120/104 unchanged. No executable export.

## 2026-10-08 crown/base refinement

Re-inspected full NPS photos82/96 and explicit Lawyers Building CTBUH photo. Added connected solid crown panels and short fluting between raised piers, extended pier tops to contact caps, and framed shallow diamond reliefs at the lower public spandrels. These relief motifs/proportions are photo-fit interpretations, not exact carving reproductions. Corrected the portal's missing third-floor windows: only the documented two-story opening now suppresses regular bays/piers. Final GLB68,972tri/eight materials.

Blender exited0, headless import exited0/empty stderr, final native stagePID157276 and entryPID157440 exited0/empty stderr/terminalPASS. Six actual final front/crown/entry day/night images inspected, saved in chicago-lasalle100-refined. No production integration/cache/routes change or EXE. Next production replacement/geometry-clearance and route review; precise base/entrance/roof/return proportions and fine carving remain open.

## 2026-10-08 working exterior installed

Mapped w147095666 now replaced once by shared LaSalle100 fixture at (-695,8,148.95), eight physical materials/68,972tri. Night glass uses existing shared switching; generic exclusion logged exactly once. Cache203, Original@v7/Grid@v5 retained.

First geometry run failed an incorrect eight-vertex test expectation copied from the material count; corrected to the actual six-vertex footprint. Final six gates223203 allPASS111s: geometry19/menu123/coverage23/fullclip1+1 =167checks plusparse. Actual mapped foundation distance327.05014m Original/9.54773m Grid; whole-city clips120/104 unchanged. Geometry test verifies portal pane is unobstructed, solid87.5m roof, architectural tip90m, physical/no-photo materials and both foundation clearances.

Native productionPID151028 exited0/empty stderr/terminal LASALLE100 CITY REVIEW PASS. Four actual Grid street/crown day/night views inspected; lower crown and occupied-window switching visible. Frozen15.38ms is not driving performance evidence. Evidence chicago-lasalle100-installed. This is an installed working exterior; exact carving, measured base/entrance/proportions/roof/returns and retro graphics modes remain open. No EXE export.
