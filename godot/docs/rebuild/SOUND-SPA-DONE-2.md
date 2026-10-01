# Sound Design and Spa-Francorchamps Circuit Realism — Pass 2

Tracking checklist for Sound Design and Spa circuit polish (Pass 2).
Tick an item only when accompanied by file/line implementation and empirical verification evidence.

## Part A: Sound Design

- [ ] **A1. Engines**
  - [ ] Per-car sound character for all cars in `data/cars.json` (MX-5 inline-4, GT V8, Ferrari 296 GT3 V6 twin-turbo, F2004 V10, RB19 V6 hybrid) with distinct acoustic timbre and harmonic synthesis
  - [ ] RPM-blended multi-layer loops with load (on-throttle / power vs. off-throttle / coast) per engine architecture
  - [ ] Smooth pitch scaling with no loop pops or harsh seam clicks (verified monotonic sweep)
  - [ ] Turbo whistle, blow-off valve flutter, and hybrid MGU-K electric motor whine
  - [ ] Gearshift sounds (upshift ignition cut, downshift blip / overrun burble, sequential gearbox straight-cut whine)
  - [ ] Rev limiter oscillation / bouncing
  - [ ] Engine start-up and shutdown audio events
  - [ ] Dynamic intake and exhaust resonance filtering scaling with throttle load
  - [ ] Differential and driveline whine scaling with wheel speed and transmission gear ratio
  - [ ] Clutch bite / launch squeal sounds
- [ ] **A2. Tyres and Surfaces**
  - [ ] Tyre squeal from slip (differentiated lateral scrub vs. longitudinal lock/spin, per surface: tarmac, kerb, grass, gravel)
  - [ ] Kerb rumble (frequency and amplitude proportional to wheel speed and kerb profile)
  - [ ] Gravel / grass spray and off-road roar
  - [ ] Wet road tyre hiss / spray
  - [ ] Surface rolling tyre roar scaling with speed
- [ ] **A3. Environment & Spatial Audio**
  - [ ] Wind rush noise scaling with velocity and camera perspective (stronger in cockpit / bonnet views)
  - [ ] Spatial / Doppler passing audio for ghost car and other vehicles
  - [ ] Reverb zones (open air, tunnel / under bridge, grandstand slap-back reflection) with proper wet/dry sends
  - [ ] Crowd ambience near grandstands with spatial distance falloff
  - [ ] Forest birds, wind in trees, and distant circuit PA announcements for Spa
  - [ ] Obstacle / wall acoustic occlusion (low-pass filtering and attenuation behind concrete/armco barriers)
- [ ] **A4. Impacts & Body Dynamics**
  - [ ] Collision sounds differentiated by barrier type (Armco barrier, tyre wall, concrete wall, props)
  - [ ] Chassis scrape sounds and bottoming-out spark bursts
  - [ ] Exhaust backfire pops and crackles on overrun / gearshift
- [ ] **A5. Mixing & Audio Architecture**
  - [ ] Multi-bus layout (`Master`, `Engine`, `Tyres`, `World`, `UI`, `Music`) in Godot audio server
  - [ ] Master limiter guaranteeing zero digital clipping (-0.2 dB ceiling) across all voices
  - [ ] Audio bus volume sliders in Settings menu (`v2_panels.gd`), persisted under `user://v2/settings.json`, active in menus without muting UI
  - [ ] Dynamic sidechain ducking of ambient/world audio under high engine loads
  - [ ] Camera acoustic mix presets: Cockpit (muffled cabin, high intake/whine), Chase (balanced external), TV (distant exhaust emphasis, high reverb/Doppler)
  - [ ] Loudness normalization targeting ~-16 LUFS dynamic range
- [ ] **A6. Audio Assets & Licencing**
  - [ ] Sourced high quality CC0/CC-BY audio samples or procedurally generated clean wave files
  - [ ] Complete licensing attribution documented in `godot/THIRD-PARTY.md`
  - [ ] Assets within repository size limits (<50 MB)
- [ ] **A7. Verification & Telemetry Overlay**
  - [ ] Headless audio verification script (`tests/v2/audio_sweep_test.gd`) checking clipping, loop continuity, monotonic spectral centroid/pitch, and layer blending
  - [ ] Audio engine regression suite checking negative controls (mutations fail tests)
  - [ ] In-game audio debug telemetry HUD overlay (toggleable with KEY_U or in debug/telemetry)

---

## Part B: Spa-Francorchamps Circuit Realism

- [ ] **B1. Terrain and Elevation**
  - [ ] SPW LiDAR ground model integration (Wallonia MNT 2021-2022 0.5m LiDAR, 20m grid DEM in `dem.raw` resampled to 10m mesh)
  - [ ] Accurately verified elevation gradients, crests, compressions, and camber for Eau Rouge / Raidillon (28.6m climb, ~14.5% peak grade), Kemmel (~1km, +48m climb), Pouhon, Blanchimont
- [ ] **B2. Corner-by-Corner Ground Truth & Dossiers**
  - [ ] Sourced documentation dossier for all 11 named sections under `godot/docs/rebuild/spa/<name>.md` with Wikimedia Commons reference links, facts, and before/after captures:
    - [ ] `eau_rouge_raidillon.md`
    - [ ] `kemmel.md`
    - [ ] `les_combes.md`
    - [ ] `malmedy.md`
    - [ ] `rivage.md`
    - [ ] `pouhon.md`
    - [ ] `fagnes.md`
    - [ ] `stavelot.md`
    - [ ] `blanchimont.md`
    - [ ] `bus_stop.md`
    - [ ] `la_source_pit.md`
  - [ ] Corner-specific runoff surfaces, gravel traps, Tecpro tyre stacks, and armco alignments
- [ ] **B3. Real Structures & Dressing**
  - [ ] F1 pit complex: pit building shape, individual pit bays with concrete jambs, pit lane markings, pit wall
  - [ ] Start/finish gantry, podium structure, and pit entry/exit lines
  - [ ] Raidillon covered grandstand following hillside topography
  - [ ] Covered pit footbridge spanning start/finish straight with sponsor signage
  - [ ] Eau Rouge historic stone culvert bridge and access deck over L'Eau Rouge stream
  - [ ] Hotel de la Source / paddock hospitality silhouettes
  - [ ] Marshal posts (20 positions) and trackside safety signage
  - [ ] Dense Ardennes pine and mixed broadleaf forest enclosure
- [ ] **B4. Surfaces and Markings**
  - [ ] Asphalt wear map: darker rubbered racing line, off-line dusty marbles, asphalt repair patches
  - [ ] Accurate painted edge white lines (~0.12 m inside kerb/verge)
  - [ ] Kerb colours: Wallonia red/yellow painted kerbs on corner apexes and exits
  - [ ] Belgian tricolour run-off stripes at Eau Rouge/Raidillon and Bus Stop chicane
- [ ] **B5. Atmosphere & Lighting**
  - [ ] Overcast Ardennes daylight look with valley mist / light fog (`spa_day_puresky.hdr`)
  - [ ] Night atmosphere with 286 sodium floodlights, halos, and sky HDRI (`spa_night_puresky.hdr`)
  - [ ] Smooth 60 FPS performance maintained on dev machine
- [ ] **B6. Packaging & Asset Export**
  - [ ] Generator inputs registered in `export_presets.cfg` `include_filter`
  - [ ] Validated with `RacingSim.exe --headless -- --v2-export-check`
  - [ ] Bot completes full lap on Spa (`tests/v2/laps.gd`) without off-track or wall contact
