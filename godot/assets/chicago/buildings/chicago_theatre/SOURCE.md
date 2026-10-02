# Chicago Theatre / Page Brothers exterior models

Original Blender-authored interpretations for Racing Sim, 2026-10-01.
No full-building photograph is used as a runtime material. The editable sources
are `tools/blender/authored/chicago_theatre.blend` and `page_brothers.blend`;
rebuild both with `tools/blender/chicago_theatre.py` (see its command header).

Theatre: 99,142 triangles, 11 material surfaces. Page Brothers: 14,424 triangles,
5 material surfaces. Repeated details are joined by material at export.
Origins are the State Street frontage midpoint, ground at zero, glTF +Y up.
Footprint IDs are OSM w124873919 and w124873930; frontage roof medians are
27.5 m in the existing USGS data. Ornament and backstage massing are authored
approximations, not an architectural survey. Interiors are not modelled.

References:

- [Chicago Architecture Center: Chicago Theatre](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-theatre)
- [Daniel Schwen: Chicago Theatre blend](https://commons.wikimedia.org/wiki/File:Chicago_Theatre_blend.jpg), CC BY-SA 4.0, already credited; visual reference only, no pixels copied into these models.
- [Chicago Landmarks: Page Brothers](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1393)
- Existing `trackgen/data/chicago/city.json` footprints and measured roof returns;
  provenance is in the Chicago data README.

Online acquisition checked first: the Free3D Theatre asset covers only the signs
and is paid; the Polycam scan's usable download was not verified. Neither is used.
