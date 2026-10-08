# Franklin / Van Buren garage — exterior draft

Mapped identity w74268219, six-vertex foundation retained. Origin
(-859.5,8,844.05), no yaw; Blender +Y north/+Z up. Mapped height49m;
photo-fit roof49m and guardrail top50.1m. No independent height survey.

Reference: Cast-In-Place Concrete Parking Structures, Post-Tensioning Institute
brochure, PDF pages2–3, photographs credited to Desman Associates:
https://ptsindia.net/wp-content/uploads/knowledge-center/pdf/UBPT%20Parking%20Structures.pdf
Inspected full rendered pages2026-10-08. Historical exterior has closely spaced
concrete piers, exposed slab bands/open parking apertures, taller retail base
and a rounded slotted corner tower. Brochure states14 parking levels and1990
construction. Listing instead states1988:
https://www.loopnet.com/Listing/325-335-S-Franklin-St-Chicago-IL/7451701/
No claim resolving dates. No photograph redistributed or used as model texture.

Do not copy the neighboring Traders Wells structure: engineering reference
shows a glazed stair/elevator tower and different bay proportions:
https://wginc.com/projects/traders-self-park
Operator groups Franklin/Wells/VanBuren entrances under Traders:
https://parkchirp.com/facilities/traders-self-park/
Those naming links do not establish that all linked structure photographs
show the mapped Franklin footprint. Exact corner orientation, bay count,
retail tenants/signs, ramp layout and roof markings remain photo-fit drafts.
The approximate ramps/columns provide visible interior depth; this is an
exterior scenery model, not a functional navigable parking simulation.

Authoring: tools/blender/chicago_franklin_garage.py, shared architecture helpers;
authored/franklin_garage.blend and franklin_garage.glb. Seven materials,35484
triangles. Fourteen slab levels, true apertures and recessed retail panes;
physical rounded-core slots, parking signs, roof rails/stall stripes/wheel stops.
Finite vertices/height/level-count authoring assertions; native17 geometry and
night-switch checks plusparse pass before final roof detail reimport.

## Draft checkpoint placement — 6d9c69d

At the draft checkpoint, production routes exclude this footprint for authored route clearance.
Native current corner camera(-837.8822,5.3476,843.028) is inside the footprint;
Gridstation6124.335/original5555.321. Both share the same connector coordinates.
Staged mesh reviews deliberately reveal the road/foundation conflict; they are
not acceptance of production placement. No production integration/cache or
record version change in this draft checkpoint.

Experimental alignment tested in ignored visual-review/franklin-candidate.gd:
for both South connector controls usez887.1; second controlx-896.5; South
connector rampx-898.0. Other controls/heights retained. These are authored
race-connector choices along mapped VanBuren/Franklin streets, not a surveyed
street recreation. Native2m sample audit of38 nearby footprints in connector
region: old route crossesgarage/Brooks, candidate crossesnone. Garageclearance
original14.558/Grid14.566m; Brooksclearanceoriginal14.727/Grid14.683m.
Original length7934.720→7858.542; Grid8569.649→8487.329m. This local sampled
centreline audit is not a rendered full-course clearance or driving test.
Initial broad scratch audit timed out120s; bounded local audit completed0.4s.

Next: integrate validated alignment and model, preserve old saved records with
new route identities, verify both full rendered clip scans, relevant route/menu
checks and all cars/modes, then update timing references only if justified.
Brooks should become a visible modeling candidate after this correction.
Native Godot4.6.2/M4 staged High day/night images:
docs/rebuild/screenshots/chicago-franklin-draft-mac/ (sixviews).
Current route absence: chicago-franklin-placement-mac/ (eight retained views).
No export, performance, Intel or wheel validation. Whole trackside goal remains open.

Final roof stripe/wheel-stop mesh reimport exits0,17 geometry/night checks
plusparse pass0.7s. Six final staged day/night views rerendered and inspected,
exit0/empty stderr. No production placement acceptance at this checkpoint.


### 2026-10-08 — Franklin garage integrated; both connectors clear retained buildings

Integrated FranklinGarage at(-859.5,8,844.05), mapped foundation unchanged,
35484tri/seven materials; generic w74268219 excluded exactly once. Night
fixtures use the existing Chicago material toggle, restrained specular response.
Shared world(row) places both South connector controls on z887.1, secondx-896.5,
rampx-898.0; corner aliases and roadside generators share the correction.
Mapped VanBuren/Franklin reference, authored widths/grades/easing; no road-survey
claim. Cache174; original@v6/Grid@v4 preserve older saved record/ghost identities.

Native1m samples clear garage14.558m andBrooks14.682m on both layouts.
Brooks generic frontage is now visible; replace it next from retained primary
references. Production foundation geometry is not shortened or lifted to fit.
Refreshed native5m candidate CSV:237 within50m (prior241 snapshot retained as
dated evidence). Garage14.6/Grid6135; Brooks14.7/Grid6160;22514.4/original6765.
Candidate distances remain neither a visibility guarantee nor completion tally.

36 headless Chicago/parse suites passed185.8s during integration. After shared
coordinate/caching refinement, final scoped six suites pass119.3s: garage25,
menu111, Gridroute49, authoredcoverage23,225Wacker38, plusparse (246assertions).
Both full windowed5m/five-offset clip scans pass: Grid107/original110 accepted
overhead hits, zero failures, exit0/empty stderr. Grid rerun after shared
coordinate change also passes107. Original scan already used final placement.

Allfivecars/both handling modes on both layouts completed20 clean lap cases,
zerooff-road/wall/prop ticks; lap harness has0props. Ten bounded per-car runs,
max2 concurrent, exit0/empty stderr. All16 stored timing references stay inside
unchanged2% tolerance; original formula modes have no timing baseline. No
baseline fixture rewritten for this shorter connector. Logs mac-civic/franklin-*.

Original eight High source day/night approach/corner/exit/building captures
completed and inspected. Combined review hit180s; split Grid30-frame-wait
review also hit180s after two views. Completed Grid capture uses five awaited
frames plus RenderingServer.frame_post_draw for each image; results recorded
only after exit0/empty stderr. Allsixteen final views inspected. Final captures live in
rebuild/screenshots/chicago-franklin-production-mac/. Frozen captures establish
appearance, not frame-time acceptance. Broader building fidelity, finer civic
sculpture and remaining trackside exteriors remain open. River bridges queued.
No app export, manual wheel driving, full-game/performance or Intel validation.

Final finite-clearance guard rerun: garage25 andparse pass1.6s.
