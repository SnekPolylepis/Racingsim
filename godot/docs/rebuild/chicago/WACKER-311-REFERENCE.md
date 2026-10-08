# 311 South Wacker — next close trackside exterior

Current native5m candidate: w1473502087.7m from Grid station6170. This is not
visibility or placement acceptance. city.json retains a22-point foundation
including the western winter-garden wing, x[-998.9,-906.9],z[771.9,861.4],
mapped height292.5m. Inspect neighbouring Brooks/garage and route before fitting.
No authored Blender exterior for this ID is integrated at this checkpoint.

Primary references reviewed2026-10-08:
- [KPF architect project](https://www.kpf.com/project/311-south-wacker-drive):293m/961ft; two-level85ft glass-roofed winter garden, flamed Texas red granite and polished strapping, bands at13/46, octagonal tower, open Gothic crown frame and five glazed cylinders that light at night. Primary exterior photographs linked on the page.
- [Harbour contractor project](https://www.harbour-cm.com/work/311-south-wacker/):65storeys,105ft translucent crown with four lower glazed masses; winter garden and construction drawings/images. Ignore potentially stale skyscraper rankings.

Published dimensions, mapped292.5m height and photo-fit crown/base proportions
require reconciliation; do not invent measured glazing/cylinder layout.
Retain mapped foundation and winter-garden wing rather than modeling a generic
tower on the broad union footprint. Actual source day/night checks required.

## Blender draft checkpoint — 2026-10-08

Original editable model now exists in `tools/blender/authored/wacker_311.blend`,
with generator `tools/blender/chicago_wacker_311.py` and exported
`assets/chicago/landmarks/wacker_311.glb`: 568,996 triangles, 13 materials.
Retains the 22-point mapped foundation, separate lower blades, octagonal tower,
five curved crown cylinders and western glazed barrel-roof winter garden with
physical frames, palms and fountain basin. Facade panes, jambs and rails remain
physical geometry; batching their boxes by material resolved an actual 180s
Blender timeout without reducing geometry. Generation assertions and import pass.

Standalone actual Godot 4.6.2/M4 Metal Forward+ draft render inspected; capture
exit0. This is a shape review with neutral lighting, not production day/night
acceptance. Crown framing, illuminated materials, base connections and the
Gem of the Lakes sculpture need further reference fitting. No track replacement,
cache revision or driving-surface change is included in this checkpoint. Next:
refine crown/base, integrate at mapped origin, then both-layout source day/night
review and footprint/clipping checks. No executable export.

## Integrated draft source review — 2026-10-08

`Scenery/Wacker311` at(-928,8,817), exact mapped fallback excluded once;
cache182, original@v7/Grid@v5 unchanged. Physical exterior and clear winter
garden integrated; explicit warm office/fixture emissions and pale fluorescent
crown replace the initially too-dim imported emission. Day extinguishes them.
Both packed-cache validators require the new node and13material surfaces.

Mac Godot4.6.2/M4 Metal Forward+: building37checks and parse pass; menu115
passes. Both full native5m/five-offset clip scans pass: Grid103/original120
accepted overhead hits, zero failures, exit0/empty stderr. 311 never receives a
building exemption. Native1m retained-foundation clearance7.599956original and
7.599406Grid. Eight final actual High source images inspected: Grid full tower
and winter garden day/night, both-layout driver-height facade views day/night.
All bounded two-view capture jobs exit0/empty stderr. Initial night crown was
too dim and re-rendered after correcting the emission colour. Images live in
`docs/rebuild/screenshots/chicago-wacker311-mac/`.

This is an integrated fidelity draft, not final architectural acceptance.
Crown framing/band calibration, base/entrance connections and sculpture remain.
No driving geometry or timing changed; prior lap runs remain dated evidence,
not a new lap claim. No app export, manual-wheel, Intel or frame-time claim.

Final broader run: all38headless Chicago suites pass148.8s, including both
road geometry49checks, menu115, building37 and authoredcoverage23. Parse passed
separately. Windowed clipping/capture evidence is recorded above. Full game
suites and lap baselines were not rerun for this scenery-only integration.
