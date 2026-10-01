# Spa-Francorchamps Corner Dossier: Stavelot & Paul Frère (Turns 14 & 15)

## 1. Overview & Geographic Context
- **Official Designation**: Courbe Paul Frère / Stavelot (historically Turn 14 Campus / Stavelot entrance, Turn 15 Paul Frère corner)
- **Circuit Station**: $s = 4,520.0\text{ m}$ to $s = 4,950.0\text{ m}$
- **Elevation Change**: Reaches the lowest elevation sector of the modern Grand Prix loop: enters at $h = +6.80\text{ m}$, bottoms at $h = -2.40\text{ m}$ at the Paul Frère exit before beginning the uphill rise through Blanchimont.
- **Turn Direction**: Turn 14 (medium-speed 90° right), Turn 15 (fast, accelerating long-radius right sweeper).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Campus / Stavelot corner)**:
  `https://commons.wikimedia.org/wiki/File:Circuit_de_Spa-Francorchamps_Stavelot.jpg`
- **Wikimedia Commons Image (Paul Frère curve exit onto straight)**:
  `https://commons.wikimedia.org/wiki/File:Paul_Frere_Corner,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`

## 3. Physical & Engineering Characteristics
- **Track Width**: $9.8\text{ m}$ at Turn 14 apex, opening to $11.2\text{ m}$ at Turn 15 exit.
- **Crossfall / Camber**:
  - Turn 14: $+2.0^\circ$ positive banking.
  - Turn 15: $+2.0^\circ$ banking holding the car into the accelerating arc.
- **Runoff & Safety Architecture**:
  - Turn 14 outside (left): Gravel bed followed by tire barrier.
  - Turn 15 outside (left): Wide asphalt runoff apron with high-friction green surface and sausage rumble strip along the exit boundary.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with sections at "Stavelot" ($s = 4,600\text{ m}$) and "Paul Frere" ($s = 4,820\text{ m}$).
- **Signage**: `SpaEventPanel05` ("STAVELOT / SPA-FRANCORCHAMPS") located at $s = 4,500\text{ m}$.
- **Road Wear**: Heavy traction scrubbing marks along the Turn 15 exit kerb where cars apply full power for the long flat-out run to Bus Stop.

## 5. Driving & Telemetry Target
- **Crucial Exit Speed**: Turn 15 dictates top speed down the entire 1.5 km flat-out blast through Blanchimont!
- **Turn 14**: 3rd gear trail-brake entry ($\approx 140 - 150\text{ km/h}$).
- **Turn 15**: Progressive throttle in 4th, shifting to 5th at apex, pinning throttle to $100\%$ on exit kerb ($\approx 215 - 230\text{ km/h}$).
