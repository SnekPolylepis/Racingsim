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
corridor at separate heights (0 m and 8 m in the local frame).

The harbor connector near the Wacker/Lake Shore junction and the south loop near Franklin/Jackson
are explicitly **game-only** ramp connections. They simplify the real junctions and close the lap.
They do not represent usable real-world driving directions. Width (16 m), deck height, grades,
intersection corner radii, barriers and lighting are authored for racing. No LiDAR heights or precise
building survey were acquired. This is a fictional race event, not the NASCAR Chicago course.

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
Landmark locations are approximate geographic anchors. The Bean is a stylized metallic arch;
Willis Tower uses a stepped tube silhouette and antennae; Navy Pier includes a pier and wheel.
The next authored landmark set adds original low-poly silhouettes for the Wrigley Building, Tribune
Tower, Board of Trade and the Michigan Avenue, State Street and LaSalle Street lift bridges. The two
riverfront runs now use added control points derived from the retained Upper/Lower Wacker OSM ways.
Four CC0 photo-based 1K PBR texture sets bring brick and riverwalk/sidewalk detail to selected
buildings and paths (`assets/textures/chicago/`). Water animates with a restrained world-space
procedural ripple shader; it changes presentation only. Geometry and record identity are version 2;
the six Chicago lap measurements in `docs/rebuild/laps-v2-baseline.json` were freshly recorded for
version 2 on 2026-09-25 after the new Wacker bends were added. Earlier values in the dated rebuild
log describe the version 1 route.

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
maps. Chicago water is animated; no boats, pedestrians, downloaded landmark models or photo facades
were introduced.

Only this circuit extends the fog/view distance to retain lake and skyline views; other circuits'
render settings are unchanged. Flat painted sky replaces wooded hills for Chicago. Lamp fixtures
under Lower Wacker are shortened beneath the deck and have collidable structural columns outside
the barrier. The circuit has no AI traffic or pedestrians.

Afterhours accents are authored by `add_night_details()` and toggled by
`scripts/track/chicago_night.gd`, including materials serialized into the track cache. The wheel,
pier, plaza, crown and ceiling fixtures are original procedural geometry. The Bean uses two
shadowless spotlights; repeated ceiling fixtures share one mesh. Chicago's facade materials use
reduced window density and emission, while the shared shader's default preserves other tracks.
