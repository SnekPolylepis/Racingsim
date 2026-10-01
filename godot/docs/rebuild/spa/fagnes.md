# Spa-Francorchamps Corner Dossier: Fagnes / Pif-Paf (Turns 12 & 13)

## 1. Overview & Geographic Context
- **Official Designation**: Chicane des Fagnes / Pif-Paf (Turn 12 right, Turn 13 left)
- **Circuit Station**: $s = 4,020.0\text{ m}$ to $s = 4,240.0\text{ m}$
- **Elevation Change**: Gradual descent from $h = +11.20\text{ m}$ to $h = +8.40\text{ m}$ ($\approx 2.8\text{ m}$ drop).
- **Turn Direction**: Turn 12 (medium-fast right turn over kerbing), Turn 13 (medium-fast left turn across exit kerb).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Fagnes chicane action)**:
  `https://commons.wikimedia.org/wiki/File:Fagnes_chicane,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (Curb riding through Fagnes)**:
  `https://commons.wikimedia.org/wiki/File:Spa_Classic_2017_Fagnes.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`

## 3. Physical & Engineering Characteristics
- **Track Width**: $10.0\text{ m}$ entry, $9.8\text{ m}$ through the Turn 12 apex, $10.2\text{ m}$ exiting Turn 13.
- **Crossfall / Camber**:
  - Turn 12: $+2.0^\circ$ positive banking.
  - Turn 13: $-2.0^\circ$ transition.
- **Runoff & Safety Architecture**:
  - Turn 12 outside (left): Gravel bed bordered by Armco barrier.
  - Turn 13 outside (right): Asphalt runoff strip backed by gravel trap and tire barrier.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with two apexes: "Fagnes" ($s = 4,100\text{ m}$) and "Fagnes exit" ($s = 4,195\text{ m}$).
- **Kerb Textures & Profile**: Low-profile serrated Wallonia red/yellow apex kerbs designed for aggressive kerb striking without unsettling dampers.
- **Signage**: `SpaEventPanel04` placed at $s = 4,190\text{ m}$ ("SPA 24 HOURS / PIRELLI").

## 5. Driving & Telemetry Target
- **Gear & Speed**: 4th gear downshift ($\approx 165 - 175\text{ km/h}$ in GT3, $\approx 200 - 215\text{ km/h}$ in F1).
- **Technique**: Hard right flick over the Turn 12 kerb, settling the dampers immediately before pitching the car left across Turn 13 onto the approach to Stavelot.
