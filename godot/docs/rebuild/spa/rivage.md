# Spa-Francorchamps Corner Dossier: Bruxelles / Rivage & Speaker's Corner (Turns 8 & 9)

## 1. Overview & Geographic Context
- **Official Designation**: Virage de Bruxelles (often historically called Rivage, Turn 8) and Virage No Name / Speaker's Corner (Turn 9)
- **Circuit Station**: $s = 2,750.0\text{ m}$ to $s = 3,250.0\text{ m}$
- **Elevation Change**: Steep downhill carousel descent: drops from $h = +31.40\text{ m}$ to $h = +14.80\text{ m}$ ($16.6\text{ m}$ continuous drop through the hairpin and chute, $-6.2\%$ gradient).
- **Turn Direction**: Turn 8 (long, downhill 180° off-camber right-hand hairpin carousel), Turn 9 (fast downhill 90° left-hand kink).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Bruxelles / Rivage hairpin overview)**:
  `https://commons.wikimedia.org/wiki/File:Bruxelles_corner,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (GT cars descending Bruxelles)**:
  `https://commons.wikimedia.org/wiki/File:Spa_24_Hours_2019_Bruxelles.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Circuit_de_Spa-Francorchamps`

## 3. Physical & Engineering Characteristics
- **Track Width**: Widens to $12.0\text{ m}$ on entry, narrowing to $9.2\text{ m}$ around the carousel inside kerb, $10.0\text{ m}$ exiting Turn 9.
- **Crossfall / Camber**:
  - Turn 8 (Bruxelles): Downhill off-camber $+2.0^\circ$ crossfall sloping down towards the outside edge; extremely easy to lock inside-front tyre.
  - Turn 9 (Speaker's Corner / No Name): Off-camber $-1.5^\circ$ adverse banking demanding patient throttle pickup.
- **Runoff & Safety Architecture**:
  - Turn 8 outside: Large, deep gravel trap with access road and safety crane.
  - Turn 9 outside: Asphalt runoff strip leading into gravel bed and tire barrier.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with sections at "Bruxelles" ($s = 2,840\text{ m}$) and "No Name" ($s = 3,150\text{ m}$).
- **Wall Systems**: `add_wall(asset, "BruxellesTyres", WallPath.Side.LEFT, 1, ...)` creates multi-layer tire wall protection along the exterior runoff contour.
- **Kerbs**: Negative-kerb apron on the inside of Bruxelles allowing aggressive clipping without destabilizing the suspension.

## 5. Driving & Telemetry Target
- **Turn 8 Apex**: 2nd gear ($\approx 85 - 95\text{ km/h}$). Constant trail-braking required down the hill while combating understeer caused by the negative gradient.
- **Turn 9 Apex**: 3rd/4th gear ($\approx 150 - 165\text{ km/h}$). Smooth lateral transition, keeping right for the critical entry trajectory into Pouhon.
