# Spa visual polish — 2026-09-30

The surveyed centreline, road widths, banking, elevation, runoff collision and lap identity are preserved. `trackgen/spa_landmarks.gd` adds authored visual architecture to the existing circuit generator: a longer F1 garage with an upper glazed terrace, bay frames/shutters, roof balustrades and lettering; a larger Raidillon grandstand with a continuous canopy and rear VIP glazing; a covered Endurance grandstand on the descent; a paddock office silhouette by Bus Stop, transporters/team awnings and circuit/event boards. These are recognisable approximations informed by reference photographs and circuit information, not surveyed replicas. Buildings and stand areas reserve crown clearance from scattered trees. Ardennes forest bands are denser and use a summer tint.

Spa's kerbs now have their own red/yellow Wallonia stripe texture. Belgian black/yellow/red perimeter paint is added around Eau Rouge–Raidillon and Bus Stop, without changing the underlying drivable surface. Existing licensed tree cards, road materials and scenery mesh builders are reused; no reference photographs or third-party model downloads are included by this helper.

Primary references consulted:

- [Circuit overview](https://www.spa-francorchamps.be/en/the-circuit): modern Raidillon covered grandstand, 4,600 places.
- [2023 Endurance opening](https://www.spa-francorchamps.be/en/news/325_the-endurance-grandstand-and-terraces-are-open-to-the-public): grandstand/terraces on the La Source descent.
- [Endurance construction announcement](https://www.spa-francorchamps.be/en/news/295_construction-works-on-the-endurance-grandstand-and-terraces-have-begun-at-the-circuit-of-spa-francor): 4,104-seat grandstand.
- [Formula 1 terrace](https://www.spa-francorchamps.be/en/directory/rooms/224_formula-1-terrace): terrace on pit-building roof, overlooking start line and La Source.
- [2022 track colours](https://www.spa-francorchamps.be/en/news/275_the-spa-francorchamps-track-is-decked-out-in-new-colours): red/yellow Wallonia kerbs and Belgian flag runoff colours at Raidillon and Bus Stop.
- [Official paddock access map](https://www.spa-francorchamps.be/assets/6bb9f494-1cc0-43b8-9d6f-ef93bc8701e3/plan-parking-2025.pdf): venue organisation and paddock context.

Validation command from the workspace root:

```sh
godot/tools/Godot.app/Contents/MacOS/Godot --headless --path godot --script tests/v2/spa_landmarks.gd
```

This builds the complete asset, checks its track contract, required landmarks and paint, and the unchanged 6999.732 m lap length. Separate main-game screenshot/drive evidence belongs in the branch's final validation record; this content guard alone does not establish visual or driving acceptance.

## Final visual review follow-up

Reviewed 20 day and 20 Afterhours whole-lap captures (350 m spacing), plus nine named corner/pit views. Dense mixed Ardennes silhouettes, broadleaf summer tint, red/yellow kerbs and paddock structures are consistent around the lap. Grandstand canopies had cancelling smooth normals on opposing faces: flat face normals remove the triangle lighting artefact, confirmed in the fresh pit-straight capture. The scenery suite now checks canopy normal magnitude. This is an authored PS2-era venue approximation, not a surveyed architectural replica.

Affected follow-up suites: scenery 13 checks and Spa landmarks 13 checks, zero failures. Captures end with the existing ObjectDB cleanup warning; no script errors.

## Close-up continuation

Paddock transporters now use native 12-sided cylindrical tyres/hubs and include cab glazing, mirrors, lights, steps, rear doors and side rails. The existing SurfaceTool mesh batches remain; no assets or dependencies added. Fresh main-game paddock capture in `screenshots/chicago-spa-polish/detail-pass/`. The landmark suite now has 14 passing checks, including round tyre geometry and axle width.
