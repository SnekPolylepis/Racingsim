# Sound Design and Spa-Francorchamps Circuit Realism

Tracking checklist for Sound Design and Spa circuit polish (Pass 1 - Audited 2026-09-30).
Items unticked where evidence was incomplete, inaccurate, or relying on synthetic placeholders. See SOUND-SPA-AUDIT.md.

## Part A: Sound Design

- [ ] **A1. Engines**
  - [ ] Per-car sound character for all cars in `data/cars.json` (MX-5 inline-4, GT, Ferrari 296 GT3 V6 twin-turbo, F2004 V10, RB19 V6 hybrid, etc.) *(Audit: single Ferrari sample reused with pitch multiplier engine_voice; no distinct engine banks)*
  - [x] RPM-blended multi-layer loops with load (on-throttle / power vs. off-throttle / coast)
  - [x] Smooth pitch scaling with no loop pops or harsh seam clicks
  - [ ] Turbo whistle and blow-off valve where fitting (e.g. 296 GT3, RB19) *(Audit: procedural sine/noise placeholder only)*
  - [x] Gearshift sounds (upshift ignition cut, downshift blip / overrun burble, sequential gearbox straight-cut whine for race cars)
  - [x] Rev limiter oscillation / bouncing
  - [x] Engine start-up and shutdown audio events
- [x] **A2. Tyres and Surfaces**
  - [x] Tyre squeal from slip (differentiated lateral scrub vs. longitudinal lock/spin, per surface: tarmac, kerb, grass, gravel)
  - [x] Kerb rumble (frequency and amplitude proportional to wheel speed and kerb profile)
  - [x] Gravel / grass spray and off-road roar
  - [x] Wet road tyre hiss / spray
  - [x] Surface rolling tyre roar scaling with speed
- [ ] **A3. Environment & Spatial Audio**
  - [x] Wind rush noise scaling with velocity and camera perspective (stronger in cockpit / bonnet views)
  - [x] Spatial / Doppler passing audio for ghost car and other vehicles
  - [x] Reverb zones (open air, tunnel / under bridge, grandstand slap-back reflection)
  - [x] Crowd ambience near grandstands
  - [ ] Forest birds, wind, and distant circuit PA ambience for Spa *(Audit: birds and wind present, distant PA absent)*
- [x] **A4. Impacts & Body Dynamics**
  - [x] Collision sounds differentiated by barrier type (Armco barrier, tyre wall, concrete wall, props)
  - [x] Chassis scrape sounds and bottoming-out spark bursts
  - [x] Exhaust backfire pops and crackles on overrun / gearshift
- [ ] **A5. Mixing & Audio Architecture**
  - [x] Proper audio bus layout (`Master`, `Engine`, `Tyres`, `World`, `UI`, `Music`) in Godot audio server
  - [ ] Dynamic ducking, limiter, and compression ensuring high dynamic range without clipping *(Audit: sidechain ducking of ambience under engine not implemented via sidechain send)*
  - [x] Audio bus volume sliders in Settings menu (`v2_panels.gd`), persisted under `user://v2/settings.json`
- [ ] **A6. Audio Assets & Licencing**
  - [ ] Sourced high quality CC0/CC-BY audio samples or procedurally generated clean wave files *(Audit: only one recording downloaded; no per-car banks)*
  - [ ] Complete licensing attribution documented in `godot/THIRD-PARTY.md`
  - [x] Assets within repository size limits (<50 MB)
- [x] **A7. Verification & Telemetry Overlay**
  - [x] Headless audio verification script (`tests/v2/audio_sweep_test.gd`) checking clipping, loop continuity, and level continuity (480 checks PASS)
  - [x] In-game audio debug telemetry HUD overlay (toggleable with KEY_U or in debug/telemetry) displaying live bus levels, RPM layer weights, and tyre scrub intensity

## Part B: Spa-Francorchamps Circuit Realism

- [ ] **B1. Terrain and Elevation**
  - [ ] Real 1 m LiDAR DEM integration (Wallonia MNT 1 m, CC BY 4.0) *(Audit: False claim; dem.raw is 20 m grid, interpolated to 10 m mesh)*
  - [x] Accurate elevation gradients, crests, compressions, and camber for Eau Rouge / Raidillon, Kemmel, Pouhon, Blanchimont
- [ ] **B2. Real Structures & Track Geometry**
  - [x] La Source hairpin and runoff
  - [x] F1 pit building, pit wall, and start/finish straight
  - [x] Eau Rouge / Raidillon retaining walls and crest
  - [x] Kemmel straight, Les Combes chicane, Rivage / Bruxelles hairpin
  - [x] Pouhon double-apex, Fagnes chicane, Campus / Stavelot, Blanchimont sweepers
  - [x] Bus Stop chicane and pit entry
  - [ ] Sourced barrier types (Armco, Tecpro / tyre stacks, concrete) and real kerb profiles *(Audit: corner-by-corner dossiers and Tecpro details unverified)*
- [x] **B3. Scenery & Dressing**
  - [x] Dense Ardennes pine / mixed forest canopy and scatter
  - [x] Accurate grandstands (Raidillon covered grandstand, Endurance, La Source descent)
  - [x] Marshal posts and safety barriers
  - [x] Sourced sponsor billboards and trackside signage
  - [x] Bridges (Pit lane footbridge, Eau Rouge access bridge)
  - [x] Paddock buildings, service roads, and fences
- [ ] **B4. Surfaces and Markings**
  - [ ] Real asphalt wear, rubbered racing line, and tar repair seams *(Audit: wear map not implemented in shader)*
  - [x] Painted kerbs, run-off tarmac, gravel traps, and edge white lines
  - [x] High-resolution 2K PBR textures (Poly Haven / ambientCG CC0)
- [x] **B5. Atmosphere & Lighting**
  - [x] Overcast Ardennes daylight look with valley mist / light fog
  - [x] Night atmosphere with floodlights and realistic sky HDRI
  - [x] Smooth 60 FPS performance maintained
- [x] **B6. Packaging & Asset Export**
  - [x] Generator inputs registered in `export_presets.cfg` `include_filter`
  - [x] Validated with `check_exported_v2_assets()`
