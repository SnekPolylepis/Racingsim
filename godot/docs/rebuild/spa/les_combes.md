# Spa-Francorchamps Corner Dossier: Les Combes (Turns 5 & 6)

## 1. Overview & Geographic Context
- **Official Designation**: Chicane des Combes (Turn 5 right, Turn 6 left)
- **Circuit Station**: $s = 2,180.0\text{ m}$ to $s = 2,380.0\text{ m}$
- **Elevation Change**: Highest point of the circuit! Apex crests at $h = +50.25\text{ m}$ above the start/finish reference before beginning the long, sweeping descent through the Ardennes valley towards Rivage and Pouhon.
- **Turn Direction**: Turn 5 (tight 90° right turn), Turn 6 (immediate 90° left switchback).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Les Combes chicane entrance & kerbs)**:
  `https://commons.wikimedia.org/wiki/File:Les_Combes_chicane,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (Overtaking into Les Combes)**:
  `https://commons.wikimedia.org/wiki/File:Formula_One_2011_Rd_12_Belgian_GP_Les_Combes.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Les_Combes`

## 3. Physical & Engineering Characteristics
- **Track Width**: $10.0\text{ m}$ on entry, widening to $11.5\text{ m}$ through the braking zone, $9.5\text{ m}$ at the Turn 5 apex, $9.8\text{ m}$ at Turn 6 exit.
- **Crossfall / Camber**:
  - Turn 5 apex: $+2.0^\circ$ positive banking.
  - Turn 6 apex: $-2.0^\circ$ banking (left transition).
- **Runoff & Safety Architecture**:
  - Outer runoff (straight-on escape road): Extensive asphalt runoff area with speed-reduction sausage kerbs and a tire barrier deceleration buffer.
  - Turn 6 exit runoff: Asphalt apron ($8.0\text{ m}$ width) followed by deep gravel trap and triple Armco barrier.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with dual apex sections: "Les Combes" ($s = 2,250\text{ m}$) and "Les Combes exit" ($s = 2,340\text{ m}$).
- **Braking Markers**: `TrackBoards` countdown boards at $150\text{ m}$, $100\text{ m}$, and $50\text{ m}$ on the driver's left.
- **Kerb Profile**: Multi-stage Wallonia red/yellow painted kerbs with rumble strip thrum audio triggers (`kerb_thrum.wav`).
- **Surface Wear**: Heavy braking black rubber deposit marks and turn-in scrub wear mapped via `shaders/road_v2.gdshader`.

## 5. Driving & Telemetry Target
- **Primary Overtaking Zone**: Heavy braking from $>300\text{ km/h}$ down to $\approx 135 - 145\text{ km/h}$ in 3rd gear (F1/GT3).
- **Turn 5 Apex**: Attack inside kerb firmly without bottoming the floor pan.
- **Turn 6 Transition**: Rapid lateral weight transfer across the car's roll axis; throttle application must be progressive to avoid exit snap oversteer.
