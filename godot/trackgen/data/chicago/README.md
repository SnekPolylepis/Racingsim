# Chicago river-and-lake circuit (CHI-01)

An authored closed race circuit, not a surveyed reproduction or a public-road navigation map.
`route.json` is the editable geographic scaffold. `trackgen/chicago.gd` converts longitude/latitude to
local metres about 41.8848 N, 87.6244 W, eases intersections, and constructs the complete TrackAsset.
The generator runs offline and its result is cached separately for headless and windowed Godot.

## Route

Start on Michigan Avenue southbound beside Millennium Park; turn east onto Jackson Drive; run north
on Lake Shore Drive; turn west through the harbor connector into Lower Wacker; follow Lower Wacker
west and south, bending through the riverfront return; use the south connector to climb to Upper
Wacker; return north through several staggered bends along its east end before turning south onto
Michigan Avenue. The riverfront control points are simplified from retained OSM geometry and eased
for racing. Both Wacker decks occupy the same geographic
corridor at separate heights (3.4288 m and 8 m in the local frame).

The harbor connector near the Wacker/Lake Shore junction and the south loop near Franklin/Jackson
are explicitly **game-only** ramp connections. They simplify the real junctions and close the lap.
They do not represent usable real-world driving directions. Width (16 m), deck height, grades,
intersection corner radii, barriers and lighting are authored for racing. Building roof massing uses
USGS LiDAR grids where available; that does not make the circuit's authored ramps a road survey.
This is a fictional race event, not the NASCAR Chicago course.

## Sources and licence

Road reference acquired 2026-09-25 from OpenStreetMap contributors via
`https://overpass.kumi.systems/api/interpreter`, using:

```overpass
[out:json][timeout:60];
way[highway][name~"Wacker|Michigan Avenue|Lake Shore Drive|Jackson Drive|Monroe Street|Franklin Street"]
(41.875,-87.64,41.896,-87.605);
out geom;
```

The response is retained in `osm-roads.json`, with way IDs, geometry and tags. `route.json` is a
simplified, edited derivative; both geographic data files are distributed under ODbL 1.0:
https://opendatacommons.org/licenses/odbl/1-0/ . © OpenStreetMap contributors:
https://www.openstreetmap.org/copyright . The original reference is not needed inside the game PCK.
The source repository supplies the editable geographic data alongside the produced track.

Context reference for Wacker's two levels and the riverwalk:
https://www.transportation.gov/buildamerica/projects/riverwalk-expansion . No article images or map
tiles are copied into the game. All city/landmark geometry is original procedural low-poly artwork.
Landmark locations are approximate geographic anchors. The Bean uses John Helman's model;
Willis Tower uses BoldlyBuilding's model and textures; Navy Pier includes a pier and wheel.
The next authored landmark set adds original low-poly silhouettes for the Wrigley Building, Tribune
Tower, Board of Trade and the Michigan Avenue, State Street and LaSalle Street lift bridges. The two
riverfront runs now use added control points derived from the retained Upper/Lower Wacker OSM ways.
Four CC0 photo-based 1K PBR texture sets bring brick and riverwalk/sidewalk detail to selected
buildings and paths (`assets/textures/chicago/`). Water animates with a restrained world-space
procedural ripple shader; it changes presentation only. Geometry and record identity are version 3;
the six Chicago lap measurements in `docs/rebuild/laps-v2-baseline.json` were freshly recorded for
version 2 on 2026-09-25 after the new Wacker bends were added. Earlier values in the dated rebuild
log describe the version 1 route.
Version 3 (2026-09-30) raises the lower road to the sourced 4.191 m clearance
beneath Upper Wacker and narrows the north–south racing bay to the published
26 ft section. Version 2 lap baselines are historical measurements; version 3
full laps have not been recorded during the owner's screenshot-focused work.

## Acceptance and reproduction

`tests/v2/chicago.gd` checks the whole road's width, grade, clearance, grid, separate deck contact
and timing-gate isolation. `tests/v2/laps.gd -- --track=chicago` runs all cars and handling modes;
`--record` updates only the selected track's measured baselines. The normal full lap gate includes
Chicago alongside existing circuits.

Run the game with `-- --v2-track=chicago`, or select **Chicago — River & Lake** in the track picker.
`tests/v2/chicago_screenshots.gd -- --v2-flow-test --v2-track=chicago` captures day/night driving views
and explicit side-view landmark sightlines through the actual game renderer. Pictures marked
`sightline` turn the camera from the driver's position; they are not all forward-facing views.
The original five required landmarks remain permanent geometry/anchors, not just labels. The new
bridge and skyline forms are additional geometry, and the city uses selected CC0 masonry and paver
maps. Chicago water is animated, with moored boat geometry from the retained map data. Pedestrians
are absent. The city generator now also uses OSM parts, cited `landmarks.json` overrides and USGS
roof grids; remaining placeholders and unsourced procedural landmarks are tracked in
`docs/rebuild/CHICAGO-DONE.md`. Asset licences are recorded in `THIRD-PARTY.md`.

