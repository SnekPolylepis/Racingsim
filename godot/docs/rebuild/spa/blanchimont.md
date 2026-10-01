# Spa-Francorchamps Corner Dossier: Blanchimont (Turns 16 & 17)

## 1. Overview & Geographic Context
- **Official Designation**: Courbe de Blanchimont (Turn 16 Blanchimont 1, Turn 17 Blanchimont 2)
- **Circuit Station**: $s = 5,600.0\text{ m}$ to $s = 6,250.0\text{ m}$
- **Elevation Change**: Uphill valley floor climb: rises from $h = -1.20\text{ m}$ through Blanchimont 1 to $h = +12.40\text{ m}$ entering the braking zone for Bus Stop.
- **Turn Direction**: Ultra-high-speed blind left kink (Turn 16) followed by wide-open high-speed left curve (Turn 17).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Blanchimont high-speed entry & tree line)**:
  `https://commons.wikimedia.org/wiki/File:Blanchimont_Corner,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (F1 cars flat-out through Blanchimont)**:
  `https://commons.wikimedia.org/wiki/File:2019_Belgian_GP_FP2_Hamilton_Blanchimont.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Blanchimont`

## 3. Physical & Engineering Characteristics
- **Track Width**: $10.0\text{ m}$ entry, $10.5\text{ m}$ through the apex, $10.8\text{ m}$ on exit.
- **Crossfall / Camber**: $-2.5^\circ$ positive banking providing high lateral stability at extreme speeds.
- **Runoff & Safety Architecture**:
  - Driver's right (outside): Paved asphalt runoff area leading to energy-absorbing Tecpro barriers and triple Armco fences.
  - Driver's left (inside): Grass verge and Armco guarding the Ardennes forest embankment.
  - FIA catch-fencing (`BlanchimontCatchFence`) extending for $200\text{ m}$ along the outside boundary.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` at station $s = 5,750\text{ m}$ with bank $-2.5^\circ$.
- **Landmarks & Walls**:
  - `BlanchimontTyres`: Multi-row tire wall and barrier array at $s = 5,640\text{ m}$ to $s = 5,875\text{ m}$.
  - `BlanchimontCatchFence`: $200\text{ m}$ high-tensile safety fence on the right runoff margin.
  - `SpaEventPanel06`: "BLANCHIMONT / SPA 24 HOURS" event panel at $s = 5,610\text{ m}$.
- **Audio Spatialization**: High wind rush audio (`wind_rush.wav`) accentuated by cockpit camera preset at speeds $>280\text{ km/h}$.

## 5. Driving & Telemetry Target
- **F1 (F2004 / RB19)**: Flat out in top gear ($\approx 310 - 325\text{ km/h}$). Peak lateral acceleration: $-3.8\text{ G}$ to $-4.1\text{ G}$.
- **GT3 (Ferrari 296 GT3)**: 5th/6th gear, flat out or tiny throttle balance tap ($\approx 250 - 262\text{ km/h}$).
- **Roadster (MX-5)**: Full throttle in top gear without hesitation ($\approx 180\text{ km/h}$).

## 6. In-Engine Captures
- **Blanchimont Sweep (Day)**: `docs/rebuild/screenshots/spa/blanchimont_day.png`
- **Blanchimont Sweep (Night)**: `docs/rebuild/screenshots/spa/blanchimont_night.png`
