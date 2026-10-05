# Trackside-first exterior work

Owner direction 2026-10-04: prioritize all buildings and scenery beside the
driving route before distant buildings. Existing individual exteriors stay in
place; the next work targets generic frontage, entrances, roofs and nearby props.

TRACKSIDE-PRIORITY.csv lists 242 mapped building footprints whose boundary is
within 50 m of either current route, sampled from chicago.gd route_curve at 5 m
intervals (@v4 / Grid @v2). Distance is horizontal centreline-to-footprint-edge,
not car-to-facade distance, surveyed clearance, proof of visibility or proof that
a building is rendered. Names/address fields reuse route-inventory.csv metadata;
height is current city.json data, not newly verified height. Individual replacement
status and renderer exclusions must be inspected before modeling. This list
includes already authored buildings and footprints that may be excluded.

Native 2026-10-04 review puts Monroe (9.3 m) first, then Peoples Gas/122 South
Michigan (9.6 m). Both dominate immediate street-level car views. 333 West Wacker
(13.3 m horizontal) is nearest to the lower deck; the closest street-level camera
is at (-896.881,9.3,174.61), much farther away and screened by neighbors. Defer
its full exterior behind direct frontage despite the existing reference research.
Continue with
Old Republic (6.6 m) and 333 North Michigan (8.8 m), alongside unnamed immediate
frontages in the CSV. These are work candidates, not a claim that the rest of the
trackside inventory is complete. Review actual driving views before choosing
each exterior. Distant skyline work follows this pass.
