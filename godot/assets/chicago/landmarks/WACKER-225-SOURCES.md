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