Only this circuit extends the fog/view distance to retain lake and skyline views; other circuits'
render settings are unchanged. Flat painted sky replaces wooded hills for Chicago. Lamp fixtures
under Lower Wacker mount against the slab soffit, with round structural columns
and open side bays. Fixture dimensions, service lanes, signage and portals remain
under source review. The circuit has no AI traffic or pedestrians.

Afterhours accents are authored by `add_night_details()` and toggled by
`scripts/track/chicago_night.gd`, including materials serialized into the track cache. The wheel,
pier, plaza, crown and ceiling fixtures are original procedural geometry. The Bean uses two
shadowless spotlights; repeated ceiling fixtures share one mesh. Chicago's facade materials use
reduced window density and emission, while the shared shader's default preserves other tracks.

Chicago's pooled lights cast shadows so the Wacker slab separates the two decks.
Ceiling-light halo batches fade out when viewed from above the ceiling. Willis Tower's night
emission multiplies its facade texture, preserving the dark window grid instead of adding a
solid glow. Imported sidewalk props are seated by their mesh bounds and kept clear of nearby
road sections on the same level; drain and manhole tops sit flush with the road.

### Authored 3D building replacements — 2026-10-01

Chicago Theatre and Page Brothers use Blender-authored GLBs from
`assets/chicago/buildings/chicago_theatre/`, in both Chicago layouts. The city
generator skips their former mass/photographic facade geometry. The original
photo-wall metadata still identifies the mapped frontage and placement frame;
it no longer creates a rendered photo panel for these two buildings. Night sign
materials follow the existing Chicago emission toggle. Editable Blender sources
and their reproduction script live under `tools/blender/`; `.gdignore` prevents
Blender source files from becoming game imports. Building model bytes participate
in track cache identity, including remapped resources in exports.

The wider conversion is in progress. Remaining photographic frontage assets:
Railway Exchange, Cultural Center, Athletic Association, University Club and
Orchestra Hall. Other route-facing generic building exteriors still require
individual source/model review; this first pair does not finish the request.

### Park paths — 2026-09-30

After adding missing Grant Park relation boundaries, city.json contains 1,367
park path records (all 920 prior geometries retained, 447 newly selected from
the same staged downtown-trees-paths.json). `path_of()` keeps OSM element ID,
`surface` and `width_source`. Seventeen paths have an explicit OSM width;
others retain old 4/2.6 m defaults, explicitly unverified. Concrete, asphalt
and paving-stone tags select existing native material types; untagged and
other surfaces retain the old path material pending source-specific finishes.
Paths are emitted before flat meshes commit, with a 15 mm rendering bias above
raised park polygons. That bias is not a surveyed elevation. Accurate terrain
grade, default widths, materials, joins and clipping remain open.

## Chicago — Loop Grid variant

`route-grid.json` adapts Route I (Grand Tour II) from
`claude/chicago-track-detours-kzoiyk` commit c46748e1. Michigan/Wabash weave,
Columbus/Monroe lakefront connection and Franklin/Washington/State return follow
the draft OSM coordinates. Geographic-source licence remains ODbL. Existing
harbor and south connectors remain authored game links. Lower Wacker uses the
current 3.4288 m road level and south ramp midpoint 5.7144 m. A Willis-view
point remains on the upper south approach.

`chicago_grid.gd` calls shared `chicago.gd` with the variant enabled. It has
its own track id, record identity and cache; original `route.json` is unchanged.
Downtown intersection setbacks are limited to 18 m to keep the weave on the street
grid. Measured Wacker lane bay, current city assets, elevated L, river, lake
and day/night presentation use the shared implementation. Draft polyline
lengths differ from baked racing-line lengths.


### South connector placement — 2026-10-08

Current generator world(row) maps the two South connector controlsz887.1,
secondcontrolx-896.5 and South connector rampx-898.0. Row indices, elevation
profile and geographic source scaffolds remain stable; corner station aliases
and roadside generators share adjusted coordinates. This follows the mapped
VanBuren/Franklin corridor instead of cutting through mapped w74268219 garage
and w73766157 Brooks footprints. Heights/widths/easing are race authoring,
not real-world driving directions. Original recordidentity@v6/Grid@v4 separates
changed routes from previously saved laps/ghosts; cache174 rebuilds scenery.
See latest REBUILD-LOG and FRANKLIN-GARAGE-SOURCES.md for validation and limits.

2026-10-08: cache175 adds authored Brooks exterior at retained w73766157
foundation; route versions and candidate distances unchanged. See BROOKS-SOURCES
and the MacBook handoff for provisional height/details and actual validation.

### Mapped South Wacker approach — 2026-10-08

Current points() inserts mapped road controls(-1038.4,747.8) and(-1031.1,811.5)
after the last Lower Wacker south source row. Shared world(row) places the
western South connector at(-1028,887.1), keeping its geographic source index
and the other connector/ramp coordinates intact. The former straight racing
line was too far west beside w147350178300SouthWacker. Native mapped-road
plan alignment, authored heights/widths/easing; not a surveyed drivable route.
Centreline lengths7859.992m/original and8488.778m/Grid. Drivable surface changed,
so original@v7/Grid@v5 select separate records/ghosts; existing saves stay intact.
Cache180 also adds physical300SouthWacker and retains all nine foundation points.
Candidate CSV now236within50m; see latest MacBook handoff for actual validation.
