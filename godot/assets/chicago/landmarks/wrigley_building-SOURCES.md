# Wrigley Building exterior

Original Blender mesh geometry for Racing Sim; no photographic facade panel or
external mesh is shipped. Authoring source is `tools/blender/chicago_wrigley_building.py`
and editable `tools/blender/authored/wrigley_building.blend`, using the existing
`architecture.py` helpers.

References consulted 2026-10-02:

- [Chicago Architecture Center: Wrigley Building](https://www.architecture.org/online-resources/buildings-of-chicago/wrigley-building/): exterior/clock photograph, west-of-Michigan site, white terra cotta, linked buildings.
- [Building owner Zeller: Legacy](https://zeller.us/thewrigleybuilding/legacy/): trapezoidal south block, Giralda-inspired tower, molded terra-cotta details, upper colonnade/cupola and connecting third-/14th-floor walkways. Owner detail photograph `IMG_4278-copy-1-1.jpg` used as a visual reference only.
- Existing [OSM relation 17460539](https://www.openstreetmap.org/relation/17460539) outlines in `city.json` and `route-inventory.csv`: both block footprints, heights 132/94.5 m. Existing Chicago OSM attribution applies.

Blender XY uses the actual mapped outlines relative to Chicago world
(-40, 8, -530), with Blender +Y pointing north. The former separate landmark
was positioned east of Michigan and south of these footprints; it is not a
geometry reference. Outline-derived massing, modeled windows/sills/lintels,
cornices/urns, four clock dials with Roman numerals/hands, colonnade, cupola,
north pavilion and connecting bridges replace its painted blocks.

Bay counts, roof subdivisions, relief carvings and exact bridge positions are
stylized interpretations, not surveyed elevations. Clocks retain the existing
5.969 m diameter convention and use a static display. Small creatures and
individual sculpted figures are omitted. No photograph pixels are included.
