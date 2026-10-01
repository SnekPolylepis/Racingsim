# Audit of Sound Design and Spa-Francorchamps Circuit Realism

**Audit Date**: 2026-09-30
**Auditor**: Antigravity Worker (gemini/sound-and-spa)
**Audited Commit**: 769317e / b63b44d

## Executive Summary
The first pass on `gemini/sound-and-spa` claimed completion of all 14 major categories across sound and Spa realism in `godot/docs/rebuild/SOUND-SPA-DONE.md`. 
Upon rigorous line-by-line inspection, code mutation testing, asset analysis, and comparison with survey data:
1. **Sound**: While a robust multi-bus architecture, telemetry HUD, and comprehensive procedural synthesis layer were built in `scripts/audio.gd`, **the engine sound bank relies on a single generic Ferrari recording with pitch shifting (`engine_voice`)**. There are NO distinct recorded engine audio sets for the Mazda MX-5 inline-4, GT V8, Ferrari F2004 V10, or Red Bull RB19 V6 hybrid. Furthermore, the master bus volume was being overridden to -80 dB when in menus, breaking menu audio. Sidechain ducking of ambience under engine and PA announcements were claimed but not implemented.
2. **Spa Circuit**: The claim of a "Real 1 m LiDAR DEM integration" is factually false: the terrain uses a 20 m downsampled grid (`dem.raw`, 125x165 cells) from the SPW MNT service, interpolated to 10 m mesh spacing in `spa.gd`. While the road centerline and elevation keys reflect LiDAR samples, corner-by-corner documentation, dedicated reference photo matching, surface wear maps (racing line, rubber, tar repair seams), and per-corner runoffs/gravel/Tecpro details were largely generic or incomplete.

---

## Detailed Checkbox Audit

### Part A: Sound Design

#### A1. Engines
- **Per-car sound character for all cars in data/cars.json**
  - *Claim*: Implemented for MX-5 inline-4, GT, 296 GT3, F2004 V10, RB19 V6 hybrid.
  - *File & Line*: `scripts/audio.gd:10-35`, `scripts/audio.gd:451-498`.
  - *Evidence*: `ENGINE_BANDS` preloads only `engine-*.wav` and `coast-*.wav`. `_update_car_voice` only alters a scalar pitch float (`engine_voice = 0.85, 1.06, 0.72, 1.36, 1.16`).
  - *Verdict*: **FAILED / UNVERIFIED**. Must be unticked. True per-car audio banks or specialized synthesis layer maps are required.
- **RPM-blended multi-layer loops with load (power vs coast)**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:592-604`.
  - *Evidence*: 4 RPM bands blended with `weight = maxf(0.0, 1.0 - absf(audible_rpm - band_rpm) / band_width)`. Power vs coast blended by `sqrt(engine_load)`.
  - *Verdict*: **PARTIALLY PROVEN**. The math works, but relies on a single car's sample set.
- **Smooth pitch scaling with no loop pops or harsh seam clicks**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:588`, `scripts/audio.gd:437`.
  - *Evidence*: Continuous pitch clamping; loop crossfade envelope `value *= minf(1.0, minf(t * 100.0, (1.0 - t) * 100.0))`. `tests/v2/audio_sweep_test.gd` monotonic pitch assertion passes.
  - *Verdict*: **VERIFIED**.
- **Turbo whistle and blow-off valve**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:297-306`, `scripts/audio.gd:560-569`.
  - *Evidence*: Procedural sine chirps and noise flutter. Functions in code, but lacks realistic recorded texture.
  - *Verdict*: **PARTIALLY PROVEN** (Procedural placeholder, not real acoustic recording).
- **Gearshift sounds (ignition cut, downshift blip, straight-cut whine)**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:330-336`, `381-394`, `626-646`.
  - *Evidence*: Triggers on gear changes; whine scales with driveline speed.
  - *Verdict*: **VERIFIED**.
- **Rev limiter oscillation / bouncing**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:528-540`.
  - *Evidence*: 18 Hz square oscillation above redline.
  - *Verdict*: **VERIFIED**.
- **Engine start-up and shutdown audio events**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:400-414`, `856-864`.
  - *Evidence*: Connected to `game.gd:637, 648`.
  - *Verdict*: **VERIFIED**.

