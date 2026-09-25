# Console-era circuit presentation

The target is a 2003-2006 console *presentation* with original content: GT4 by day (Nürburgring
Nordschleife, Spa or another European circuit), NFS Underground at night (amber sodium light, glow,
wet-road reflection), rendered with modern lighting underneath. The era is expressed through the
raster, dither, palette-limited/photographic-source textures, card foliage and silhouette budgets —
not by restricting how light is evaluated; see PS2-REFERENCE.md and PS2-FOLLOWUP-REPORT.md for the
superseded native-UI build's acceptance history and the pre-rebuild research it recorded.

**Look-0 (2026-09-25) rewrote this document from measured evidence.** The owner's complaint — the game
reads as "a devbox, not a game": flat grey stretched road, sparse single-colour cone trees, a wide flat
grass plain, a bare empty horizon, no white edge lines, a Nordschleife that feels flat instead of sunk
into the landscape — is confirmed by direct code inspection and fresh captures (`docs/art/baseline/`,
taken 2026-09-25 through the real presentation chain, `tests/v2/track_screenshots.gd`), compared against
real reference frames in `docs/art/reference/` (see that folder's README for what's there and what
isn't: collection was cut short mid-session by an infrastructure outage). **Review (Claude Opus 5.5,
2026-09-24):** the board was completed with seven GT4 Nordschleife frames, including an official October
2004 press shot, and six NFS Underground night frames (`gt4-nordschleife-*`, `gt4-car-detail-slr.jpg`,
`nfsu-night-*`). Several rules below were corrected against them and against the owner's direction:
sharp, photographic textures; detailed cars; no empty horizon.

**Every rule below is checkable against a screenshot and cites the reference or measurement it came
from.** Where a rule cites a baseline file, re-run `tests/v2/track_screenshots.gd --compare` after a
change and look at the new `<shot>-compare.png` before claiming the rule is met.

## What was wrong with the old guidance

The previous version of this document said: *"Twenty-one 128/256-pixel build outputs use CLUT4/CLUT8 or
RGB555-expanded colours."* That is still descriptive of `assets/ps2/*.png` today — `asphalt_track_diff.png`
is a 256x256 **palette-indexed** image — but treating "PS2 look" as "low-resolution, palette-reduced,
therefore blurry and flat" was the root mistake. Opening the file shows why: it is near-uniform dark
noise with no rubber line, no seams, no patch repairs, no stains — nothing for the road shader to
modulate. Real PS2 racers did not look flat because their textures were small or indexed; GT4's own
in-game captures (`docs/art/reference/gt4-unidentified-*.jpg`) show **high-contrast, photographically-
sourced** surfaces with real tonal range, and a 256-colour palette can hold plenty of that contrast — the
lost detail from indexing is in colour *count*, not in luminance variation or apparent sharpness. Low
resolution and a reduced palette are console-era production constraints, not an instruction to paint
everything one flat mid-grey. The fix is photographic source detail, not a
blur. **Owner direction (2026-09-24):** textures must be sharp. Road, grass, kerb, armco, tree and
building textures are authored at 1024-2048 px from photographic sources. The console character comes
from the output chain (Look-3's 640x448 raster, dither, optional RGB555), not from shrinking source
textures. Palette-reducing a texture is allowed only when it does not visibly soften it.

## Road

**Texture and texel density.** `road_v2.gdshader` tiles `asphalt_track_diff.png` (256x256) with
`tile = 0.32` against UVs in metres (`UV.y` is arc-distance): one full vertical repeat covers `1/0.32 ≈
3.1 m` of road, giving **≈82 texels/m longitudinally**. Laterally, `UV.x` is clamped to `±1.3 ×
half_width` and scaled by 2.5, so one repeat covers roughly `0.4 × half_width` metres — **≈128
texels/m** across a typical 10 m-wide road (`scripts/track/ps2_materials.gd`, `shaders/road_v2.gdshader`
lines 12, 29-31). **That density is too low.** It comes from one 256 px tile repeated every 3 m, so the road has no
large-scale structure. GT4's Nordschleife road (`gt4-nordschleife-chase-kerbs-armco.jpg`,
`-bonnet-forest-wall.jpg`, `-official-press-overview.jpg`) shows repair patches several metres long,
tar seams, darker tyre lines and even painted fan graffiti, all readable at driving distance. **Rule:**
a photo-sourced asphalt set (albedo, roughness, normal) of at least 1024 px (2048 preferred), about 250+
texels/m at the camera, plus a second, non-repeating macro layer (patches and repairs at 5-30 m scale)
so the road never visibly tiles. The measured problem, measured directly
(`docs/art/reference/../color_stats` methodology, cropped to the road surface only, avoiding
sky/car/grass so the road's own contrast isn't diluted by the rest of the frame):

