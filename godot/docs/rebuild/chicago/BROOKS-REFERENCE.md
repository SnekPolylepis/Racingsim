# Brooks Building candidate

Mapped w73766157: approximately46.8m east/west by31.2m north/south,
centre(-861.3,769.8),city height57m not independently verified.
Owner confirms12stories:
https://marcrealty.com/223-w-jackson-blvd-office-space-chicago/
City identifies1909-1910,Holabird & Roche,orange-brown/green terracotta:
https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1255

Owner brochure cover photograph inspected2026-10-04 via PDF render:
https://marcrealty.com/wp-content/uploads/2025/04/223_MB_Building_Basic.pdf
Large grouped windows,thin terracotta piers,lighter two-story retail base,
green upper frieze and projecting cornice. Photo is reference only; no
photograph embedded or redistributed as a facade texture. Window counts,
entrance and dimensions require closer reference inspection before authoring.

Native Grid review exit0,empty stderr. Corrected inherited road-height filter:
closest route camera(-873.9678,7.440593,756.976),inside the mapped footprint.
Upward view shows surrounding skyline rather than Brooks frontage. Inspect
city.excluded before adding this model. Candidate boundary-distance0.4m is
not proof of visibility or placement clearance.

Confirmed native city metadata:Brooks and McKinlock,Franklin-Van Buren
Parking Garage,and225 West Wacker are excluded for authored route clearance.
Do not place a full mapped Brooks footprint over the current driving corridor.
Retain this candidate for a later fit/route-placement pass.


## Connector correction — 2026-10-08

Earlier exclusion evidence above is retained. Current cache174/original@v6/
Grid@v4 connector follows VanBuren/Franklin, leaving Brooks mapped footprint
14.682m from both1m-sampled centrelines. Generic frontage now visible beside
FranklinGarage in production source day/night driving views. Both full clip
scans and20car/mode laps pass. Author Brooks from primaryowner/city references
next; prior excluded-camera snapshots do not describe current visibility.


### 2026-10-08 — Brooks physical trackside exterior

Brooks replaces generic w73766157 once at (-861.3,8,769.8), retaining the
five-vertex mapped foundation. Blender source and GLB:93044tri/ten materials.
Owner and City landmark photos inform five Franklin/eight Jackson bays,
three recessed panes per bay, ribbed piers, tiled spandrels, pale two-storey
retail base, green frieze/caps, projecting cornice and red Jackson awnings.
Twelve storeys follow the owner description; mapped57m height remains provisional.
Small cap/frieze reliefs are photo-fit silhouettes, not exact sculpted replicas.
Entrance bay, rear treatment and roof configuration remain unverified.
Cache175; original@v6/Grid@v4 and route geometry unchanged.

Mac Godot4.6.2 M4 Forward+ source checks: Brooks31, menu113, authoredcoverage23,
Franklin25 andparse pass (192assertions plusparse). First Brooks check caught
an incorrect17m test envelope around the north awnings (actual17.312m); the
explicit17.5m awning bound and unchanged other bounds pass on rerun1.8s.
No geometry reduced to satisfy the test. Preceding menu113 ran73.2s.

Remaining trackside exteriors, finer civic reliefs/seals and broader performance
review remain open; river bridges queued. No export or new driving-lap run:
route unchanged, preceding20 clean car/mode cases retained as dated evidence.

Both full native5m/five-offset clip scans pass: Grid107/original110 accepted
overhead hits, zero failures, exit0/empty stderr. Initial eight High source views
completed exit0/empty stderr; seven inspected views show the Brooks exterior.
The first Jackson camera was inside a neighbouring building; its image is not
appearance evidence. Corrected Jackson day view inspected; a full rerender
hit180s after three daylight images. Single corrected Jackson night review
follows separately. Frozen renders do not establish frame-time acceptance.

Corrected Jackson night single-view source capture completed exit0/empty stderr
and was inspected. Final eight High day/night corner/Franklin/Jackson/route
images reviewed in rebuild/screenshots/chicago-brooks-mac/. Original successful
set plus corrected Jackson captures supplies appearance evidence; timed-out
multi-view rerun remains recorded above. Next close candidate:300SouthWacker,
with primary architect/owner references in chicago/WACKER-300-REFERENCE.md.
