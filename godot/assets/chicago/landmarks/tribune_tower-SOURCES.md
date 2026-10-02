# Tribune Tower exterior

Original Blender geometry authored for Racing Sim; no facade photograph or third-party mesh is included.
Editable source: `tools/blender/authored/tribune_tower.blend`; reproducible authoring script:
`tools/blender/chicago_tribune_tower.py`, using the existing `architecture.py` helpers.

Visual references consulted 2026-10-01:

- [Chicago Architecture Center: Tribune Tower](https://www.architecture.org/online-resources/buildings-of-chicago/tribune-tower), exterior photograph credited to Eric Allix Rogers; limestone office block, vertical piers, recessed window bays and Gothic crown.
- [SCB: Tribune Tower Conversion](https://scb.com/project/tribune-tower-conversion/), crown terrace photograph showing open buttresses, stone tracery and pinnacles.

The model interprets those features with actual mesh depth. Lower block, setbacks,
window spacing and carved details are stylized approximations inside the game's
existing landmark site, not a measured elevation or a survey. Highest stone
pinnacle is 141 m above its base; flags and a flagpole are omitted. The model
replaces the previous 159 m rectangular shaft/triangular-spire approximation.
Photos were viewed as references only; their pixels are not shipped.

Placement uses mapped OSM [way 150407241](https://www.openstreetmap.org/way/150407241),
435 North Michigan Avenue, and the existing local footprint centre
(67.1, -632.6) m in `route-inventory.csv`. The earlier POI pin was about 49 m
east of the footprint and failed to exclude its generic duplicate. Model and
city exclusion now share the mapped position.
