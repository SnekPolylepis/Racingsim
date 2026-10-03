# Board of Trade authored exterior

Original Blender geometry in `tools/blender/chicago_board_of_trade.py`;
editable source in `tools/blender/authored/board_of_trade.blend`. No photograph
pixels or downloaded model geometry are included.

References consulted 2026-10-03:

- [Building owner's history](https://www.cbotbuilding.com/history/): 13-foot
  LaSalle clock and 31-foot aluminum Ceres. Owner photographs show the roof,
  its seams and the statue's dress and arms.
- [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-board-of-trade-building):
  limestone piers, recessed windows/spandrels, throne massing, pyramidal roof
  and sculptural details. Eric Allix Rogers clock and north street photographs
  used for reference.
- [CME's 2006 restoration notice](https://www.cmegroup.com/media-room/press-releases/2006/9/20/chicago_board_oftradetobehonoredforlandmarkrestoration.html):
  23-storey Murphy/Jahn south addition and five-storey Fujikawa Johnson east addition.
- [FJG architect's project sheet](https://www.fjgarchitects.com/commercial-building/chicago-board-of-trade-expansion-building):
  tall east trading-floor curtain walls, limestone piers and the raised span
  over the LaSalle plaza. Reference photographs remain outside shipped assets.
- Existing OSM w28951633 in `trackgen/data/chicago/city.json` and its entry in
  `route-inventory.csv`: the combined footprint includes the later wings;
  its centroid is not the centre of the historic north tower. Existing USGS
  roof cells give south-region median 88.5 m and east-region median 40.5 m.
  South office body 82 m plus stepped roof; east hall roof 40.5 m.

Historic north-building origin: (-653, 8, 788), north towards negative Godot Z.
Approximate north block 52 x 72 metres. Previous landmark pin
(-671.166, 8, 679.052) is displaced from the mapped structure. Compound centroid
(-629.9, 834.4) must not position the historic north tower. South wing local
centre (0, 60); east hall (81, 47); raised connector (36, 47) above 12.3 m.

Setback heights, bay counts and sculptural shapes are approximate. Hooded clock
figures/eagle and Ceres are original simplified sculptures. Crown reliefs are
geometric grain motifs rather than exact carving reproductions. South roof
terraces, atrium, entrance details and minor footprint steps are stylized.
Mapped massing, recessed windows, sash/spandrel geometry, inscriptions and
roof seams replace the previous flat facade blocks/triangular roof approximation.

Native night toggle enables occupied windows, clock dial and low-level limestone/Ceres
floodlighting; daylight disables those accent emissions. Exact ID exclusion
removes the generic compound in both Chicago layouts.

The authoring plan uses +Y south, then mirrors Y before glTF export (+Y-up maps
Blender +Y to Godot -Z). Text receives its own horizontal correction and face
winding follows the transform determinant, preserving readable north lettering.