| | mean saturation | luminance std-dev (contrast) |
|---|---:|---:|
| Reference road patch (`real-nordschleife-flugplatz.jpg`, tarmac only) | 0.072 | 0.078 |
| Our road patch (`baseline/ns-flugplatz.png`, tarmac only) | 0.157 | 0.036 |
| GT4 road patches (`gt4-nordschleife-chase-kerbs-armco`, `-bonnet-forest-wall`, `-chase-edge-lines`, `-official-press-overview`) | 0.14-0.37 | 0.056-0.143 |

**Acceptance number:** a road-only crop of any baseline shot must reach luminance std-dev ≥ 0.07 (GT4's
lower range) without raising mean saturation above 0.20.

Real asphalt is close to neutral grey (low saturation) with real luminance variance (patches, rubber,
wear). Ours is **more saturated than real asphalt** (picking up ambient/sun tint the flat texture can't
resist) and has **less than half the real contrast**. Rule: the road albedo texture needs authored
luminance variation (patches at a scale of metres, a visible rubber line ±0.6 m either side of the
racing line, seams every ~4-5 m matching real paving-slab spacing) and a desaturated base (`Color(.22,
.22, .24)`-ish neutral, not a tinted grey) so contrast comes from luminance, not hue.

**Matte vs gloss by day.** `look-tracks` (2026-09-24) already lowered day metallic to 0.08 and roughness
to 0.5-0.64 specifically to kill a glare stripe; that's correct and matches the reference (no gloss
highlight on dry GT4/real-world tarmac in daylight — `real-nordschleife-adenauer-forst.jpg`,
`gt4-unidentified-cockpit-view.jpg`). Keep it matte by day; night gloss/reflectivity is unchanged
(Look-2, below).

**Edge lines: absent.** There is no edge-line rendering anywhere in `road_v2.gdshader` or
`road_builder.gd` — the only "paint mask" in the codebase (`ps2_materials.gd` line 43,
`ground.gdshader`) selects grass/gravel/runoff *surface type*, not a visible line. Every reference frame
with a road edge shows a continuous painted white line, roughly 0.10-0.15 m wide by scale
(`real-nordschleife-flugplatz.jpg`, `real-nordschleife-adenauer-forst.jpg`,
`real-nordschleife-brunnchen.jpg`). This is the single most visible missing rule and a likely top
contributor to the "flat" read: **add a white edge line, ~0.12 m wide, just inside the kerb/verge
boundary**, in the road mesh's UV space so it doesn't need new geometry.

**Other markings seen in reference.** Brünnchen shows painted corner-name lettering directly on the
tarmac; not required, but if trackside signage is ever authored on the road surface (vs. a board), match
that precedent rather than a modern sponsor logo.

## Kerbs