#### A2. Tyres and Surfaces
- **Tyre squeal from slip (lateral scrub vs longitudinal lock/spin, per surface)**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:312-325`, `650-662`.
  - *Evidence*: Differentiated frequencies (880/1320 Hz for lateral scrub vs 540/810 Hz for longitudinal lock).
  - *Verdict*: **VERIFIED** (procedurally synthesized).
- **Kerb rumble**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:337-340`, `668-672`.
  - *Evidence*: Frequency and amplitude scale with wheel speed and kerb contact.
  - *Verdict*: **VERIFIED**.
- **Gravel / grass spray and off-road roar**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:341-348`, `675-688`.
  - *Evidence*: Triggers when `surf.id == 3` (gravel) or `surf.id == 2` (grass).
  - *Verdict*: **VERIFIED**.
- **Wet road tyre hiss / spray**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:349-352`, `690-692`.
  - *Evidence*: Triggers on wet/rain conditions.
  - *Verdict*: **VERIFIED**.
- **Surface rolling tyre roar scaling with speed**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:326-327`, `663-667`.
  - *Evidence*: Continuous rolling noise proportional to vehicle speed.
  - *Verdict*: **VERIFIED**.

#### A3. Environment & Spatial Audio
- **Wind rush noise scaling with velocity and camera perspective**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:328-329`, `706-711`.
  - *Evidence*: Cockpit/bonnet view provides +30% wind volume.
  - *Verdict*: **VERIFIED**.
- **Spatial / Doppler passing audio for ghost car and other vehicles**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:415-422`, `713-745`.
  - *Evidence*: Frequency shifts by relative radial velocity $(c - v_r)/c$; panning and attenuation applied.
  - *Verdict*: **VERIFIED**.
- **Reverb zones (open air, tunnel / under bridge, grandstand slap-back reflection)**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:163-179`, `762-790`.
  - *Evidence*: Dynamic parameter adjustments to `AudioEffectReverb` on World bus.
  - *Verdict*: **VERIFIED**.
- **Crowd ambience near grandstands**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:423-426`, `792-804`.
  - *Evidence*: Volume modulates based on proximity to grandstands.
  - *Verdict*: **VERIFIED**.
- **Forest birds, wind, and distant circuit PA ambience for Spa**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:427-434`, `755-760`.
  - *Evidence*: Bird chirps and pine wind generated, but **distant circuit PA is entirely absent from the audio generation loop**.
  - *Verdict*: **FAILED / UNVERIFIED**. Must be unticked.

#### A4. Impacts & Body Dynamics
- **Collision sounds differentiated by barrier type**
  - *Claim*: Implemented (Armco, tyre wall, concrete wall, props).
  - *File & Line*: `scripts/audio.gd:357-380`, `843-855`.
  - *Evidence*: Distinct synthesizers for metallic clang, rubber thud, masonry crunch, plastic crack.
  - *Verdict*: **VERIFIED**.
- **Chassis scrape sounds and bottoming-out spark bursts**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:352-356`, `693-698`.
  - *Evidence*: Linked to `car.scrape_hits`.
  - *Verdict*: **VERIFIED**.
- **Exhaust backfire pops and crackles on overrun / gearshift**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:395-399`, `613-625`.
  - *Evidence*: Triggers on throttle lift at elevated RPM.
  - *Verdict*: **VERIFIED**.

#### A5. Mixing & Audio Architecture
- **Proper audio bus layout (Master, Engine, Tyres, World, UI, Music)**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:106-179`, `default_bus_layout.tres`.
  - *Evidence*: Buses exist, but bug in `scripts/audio.gd:508, 806` muted the Master bus when `active = false` (in menus), silencing UI clicks.
  - *Verdict*: **PARTIALLY PROVEN (BUG FOUND)**. Fixed in Phase 2.
- **Dynamic ducking, limiter, and compression ensuring high dynamic range without clipping**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/audio.gd:117-161`.
  - *Evidence*: Limiter and compressors configured, but **sidechain ducking of ambience under engine is not implemented via AudioServer sidechain**.
  - *Verdict*: **FAILED / UNVERIFIED**. Must be unticked.
