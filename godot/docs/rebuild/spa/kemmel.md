# Spa-Francorchamps Section Dossier: Kemmel Straight

## 1. Overview & Geographic Context
- **Official Designation**: Ligne Droite de Kemmel (Kemmel Straight)
- **Circuit Station**: $s = 1,180.0\text{ m}$ to $s = 2,180.0\text{ m}$ (approximately $1,000\text{ m}$ length)
- **Elevation Change**: $h = -0.02\text{ m}$ at Raidillon crest climbing continuously up the Ardennes ridge to $h = +49.96\text{ m}$ at the braking zone for Les Combes ($s \approx 2,180\text{ m}$). Total climb: $49.98\text{ m}$ ($5.0\%$ steady gradient).
- **Track Layout**: High-speed, gentle left kink early in the straight followed by a long uphill full-throttle draft straight.

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Kemmel straight view toward Les Combes)**:
  `https://commons.wikimedia.org/wiki/File:Kemmel_straight_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (Kemmel hill and forest backdrop)**:
  `https://commons.wikimedia.org/wiki/File:Circuit_de_Spa-Francorchamps_straight_Kemmel.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`
- **Topographical Source**: Service public de Wallonie (SPW) LiDAR DEM 2021-2022.

## 3. Physical & Engineering Characteristics
- **Track Width**: $10.0\text{ m}$ uniform width along the full straight.
- **Crossfall / Camber**: Nominal $+1.0^\circ$ to $+1.5^\circ$ crown drainage crossfall draining water toward the right-hand drainage channel.
- **Runoff & Safety Architecture**:
  - Left verge: $4.0\text{ m}$ grass verge flanked by triple-rail galvanized steel Armco barrier and FIA debris fencing.
  - Right verge: $4.0\text{ m}$ grass and access road separated by Armco.
  - Emergency escape gates and marshal posts situated every $200 - 350\text{ m}$.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` using OSM raceway centerline nodes 1180 to 2180.
- **Landmarks & Scenery**:
  - `KemmelBillboards`: Double-sided overhead and trackside sponsor billboard structures spaced every $60\text{ m}$ between $s = 1,350\text{ m}$ and $s = 2,050\text{ m}$.
  - `KemmelCrowdBank`: Earth spectator berm with crowd scatter situated at $s = 1,500\text{ m}$ on the driver's left.
  - `ArdennesNear` and `ArdennesDeep`: Dense mixed conifer (Pinus sylvestris) and deciduous beech forest wall bordering both sides of the straight.
- **Acoustic Environment**:
  - High-speed aerodynamic wind buffeting dominant over exhaust audio.
  - Dynamic transmission gear whine and high-RPM engine load sidechain ducking active (-3.4 dB World bus attenuation).

## 5. Driving & Telemetry Target
- **F1 (F2004 / RB19)**: Top speed reaches $335 - 345\text{ km/h}$ in 8th gear before heavy braking into Les Combes.
- **GT3 (Ferrari 296 GT3)**: Top speed reaches $265 - 272\text{ km/h}$ in 6th gear.
- **Roadster (MX-5)**: Uphill climb limits top speed to $\approx 185 - 192\text{ km/h}$ in 5th gear.

## 6. In-Engine Captures
- **Kemmel Straight (Day)**: `docs/rebuild/screenshots/spa/kemmel_day.png`
- **Kemmel Straight (Night)**: `docs/rebuild/screenshots/spa/kemmel_night.png`
