# Spa-Francorchamps Corner Dossier: Bus Stop Chicane (Turns 18 & 19)

## 1. Overview & Geographic Context
- **Official Designation**: Chicane du Bus Stop (Turn 18 right, Turn 19 left)
- **Circuit Station**: $s = 6,650.0\text{ m}$ to $s = 6,850.0\text{ m}$
- **Elevation Change**: Crests the hill entering the chicane at $h = +14.60\text{ m}$, then slopes down slightly onto the start/finish straight at $h = +12.80\text{ m}$ (slight $-1.8\text{ m}$ descent into pit straight).
- **Turn Direction**: Turn 18 (sharp, tight right 90° turn), Turn 19 (tight left 90° switchback onto the pit straight).

## 2. Photographic Reference & Wikimedia Commons Sources
- **Wikimedia Commons Image (Bus Stop chicane layout and Belgian paint)**:
  `https://commons.wikimedia.org/wiki/File:Bus_Stop_chicane,_Circuit_de_Spa-Francorchamps.jpg`
- **Wikimedia Commons Image (F1 pit entry and Bus Stop chicane)**:
  `https://commons.wikimedia.org/wiki/File:Bus_Stop_Chicane_2011_Spa.jpg`
- **Wikimedia Commons Category**:
  `https://commons.wikimedia.org/wiki/Category:Bus_Stop_chicane`

## 3. Physical & Engineering Characteristics
- **Track Width**: Widens to $13.5\text{ m}$ on entry, narrowing to $8.8\text{ m}$ through the Turn 18 sausage curb, $9.2\text{ m}$ through Turn 19 apex, flaring to $14.0\text{ m}$ onto the pit straight.
- **Crossfall / Camber**:
  - Turn 18: $+1.0^\circ$ positive banking.
  - Turn 19: $-1.0^\circ$ banking.
- **Runoff & Safety Architecture**:
  - Belgian Flag Tricolour Runoff: Painted black, yellow, red perimeter runoff bands along the outer runoff apron ($s = 6,620\text{ m}$ to $s = 6,850\text{ m}$).
  - Outer exit barrier: Energy-absorbing Tecpro blocks and double-layer tire wall guarding the pit lane entry split.
  - Pit entry: Diverges from the driver's right immediately before Turn 18.

## 4. Built Implementation in Sim Engine
- **Geometry**: Authored in `trackgen/spa.gd` with two apexes: "Bus Stop" ($s = 6,720\text{ m}$) and "Bus Stop exit" ($s = 6,775\text{ m}$).
- **Landmarks & Architecture (`trackgen/spa_landmarks.gd`)**:
  - `BusStopGrandstand`: 8-row covered grandstand ($70\text{ m}$ length) with solid facade on the chicane exit.
  - `BelgianRunoff`: Official Belgian tricolour painted runoff along the chicane apron.
  - `SpaRaceControl`: Multi-tier race control and timing tower with glass observation deck situated at $s = 6,855\text{ m}$.
  - `BusStopTyres`: Tire barrier array along the escape road and outside perimeter.
- **Acoustic Ambience**: Proximity to grandstands triggers spectator crowd cheer swells and circuit PA loudspeaker commentary.

## 5. Driving & Telemetry Target
- **Violent Deceleration**: Hardest braking point on the circuit alongside Les Combes: from $>315\text{ km/h}$ down to $\approx 75 - 85\text{ km/h}$ in 1st/2nd gear.
- **Apex Curbing**: Must straddle the inside kerb of Turn 18 without launching the car over the yellow sausage kerb.
- **Traction on Exit**: Immediate straight-line acceleration onto the pit straight; wheelspin control is essential.

## 6. In-Engine Captures
- **Bus Stop Chicane (Day)**: `docs/rebuild/screenshots/spa/bus_stop_day.png`
- **Bus Stop Chicane (Night)**: `docs/rebuild/screenshots/spa/bus_stop_night.png`
