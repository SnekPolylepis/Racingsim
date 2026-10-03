# 35 East Wacker / Jewelers Building — original exterior

Original Blender geometry authored for Racing Sim, 2026-10-03. Original geometry
may be reused under CC0. No reference photographs or drawing pixels are included
in the GLB. Editable source: tools/blender/authored/jewelers_building.blend;
authoring script: tools/blender/chicago_jewelers_building.py.

Design references inspected on 2026-10-03:
- City of Chicago landmark listing, north elevation and northeast corner clock:
  https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?counter=2&lanId=1233
  https://webapps1.chicago.gov/landmarksweb/static/images/photos/7171.jpeg
  https://webapps1.chicago.gov/landmarksweb/static/images/photos/7174.jpeg
- Council on Vertical Urbanism / Skyscraper Center: 159.4 m architectural height,
  40 floors; full shaft, dome coffers and lantern photographs viewed in browser:
  https://www.skyscrapercenter.com/building/35-east-wacker-drive/3398
  https://s3.amazonaws.com/images.skyscrapercenter.com/thumbs/69103_500x650.jpg
  https://s3.amazonaws.com/images.skyscrapercenter.com/thumbs/24674_500x650.jpg
- Goettsch Partners renovation project PDF: street entrances/storefronts and
  bronze details. Text read; web screenshot retrieval timed out, not used as
  visual proof: https://www.gpchicago.com/architecture/35-east-wacker-drive/pdf/
- Original 1926 tower section attribution inspected (not copied into assets):
  https://commons.wikimedia.org/wiki/File:Jewelers_Building_tower_cross_section.png

Mapped placement uses existing city.json OSM w124865488 (~50.4 x 44.3 m), origin
(-198.2, 8, -192.35) and 0.006 rad yaw. Existing USGS roof grid has a major 88.5 m
plateau, used for the main office block roof. Authored top is 159.4 m above the
model base. Floor spacing, tower setbacks, carvings, corner tank screens and
Father Time sculpture are reference-guided approximations, not measured as-built
survey data. Published floor counts vary (GP says 38); the visually distinct
facade groups are modelled independently of tenancy/floor numbering.

Features: continuous raised piers, paired recessed glazing and sash, rounded
upper window heads, layered projecting cornices, terrace roof, four open
colonnaded corner turrets with small domes, stepped upper shaft, glazed drum,
Doric columns and corner buttresses, ribbed/coffered dome, north street entrance,
mesh address lettering and projecting northeast corner clock. All rendered
surfaces are geometry/materials; no full-building photo panel. Night occupied
windows (selected office bays, with other panes left unlit), clock dial and
restrained cornice/dome accents toggle through ChicagoNight. The exact mapped generic
building is excluded in both Chicago layouts to avoid a duplicate body.