`road_builder.gd::kerb_texture()` returns a 1x2-pixel, nearest-filtered texture: red `(.85, .15, .12)`
over white `(.95, .95, .95)`, tiled along the kerb band (default width 0.9 m, height 0.070 m on the
Nordschleife; Spa varies 0.6-1.8 m). This is the right idea in miniature — every reference frame with a
kerb shows exactly this two-colour alternating stripe (`real-nordschleife-flugplatz.jpg` at the crest
apex, `real-nordschleife-adenauer-forst.jpg`, `real-nordschleife-brunnchen.jpg`) — but `ns-flugplatz.png`
in the baseline shows no visible kerb colour at that specific camera angle/station, which needs checking
against the actual corner apex station rather than the shot's approach point used here. Rule, unchanged
from what's implemented, just confirmed against reference: red/white alternating, roughly 0.9 m band
width, low profile (under 10 cm) — verify visually at the apex station itself, not just the approach.

## Trackside enclosure

**Distances, Nordschleife (current generator, `trackgen/nordschleife_s1.gd`, NS-section part 1,
2026-09-24):** 0.5-2.5 m grass shoulder, 1.5 m verge, armco 0.3 m beyond the verge (≈2.3 m off the
tarmac), forest starting 1.5 m past the verge at 34 trees/100 m (near band, to 18 m) then 22/100 m
(deep band, 18-120 m), trees cleared only within 9.5 m of centreline. That is now genuinely tight — road
edge to armco to forest wall in well under 5 m — and it shows in the baseline: `ns-flugplatz.png`'s
armco and tree line sit close on both sides, matching the reference's proportions reasonably well. The
gap that remains (see the `ns-flugplatz-compare.png` side-by-side) is **canopy closure**: the reference
shows an unbroken wall of foliage with no sky visible through it, while ours has visible sky gaps between
individual tree cards even at 34/100 m, because each card is a single flat cone with no canopy overlap
or varied height. Rule: either raise near-band density further or vary tree height/card width randomly
enough that adjacent canopies overlap and close the gaps, rather than reading as individually placed
cones.

**Distances, Spa (`trackgen/spa.gd`):** deliberately wider — verge 7-35 m, forest starting 12 m off the
verge at 18/100 m (near) and 24/100 m (deep, to 180 m), plus a far belt (`ArdennesFar`, 14/100 m,
110-260 m) behind the paddock/La Source/Eau Rouge so distant hills aren't bare. This width is correct
for Spa's real modern runoffs (not a bug to match the Nordschleife's tightness) but the far belt's
density should be checked against a real Spa or Ardennes-forest reference the same way Flugplatz was —
none is in the reference board yet (`Look-0-refs`, QUEUE.md).

**Barrier types.** Corrugated armco throughout, confirmed against every close reference photo. No tyre
walls or concrete walls are visible in the current Nordschleife/Spa captures; GT4 and real photos show
tyre walls at some corners (not captured here) — out of scope for this rewrite, flagged for Look-5.

**Nordschleife banks and cuttings.** Fixed by NS-section part 2 (2026-09-24): the terrain is
rebuilt from the 1 m DGM1 tiles at 5 m, and it blends to the road over 6 m instead of 30 m, so real
banks and cuttings meet the verge (`real-nordschleife-flugplatz.jpg`, `-brunnchen.jpg` are the
check). The road's own elevation keys are still 20 m apart. **Barriers** (GT4 frames): double or
triple armco rails on dark posts, about 0.75-1 m tall, 1-3 m from the tarmac, continuous through most
corners (`gt4-nordschleife-chase-kerbs-armco.jpg`, `-bonnet-forest-wall.jpg`). Ours is a single
ribbed band; make it rails on posts.

## Horizon and enclosure

`scripts/retro_assets.gd::panorama()` generates the sky procedurally: a 256x128 vertical gradient
(`top` to `horizon` colour, a `pow(v*2, .65)` falloff) plus a sine-noise cloud band. **There is no
distant silhouette layer at all** — no hills, no tree line, no horizon geometry beyond the gradient.
`pg-start.png` in the baseline shows this directly: flat pale sky meeting a flat grass plain with a few
isolated blob shapes (structures) and nothing else out to the horizon. This is a direct, confirmed
contributor to "bare empty horizon". Every reference frame with a horizon (`real-nordschleife-
overview-autumn.jpg`, `real-nordschleife-panorama-banking.jpg`, `spa-*` baseline shots) shows a distant
tree-line or hill silhouette breaking the sky. Rule: add a distant silhouette (a cheap billboard ring or
painted-into-the-sky-texture tree/hill line) at the world's edge, even a single flat colour band, so the
horizon isn't a hard sky/ground cut.

