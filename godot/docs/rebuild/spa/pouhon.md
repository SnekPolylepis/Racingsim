# Spa-Francorchamps Corner Dossier: Pouhon / Double Gauche (Turns 10 & 11)

## 1. Overview & Geographic Context
- **Official Designation**: Double Gauche / Pouhon (Turns 10 & 11)
- **Circuit Station**: $s = 3,450.0\text{ m}$ to $s = 3,850.0\text{ m}$
- **Elevation Change**: Sweeps down into a deep natural valley basin: enters at $h = +14.80\text{ m}$, bottoms out in the double-apex depression at $h = +5.20\text{ m}$, then climbs out toward Fagnes at $h = +8.60\text{ m}$.
- **Turn Direction**: Monstrous double-apex high-speed downhill left-hander.

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Pouhon double-apex view from spectator bank)**:
  `https://commons.wikimedia.org/wiki/File:Pouhon,_Circuit_de_Spa-Francorchamps_2022.jpg`
- **Wikimedia Commons Image (GT3 field through Pouhon)**:
  `https://commons.wikimedia.org/wiki/File:24_Hours_of_Spa_2018_Pouhon.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Pouhon`

## 3. Physical & Engineering Characteristics
- **Track Width**: $10.5\text{ m}$ on entry, widening to $11.8\text{ m}$ through the mid-corner bowl, $10.0\text{ m}$ at exit kerb.
- **Crossfall / Camber**: $-3.5^\circ$ positive banking into the mountain face, generating immense aerodynamic and mechanical grip.
- **Runoff & Safety Architecture**:
  - Outside (driver's right): In 2022, the outer runoff was enlarged, converting the asphalt apron into a combination of asphalt strip and deep gravel bed backed by Tecpro and tire barriers to prevent cars from rebounding onto the track.
  - Spectator berm: Massive natural hillside grandstand and spectator bank towering over the corner.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` at station $s = 3,600\text{ m}$ with bank $-3.5^\circ$.
- **Landmarks & Spectators**:
  - `PouhonCrowdBank`: $140\text{ m}$ curved natural earth berm with dynamic crowd cheering and horn sounds.
  - `PouhonTyres`: Multi-row tire wall barrier mapped along the outer perimeter ($s = 3,490\text{ m}$ to $s = 3,725\text{ m}$).
  - `SpaEventPanel03`: "POUHON / TOTALENERGIES" trackside event board.
- **Acoustic Profile**: High-G tire scrub lateral hiss (`tyre_scrub_lat.wav`) and engine exhaust roar reflecting off the hillside bowl.

## 5. Driving & Telemetry Target
- **F1 (F2004 / RB19)**: Taken flat or with a tiny confidence brush in 6th/7th gear ($\approx 275 - 290\text{ km/h}$). Lateral G-load peaks at $-4.2\text{ G}$ sustained across both apexes.
- **GT3 (Ferrari 296 GT3)**: 5th gear, decisive turn-in with trail-brake down to $\approx 205 - 215\text{ km/h}$, commitment to the second apex curbing.
- **Roadster (MX-5)**: Full throttle in 4th gear ($\approx 145 - 150\text{ km/h}$), testing chassis balance and suspension rebound damping.
