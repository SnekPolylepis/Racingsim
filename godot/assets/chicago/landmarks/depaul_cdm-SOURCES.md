# DePaul CDM Center exterior draft

Original authored geometry CC0, Blender source/.blend in tools/blender.
No facade photo embedded or redistributed.

Owner building page and full corner photograph inspected2026-10-05:
https://resources.depaul.edu/campus-maps/buildings/Pages/cdm-center.aspx
https://resources.depaul.edu/campus-maps/buildings/PublishingImages/cdm.jpg
Owner identifies243SouthWabash,built1916,acquired1981.
Restoration contractor primary sheet, photograph actually inspected via local
PDF render (reference only, ignored tests/logs/cdm-restoration.pdf/.png):
https://www.nrsys.com/site/wp-content/uploads/16-Facades-Masonry-Restoration-DePaul-CDM-1.pdf
Nine-story steel-framed masonry/terracotta building; restoration of south
and west elevations,cornice and southwest corner. Photo shows upper grouped
sashes,terracotta spandrel panels and rooftop masonry/service equipment.

Draft: south nine bays,west five bays,seven office rows (four middle rows
with edge singles and three upper rows of triples),narrow mezzanine windows,
separate retail panes and southwest recessed doors,projecting cornices,
two blue university signboards with physical lettering. Pane/bay counts and
sign/door placement approximate from owner photo; full joint texture,terra
cotta relief and roof service equipment not yet replicated.
Mappedw35601477 footprint approx52.2x29m centre(-99.85,702.45); mapped58m
height not independently verified. Draft39m is a photo-proportion estimate,
not a survey or verified architectural height. Plain north/east party walls.
Local-Y frontage exports Godot+Z/south; local-X west is also modeled.

Native Grid baseline reviewPID136324 completed,CITY REVIEW PASS/empty stderr,
no exclusion forw35601477. Route camera(-99.28468,9.3,726.7522) faces existing
generic frontage. Street-day/entrance-day captures inspected. Frozen32.026ms/
57.176M primitives is not controlled driving performance.

Second Blender buildPID134088 exit0,58,800tri/8materials. Import exit0;
model reviewPID138224 exit0/empty stderr. Four standalone front/corner/entry/
roof captures inspected. Bounds53.078x47x29.878 including foundation/trim/signs.
Corrected clear full-bay glazing in front of deep entry,filled roof-head strip,
added raised lettering. Not integrated; placement,geometry/menu/both clipping
scans and runtime day/night review pending. No EXE export.

Integrated source review2026-10-05: centre(-99.85,8,702.45),yaw.022,
cache140; mappedw35601477 replaced explicitly once. Geometry17/menu95/
coverage23/parse pass (gates/20261005-205956,88s); Original/Grid clipping
scans and parse pass (gates/20261005-210031,77s), no new failures against
111/101 baseline hits. Eight street/corner/south-retail/west-entry day/night
views inspected. Initial south close-up camera was inside a building across
the road; excluded from acceptance and corrected to the route camera.
Final native reviewPID43248 exit0,CITY REVIEW PASS/empty stderr. Frozen
9.407ms/33.247M primitives is not controlled drive performance. No EXE.
Approximate dimensions,ornament and roof service equipment limits remain
as recorded above; earlier draft notes are historical build evidence.