**Fog.** *(Look-6 fixed this.)* Day fog used to run from 150 m to 2.4 km (`game.gd::apply_time_of_day()`,
look-tracks), which exposed the bare horizon the owner objects to; it now ends at 1.15 km with `camera.far`
1250 and full density at the end, and `RetroAssets.hills_panorama()` paints three wooded-hill ridges into the
sky (Ardennes, Eifel, generic), by day hazy toward the fog colour, at night dark against the lit horizon. The old game's roughly 1 km closed the world in.
**Rule:** day fog should end at about 1-1.2 km, and a forested-hill silhouette layer should sit at the
fog distance, so from track level there is always treeline or hills against the sky, never a flat
cut. GT4's overview (`gt4-nordschleife-official-press-overview.jpg`) shows forested hills filling the
distance.

## Colour and light

**Measured, `docs/art/reference/color_stats.py`-style script (HSV saturation, Rec. 709 luminance, on the
full frame, thumbnailed to 512 px):**

| Set | mean saturation | mean luminance | luminance std-dev |
|---|---:|---:|---:|
| Reference (7 real photos + 2 GT4 shots) | 0.251 | 0.379 | 0.219 |
| Our Proving Ground (9 baseline shots) | 0.192 | 0.485 | 0.217 |
| Our Spa (9 baseline shots) | 0.229 | 0.421 | 0.206 |
| Our Nordschleife (8 baseline shots) | 0.304 | 0.319 | 0.223 |

At the whole-frame level our numbers are **not dramatically off** — contrary to the "everything reads as
one flat mid-value" assumption, overall luminance spread is within a few percent of the reference set,
and Nordschleife's saturation is if anything higher than the reference mean. This matters: it means the
flatness the owner is seeing is not a global tonemap/exposure problem, it's concentrated in specific
surfaces (the road, per the road-patch measurement above) and in missing detail layers (edge lines,
canopy closure, horizon silhouette) rather than a wrong global colour grade. Don't "fix" this with a
blanket saturation/contrast push; fix the specific surfaces above.

**Shadow depth and sky treatment:** `apply_time_of_day()`'s comment already documents the fix history
correctly — ambient `9db7d6` (cool, weak, energy 0.42) against sun `ffd79a` (warm, energy 1.5) — and
this matches the GT4 photo-mode reference (`gt4-unidentified-photomode-car.jpg`), which shows a warm-lit
car against a distinctly cooler, flatter background. No change needed here; it's already right and now
has a reference frame confirming it.

