# Spa-Francorchamps Corner Dossier: Eau Rouge & Raidillon (Turns 2, 3, 4)

## 1. Overview & Geographic Context
- **Official Designation**: Virage de l'Eau Rouge (Turn 2) & Raidillon de l'Eau Rouge (Turns 3 & 4)
- **Circuit Station**: $s = 820.0\text{ m}$ to $s = 1,180.0\text{ m}$
- **Elevation Change**: $h = -28.60\text{ m}$ at the compression bottom ($s = 839.3\text{ m}$) climbing to $h = -0.02\text{ m}$ at the crest ($s = 1,179.1\text{ m}$). Total climb: $28.58\text{ m}$ over $340\text{ m}$ ($\approx 8.4\%$ average gradient, with peak climb grade exceeding $14.5\%$ entering Raidillon).
- **Turn Direction**: Turn 2 (Eau Rouge left kink across culvert), Turn 3 (Raidillon steep uphill right snap), Turn 4 (Raidillon blind left crest onto Kemmel).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Modern Raidillon grandstand & runoff)**:
  `https://commons.wikimedia.org/wiki/File:Eau_Rouge_and_Raidillon,_Spa-Francorchamps_2022.jpg`
- **Wikimedia Commons Image (Compression & Culvert detail)**:
  `https://commons.wikimedia.org/wiki/File:Spa-Francorchamps_Eau_Rouge.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Eau_Rouge`
- **Circuit Wallonia Orthophoto / Elevation Baseline**:
  Service public de Wallonie (SPW) LiDAR MNT 2021-2022 (0.5 m campaign); EPSG:3812 / EPSG:5710.

## 3. Physical & Engineering Characteristics
- **Track Width**: Nominal $10.0\text{ m}$ entering Eau Rouge, narrowing slightly to $9.6\text{ m}$ through the Turn 3 apex, expanding to $10.4\text{ m}$ across the crest.
- **Crossfall / Camber**:
  - Eau Rouge apex ($s \approx 950\text{ m}$): $-3.0^\circ$ negative (off-camber downhill turn-in).
  - Raidillon apex ($s \approx 1,100\text{ m}$): $+4.0^\circ$ positive banking into the mountain face.
  - Crest ($s \approx 1,175\text{ m}$): Rolls over to $-1.8^\circ$ as cars crest into unweighting.
- **Runoff & Safety Architecture**:
  - Left-hand runoff: Widened asphalt runoff apron featuring the official Belgian national colours (black, yellow, red painted bands) introduced in 2022.
  - Right-hand runoff: Reconfigured gravel trap and multi-layer Tecpro barrier at the Raidillon crest following the Anthoine Hubert / W Series safety updates.
  - Left retaining wall: Reinforced concrete retaining wall with catch-fencing holding the hillside terrace.
  - Culvert bridge: Historic stone masonry parapet over the L'Eau Rouge brook on the inside right of Turn 2.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` via cubic Hermite tangents sampled from OpenStreetMap GP centerline and SPW 0.5 m LiDAR elevation spline.
- **Landmarks & Structures (`trackgen/spa_landmarks.gd`)**:
  - `EauRougeBridge`: Ardennes stone culvert ($32\text{ m}$ span) crossing over L'Eau Rouge stream bed ($s \approx 920\text{ m}$).
  - `RaidillonGrandstand` & `RaidillonCanopy`: Covered hillside grandstand (18 rows, $130\text{ m}$ length) following the natural terrain grade with rear VIP lounge glazing.
  - `BelgianRunoff`: Distinctive black/yellow/red perimeter runoff paint along the left apron ($s = 900\text{ m}$ to $s = 1,230\text{ m}$).
  - `EnduranceGrandstand`: 2023 grandstand ($150\text{ m}$ length) along the descent from La Source to Eau Rouge.
- **Shaders & Surfaces**:
  - `road_v2.gdshader`: Dynamic dual-groove rubbered racing line through the compression, tar repair seams, damp sheen at night.
  - Kerbs: Wallonia red/yellow painted apex and exit kerb textures (`kerb_colours()`).
- **Acoustic Zone**: `scripts/audio.gd` triggers culvert wet reverb send (room size 0.65, wet 0.38) and hillside wall slap-back reflection.

## 5. Driving & Telemetry Target
- **F1 / High Downforce (F2004 / RB19)**: Flat out in 7th/8th gear ($\approx 295 - 315\text{ km/h}$). Peak vertical G-force in compression: $+3.5\text{ G}$, crest lateral snap: $-1.2\text{ G}$ unweighting.
- **GT3 (Ferrari 296 GT3)**: 5th gear, slight lift or trace brake depending on fuel load ($\approx 235 - 250\text{ km/h}$).
- **Roadster (MX-5)**: Full throttle in 4th/5th gear ($\approx 160\text{ km/h}$), momentum critical for Kemmel straight climb.

## 6. In-Engine Captures
- **Eau Rouge & Raidillon (Day)**: `docs/rebuild/screenshots/spa/eau_rouge_raidillon_day.png`
- **Eau Rouge & Raidillon (Night)**: `docs/rebuild/screenshots/spa/eau_rouge_raidillon_night.png`
