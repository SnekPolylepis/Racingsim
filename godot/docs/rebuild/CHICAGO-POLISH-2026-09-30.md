# Chicago polish — 2026-09-30

Branch: `codex/chicago-spa-polish`, owner-directed city/Spa art iteration.

## Changes

- Chicago River bridges use low red-brown bascule guardrails / girders and compact limestone bridgehouses with cornices, pilasters, windows and copper roofs. Removed the overhead trusses and fantasy spires; roads and physics unchanged.
- A continuous stone promenade follows the mapped south bank from Lake Street toward LaSalle at river level, with coping and metal railing. Replaces two isolated slabs submerged below the river.
- Lower Wacker ceiling/columns use existing Concrete034 texture.
- City facade bay widths/floor heights vary per building. Night windows have lower exposure, partly lowered blinds and shaded edges; storefront/neon retain their existing contrast.
- Mapped park footpaths now enter the chunk geometry before meshes commit; formerly they were constructed too late to render, and beneath the grass. Short pieces clip clear of the racing route.
- CTA train cars use brushed stainless steel, individual side / door panes, front windscreens and lower-body fluting, replacing the chrome tube appearance.
- Generic kit cornices and roof clutter are restricted to flat extruded buildings: applying the nominal maximum roof height to every LiDAR step caused floating strips, cornices and boxes. Category-hide renders proved the kit culprit; a camera ray proved the apparent blank Navy-view podium was empty sky enclosed by the unsupported cornice.
- Traffic signal supports now move outward until clear of all same-deck road stations; local offsets on the Michigan turn previously put a support inside the driving corridor.
- Board of Trade tiers now use the existing stone/window facade helper. Wrigley has a round illuminated clock with hands/hour marks.
- Navy Pier placeholder pavilions and submerged base removed from the main generator; detailed exhibition halls and correct-height deck are authored in ChicagoHarbor by the reference/content agent. Wheel retained.

## Reference points

- Chicago Architecture Center: [DuSable Bridge](https://www.architecture.org/online-resources/buildings-of-chicago/michigan-avenue-bridge-dusable-bridge), Beaux Arts houses and double-deck bascule structure.
- Chicago Architecture Center: [Chicago Riverwalk](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-riverwalk), promenade along Wacker Drive.
- City of Chicago: [Michigan Avenue Bridge / Wacker esplanade landmark](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1369).
- Mapped shoreline / park paths: existing OpenStreetMap city.json, existing credits retained. No new external assets in these edits.

## Recorded evidence

- Godot 4.6.2 macOS headless `tests/v2/chicago.gd`: 37 checks, zero failures after bridge/facade/Riverwalk/paths CTA, cornice/roof and traffic-support changes. Length8161.20m, maximum grade6.014%, no width misses/headroom intrusions; cache night transitions pass. Added regression checks for low closed-bridge steel, committed park path surfaces, traffic-support clearance and no generic clutter on measured stepped roofs.
- `git diff --check`: pass.
- Compared /tmp/racingsim-polish/chicago-before and chicago-pass1 views: night windows no longer clipped to white, Lower Wacker concrete has visible texture. Daytime sweep inspected at1050,1400,2100,2450,2800,7000,7350m with clear racing corridor.
- CTA appearance verified in chicago-pass2 (distinct side windows / brushed silver). Latest cornice, pole and Navy Pier changes require fresh windowed review after this recorded pass; no claim of full-lap visual completion from these limited screenshots.

## Final full-lap follow-up

- Full-lap capture at6650m exposed elevated railway support columns inside Upper Wacker. Elevated L deck and girders are unchanged; column placements overlapping the racing corridor are omitted, creating bridge spans. Clearance uses actual authored left/right road width plus1m and the full8..13.2m column height with3m car headroom, including raised roads/ramps.
- Regression reads actual emitted trestle mesh bases/midpoints/tops and projects them to the road. A separate regression verifies tree crowns clear Cloud Gate's70x60m paved plaza.

- Stricter L-column / plaza headless check:39 checks, zero failures,58.5s; source after full-height guard.

## Final review and root fixes

The fresh 24 Daybreak + 24 Afterhours whole-lap views and 34 focused captures showed an elevated L support in the racing corridor at 6650 m. Interior supports now bridge the route: their full vertical span (including raised road/car height) clears actual section widths, while trestle decks/girders remain continuous. The paved Cloud Gate plaza and its authored narrow west approach exclude tree crowns, so the imported Bean is visible from Michigan Avenue. The City of Chicago identifies Cloud Gate as a plaza sculpture: [official reference](https://chicago.gov/city/en/depts/dca/supp_info/chicago_s_publicartcloudgateinmillenniumpark.html).

A Riverwalk close-up exposed the shared batched-box helper scaling along world axes and using a 2 m default cube. It now uses a 1 m mesh and scales local axes before rotation. This restores authored promenade/deck/trim dimensions; a rendered unit probe verifies a rotated 2 x 3 x 7 m box. The headless Dummy renderer discards MultiMesh transform buffers, so its suite only verifies the unit mesh; the rendered Chicago suite checks actual dimensions and tree transforms.

Final Chicago suite: **40/40**, both headless and windowed Metal runs, no script errors. Parent reviewed all final lap sheets plus enlarged Bean, Riverwalk, DuSable, Navy Pier and the corrected 6650 m trestle view. Saved evidence: [screenshots/chicago-spa-polish/README.md](screenshots/chicago-spa-polish/README.md). Existing frozen-capture shutdown reports an ObjectDB cleanup warning. These views establish the authored PS2 presentation, not surveyed architecture or physical hardware input testing.


## Centennial Wheel follow-up

The old wheel origin used route.json y=2 while the pier deck is y=7.3 and the lake y=6.5: its lower rim/cabins intersected the lake. The wheel now anchors to the raised deck, with a 31.7 m hub height, 21 spokes, 42 blue enclosed cabins and six structural legs. Those dimensions/counts follow [Navy Pier’s behind-the-scenes account](https://navypier.org/support-the-pier/articles/behind-the-scenes-at-the-centennial-wheel/); its approximately 60 m silhouette follows the [official attraction reference](https://navypier.org/pier-locations/centennial-wheel/). An open west plaza, raised loading platform, stairs and shelter replace the first generic exhibition shed.

The low close-up camera then exposed a second real overlap: the emitted `City/Low_2_-2` facade was only 0.72 m from the camera, ahead of the axle at 59.9 m. An elevated diagnostic showed mapped low halls across the authored wheel and loading plaza. Generic building polygons intersecting the 64 x 90 m plaza rectangle are now omitted before facade/roof/detail emission; surrounding mapped structures and authored eastern halls remain. This is a geometry correction, rather than hiding an obstruction by moving the review camera. The cabin regression counts 42 actual mesh nodes and checks the lowest glass bottom at 10.53 m clears the deck. A ray against emitted city triangles guards the previously blocked plaza approach. The follow-up headless Chicago run passed 42 checks with zero failures; daytime/nighttime close-up review is pending.

Final close-up review also caught the removed shed’s orphan roof light. Roof strips now attach to the five surviving raised hall cornices; the wheel plaza has no floating light bar. Fresh day/night review is saved in `screenshots/chicago-spa-polish/detail-pass/`; final Chicago run passes 43 checks. Riverwalk paving now uses the existing material’s world-space triplanar mapping, preserving square stones along long slabs.
