# 225 West Wacker exterior

Original geometry authored in Blender by `tools/blender/chicago_wacker_225.py`;
editable `tools/blender/authored/wacker_225.blend`, runtime `wacker_225.glb`.
No source photograph, third-party logo or purchased mesh is embedded.

Reference inspected 2026-10-08:

- Building owner, [225 West Wacker](https://www.225westwacker.org/): 31 stories,
  375 ft, 1989, renovation 2021. Owner figures differ from the mapped 126.5 m.
- Photographer Michael Davis, [225 West Wacker Drive](https://www.flickr.com/photos/perspectivephotography/3935592473),
  2009: clear elevated full-building view, four corner turrets and central
  barrel roof. Photographer caption gives 433 ft, another unresolved height.
- Chicago Architecture Today, [Exterior 2](https://www.flickr.com/photos/chicagoarchitecturetoday/8401452098/)
  and [Exterior 4](https://www.flickr.com/photos/chicagoarchitecturetoday/8401458030/),
  2013: paired vertical glazing channels, granite piers, coursed spandrels,
  upper stepped glazing and street frontage. Photographs are references only.
- Renovation architect [Valerio Dewalt Train](https://www.buildordie.com/225-w-wacker):
  Wacker half rotunda, Franklin main entrance, replacement curtain wall;
  interior photos show round pale columns, wood screens and exposed lights.
- [KPF renovation](https://www.kpf.com/project/225-west-wacker-drive-interior-renovation):
  lobby circulation and linked entrances; original completion stated as 1990.

Placement uses OSM w64391366 from checked-in `city.json`, origin
(-886, 8, -164.75), seven-vertex foundation preserved. Geometry uses mapped
126.5 m as provisional overall finial height, not a verified measurement.
Floor heights, piers, turret sizes, vault, lobby and roof dimensions are
photo-fit estimates. Fine turret ribs, frontage proportions and current lobby
configuration need further refinement. Thirty-one-story reference informs
27 office rows, ground/upper podium and crown glazing; no measured floor plan.

Primary photos establish the distinctive roof and façade; incidental Nuveen
river photos include neighboring towers and are not sufficient identification
on their own. No reference-image licensing is implied by authoring geometry.

Mac review uses source Godot 4.6.2, M4/Metal, High Grid day/night. The frozen
BotLine station 4785 camera is (-901.8246, 4.8288, -213.0615): Lower Wacker
near the foundation, not Upper Wacker street level. Direct look toward the
building is wall-occluded; forward view has substantial wall occlusion. This
is evidence of a clearance/review issue, not proof of complete trackside
visibility or safe vehicle clearance. Do not shift/hide the building based
only on the distance ranking. Check neighboring stations and physical road
clearance before calling this model finished.

## Clearance correction — 2026-10-08

The earlier cache169 observation above is retained as dated evidence. Native
full-course scans confirmed wall intersections in both layouts. Route controls
now follow the mapped bend north of the foundation. `osm-roads.json` way
124538336 supplies the Lower Wacker westbound point(-919.3,-228.6); way
253716332 supplies the other mapped carriageway. Upper control(-917.9,-225.3)
is an authored centre between these split carriageways, not a surveyed line.
Building geometry/footprint was retained. New identities chicago@v5 and
chicago_grid@v3 separate records after this geometry change, cache171.

One-metre route samples give approximately17.1m(Grid) and14.4m(original)
centreline-to-footprint minimums; both full-course 5m/five-lateral-ray clipping
scans pass after removing the broad Wacker-building overhead exemption. Ten
High day/night source captures inspected in chicago-wacker225-clearance-mac:
Grid approach/corner/exit and original Upper Wacker forward/building views.
The deck screens the upper building from Lower Wacker as expected; upper view
shows its actual frontage behind the race fence. Sampled checks are recorded
evidence, not proof of surveyed road dimensions or every possible vehicle path.


## Crown refinement — 2026-10-08 Mac

Michael Davis aerial reference above guides pale silver painted stepped square
shoulders, four-sided fins/circular turret caps, enclosed side glazing under
the barrel vault, open end ties/braces and raised side service terraces.
Cabinet layout and roof dimensions are photo-fit estimates; no equipment
identification or survey claim. Existing foundation/height discrepancy remains.
Blender168016tri/nine materials; cache172. Native Godot4.6.2/M4 building38,
menu109 and parse pass; both 5m/five-offset full clip scans pass with zero
failures (Grid107/original114 accepted overhead hits). Six High day/night
street/tower/crown views inspected: docs/rebuild/screenshots/chicago-wacker225-crown-mac/.
No app export or performance acceptance. Remaining trackside work stays active.
