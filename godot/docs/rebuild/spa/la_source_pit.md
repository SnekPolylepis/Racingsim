# Spa-Francorchamps Section Dossier: La Source Hairpin & Pit Complex (Turn 1 & Start/Finish)

## 1. Overview & Geographic Context
- **Official Designation**: Épingle de La Source (Turn 1) & Ligne Droite des Stands (F1 Pit Straight)
- **Circuit Station**:
  - Pit Straight / Start-Finish: $s = 6,850.0\text{ m}$ to $s = 200.0\text{ m}$ ($s = 0.0\text{ m}$ timing line)
  - La Source Hairpin: $s = 250.0\text{ m}$ to $s = 450.0\text{ m}$ ($s \approx 350.0\text{ m}$ apex)
- **Elevation Change**:
  - Pit straight descends gradually from $h = +12.80\text{ m}$ through the start/finish gantry to $h = +6.40\text{ m}$ at the braking zone for La Source.
  - La Source hairpin begins the massive drop towards Eau Rouge: drops from $h = +6.40\text{ m}$ through the hairpin down to $h = -5.80\text{ m}$ along the descent past the Endurance pits. Total drop from hairpin apex to Eau Rouge foot: over $34\text{ m}$.
- **Turn Direction**: Very tight 180° right-hand hairpin turning back down the Ardennes valley towards the historic old pits and Eau Rouge.

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (La Source hairpin and Hotel de la Source view)**:
  `https://commons.wikimedia.org/wiki/File:La_Source_hairpin,_Circuit_de_Spa-Francorchamps_2022.jpg`
- **Wikimedia Commons Image (F1 Pit Straight and grandstands)**:
  `https://commons.wikimedia.org/wiki/File:Start-Ziel-Gerade_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (Pit building and covered footbridge)**:
  `https://commons.wikimedia.org/wiki/File:Pit_lane_Spa-Francorchamps.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`

## 3. Physical & Engineering Characteristics
- **Track Width**: Widest section on the circuit: $14.5\text{ m}$ along the pit straight, expanding to $15.5\text{ m}$ entering the braking zone, pinching to $8.2\text{ m}$ at the apex of La Source, then flaring wide to $14.0\text{ m}$ on the downhill exit.
- **Crossfall / Camber**:
  - Pit straight: $+1.0^\circ$ drainage crossfall.
  - La Source apex: $+1.5^\circ$ positive banking helping pivot the front tyres.
- **Runoff & Safety Architecture**:
  - Exterior of hairpin (driver's left): Expansive asphalt runoff with energy-absorbing Tecpro safety barriers protecting the access road and the landmark Hotel de la Source terrace.
  - Pit wall: Reinforced concrete pit wall with stainless steel safety mesh and electronic signaling perches.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with 20 grid slots (`grid_slots = 20`, `grid_spacing_m = 8.0 m`), start gantry at $s = 0.0\text{ m}$, and apex section at $s = 350.0\text{ m}$.
- **Landmarks & Architecture (`trackgen/spa_landmarks.gd`)**:
  - `PitBuilding`: $230\text{ m}$ multi-tier F1 pit garage facility on the driver's right with 23 individual pit bay shutters and concrete structural jambs.
  - `F1Terrace`: Continuous upper hospitality terrace with pale overhangs, structural mullions, rooftop balustrades, and "CIRCUIT DE SPA-FRANCORCHAMPS" signage.
  - `PitFootbridge`: Covered pedestrian bridge spanning across the track at $s = 6,940\text{ m}$ with "TOTALENERGIES" and circuit signage.
  - `PitGrandstand`: 12-row covered main grandstand ($145\text{ m}$ length) directly opposite the pit garages.
  - `LaSourceGrandstand`: 8-row covered grandstand ($60\text{ m}$ length) overlooking the hairpin entry.
  - `HotelDeLaSource`: Modern 4-storey luxury hotel and hospitality complex situated on the hillside terrace overlooking the outside of La Source.
  - `PaddockTeam00` to `PaddockTeam08`: Detailed race team transport trailers with 12-sided cylindrical tires, axles, team livery awnings, and paddock operations.
- **Acoustic Environment**:
  - Spatial grandstand slap-back reflection on the main straight.
  - Pedestrian footbridge tunnel wet send when driving underneath.
  - Spa circuit PA loudspeaker system announcing track proceedings (`spa_pa_announcement.wav`).
  - Crowd cheering swells near the main grandstand and hairpin bowl.

## 5. Driving & Telemetry Target
- **Start/Finish**: Acceleration zone reaching $240 - 260\text{ km/h}$ before standing on the brakes for La Source.
- **Hairpin Apex**: 1st gear in all cars ($\approx 65 - 75\text{ km/h}$). Tight line hugging the inside kerb is essential to maximize launch down the hill towards Eau Rouge.
- **Downhill Launch**: Extremely long full-throttle section begins immediately at the La Source exit curb, holding full throttle all the way to Les Combes!
