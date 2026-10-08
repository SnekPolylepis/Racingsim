# 200 South Wacker — staged physical exterior draft

2026-10-08: original Blender generator `tools/blender/chicago_wacker_200.py`,
editable `tools/blender/authored/wacker_200.blend`, GLB `assets/chicago/landmarks/
wacker_200.glb`. 73,760 triangles/seven materials. Separate recessed panes,
physical silver jambs/rails, pale horizontal panels, tall lobby columns and
angled upper lobby glazing. Retained six-point city.json w64888042 foundation.
Proposed origin(-1076.05,8,641.75), no rotation; not integrated yet.

Primary references inspected:
- https://www.gpchicago.com/architecture/200-south-wacker-drive/ — restoration architect; existing lobby photograph shows pale columns and angled glazing. Its image called200W_overall is an interior, not full tower evidence.
- https://www.tjbc.com/project/200-south-wacker/ — original developer;41floors, Harry Weese,1981. Existing entrance photo shows suspended glass canopy and physical200sign; these still need modeling.
- https://200southwacker.com/ — owner;40storeys and current redevelopment imagery. The2025-11-06exterior image is a rendering, not proof of completed works; proposed river terrace/entry design not treated as as-built.
- https://www.skyscrapercenter.com/building/200-south-wacker/3831 —152.3m/41floors versus mapped155.5m; discrepancy unresolved.

Native 2m height raster strongest roofs near122,147and154m; higher raster zone
forms a diagonal boundary through the foundation. Current upper polygon/roof
service shape is a provisional interpretation, requiring full-tower photographs
and footprint fitting before production replacement. Exact facade bay/floor
counts, portal/canopy/signage, river base, terrace and roof services remain open.
No source photos are embedded in the model.

Blender generation assertions pass; import exit0. Actual standalone Godot4.6.2/
M4 Metal Forward+ neutral-light draft capture inspected, exit0/empty stderr.
This is shape evidence, not production day/night/placement acceptance. Scratch
image visual-review/wacker200-draft.png is ignored. No cache/record change,
route edit, app export or user-save change. Next: resolve full-tower proportions,
author distinct entrance canopy/sign, then integrate and inspect both-layout
source day/night with foundation and full clipping checks. Full trackside goal
continues;311base/sculpture and other building fidelity work remain open.

## Entrance reference pass — 2026-10-08

Added physical suspended glass canopy panels, steel arms/fascia, diagonal
suspension rods, dark corner plaque and extruded200numerals. Existing developer
photo supports this entrance concept; exact dimensions and corner location are
photo-fit, not surveyed. Canopy projects only about0.8m past the mapped eastern
wall to preserve close roadway clearance pending full production checks.

Additional original photographs inspected in the browser:
- [Mike Oropeza, west view,2011](https://commons.wikimedia.org/wiki/File:200_S._Wacker_West_View.jpg), CC BY-SA3.0: pale horizontal facade and flat full-height western roof edge. This view does not establish the diagonal roof join dimensions.
- [Ken Lund street view,2013](https://commons.wikimedia.org/wiki/File:200_South_Wacker_Drive_from_Willis_Tower,_Chicago,_Illinois_(9179392553).jpg), CC BY-SA2.0: pale panels, narrow pane mullions and tall podium columns. Despite its filename, the actual image is a street view; do not treat it as roof/overhead evidence.
No reference photographs copied into runtime materials or redistributed here.

Generation assertions/import pass. Actual standalone Godot4.6.2/M4 Metal
neutral-light entrance capture inspected, exit0/empty stderr, under rebuild/
screenshots/chicago-wacker200-draft-mac/entrance-neutral.png. Number reads200;
glass canopy, individual support rods and lobby recess are visible. No
production integration/day-night/roadway-clearance acceptance yet. Retained roof
tiers are still provisional pending a photograph that exposes the diagonal join.
Next: check paired tower/roof join, integrate at mapped origin and inspect both
layouts day/night with foundation probes and full clip scans. Goal remains active.

## Paired roof and production integration — 2026-10-08

[Vincent Desjardins's actual roof-facing photograph,2010](https://commons.wikimedia.org/wiki/File:View_down_from_the_Sears-Willis_Tower_Skydeck.jpg), CC BY2.0, inspected in the browser. It confirms the two triangular masses meeting along a diagonal and the long enclosure on the taller roof. Revised the generic rooftop box into a diagonal enclosure with physical louvres; added three photo-fit lower-roof service cabinets. Exact join/corner/enclosure dimensions remain provisional rather than measured. Current original Blender source/GLB81,532triangles/sevenmaterials; no photo textures.

`Scenery/Wacker200` integrated at(-1076.05,8,641.75); mapped w64888042 fallback
excluded. Both packed-cache validators require the node/seven materials. Cache184,
original@v7/Grid@v5 unchanged; no road/timing changes. Clear lobby/canopy alpha.18,
explicit warm night fixtures/selected office panes and day-off toggles.

Mac Godot4.6.2/M4 Metal Forward+: building29checks and parse pass; all39headless
Chicago suites pass208.1s, including menu115, both roadway geometry49 and
all other authored exteriors. Both full native5m/five-offset clipping scans pass:
Grid103/original120 accepted overhead hits, zero failures, exit0/empty stderr.
Wacker200 is explicitly not exempt from building clipping. Native1m foundation
clearance12.808571original/8.469823Grid; roof/canopy ray probes pass.

Eight actual High source views inspected: Grid full tower and street entrance,
plus driver-height frontage on each layout, each day/night. Image filenames
ending river are street entrance cameras in this folder. Final evidence in
screenshots/chicago-wacker200-mac. Two-view jobs completed exit0; first night
job reported shared-cache load errors during concurrent rebuild and fell back
to source generation. Final night job ran alone, rebuilt the source cache and completed exit0/empty stderr; both resulting images inspected. This confirms clean source rendering, not a warm-cache-load guarantee.
No broad day/night acceptance based on neutral-light staged screenshots.

Fine lobby interior, river base, precise diagonal join/corners, entrance placement
and equipment remain fidelity work. The roof-facing photo resolves topology;
physical dimensions and published152.3m versus mapped155.5m discrepancy remain.
No app export or new lap/manual-wheel/Intel/performance claim. Prior laps remain
dated evidence; no baseline rewrite. Full trackside-building goal continues.
