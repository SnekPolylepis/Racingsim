# Spa-Francorchamps Corner Dossier: Malmedy (Turn 7)

## 1. Overview & Geographic Context
- **Official Designation**: Courbe de Malmedy (Turn 7)
- **Circuit Station**: $s = 2,420.0\text{ m}$ to $s = 2,560.0\text{ m}$
- **Elevation Change**: Rapid downhill drop: descends from $h = +47.50\text{ m}$ to $h = +39.20\text{ m}$ ($\approx 8.3\text{ m}$ descent over $140\text{ m}$, $\approx -5.9\%$ downhill slope).
- **Turn Direction**: Fast, sweeping medium-radius right-hand downhill curve exiting the Les Combes complex.

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Malmedy turn downhill sweep)**:
  `https://commons.wikimedia.org/wiki/File:Malmedy_corner,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`
- **LiDAR Baseline**: SPW MNT 2021-2022 crossfall query data (`trackgen/data/spa/cross-sections.json`).

## 3. Physical & Engineering Characteristics
- **Track Width**: $9.6\text{ m}$ nominal width through the apex, flaring to $10.4\text{ m}$ at exit onto the downhill chute toward Bruxelles.
- **Crossfall / Camber**: $+2.0^\circ$ positive banking aiding turn-in bite despite the downhill unweighting.
- **Runoff & Safety Architecture**:
  - Left-hand exit runoff: $6.0\text{ m}$ wide asphalt strip with green astroturf/carpet strip on outer edge, bordered by a large gravel trap.
  - Outer boundary: Galvanized Armco with double conveyor-belt tire stacks.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` at station $s = 2,470\text{ m}$ with $6.3\text{ m}$ half-width.
- **Surface Transitions**: Clean transition between high-friction asphalt (`TARMAC = 0`) and high-rolling-resistance gravel (`GRAVEL = 3`).
- **Scenery**: Dense Ardennes birch and oak forest canopy lining the external embankment.

## 5. Driving & Telemetry Target
- **Gear & Speed**: 4th gear ($\approx 180 - 195\text{ km/h}$ in GT3, $\approx 220 - 235\text{ km/h}$ in F1).
- **Technique**: Critical to balance the throttle while descending; front axle can push into understeer if trail-braking is held too late.

## 6. In-Engine Captures
- **Malmedy Curve (Day)**: `docs/rebuild/screenshots/spa/malmedy_day.png`
- **Malmedy Curve (Night)**: `docs/rebuild/screenshots/spa/malmedy_night.png`
