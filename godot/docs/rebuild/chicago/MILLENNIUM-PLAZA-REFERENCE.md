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
