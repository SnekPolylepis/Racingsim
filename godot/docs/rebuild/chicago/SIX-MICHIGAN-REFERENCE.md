# Six North Michigan: reference and native baseline

2026-10-09; next trackside building. No matching authored GLB, Blender author or shared fixture/exclusion found in current source.

Mapped w126982631, stone86.5m, exact footprint[[-23.7,260.0],[-23.6,287.5],[-73.1,288.2],[-73.4,260.3]], planned origin(-48.5,8,274.4). Keep exact foundation, estimate Grid clearance11m/station320 from priority inventory; measure both routes before installing.

## Primary references actually read

[CVU](https://www.skyscrapercenter.com/chicago/6-north-michigan/11145/) lists architectural/tip86m, occupied79.6m,22floors, completion1899; aliases Montgomery Ward & Company Building/TowerBuilding. Use current86m envelope rather than historical clock tower silhouette. Floor intervals, body/crown split and original tower history are not established by these metrics.

[Renovation contractor Leopardo](https://leopardo.com/projects/six-north-michigan/) reports renovation across21floors,129units/110000sqft and built1898. These differ from CVU's22floors/1899 completion; keep separate evidence, do not silently reconcile. Renovation attribution JohnBurgerDesignStudio versus CVU JohnBergerDesignStudio also differs.

Actually inspected [contractor exterior photo](https://leopardo.com/wp-content/uploads/2010/06/6-N-Michigan_1-scaled.jpg): pale stone lower levels/cornices, warm brick continuous piers, grouped narrow windows/stone surrounds, horizontal decorated spandrels, projecting body cornice, central raised crown partly clipped by image. Broad lower body is long along Madison/short facing Michigan. Crown, exact bay counts/floor split/entrance/roof equipment need closer reference before modeling. Contractor hero/photo6-North-Michigan_1 are interiors, not complete exterior reference.

[Former redeveloper Beitler](https://beitlerre.com/historic) actually read: historical architecture preserved through repositioning; its6NMimage is an INTERIOR arched room, not roof/cornice exterior. Do not infer exterior dimensions from it.

[Photographer Sean Flynn,2017-05-14](https://www.hmdb.org/PhotoFullSize.asp?PhotoID=763703) full photo actually opened: distant overall skyline, building just left of tree; provides only weak overall crown silhouette, no close ornament/roof equipment evidence. Observedimage https://www.hmdb.org/Photos7/763/Photo763703o.jpg?820202421900PM . No external photograph copied into assets.

## Actual native baseline

Source Godot PID20252exit0/empty stderr/terminalSIXMICHIGAN CITY REVIEW PASS, Gridcache205 saved. Actual streetday/night images inspected in ../screenshots/chicago-sixmichigan-before: current generic uniform windows/block lacks stone base/brick-pier distinction, projecting cornice and raised crown. Camera(-7,12,300) aim(-48.5,48,274.4); upper cropped by framing, not proof of complete roof. Frozen16.34ms is not driving performance. Surrounding skyline remains unaudited. No production geometry changed/no EXE.

Next: close crown/base reference, author distinct stone base/brick piers/window groups and raised crown in Blender using existing helpers, exact footprint and86m envelope; photo-fit intervals must remain labelled. Draft source review before shared integration/gates.

## Closer current crown reference — 2026-10-09

Actually inspected SteveMinor completefacadephoto https://flickr.com/photos/sminor/7221832754 (taken2010-03-25/upload2012-05-18), observedimage https://live.staticflickr.com/7082/7221832754_8f4c2e7013.jpg . Eastface9windowsacross, centralbrickstrips/flankingstonewindowgroups; abovebodycornice raisedcentralcrownwiththreearchedwindows, cornice/dentils and rectangularuppercapwiththreecircularreliefs. This corrects the earlier croppedreference's insufficientcrown evidence. Groundentrypartlyhiddenbytrees; exactdepths/heightintervals/roofequipment/unseenreturns remainunverified. HistoricalHMDB763698 is circa1900/1906, notcurrentgeometryreference. BrokerShowcasePDF denieddirectdownload/webreaderreports10.8MBlimit, noPDFcontentsinspected/claimed.

## Authored draft and crown-core fix

Original Blender study151,356tri/eightmaterials, finitevertexassert/exit0; exactmappedfoundation/currentpublished86menvelope retained. Base12m/body68m/16regularrows/tower68–86m are photo-fit, not measured. Physical recessedglass/sashes/stone surrounds, brickpiers, reliefspandrels/cornices/dentils, three-bay archedcrown and rectangularcap/circularreliefs authored. Firstdraft had solidcrowncore concealing recessedglass; insetcore90%X/88%Y repaired actualvisibility. Initialpreview45448started beforeGLB existed and was stopped(-1/resourceerror); successful correctedimportexit0/native56964exit0/empty stderr/terminalPASS. Actualfinalfrontday/crownday/crownnight images inspected and saved; visiblecrown glazing now ahead of backing. Finalgeometry59152exit0/empty stderr16checksPASS:8nophotomaterials,86mtip,24groundopaque rays/cornerbacking, crownrayfirsthitglass rather than opaque core, exact4pointfootprint, foundation23.60166Original/10.93482Grid. Fullbody/roof proportions, finecarving, entry and hiddenreturns/roofequipment remainopen; notinstalled/cache205unchanged/noEXE.
