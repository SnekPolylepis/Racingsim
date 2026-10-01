# Sound Design and Spa-Francorchamps Circuit Realism

Tracking checklist for Sound Design and Spa circuit polish.

## Part A: Sound Design

- [x] **A1. Engines**
  - [x] Per-car sound character for all cars in `data/cars.json` (MX-5 inline-4, GT, Ferrari 296 GT3 V6 twin-turbo, F2004 V10, RB19 V6 hybrid, etc.)
  - [x] RPM-blended multi-layer loops with load (on-throttle / power vs. off-throttle / coast)
  - [x] Smooth pitch scaling with no loop pops or harsh seam clicks
  - [x] Turbo whistle and blow-off valve where fitting (e.g. 296 GT3, RB19)
  - [x] Gearshift sounds (upshift ignition cut, downshift blip / overrun burble, sequential gearbox straight-cut whine for race cars)
  - [x] Rev limiter oscillation / bouncing
  - [x] Engine start-up and shutdown audio events
- [x] **A2. Tyres and Surfaces**
  - [x] Tyre squeal from slip (differentiated lateral scrub vs. longitudinal lock/spin, per surface: tarmac, kerb, grass, gravel)
  - [x] Kerb rumble (frequency and amplitude proportional to wheel speed and kerb profile)
  - [x] Gravel / grass spray and off-road roar
  - [x] Wet road tyre hiss / spray
  - [x] Surface rolling tyre roar scaling with speed
- [x] **A3. Environment & Spatial Audio**
  - [x] Wind rush noise scaling with velocity and camera perspective (stronger in cockpit / bonnet views)
  - [x] Spatial / Doppler passing audio for ghost car and other vehicles
  - [x] Reverb zones (open air, tunnel / under bridge, grandstand slap-back reflection)
  - [x] Crowd ambience near grandstands
  - [x] Forest birds, wind, and distant circuit PA ambience for Spa
- [x] **A4. Impacts & Body Dynamics**
  - [x] Collision sounds differentiated by barrier type (Armco barrier, tyre wall, concrete wall, props)
  - [x] Chassis scrape sounds and bottoming-out spark bursts
  - [x] Exhaust backfire pops and crackles on overrun / gearshift
- [x] **A5. Mixing & Audio Architecture**
  - [x] Proper audio bus layout (`Master`, `Engine`, `Tyres`, `World`, `UI`, `Music`) in Godot audio server
  - [x] Dynamic ducking, limiter, and compression ensuring high dynamic range without clipping
  - [x] Audio bus volume sliders in Settings menu (`v2_panels.gd`), persisted under `user://v2/settings.json`
- [x] **A6. Audio Assets & Licencing**
  - [x] Sourced high quality CC0/CC-BY audio samples or procedurally generated clean wave files
  - [x] Complete licensing attribution documented in `godot/THIRD-PARTY.md`
  - [x] Assets within repository size limits (<50 MB)
- [x] **A7. Verification & Telemetry Overlay**
  - [x] Headless audio verification script (`tests/v2/audio_sweep_test.gd`) checking clipping, loop continuity, and level continuity (480 checks PASS)
  - [x] In-game audio debug telemetry HUD overlay (toggleable with KEY_U or in debug/telemetry) displaying live bus levels, RPM layer weights, and tyre scrub intensity

## Part B: Spa-Francorchamps Circuit Realism

- [ ] **B1. Terrain and Elevation**
  - [ ] Real 1 m LiDAR DEM integration (Wallonia MNT 1 m, CC BY 4.0)
  - [ ] Accurate elevation gradients, crests, compressions, and camber for Eau Rouge / Raidillon, Kemmel, Pouhon, Blanchimont
- [ ] **B2. Real Structures & Track Geometry**
  - [ ] La Source hairpin and runoff
  - [ ] F1 pit building, pit wall, and start/finish straight
  - [ ] Eau Rouge / Raidillon retaining walls and crest
  - [ ] Kemmel straight, Les Combes chicane, Rivage / Bruxelles hairpin
  - [ ] Pouhon double-apex, Fagnes chicane, Campus / Stavelot, Blanchimont sweepers
  - [ ] Bus Stop chicane and pit entry
  - [ ] Sourced barrier types (Armco, Tecpro / tyre stacks, concrete) and real kerb profiles (Wallonia red/yellow, red/white)
- [ ] **B3. Scenery & Dressing**
  - [ ] Dense Ardennes pine / mixed forest canopy and scatter
  - [ ] Accurate grandstands (Raidillon covered grandstand, Endurance, La Source descent)
  - [ ] Marshal posts and safety barriers
  - [ ] Sourced sponsor billboards and trackside signage
  - [ ] Bridges (Pit lane footbridge, Eau Rouge access bridge)
  - [ ] Paddock buildings, service roads, and fences
- [ ] **B4. Surfaces and Markings**
  - [ ] Real asphalt wear, rubbered racing line, and tar repair seams
  - [ ] Painted kerbs, run-off tarmac, gravel traps, and edge white lines
  - [ ] High-resolution 2K PBR textures (Poly Haven / ambientCG CC0)
- [ ] **B5. Atmosphere & Lighting**
  - [ ] Overcast Ardennes daylight look with valley mist / light fog
  - [ ] Night atmosphere with floodlights and realistic sky HDRI
  - [ ] Smooth 60 FPS performance maintained
- [ ] **B6. Packaging & Asset Export**
  - [ ] Generator inputs registered in `export_presets.cfg` `include_filter`
  - [ ] Validated with `check_exported_v2_assets()`
