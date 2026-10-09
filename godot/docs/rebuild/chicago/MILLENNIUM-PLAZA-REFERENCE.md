# Millennium Park Plaza / Doral Plaza reference

2026-10-09. Next remaining close trackside building; mapped `w127107026` has no matching authored exterior or shared fixture. Production remains unchanged at cache206.

Mapped footprint `[[30.2,-95.3],[32.2,-5.4],[30.2,-3.9],[13.1,-3.5],[11.2,-5.7],[10.0,-94.8]]`, mapped height126.5m, stone. Proposed model origin `(21.1,8,-49.4)`. Preserve the exact foundation and measure both route clearances before installation.

## Primary references actually inspected

[Council on Vertical Urbanism record](https://www.skyscrapercenter.com/building/millennium-park-plaza/10316): architectural/tip121.9m/400ft,40floors, completed1982, residential/office, concrete, aliasDoralPlaza,155NorthMichigan; architectReinheimer&Associates. This supports replacing the mapped126.5m envelope; it does not establish individual floor intervals or rooftop dome dimensions.

[Property website](https://www.millenniumparkplaza.com/) lists151NorthMichigan, a38th-floor roof deck and indoor pool. Actual aerial hero video inspected: pale narrow end wall with vertical window strips, chamfered corners and a ribbed round/conical glass pool dome. Observed video URL `https://www.millenniumparkplaza.com/assets/images/mpp_cover.mp4`; no video copied into game assets. Background2.jpg is a lobby interior, not an exterior reference.

[Property amenities](https://www.millenniumparkplaza.com/amenities/) describes a glass-domed heated indoor pool. Actual [roof deck photograph](https://www.millenniumparkplaza.com/assets/images/9.jpg) inspected: brown paver terrace, dark vertical-baluster railing, low conical dark-glass dome with pale radial ribs and small central cap. Adjacent tan wall has narrow vertical window strips with light fluted metal spandrels. Exact dome/deck elevations, orientation, radius and footprint remain unmeasured.

[UIC C.William Brubaker Collection](https://collections.carli.illinois.edu/digital/collection/uic_bru/id/376/) actually read and full photograph inspected. Metadata dates the construction view1980, looking northeast from south of Randolph; Reinheimer&Associates credited. The original building is a long tower slab, with pale continuous piers and narrow dark residential window strips above a distinct darker ribbed office base, broad recessed glazed short-end base and open ground arcade. This supports a full-length tower rather than treating most of the mapped ring as a low annex. Original office/base appearance is historical evidence; current entrance/base renovation still needs verification. Collection permits noncommercial use only; no photograph copied into distributable assets.

Secondary reports about a2023 three-story southern addition were encountered in search results; its relationship to this mapped ring and present architecture has not been verified from a primary project source. Do not merge that addition into the tower based on search snippets.

## Native baseline status

First source review PID72604 timed out at180s. Output contained only engine/Vulkan startup and stderr was empty; no terminalPASS or inspected baseline captures. Retry56844 also stalled before the first post-startup review message and was explicitly stopped, exit-1. Neither is a pass.

Startup tracing with `-- --v2-flow-test --mute-audio` reached scene instantiation/readiness and completed: PID56764exit0, empty stderr, terminalMILLENNIUM CITY REVIEW PASS, Gridcache206 saved. This existing test mode bypasses wheel hardware and uses native-tests settings; no saved owner controls changed. Hardware startup is a suspected cause of the earlier stalls, not yet a proven hardware defect.

Actual streetday/night and crownday captures inspected and saved in `../screenshots/chicago-millennium-before`: generic uniform windows and rooftop boxes lack the distinct office/residential split and glass pool dome. Street camera(-10,12,25), aim(21.1,60,-49.4); crown camera(-30,140,30), aim(21.1,118,-49.4). Upper street view is cropped; separate roof view used. Frozen13.97075ms is not driving performance evidence. No executable exported.

Additional actual property hero frame shows four narrow short-end window strips, pale fluted spandrels, chamfered end corners, round dome near the end and terrace directly behind it. The adjacent Prudential tower places this end on the south side; orientation is inferred from surroundings, not a surveyed roof plan. Exact roof/deck levels remain open.

Next: finish actual native baseline, verify current base and roof orientation, then author physical recessed glazing, distinct office/residential piers, roof terrace and ribbed pool dome using existing Blender helpers. Published envelope is121.9m; facade intervals and all unmeasured roof/base details must be labelled photo-fit. No complete-building claim.

## Authored draft — 2026-10-09

Original editable Blender exterior with exact six-point foundation,121.9m tip, grouped residential piers, separate physical glazing/sash and fluted spandrels, denser ribbed office base/ground arcade, roof terrace with real balusters and conical glass pool dome/radial ribs. Current190,340tri/eight flat materials. Base30m/ground5m/31upperrows, roof118.8m, dome radius7.4m, terrace and north service enclosure are photo-fit, not surveyed. Current base renovation/entrance, precise office rib spacing, roof furniture/equipment and hidden elevations remain open.

First188,420tri build passed but took approximately213s with thousands of separate panel objects. Direct material-mesh batching preserved the188,420tri count and completed in1.67s; facade grouping/sash refinement then produced190,340tri in1.77s. These are authoring timings, not game performance. Shared architecture helper unchanged. Blender finite-vertex/envelope assertions passed, refined import71468exit0/empty stderr.

First geometry test failed its dome-glass ray because that ray landed on an intentional solid radial rib. Moved the sample between ribs; actual dome was already visible. Final direct64320exit0/empty stderr,17checks PASS, followed by registered gate20261009-115155 allPASS17checks plusparse. Checks include opaque arcade rays, residential glass ahead of core and dome glass above roof;1m foundation clearance12.5670204mOriginal/11.0333424mGrid.

Native refined stage69180exit0/empty stderr/terminalMILLENNIUM STAGED REVIEW PASS. All four actual front/crown day/night images inspected and saved in ../screenshots/chicago-millennium-draft; sparse occupied glazing switches at night. Façade camera(-110,70,140) aim(0,60,0), roof camera(-32,144,75) aim(0,119,25). Dense office ribs produce visible shadow detail needing closer base review; no artifact-free claim. This is an isolated asset review, not installed game/driving evidence.

Draft is not installed; production remains cache206 and both route geometries unchanged. Next current base/entrance verification and close base review, then shared fixture integration, exact generic exclusion and production route/gate/native review. No EXE generated.

## Southern retail addition and shared integration — 2026-10-09

Owner offices page actually opened: header-mpp-offices.jpg is an interior office, not base geometry evidence. Beitler retail page describes the underground Shops at Millennium Station, a separate project despite the shared151NorthMichigan address; do not attribute that SOM interior to this building's exterior. Broker PDF could not be read; no PDF contents claimed.

Actually inspected two exterior photos on [broker listing27304787](https://www.loopnet.com/Listing/155-N-Michigan-Ave-Chicago-IL/27304787/), dated on market2025-09-23. Photo capture dates are not established. Observed images:

- https://images1.loopnet.com/i2/Gn5FLUq9Vsv85fOTakNogSyzj1gMuaPOupAuP2OQnLQ/110/155-N-Michigan-Ave-Chicago-IL-Building-Photo-1-Large.jpg
- https://images1.loopnet.com/i2/giYEm_xciA-PQYPZAqpZn_-KaX6RDdGF_IbXwqlS7GQ/110/155-N-Michigan-Ave-Chicago-IL-Building-Photo-2-Large.jpg

These show a low stepped glass retail addition immediately south of the tower, pale/gray metal-clad projecting frames, broad glazed frontages, lower west terrace/rails, recessed upper level, flat light roofs and service screens. Main tower's short office end retains narrow glass bays/brown spandrels. Current entrance door arrangement, exact metal/glass dimensions and precise long office ribs still unverified; no external photos embedded.

Separate adjacent mapped w228971614 ring `[[11.2,-5.7],[11.9,19.9],[32.9,19.8],[32.2,-5.4],[30.2,-3.9],[13.1,-3.5]]` has erroneous118m height, creating a false tower beside the actual tower. Added an original low stepped addition in the same authored asset, exact foundation; lower roof10m/upper14.3m/service screen16.1m and6m west setback are photo-fit, unmeasured. Tower's121.9m tip unchanged. Updated192,212tri/eight materials; Blender113020exit0/finite geometry/envelope checks. Import46980exit0/empty stderr. Isolated native stage1056exit0/empty stderr/terminalPASS; actual close base day view inspected. Geometry22checks plusparse PASS165023; tower clearance12.56702Original/11.03334Grid, retail addition11.35162Original/11.26387Grid.

Shared MillenniumPlaza fixture at(21.1,8,-49.4) and both mapped generic exclusions staged/cache207. Production gates and native city review pending; route geometry unchanged. Fine roof/entrance/base/returns remain provisional. No EXE.

## Working exterior installed — cache207

Shared fixture now replaces both w127107026 and w228971614 exactly once on both routes. Final six targeted gates20261009-165126 allPASS167s: geometry23/menu132/coverage23/fullclips1+1=180checks plusparse. City clipping baseline remains120Original/104Grid; no clipping-free city claim. Automated menu gate includes actual selected-variant driving and gameplay engine audio; human listening remains separate.

Native production18632exit0/empty stderr/terminalMILLENNIUM CITY REVIEW PASS, Gridcache207 loaded. Six actual street/base/crown day/night views inspected and saved in ../screenshots/chicago-millennium-installed. Recessed residential glazing/piers, ribbed office base, stepped low glass retail addition and roof terrace/radial glass dome visible; incorrect118m south block absent. Street and roof cameras match baseline; separate base camera(-16,14,38), aim(21.1,18,0). Frozen43.888575ms from the final base-night view is not driving performance and cannot be compared directly with the prior roof-view timing. Surrounding generic skyline remains unaudited.

All tower/retail roof and floor splits remain photo-fit within the published tower envelope. Exact entrances, long office-rib depth/spacing, retail frame proportions, roof furniture/equipment and hidden returns remain open. This is a working exterior, not complete architectural fidelity. No EXE generated.
