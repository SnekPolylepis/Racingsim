# 311 West Monroe / Harris Bank Operations Center reference

## Primary sources read and images inspected, 2026-10-08

- [CVU building record](https://www.skyscrapercenter.com/building/west-monroe-partners-hq/36374): address311WestMonroe, architectural/tip62.5m, occupied51.6m,15floors, retrofit2017-2019. Listed completion1973 conflicts with original architect's August1970 account; preserve that uncertainty.
- [Original architect Epstein historical account](https://www.epsteinglobal.com/news/throwback-thursday-harris-trust-and-savings-bank):15stories, reinforced concrete/tinted glass/granite, approximately28000sqft floorplates, service core/restrooms along north wall. The text refers to August1970 completion. Actual entrance/detail page image and historical full facade/aerial image inspected in browser. Continuous narrow projecting piers, recessed rectangular sashes, lower meeting rail, deep ground arcade/piers and blank upper granite band. Historical image is not evidence of current entrance signage.
- [Renovation architect Perkins&Will](https://perkinswill.com/project/311-west-monroe/):2019completion, entrance canopy, retail, large operable conference windows on top floor and new high-albedo roof. Actual exterior photo311wMonroe_cs_8185Ccrop.jpg inspected: broad top-floor glazed groups with light metal frames beneath blank ribbed granite roof band; original narrow granite piers continue below. Main hero photo is interior, not a facade reference.
- [Renovated upper exterior photo](https://perkinswill.com/wp-content/uploads/2020/06/311wMonroe_cs_8185Ccrop.jpg): primary published photograph, capture date/photographer not established by page. No photograph may be treated as an exact survey.

## Mapped target and next authoring

w147350188, mapped eight-vertex nearly rectangular footprint with small south notch. Mapped210m height contradicts CVU62.5m/15floor record, so use62.5m for authored architectural tip. Proposed origin(-938.85,8,499.1), retain mapped plan, no global footprint edits. PriorityCSV Grid10.4m atstation6675 is not a final mesh-clearance result. Source/blender searches found no authored replacement for this ID at checkpoint7910c87.

Author an original Blender exterior using existing architecture helpers: continuous granite piers, recessed tinted glass/physical sash rails and granite spandrels; distinct wider glazed top-floor groups and solid upper band; tall ground arcade with recessed shop/entrance glazing. Preserve actual footprint and buried foundation. Roof/base/floor intervals and bay dimensions must be documented as photo-fit until measured; CVU occupied height does not directly specify the roof slab height. Historical north core suggests different treatment but lacks current full-north facade evidence.

Current production remains cache203/Original@v7/Grid@v5; no model integrated for311WestMonroe yet. No executable export. Next complete before-view review, then original authoring/native stage review before fixture replacement/geometry/menu/coverage/fullclips/production review.

Before review: initial camera landed inside a neighboring generic block, so its captures were rejected. Corrected camera(-941,12,460), target(-938.85,90,499.1); final actual day/night views inspected show visible generic block without authored granite piers/top-floor treatment. NativePID162068exit0/empty stderr/terminalMONROE311 CITY REVIEW PASS; cache203 loaded, candidate not excluded. Frozen6.47ms is not driving performance. Evidence chicago-monroe311-before.

## 2026-10-08 original exterior draft

Original editable Blender model and GLB63,552tri/seven materials saved. Retained eight-vertex mapped footprint/origin(-938.85,8,499.1). Physical continuous granite piers, narrower recessed sash glazing/meeting rails, broader ground piers, broad grouped top-floor glazing/metal frames, blank ribbed granite upper band and light roof membrane. Architectural tip62.5m.

Working intervals: ground6m, thirteen regular floors to51.6m, top floor51.6-56.9m, roof band56.9-62.5m. These are a photo-fit interpretation, not measured floors; occupied-height definition alone does not prove the slab location. Bay spacing approximately2.4m, top groups approximately8m. Main facade treatment provisionally carried around all returns; north core arrangement remains unverified. North canopy/location/door stiles provisional; exact entrance and ground arcade depth need current reference refinement. Roof equipment not authored yet.

Blender exited0/finite-vertex authoring assert passed; a one-object material group produced a harmless 'No mesh data to join' warning before successful seven-material GLB export. Godot editor import exited0/empty stderr. Native stagePID163748 and basePID164140 exited0/empty stderr/terminalMONROE311 STAGED REVIEW PASS. Four actual front/crown day/night stage views and two base day/night views inspected; saved chicago-monroe311-draft. Isolated low ambient stage views do not verify production night switching or graphics modes.

Not integrated. Next refine ground arcade/entrance and roof references, then fixture replacement/geometry/menu/coverage/fullclips and production review. Cache203/routes unchanged/no EXE.

## 2026-10-08 ground arcade refinement

Ground panes recessed from0.62m to1.10m, frames/door stiles moved with them. First close review exposed daylight side gaps behind shallow columns. Extended broad ground piers to1.80m depth and added previously missing end piers; final close day/night images inspected show those open vertical corner gaps closed. A small isolated ground-plane white fleck remains in this baseline stage image; not investigated or claimed fixed.

Current mesh63,624tri/seven materials. Finite-vertex authoring assert/Blender export exit0, final editor importexit0/empty stderr, native stage164456/base169928exit0/empty stderr/terminalPASS. Two final close base views saved chicago-monroe311-base-refined. Previous broad day/night evidence remains the initial draft, not a new all-view acceptance claim. Exact canopy/entrance location, roof equipment/proportions/returns still open. Working draft not integrated; production cache203 unchanged/no EXE.

## 2026-10-08 owner brochure bay/canopy refinement

Read [Sterling Bay brochure](https://sterlingbay.com/wp-content/uploads/2021/11/WMPHQ_Brochure_20NOV2020.pdf), filename20NOV2020. Page2 gives15stories,25-30ft column spacing and11ft6in slab spacing (3.5052m, consistent with draft3.5077m upper intervals). Page6 floor plan/upper exterior and page7 lobby photo actually rendered and inspected. Plan shows roughly30 narrow perimeter bays per main face, prompting draft bay target1.65m instead of2.4m; broad ground piers every fifth bay approximate8.25m, within the owner's structural-column range. Approximate bay counting is not an exact survey. Core shown at left under upward north marker conflicts with Epstein north-wall account; facade/core orientation remains unresolved rather than inferred as certain.

Lobby view looking out shows metal canopy underside ribs; added seven photo-fit ribs/front fascia to provisional north canopy. Its precise location/dimensions still unverified. No roof equipment layout established. Current90,216tri/seven materials. Blender finite-vertexassert/exit0; importexit0/empty stderr; final native stage165324/base135032exit0/empty stderr/terminalPASS. Four final actual broad-front/base day/night views inspected, evidence chicago-monroe311-bays. Fine bright baseline-stage edge marks remain visible; need diagnostic before claiming closure/aliasing solved. Not installed/cache203 unchanged/no EXE.