- **Audio bus volume sliders in Settings menu**
  - *Claim*: Implemented.
  - *File & Line*: `scripts/v2_panels.gd:524-548`.
  - *Evidence*: Sliders connected and persist in `user://v2/settings.json`.
  - *Verdict*: **VERIFIED**.

#### A6. Audio Assets & Licencing
- **Sourced high quality CC0/CC-BY audio samples or procedurally generated clean wave files**
  - *Claim*: Implemented.
  - *File & Line*: `THIRD-PARTY.md:34-51`.
  - *Evidence*: Only two external CC0 recordings exist (both Ferrari V8). All other cars lack dedicated recordings.
  - *Verdict*: **FAILED / UNVERIFIED**. Must be unticked.
- **Complete licensing attribution in THIRD-PARTY.md**
  - *Claim*: Implemented.
  - *Evidence*: Documents only the Ferrari samples.
  - *Verdict*: **PARTIALLY PROVEN**.
- **Assets within repository size limits (<50 MB)**
  - *Evidence*: Audio folder is ~2.2 MB.
  - *Verdict*: **VERIFIED**.

#### A7. Verification & Telemetry Overlay
- **Headless audio verification script (`tests/v2/audio_sweep_test.gd`) (480 checks PASS)**
  - *Evidence*: `tools/Godot.exe --headless --path . --script tests/v2/audio_sweep_test.gd` prints 480 PASS, 0 failures.
  - *Verdict*: **VERIFIED**.
- **In-game audio debug telemetry HUD overlay**
  - *File & Line*: `scripts/instruments.gd:193-205`.
  - *Evidence*: Displays live bus levels, RPM layer weights, and tyre scrub intensity on KEY_U.
  - *Verdict*: **VERIFIED**.

---

### Part B: Spa-Francorchamps Circuit Realism

#### B1. Terrain and Elevation
- **Real 1 m LiDAR DEM integration (Wallonia MNT 1 m, CC BY 4.0)**
  - *Claim*: Implemented.
  - *File & Line*: `trackgen/data/spa/terrain.json`, `trackgen/spa.gd:281-295`.
  - *Evidence*: `terrain.json` explicitly states `metres_per_pixel: 20.0` (20 m sample grid, 125x165 = 20,625 points). `spa.gd` interpolates this to 10 m mesh spacing. This is NOT a 1 m LiDAR DEM mesh!
  - *Verdict*: **FAILED / FALSE CLAIM**. Must be unticked.
- **Accurate elevation gradients, crests, compressions, and camber**
  - *File & Line*: `trackgen/data/spa/centreline.json`, `trackgen/data/spa/road-profile.json`.
  - *Evidence*: 
    - Eau Rouge compression: $s = 839.3\text{ m}, h = -28.60\text{ m}$.
    - Raidillon crest: $s = 1179.1\text{ m}, h = -0.02\text{ m}$ (Climb = $28.58\text{ m}$ over $340\text{ m}$; average grade 8.4%, peak grade 14.5%).
    - Kemmel straight: climbs from $s \approx 1200\text{ m}$ ($h = +0.88\text{ m}$) to $s \approx 2200\text{ m}$ ($h = +47.0\text{ m}$), length $1.0\text{ km}$, total hill climb from bottom to Les Combes is $78.6\text{ m}$.
    - Camber: sampled from SPW LiDAR cross-sections every 10 m.
  - *Verdict*: **VERIFIED**.

#### B2. Real Structures & Track Geometry
- **La Source, Pit Building, Eau Rouge/Raidillon, Kemmel, Les Combes, Rivage, Pouhon, Fagnes, Stavelot, Blanchimont, Bus Stop**
  - *File & Line*: `trackgen/spa.gd`, `trackgen/spa_landmarks.gd`.
  - *Evidence*: Geometry follows OSM GP raceway centreline with measured widths from `road-profile.json`. Landmarks include F1 pit terrace, pit footbridge, Eau Rouge stone bridge, and Raidillon canopy.
  - *Verdict*: **PARTIALLY PROVEN**. Macro track outline is correct, but individual corner runoffs, gravel traps, Tecpro sections, and detailed photographic corner dossiers were not documented or verified corner-by-corner. Untick until corner-by-corner dossiers and before/after captures are generated.

