# Peoples Gas — authored exterior work in progress

Original Blender geometry intended as CC0, canonical source
tools/blender/chicago_peoples_gas.py. No facade photographs or downloaded model
embedded. Draft is not yet integrated or installed.

References inspected 2026-10-04:
- https://www.skyscrapercenter.com/building/peoples-gas-building/26977 :
  current published height92 m /20 floors (mapped city.json h93).
- https://commons.wikimedia.org/wiki/File:Peoples_Gas_Bldg_typical_floor_plan.png :
  1915 Architectural Record reproduction of D.H. Burnham & Co. typical floor
  plan, public domain. Viewed in browser; main central open court and smaller
  north light court visible. Not redistributed.
- https://commons.wikimedia.org/wiki/File:Peoples_Gas_Company_Building_122_South_Michigan_Avenue.jpg :
  Beyond My Ken original photo, CC BY-SA/GFDL, reference-only browser inspection.
  Paired windows, broad stone corner piers, base and upper engaged colonnades
  inform independently authored geometry.
- https://nara-media.s3.amazonaws.com/electronic-records/rg-079/NPS_IL/84000293.pdf :
  National Register nomination description returned as search text. PDF open
  failed (47 MB); no claim of inspected page images. Description gives 13
  Michigan/11 Adams bays, 60x70 ft court enlarged above floor16 to98x76 ft,
  Ionic granite base columns and terracotta upper colonnade floors17–20.
  It describes21 stories, differing from current CVU20. Uses current height92.
- https://npgallery.nps.gov/AssetDetail/NRIS/84000293 : nomination index;
  first download is an undigitized-record placeholder, not a usable plan.
- https://www.dougalbuildingmaintenance.com/portfolio/peoples-gas-building/ :
  restoration contractor description and Peoples-Gas-Building-4.jpg original
  photograph inspected in browser at native size. Base rectangular windows
  alternate with carved circular medallions; corrected earlier all-oculus draft.
  Contractor confirms ornamental lions at the top. Photograph not redistributed.

Mapped r15953438, x[-71.8,-18.6], z[513.3,575.0]. Draft W51.0 EW/D60.0 NS,
H92 above street, underground foundation8 m. Intended centre(-45.2,8,544.15),
yaw .022 rad; remains to verify against actual driving views and footprint.
Draft native asset:254,256 triangles /10 authored material groups. Model build
and import exit0, empty stderr; third standalone native review exit0, empty
stderr, east/roof/entry views inspected. Actual trackside day/night review
still required. Imported bounds(-25.98,-8,-30.375), size(52.21,100,61.105).
Box geometry is
batched by material before creating scene objects, preserving individual geometry.
Plan court dimensions converted from feet; roof outline/light-court positioning,
story elevations and decorative proportions are approximations. North party
wall and smaller shared light court are modeled; exact notch dimensions, bronze
entry replicas and figural lion reliefs still require refinement. Draft upper parapet follows present restrained
outline rather than reconstructing the removed historic overhanging cornice.
