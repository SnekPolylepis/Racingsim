# Board of Trade exterior study (not yet installed in the track)

Original Blender geometry authored in `tools/blender/chicago_board_of_trade.py`;
editable source in `tools/blender/authored/board_of_trade.blend`. No photo pixels
or downloaded model geometry are included. This is an exterior study awaiting
whole-city placement, refinement and runtime verification.

References consulted 2026-10-03:

- [Building owner's history](https://www.cbotbuilding.com/history/): 13-foot
  LaSalle clock and 31-foot aluminum Ceres. Owner photographs show the roof,
  its seams and the statue's dress and arms.
- [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-board-of-trade-building):
  limestone piers, recessed windows/spandrels, throne massing, pyramidal roof
  and sculptural details. Eric Allix Rogers clock photograph used for reference.
- Existing OSM w28951633 in `trackgen/data/chicago/city.json` and its entry in
  `route-inventory.csv`: the combined footprint includes later south/east wings;
  its centroid is not the centre of the historic north tower.

Proposed historic north-building origin: (-653, 8, 788), with north towards
negative Godot Z. Approximate north block 52 x 72 metres. Existing landmark pin
(-671.166, 8, 679.052) is displaced from the mapped structure. Do not use the
compound centroid (-629.9, 834.4) to position the historic north tower.

Setback heights, bay counts and sculptural shapes are approximate. Hooded clock
figures/eagle are simplified silhouettes. Upper ornament, entrance details and
modern south/east additions still require authoring/review. The draft does not replace the shipped runtime
model until placement, geometry and day/night game views are verified.
