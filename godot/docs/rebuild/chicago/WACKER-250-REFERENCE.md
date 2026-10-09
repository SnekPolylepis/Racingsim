# 250 South Wacker working draft — 2026-10-08

Primary references inspected: [Main Architecture project](https://www.main-architecture.com/Architecture-Projects.aspx?property=250+S.+Wacker&type=Commercial), [David A Seglin renovation portfolio](https://archinect.com/people/project/24033126/250-s-wacker-drive-usa/28750143), and [CVU building record](https://www.skyscrapercenter.com/sydney/awa-tower/14260) (the page identifies 250 South Wacker despite its unrelated URL slug).

Main Architecture's published exterior is a design rendering. Seglin's portfolio includes design views, a small as-built exterior photograph, lobby photographs, plans and low-resolution elevations. These support the tall white corner feature, horizontal glazing wings and white flank treatment; they are not a measured exterior survey. Portfolio text describes renovated metal/opaque white glass cladding, a reglazed entry atrium and a sixteenth-floor terrace. CVU reports 61.3 m / 15 floors; the architect describes sixteen stories. That discrepancy remains unresolved.

Draft uses mapped seven-vertex footprint w147350207, origin (-1070.15,8,712.55), no yaw. Published 61.3 m replaces the unverified mapped 65.5 m for this working model. Main body 57.5 m, ground interval 6.6 m, fourteen upper rows and the corner feature dimensions are provisional photo-fit interpretations. Separate panes, frames, metal spandrels and opaque panel joints are physical geometry. No reference photograph is embedded as a facade texture.

63,312 triangles / seven materials, Blender source and GLB saved. Not installed in Chicago; production cache remains 200. Corrected before views show the generic building from outside Willis Tower. Four staged day/night views rendered successfully. These isolated views do not establish production lighting, placement acceptance or driving performance.

Open: entrance atrium/doors, prominent white side strips, roof terrace, measured floor/base proportions, remaining bright dashed marks along floor bands and corner panel joints. Marks persist with directional shadows disabled; moving intersecting joint/head planes did not resolve them. No root cause or final fix claimed. Current diagnostic image predates the last small plane separation; current four draft views follow it. No executable export.

## 2026-10-08 — white flank and entry refinement

Added the two broad white flanks shown in Main Architecture's design rendering, north double-height atrium glazing, paired door leaves, jambs, transom and handles. Entrance outward direction corrected and actual close day/night native views inspected. These remain photo-fit design interpretations, not measured/as-built entrance validation. Replaced individual bay spandrel boxes with continuous floor bands and limited uprights to glazing heights: current model 47,736 triangles/seven materials. Removed unnecessary intersecting band pieces while keeping physical facade detail.

Controlled diagnostics: fully matte materials, high mesh LOD bias and disabled mesh compression each retained the marks. Compression override reverted. MSAA4x plus TAA removes the dashed appearance in an actual inspected crown view, supporting thin-detail aliasing rather than proving a geometry corruption. That diagnostic predates the final door-direction correction, which affects the entry only. Game graphics settings were not changed; its native setting uses MSAA2x and retro modes disable it, so appearance across those modes remains unverified. Baseline four stage views still expose aliasing. Roof terrace, measured floor/base/white-panel proportions, fuller entrance recess and production placement/lighting/graphics-mode review remain open.

Final Blender/import/stage/entry runs exited 0; Godot stderr empty and both reviews reported WACKER250 STAGED REVIEW PASS. Four flank stage views and two final close entry views inspected; evidence in screenshots/chicago-wacker250-flanks. Not integrated; production cache200 unchanged. No executable.

## 2026-10-08 — production integration / cache201

Working authored exterior installed at the mapped origin in the shared Chicago landmark loader; generic w147350207 excluded once. Night glazing uses the established Chicago emission toggles. Source model remains 47,736tri/seven materials. Routes retain original@v7/Grid@v5.

Final six gates (215826,120s): geometry21, menu119, coverage23, Original clip1, Grid clip1 plus clean parse; all PASS. Both clipping totals remain Original120/Grid104 and all six stderr files were empty. Geometry rays establish exposed recessed glazing, higher white feature, lower white flank and ground atrium; mapped foundation clearance10.68066m/10.68043m Original/Grid. This does not prove full architectural fidelity. Initial test run caught a duplicate test variable; after fixing it a glazing ray hit a frame gap, so its x-coordinate moved from-5.3 to-6.4 within the adjacent pane. Final source tests pass; no prior failures hidden.

Native production review PID137000 exited0, empty stderr, WACKER250 CITY REVIEW PASS. Actual four street/crown day/night images inspected. White corner/flanks and glass bands read in the surrounding scenery; sparse occupied panes illuminate at night. Close stage alias marks are substantially reduced in these production views, but retro modes were not separately captured. Frozen10.41ms is not driving-performance evidence. Screenshot record chicago-wacker250-installed.

Re-read the low-resolution architect plan/elevation sheet: insufficient evidence for precise roof terrace position/details, so no invented terrace was added. Roof terrace, panel/floor proportions, fuller atrium/as-built confirmation and retro-resolution review remain open. No executable export or full-building completion claim.
