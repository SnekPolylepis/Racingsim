# Chicago source and verification notes

2026-09-30, `rb/monaco-formula-cars`. Reference evidence is separate from
completed visual verification in `CHICAGO-DONE.md`.

## Measured geometry

- USGS 3DEP Cook County 2017 acquisition, LAS 2019 publication:
  https://s3-us-west-2.amazonaws.com/usgs-lidar-public/USGS_LPC_IL_4County_Cook_2017_LAS_2019/ept.json
  `fetch_lidar.py` reads public Entwine tiles and produces one-metre DSM/DTM.
  The full-city request covers latitude 41.87177718289615–41.90905080848005,
  longitude -87.6490282886797–-87.59876760801352. Acquisition date matters:
  buildings constructed later need OSM parts or other dated source geometry.
  First-surface DSM includes vegetation; it is not automatically a surveyed roof.

## Lower Wacker

- Benesch / Chicago DOT engineers, *Wacker Drive*, ASPIRE Fall 2012:
  https://www.aspirebridge.com/magazine/2012Fall/WackerDrive.pdf
  Use the cross-sections and construction photographs to validate deck,
  clearance, girder and column layout. Current generated tunnel dimensions
  have not yet been checked against these drawings.
- Existing race-route connectors are authored circuit geometry, as stated in
  `trackgen/data/chicago/route.json`; they must not be described as a survey.

## Pritzker Pavilion

- Fabricator Zahner:
  https://azahner.com/projects/pritzker-pavilion/
  Documents 24 column covers, six feet in diameter, heights ranging from
  twelve to over twenty-four feet, heavy-gauge stainless steel. This supports
  column material and diameter, but does not establish individual coordinates.
  Locate columns from map/photographic evidence before placing them.
  Reference photographs are copyrighted; viewing them does not grant an asset licence.
- Public Building Commission:
  https://www.pbcchicago.com/projects/jay-pritzker-pavilion/
- Steel fabrication reference:
  https://www.cmrp.com/uploads/millennium_tour_brochure_lores.pdf

## Wrigley clock faces

- BLDG.51 museum's salvaged-building record:
  https://bldg51.com/2017/06/07/original-cream-colored-wrigley-building-ornamental-terra-cotta-fragment-joins-bldg-51-museum-collection/
  Records four dials with diameter 19 feet 7 inches. Generated dials use
  5.969 metres; their current attachment follows the existing tower walls.
  Static displayed time is 10:10, not a claim about a historical photograph.
- Ken Lund's 2013 building photograph and metadata:
  https://commons.wikimedia.org/wiki/File:Wrigley_Building,_Chicago,_Illinois_(9179449469).jpg
  Reference only; no photograph pixels have been incorporated into assets.
  The photograph is CC BY-SA 2.0 if subsequently used as an asset.

## Baseline findings requiring fixes

The `chi-goal-baseline-*` images are in the game's user-data folder.
Inspected Michigan north day, river night, Pritzker day and Wrigley day.
The pavilion trellis lacks supports and its dense cell-neighbour links do not
prove the real pipe layout. The Wrigley view missed its clock; the capture tool
now points at the generated tower and provides a separate clock close-up.
The previous capture's throttle assignment was overwritten by the normal
controls update. Its stationary screenshots did not demonstrate driving.
The revised tool injects a held configured throttle key and fails below five
metres of displacement; car and physics source remain untouched.