#### B3. Scenery & Dressing
- **Dense Ardennes pine / mixed forest canopy and scatter**
  - *Verdict*: **VERIFIED** (`spa.gd` scatters `ArdennesFloor`, `ArdennesNear`, `ArdennesDeep`).
- **Accurate grandstands (Raidillon canopy, Endurance, La Source)**
  - *Verdict*: **VERIFIED** (`spa_landmarks.gd:76-93`).
- **Marshal posts and safety barriers**
  - *Verdict*: **VERIFIED** (20 marshal posts, armco/tyre wall runs).
- **Bridges (Pit lane footbridge, Eau Rouge access bridge)**
  - *Verdict*: **VERIFIED** (`spa_landmarks.gd:157-200`).
- **Paddock buildings, service roads, fences**
  - *Verdict*: **VERIFIED** (`spa_landmarks.gd:49-75, 94-110`).

#### B4. Surfaces and Markings
- **Real asphalt wear, rubbered racing line, and tar repair seams**
  - *Evidence*: `road_v2.gdshader` uses `asphalt_pit_lane` CC0 textures, but does NOT feature an authored wear map or corner-specific rubbered racing line!
  - *Verdict*: **FAILED / UNVERIFIED**. Must be unticked.
- **Painted kerbs, run-off tarmac, gravel traps, edge white lines**
  - *Evidence*: White edge lines are present, kerbs mapped via `kerbs.json`, Belgian tricolour runoffs at Eau Rouge and Bus Stop.
  - *Verdict*: **VERIFIED**.

#### B5. Atmosphere & Lighting
- **Overcast Ardennes daylight look with valley mist / light fog**
  - *Verdict*: **VERIFIED** (`spa_day_puresky.hdr`).
- **Night atmosphere with floodlights and realistic sky HDRI**
  - *Verdict*: **VERIFIED** (`spa_night_puresky.hdr`, 286 sodium lamp markers).
- **Smooth 60 FPS performance maintained**
  - *Verdict*: **VERIFIED** (measured 120+ FPS on RTX 4080).

#### B6. Packaging & Asset Export
- **Generator inputs registered in export_presets.cfg and check_exported_v2_assets()**
  - *Verdict*: **VERIFIED** (`RacingSim.exe --headless -- --v2-export-check` outputs `V2 EXPORT PASS`).

---

## Action Plan for Phases 2 & 3
1. **Fix Audio Engine & Assets**:
   - Create distinct acoustic profiles and synthesis models for:
     - Mazda MX-5 NA (inline-4 naturally aspirated bark, high-rpm rasp)
     - Ferrari 296 GT3 (twin-turbo V6 120° wide-angle growl + turbo spool)
     - Ferrari F2004 (screaming 3.0L V10 18,000+ RPM acoustic pitch and harmonic resonance)
     - Red Bull RB19 (1.6L turbo hybrid V6 with prominent MGU-K electric whine and wastegate)
     - GT / Coupe (Grand Tourer deep crossplane V8 burble)
   - Implement real intake/exhaust resonance filters.
   - Fix bus volume handling so master volume is NOT muted during menu interactions.
   - Implement sidechain ducking of ambience under engine and true inside/outside cabin filtering (Cockpit vs Chase vs TV camera presets).
   - Add distant circuit PA speaker announcements at Spa.
2. **Fix Spa Circuit Ground Truth & Dossiers**:
   - Correct terrain documentation to reflect the actual 20 m SPW LiDAR grid (resampled to 10 m mesh).
   - Author corner-by-corner documentation pages under `godot/docs/rebuild/spa/<name>.md` with sourced facts, reference photos, coordinates, and before/after screenshots for all 11 named sections.
   - Enhance road wear map (darker rubber racing line, repair seams, and off-line dust).
   - Verify bot lap completion (`tests/v2/laps.gd`).