**Nights (NFS Underground)**, from `nfsu-night-*.jpg` (mean saturation 0.28, luminance 0.20,
std-dev 0.15 over three frames). **Look-9 (2026-09-25) implemented and measured this section:**
- **Wet road streaks.** `road_v2.gdshader` already had per-lamp streaks (Look-2, driven by
  `track_lights.gd`'s baked `lamp_data`). Look-9 added a second, independent streak standing in for the
  car's own headlights: a camera-proximity glow using Godot's built-in `CAMERA_POSITION_WORLD`, narrow
  across the road (reuses the shader's existing lateral term) and fading over about 26 m — no per-frame
  uniform plumbing needed, since the camera always tracks the car. It reads clearly in every baseline
  shot as a bright pool stretching from the car toward the horizon
  (`docs/rebuild/screenshots/look-9/nordschleife-start.png`, `spa-pit-straight.png`), matching
  `nfsu-night-wet-street-reflections.jpg`'s signature look. Grip never changes with it (unchanged from
  Look-2). PS2-style approximation, not a real reflection, per the task's own framing — lit trackside
  structures don't separately feed this system, a known gap (below).
- **No black void.** New `shaders/night_glow.gdshader` / `scripts/track/night_glow.gd`: a shared facade
  material for `pit_building.gd`/`grandstand.gd`/`gantry.gd`/`billboards.gd` (material swap only —
  their geometry-building code is untouched). On near-vertical faces at Afterhours, a saturated surface
  (a gantry start light, a billboard's printed stripe) glows in its own colour, and a desaturated wall
  (concrete, doors, steel) gets a procedural amber window grid keyed off world position, so no UV
  changes were needed in any builder. Confirmed working with a close-up day/night comparison: a
  billboard's red/blue panel is flat and matte by day, clearly backlit at night, identical geometry.
  Zero added draw calls (same meshes, only the material differs). Combined with the hill silhouette
  (Look-6, dark against the lit sky at night) this is what keeps the horizon from reading as empty.
- **Colour, measured** (`docs/art/reference/color_stats.py` on the 9 fixed
  `docs/rebuild/screenshots/look-9/` shots, excluding the day-comparison frame):

  | | mean saturation | mean luminance |
  |---|---:|---:|
  | NFSU target (`nfsu-night-*.jpg`) | 0.28 | 0.20 |
  | Before Look-9 | 0.36 | 0.17 |
  | After Look-9 | 0.31 | 0.21 |

  Tuned in three measured rounds: the night sky's top colour (`retro_assets.gd::panorama()`, was
  `0b1035`, saturation 0.79 — much more saturated purple than the NFSU frames' dark blue-grey), the
  `hills_panorama()` forest-ridge colour (was `0b121c`, saturation 0.61), the night ambient
  (`56628c`→`656e8c`, energy .34→.40 for luminance) and the moon light colour (`8ca6df`→`a1b4df`) —
  same hues throughout, lower saturation, per `apply_time_of_day()`. Landed close on the open circuits
  (Proving Ground 0.27-0.31, Spa 0.25-0.30) but the Nordschleife's dense forest enclosure stayed near
  0.41 regardless of ambient/moon colour changes: with the sky mostly hidden by canopy, the tree cards'
  own photographic albedo (vertex-lit, so it doesn't re-hue much with the light tint) dominates more
  than ambient colour does — and NFSU has no forest-circuit reference to check this specific case
  against, only city streets. Acceptable but not fully closed; see the gap table.
- **Speed blur.** Already generic and active, day and night: Look-3's `retro_renderer.gd` history blend
  (`speed_blur` setting × car speed above 20 m/s) needed no Look-9 changes. Verified still firing by
  inspection of the render chain, not rebuilt.

**Cost, before → after Look-9** (`tests/v2/night_screenshots.gd`'s 9 fixed shots, Linux cloud,
llvmpipe software GL — absolute ms aren't meaningful across hardware, but the delta is): draw calls
identical shot-for-shot both before and after (624, 615, 432, 628, 575, 548, 645, 657, 490) — the
headlight streak is pure shader math on the existing road mesh and `night_glow` is a material swap, so
neither adds geometry or draw calls. GPU ms moved within measurement noise (±0.3 ms, no consistent
direction). A full-lap Spa sweep (1050 frames, chase view every 20 m, vsync off) after Look-9: mean
8.61 ms GPU, worst 25.82 ms, worst 684 draw calls — no comparable before number exists (that run hit the
capture script's timeout before reaching the sweep in the pre-Look-9 baseline).

## Cars

Current mesh budgets (`tests/v2/car_models.gd`): MX-5 NA 5,032 triangles, GT 3,744, 296 GT3 8,466. The
bodies are procedural lofts (`scripts/cars/`). **Correction:** the first draft said cars were "not the
problem". The owner disagrees and has asked for a real Miata body model (CAR-01). GT4's cars are
showpieces: `gt4-car-detail-slr.jpg` shows smooth curved panels, panel gaps, glass with reflections,
detailed lamps and wheels. **Rule:** each car uses a proper modelled body (15-40k triangles is fine on
current hardware), with correct proportions, real glass, lamp and wheel detail, and a paint material with
clear-coat reflection. Judge it at chase distance and in a 3/4 garage view against the GT4 frame.

## Gap table

Ranked by how much each one makes the game look like a devbox rather than a rendered circuit, from the
baseline captures and the measurements above:

| # | Gap | Where it stands today | What must change |
|---|---|---|---|
| 1 | **Fixed (Look-8):** white 0.12 m edge lines, 0.25 m inside each tarmac edge (RoadBuilder UV2 edge distance) — was: no white edge line anywhere on the road | Confirmed absent in `road_v2.gdshader`/`road_builder.gd`; every reference frame has one | Add a ~0.12 m painted edge line in the road UV space |
| 2 | **Mostly fixed (Look-8):** 2K photo asphalt tiled in metres, macro drift, stains, repair patches and seams; road-crop contrast 0.078-0.097 (target ≥ 0.07) in three of four views, saturation 0.21-0.27 still a little over 0.20 — was: road surface has less than half the real luminance contrast, and is more saturated (tinted) than real asphalt | Measured: contrast 0.036 vs reference 0.078; saturation 0.157 vs reference 0.072 | Author luminance variation (patches, rubber line, paving seams) into `asphalt_track_diff.png`; desaturate the base tone |
| 3 | ~~No distant horizon silhouette~~ **Done (Look-6)** | `RetroAssets.hills_panorama()` paints three forested ridges per circuit into the sky (Ardennes, Eifel, generic), day and night; before: `baseline` at Look-0 | Tune ridge height/colour against real Spa and Eifel photos when one is on the board |
| 4 | ~~Canopy doesn't close~~ **Done (Look-6)** | Cards 8-30 m tall, widths jittered up to 1.4x, near band 56/100 m on the Nordschleife (34 before), 28/100 m at Spa (18); `ns-hatzenbach` reads as GT4's forest wall | Still open: ground-level undergrowth is thin between trunks; a dedicated fern/bramble card would close it |
| 5 | ~~Trees are flat single-colour cone cards~~ **Done (Look-6)** | One 2048 px atlas of nine CC0 Poly Haven cut-outs (spruce, fir, one deciduous, bush; THIRD-PARTY.md), instanced from one MultiMesh per band with a per-instance atlas cell and tint | More deciduous species (only one card today) if the owner wants a beech-heavy Eifel |
| 6 | ~~Cars are procedural low-poly lofts~~ **Done (CAR-01), one of three** | The MX-5 NA is a credited real model (23,264 tri exterior); GT and 296 GT3 are still procedural lofts | A real body for GT and 296 GT3 if the owner wants the whole grid modelled |
| 7 | ~~Armco is a single ribbed band~~ **Done (Look-7)** | Double/triple corrugated rails on dark posts, 0.45-0.9 m tall, ≤3 m post spacing | — |
| 8 | ~~Day fog to 2.4 km exposes a bare horizon~~ **Done (Look-6)** | Fog end 1.15 km, `camera.far` 1250, density 1.0 at the end; the hill ridges take over where the fog closes | — |
| 9 | ~~No NFS Underground night presentation~~ **Done (Look-9)** | Camera-proximity headlight streak, glowing trackside structures (`night_glow.gdshader`), colour tuned to sat 0.31/lum 0.21 against the NFSU target of 0.28/0.20 | Nordschleife's forested night views still measure sat ~0.41 (see "Nights", above) — no forest-circuit NFSU reference exists to tune against; lit structures don't yet feed the road's wet-streak system, only lamps and the car's own headlights do |
| — | Nordschleife sat on the terrain (no banks/cuttings) | **Fixed** by NS-section part 2: DGM1 at 5 m, 6 m blend | — |

Not ranked (out of this round's evidence): barrier-type variety (tyre walls), Spa's far-forest density
against a real photo, kerb visibility at exact apex stations rather than approach shots (K-01/K-01b is
tracking a proper kerb retrace).

## Output and UI

`retro_renderer.gd` owns a world SubViewport, quarter-size glow, alternating world-history targets, transparent UI SubViewport and alternating final output targets. Default SD stores 640×448 pixels and presents at 4:3 or anamorphic 16:9. Godot 4.6 has no anisotropic camera projection, and `camera_set_transform` orthonormalizes, so the earlier X-scaled camera transform never took effect (Look-3 found SD stretched 24 % at 16:9). The 3D raster is now square-pixel at the presentation aspect (796×448 at 16:9) and the history pass resamples it into the 640×448 anamorphic store; 480i resamples the same 448-line world into one 640×224 field. Enhanced 720p/Native use square-pixel rasters at the chosen aspect throughout.

Authentic UI uses a 1280×896 logical canvas rendered to 640×448: 32 logical font pixels become 16 internal pixels. Glyphs rasterize at their logical size and are minified into the 640×448 target, which keeps 12-pixel HUD captions legible (with glyphs rasterized at 16 px, "VALID" read as "VAUD"). It joins the output after world-only motion persistence/glow. Sharp UI renders at the presentation's physical resolution and overlays the output. The whole v2 UI (HUD, front end, settings, garage, dialogs) shares that viewport. Mouse events transform into the UI canvas; embedded dialogs use that viewport. No CPU frame readback occurs during gameplay. Daytime glow is restrained (threshold 0.88, strength 0.4) so sunlit tarmac runoff does not bloom over the road; night keeps 0.64/1.1 for lamps. Look-3 wires all of this into the v2 game (ARCHITECTURE.md, "Presentation chain").

Default 480p component retains 24-bit colour. Optional RGB555 framebuffer quantization/dithering is independent of texture palettes. 480i uses a 640×224 world field, three-tap vertical deflicker and alternating retained lines at nominal 59.94 fields/s. CRT/composite averages chroma separately from luma with a mild mask. These reproduce selected visual behaviours, not a GS, CRT or electrical NTSC signal bit-for-bit.

## Materials, art and budgets

Twenty-one 128/256-pixel build outputs use CLUT4/CLUT8 or RGB555-expanded colours (`assets/ps2/*.png`). The manifest records dimensions, palette counts, nominal GS-style bytes and hashes. Godot expands them on import; mip chains and bilinear filtering remain enabled. Raw CC0/source art and reference imagery are excluded from export. THIRD-PARTY records Rajdhani OFL typography and existing surface textures. **This 128/256 px set is superseded** (see "What was wrong with the old guidance"): new surface textures are 1024-2048 px photographic sources, and the console look comes from the output chain.

Ground, road and painted surfaces shade per pixel, which is what makes their normal maps contribute at all; under the previous vertex lighting those maps were loaded and sampled but could not affect the image. Alpha-tested card geometry (foliage, fences) stays vertex-lit deliberately: crossed cards carry no meaningful normals, and shading them per pixel washes the canopy out to tan. Daylight bloom stays restrained and night glare stronger. Road UVs preserve lateral/arc-distance, rubber line, texture grain and authored lamp pools/reflection streaks; night appearance never changes grip. The runoff/gravel/grass paint mask (`ps2_materials.gd`, `ground.gdshader`) is unfiltered data shared with physics — it is a surface-*type* mask, not a visible line (see Road, "Edge lines: absent", above). Check colour-space handling on both Forward+ and Compatibility after changing multipliers.

Current player-car mesh budgets (`tests/v2/car_models.gd`, 2026-09-24, mesh triangles including shadow and wheels): Mazda MX-5 NA 5,032, GT high-downforce 3,744, Ferrari 296 GT3 8,466 — see Cars, above. (An earlier figure of "21,498 reduced to 11,546" described the pre-rebuild legacy 296 model and no longer applies; it's superseded by the P4-vis/Look-2 rebuild's own cars.) Text glyphs, shadows, ghosts and submitted scene primitives are counted separately. The primary player's silhouette is preserved instead of LOD-switched under the chase camera.

Trees (Look-6) are three alpha-scissored cards crossed at 60 degrees from one photographic atlas (`assets/trees/tree_atlas.png`), one MultiMesh and material per forest band; `INSTANCE_CUSTOM` selects the atlas cell and `INSTANCE_COLOR` a near-white tint. Original two-triangle fence spans, ribbed armco, crowd cards and painted tyre walls supply roadside detail. Medium and High use shadow maps; Low uses car projection and vertex-alpha ground darkening. The car contact-patch shadow (`shaders/blob_shadow.gdshader`) draws in the opaque pass with an ordered dither, because a transparent material on that mesh is never composited by the world SubViewport; with alpha blending the shadow did not render at all. Ambient occlusion is a High-tier extra (radius 1.4, intensity 1.6) with four shadow splits and a wider blur; Low and Medium keep the flat console fill and two splits. SSR and FXAA remain off; Native optionally enables MSAA 2×. Fog ends per `apply_time_of_day()`: 1.15 km by day, 520 m at night (see Horizon and enclosure, above).

Repeated scenery is partitioned into 128 m batches and terrain into static 24-cell tiles, allowing camera culling without constructing meshes at LOD transitions. Night lamps have depth-tested additive Gaussian halos and horizontal streaks. On TrackAssets (Look-2) they are sodium poles placed along the road by `scripts/track/track_lights.gd`, denser at pits, start/finish and grandstands; the road's amber pools and reflection streaks are read from a per-road lamp texture, so every glow on the tarmac sits under a real lamp. Circuit lamps, halos, sign/pit accents and road reflection pools are consistently amber; the indigo night sky and normal car brake lights remain distinct. All three cars now carry headlights, gated to night; they are no longer specific to `ferrari_296.gd`. Daytime flare occlusion samples the cached rendered heightfield rather than repeatedly projecting against the whole circuit; this removed the large periodic CPU stalls found in the full-lap trace.

Daylight runs a weak cool fill against a warm key (ambient 0.42, sun 1.5) — see Colour and light, above, now with a reference frame (`gt4-unidentified-photomode-car.jpg`) confirming the balance. Conifer instance colours spread across hue and value so a stand reads as a forest rather than one flat hedge.

**Correction:** this section previously said "Sky/reflections are downsampled CC0 photographs with original horizon/light-bar treatments." That is not what `scripts/retro_assets.gd::panorama()` does today: it generates the sky procedurally (a 256×128 vertical gradient plus sine-noise cloud band), with no photograph and no distant silhouette — see Horizon and enclosure, above, gap #3. Paint uses Fresnel environment sheen and a clamped specular sweep. Never feed an unclamped dot product into `pow`. No game geometry, font, logo, texture, sound or code was extracted from a reference game.

## Frontend and verification

`front_end.gd` owns the v2 pages (main, car, circuit, loading, drive, pause), focus and prompts, and menu tones; `v2_panels.gd` owns settings, garage and dialogs. Both live under `V2UIRoot`, which the presentation chain renders in its UI viewport (ARCHITECTURE.md, "Presentation chain"). Back/B/Esc returns a level; Menu/Start pauses while driving.

Verification is windowed: `--v2-present` (and `--features`) drives bot laps and then runs `scripts/presentation_check.gd` over every display mode, with screenshots in `user://look-3/` and real mouse, key and pad input. `tests/v2/track_screenshots.gd` captures daylight views of the Proving Ground, Spa and the Nordschleife with draw calls per view, plus a `--compare` mode that pairs each captioned shot against its matched reference frame from `docs/art/reference/` (Look-0); `tests/v2/night_screenshots.gd` does the day/night captures; `tests/v2/car_screenshots.gd` frames the cars. CI runs `--v2-present` under xvfb with Mesa's software GL. Look at the images and read stderr, not just the check counts. (The pre-rebuild `--compare` and `--performance` matrices went with the legacy game.)
