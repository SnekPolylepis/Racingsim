# Vehicle physics model

> **Status (2026-09-23):** this derivation was written for the planar CarModel (`scripts/car.gd`). The tyre, drivetrain and aids equations are still current: they live in the shared modules `scripts/vehicle/tyre.gd`, `drivetrain.gd` and `aids.gd`, which the 6-DOF CarBody calls per contact patch. The chassis, suspension, road-following and flight sections describe the legacy planar model only. For the 6-DOF car see PHYSICS.md and the REBUILD-LOG DONE entries P2-00 to P2-08 and P2-comp.

> **Provenance.** This is the full derivation of the vehicle model, written for the original
> single-file implementation that was removed on 2026-09-22. The mathematics, step order,
> coordinate conventions and the reasoning behind each clamp all still describe the native
> solver, which is why the document was kept. Its function names (`Car.step()`,
> `Car.drivetrain()`, `Track.elevAt`) are historical; the native equivalents are in
> `scripts/car.gd` and `scripts/track.gd`, which are authoritative where the two disagree.
> See [PHYSICS.md](PHYSICS.md) for the Simulation/Simcade handling models layered on top.

Everything here is in `Car.step()` and `Car.drivetrain()`. The step order is fixed and matters:

1. Steering angle from input and speed.
1b. **Elevation**: look up the road surface under the CG (`Track.elevAt`) → in-plane gravity force and effective gravity `gEff` (slope + crest/dip).
2. **Suspension**: corner deflections from chassis DOF → spring/damper/ARB forces → wheel loads; then integrate the chassis DOF using the *previous* step's body accelerations and `gEff − g`.
3. **Tires**: per wheel, contact velocity → slip → Pacejka forces → friction ellipse → numerical clamps → rolling resistance/surface drag → sum forces and moments; heat and wear.
4. **Drivetrain**: engine → clutch → gearbox → differential(s) → wheel angular velocities; brakes/ABS/TC.
5. **Body**: aero drag, integrate velocity, yaw rate, position, heading; store body-frame accelerations for the next step's suspension.

Fixed timestep 1/240 s, semi-implicit Euler.

## Symbols

`m` mass, `Izz` yaw inertia, `a`/`b` CG to front/rear axle, `t` track width, `R` wheel radius, `Iw` wheel inertia, `h` CG height (`setup.cgHeight`), `g` 9.81, `ρ` 1.22 kg/m³.

## 1. Steering

```
maxSteer = setup.maxSteer° · π/180 / (1 + v/14)
δ = input.steer · maxSteer
```
Both front wheels get δ (no Ackermann). The speed term is a playability choice: at 30 m/s full lock is ~10°, at rest it is the full 32° (roadster). Keyboard steering is additionally rate-limited in `Input.update` (`kbSteer / (1 + v/20)` per second) and self-centers.

## 2. Suspension and wheel loads

Chassis has heave `z`, pitch `θ` (nose-down +), roll `φ` (right-down +). Each corner's deflection (compression +):

```
d_i  = z + θ·bx_i + φ·by_i
dd_i = ż + θ̇·bx_i + φ̇·by_i + bump_i       bump_i = uniform noise · surf.bump · min(1, v/10)
F_i  = k_axle · d_i + c(dd_i) · dd_i          c = bump damper if dd>0 else rebound damper
ARB: F_FL += k_arbF (d_FL − d_FR), F_FR −= same; rear likewise
N_i  = max(0, static_i + F_i)                 static: m·g·b/(a+b)/2 front, m·g·a/(a+b)/2 rear
```

Chassis equations (aero downforce `D_f = ½ρ v² ClA_F` at the front axle, `D_r` at the rear):

```
m·z̈   = D_f + D_r − ΣF_i + m·(gEff − g)
I_θ·θ̈ = −m·ax·h − (F_FL+F_FR)·a + (F_RL+F_RR)·b + D_f·a − D_r·b
I_φ·φ̈ = −m·ay·h − Σ F_i·by_i
```

`ax, ay` are the body-frame accelerations **from tire and aero forces only** (gravity along a slope is excluded, see §2b) computed at the end of the previous step. Under braking `ax < 0` → `θ̈ > 0` → nose dives → front springs compress → front loads rise. Under a right turn `ay > 0` → `φ̈ < 0` → left side compresses. Load transfer therefore *lags* the acceleration by the chassis' natural response (~0.1–0.3 s), and the front/rear split of lateral transfer follows roll stiffness distribution (springs + ARBs), which is why the rear ARB is the biggest balance lever. DOF are clamped to ±0.15 m / ±0.12 rad as a safety net.

Not modeled: unsprung mass, tire vertical stiffness, camber, bump steer.

## 2b. Elevation, grades, crests and banking

The track carries an elevation surface (`Track.elevAt`, see ARCHITECTURE.md): along the centerline `z(s)` is a Catmull-Rom spline through the control points' `z`, across the road the height is `z(s) − lat·tan(bank)` (`lat` positive to the driver's right, so positive bank raises the **left** edge — banked for a right-hander). Each step the car reads the surface under its CG once: height `z`, world gradient `∇z = (dz/dx, dz/dy)`, centerline grade `dz/ds`, vertical curvature `kv = d(grade)/ds` (negative over a crest, positive in a dip) and bank.

The car stays a planar body; elevation enters through two terms:

```
cosθ  = 1 / √(1 + |∇z|²)
F_g   = −m·g·cosθ·∇z                    in-plane gravity, world frame (points downhill)
gEff  = clamp(g·cosθ + v²·kv, 0.1 g, 3 g)   effective gravity (crest → light, dip → heavy)
```

`F_g` is added to the velocity integration **but not to `ax, ay`**. Those stay "what the tires push", which is what physically causes load transfer: a car parked facing uphill has its tires pushing it uphill, so `ax_tires > 0` and weight shifts to the rear axle, exactly like accelerating. The same term handles banking: on a banked road the tires push laterally uphill, `ay_tires ≠ 0`, the body rolls toward the low side and the low-side wheels carry more load — with no separate banking code.

`gEff − g` is fed into the heave equation, so over a crest the springs extend and the wheel loads fall with the chassis' natural response; in a compression they rise. There is no airborne state: `gEff` bottoms out at 0.1 g, so a fast crest just makes the car very light (and slippery) for a moment. *(Native solver: superseded. The car now takes off when the required normal force goes negative; see PHYSICS.md, "Vertical dynamics and flight".)* `v²·kv` uses the car's speed regardless of direction, so a crest taken backwards is a crest too.

Two small fixes were needed to make hills behave at standstill:
- The `fxNeed` clamp (§3) assumes the wheel can spin up to absorb slip. A wheel the brake can hold locked can't, so when `|ω| < 0.5` and the brake capacity exceeds the locked-wheel torque, the clamp uses `fxNeed = sv·m_q/dt` instead. That is what makes the car sit on a hill with the brake on (it creeps <1 cm in 3 s on 8 %) instead of sliding down at a few cm/s.
- The standstill creep damping (§3) is skipped when the slope gravity exceeds 0.02 g, otherwise it would act as a free hill-hold. In neutral with no brake the car rolls downhill (≈0.7 m/s² on 8 % after rolling resistance), as it should.

The auto gearbox, steering, tires and aero are unchanged; hills change lap times purely through gravity and load: you carry less speed up the climb, brake later into a compression (more grip), and lose grip over a crest.

Verified numbers (tests/test6.js, roadster, 8 % ramp): parked front load share 0.514 facing uphill vs 0.542 facing downhill (flat: 0.528); 12° bank at rest → right-side wheels carry 56 % and the body rolls +0.37°; 10 m sine hills on a 300 m radius circle at 35 m/s → gEff 0.85 g at the crest, 1.15 g in the dip, wheel load sum 0.86–1.16 mg.

## 3. Tires

Contact point velocity in world: `vc = v + r × offset`. Rotate into the wheel frame (heading + δ for fronts): `vwx` (along), `vwy` (right).

```
κ  = (ω·R − vwx) / max(|vwx|, 1)               slip ratio
α* = atan2(vwy, max(|vwx|, 0.6))                 steady-state slip angle
α  += (α* − α) · min(1, dt · max(v, 1.5) / 0.28) relaxation length 0.28 m
```

Grip coefficient stack:

```
tempG = 1 − 0.2·(1 − exp(−((T − T_opt)/W)²))    0.8 far from optimum, 1 at optimum
wearG = 1 − 0.15·wear
loadG = clamp(1 − loadSens·(N/N_nom − 1), 0.5, 1.3)   N_nom = m·g/4  (load sensitivity)
μ = setup.tireMu · surf.grip · tempG · wearG · loadG
D = μ·N
```

Pacejka magic formula `F = D·sin(C·atan(B·x − E·(B·x − atan(B·x))))`:
- longitudinal: `x = κ`, `B = setup.tireBlong`, `C = 1.65`, `E = 0.97`
- lateral: `x = α`, `B = setup.tireBlat`, `C = 1.35`, `E = 0.96`, force sign negated so it opposes lateral slip

Friction ellipse: `ρ = √((Fx/D)² + (Fy/D)²)`; if `ρ > 1` scale both by `1/ρ`. `wheel.ellipse = ρ` is what the debug overlay shows as "use %" and what triggers skid marks (>0.92 on asphalt/curb).

### Numerical clamps (do not remove)

Explicit integration of a stiff tire at 240 Hz overshoots: the force computed from the current slip would, applied for a whole step, flip the slip sign. So each force is capped at the value that would exactly cancel the slip velocity this step:

```
sv     = ω·R − vwx
fxNeed = sv / (dt · (R²/Iw + 1/m_q))     m_q = m/4    (wheel and quarter-car both respond)
fyNeed = −vwy · m_q / dt
if same sign and |F| > |Fneed| → F = Fneed
```

This is what makes the car sit still at a standstill and roll smoothly at walking pace. A small velocity damping is also applied below 0.4 m/s with no throttle (only on level ground; see §2b for the locked-wheel variant of `fxNeed` and the slope exception).

### Rolling resistance and surface drag

```
Fx_rr = −sign(vwx) · surf.rr · N · min(1, |vwx|/0.5)
Fx_drag = −surf.drag · N · vwx,   Fy_drag = −surf.drag · N · vwy · 0.5
```
Gravel has `drag = 0.03`, so at 20 m/s it pulls ~6 m/s² total: it "drags the car down hard" as the spec asked. Grass is slippery (`grip 0.55`) but only mildly draggy.

### Temperature and wear

```
slipPow = |Fx·sv| + |Fy·vwy|                                        (W)
heat    = slipPow · 0.0006 · setup.pressureHeat + 0.02 · v · N/N_nom   (K/s)
cool    = (0.02 + 0.0012·v)·(T − 25) + 0.0004·(T − 25)²
Ṫ = heat − cool
wear   += slipPow · 3e-7 · dt   (0..1; toggleable)
```
The quadratic cooling term makes temperatures saturate around 120–130 °C even with the wheels spinning against a wall. Cold start is 25 °C; a normal lap brings the roadster to 60–85 °C (optimum 88).

## 4. Drivetrain

### Engine
`engineTorqueAt(ω, throttle)` interpolates `p.torqueCurve` (rpm fraction → torque fraction) times `p.engineTorque`, minus engine braking `p.engineBrake · max(0, ω − 0.8·ω_idle) · (1 − throttle)`. Rev limiter cuts throttle above redline. An idle controller adds up to 50 % throttle when below idle. Engine speed can't drop below 35 % of idle (no stalling, but launches can bog).

### Clutch
Engagement `eng ∈ [0,1]`: in auto/auto-clutch mode it rises with the carrier speed relative to idle and with throttle (`max(base, 0.55·throttle + 0.1)`, 0 at rest with no throttle so there's no creep); in manual mode it is `1 − clutch pedal`. During a shift it is 0.

Clutch torque is the one-step sync solve: with `A = dt/I_e`, `B = ratio²·dt/ΣIw`,
```
need = (ω_e − ω_carrier·ratio + T_e·A − T_ext·ratio·dt/ΣIw) / (A + B)
T_c  = clamp(need, ±p.clutchTorque · eng)
```
If the demanded torque is within capacity, engine and wheels are exactly synced after the step (locked clutch); otherwise the clutch slips at capacity. Launch with lots of throttle and the wheels spin; feed it gently and the engine bogs. `ω_e += (T_e − T_c)·dt/I_e`, axle input torque `T_in = T_c · ratio`.

### Gearbox
Ratios `setup.gear1..6 · setup.finalDrive`, reverse `−p.reverse · finalDrive`. A shift takes `setup.shiftTime` seconds with the clutch open and (in auto) torque cut. Automatic mode upshifts at 96 % redline under throttle and downshifts when the lower gear would sit below 82 % redline and current rpm < 55 %, using **rpm derived from road speed** (`v/R · ratio`) so wheelspin doesn't trigger upshifts. Holding the brake ≥0.8 s while stopped toggles R ↔ 1.

### Differential
For an axle with wheels L/R receiving `T_in`:
```
cap  = open: 0 | LSD: preload + |T_in|·(T_in ≥ 0 ? powerLock : coastLock) | locked: ∞
need = −((ω_L − ω_R)·Iw/dt + T_tire_L − T_tire_R) / 2
T_lock = clamp(need, ±cap)
T_L = T_in/2 + T_lock,  T_R = T_in/2 − T_lock
```
Open: inside wheel spins up under power (verified: κ_inside ≈ 2.4 at full throttle in a slow corner, no drive). LSD/locked: both wheels get torque, car can power-oversteer; locked drags the inside wheel in slow corners (slight push, lower speed). AWD (`layout 2`) first splits `T_in` front/rear by `awdRear` with a center lock `cap = 20 + |T_in|·awdLock` using the same solve on axle-average speeds, then each axle runs the diff above.

### Brakes, ABS, TC, handbrake
Per wheel brake capacity `= setup.brakeTorque · brake · (bias or 1−bias) / 2`, plus `handbrakeTorque·handbrake/2` on the rears. Applied after the drive/tire update as a speed reduction that never reverses the wheel. ABS (if on, speed > 2, no handbrake): if `κ < −(0.06 + 0.12·(1−intensity))` the wheel's brake factor ramps down to 0.15, else back up to 1. TC (if on, speed > 1.5): if the max driven-wheel `κ` exceeds `0.06 + 0.2·(1−intensity)`, effective throttle is scaled down proportionally.

## 5. Body integration

```
drag = ½ρ · cdA · v      applied as −drag·(vx, vy)
v += (ΣF + F_g)/m · dt;  r += ΣM/Izz · dt;  x += v·dt;  h += r·dt
ax, ay = ΣF/m rotated into the body frame  (tires + aero only, no F_g; used by next step's suspension)
```

## 6. Collisions (`collideCar`)

Eight points on the car's rectangle (corners + edge midpoints) are tested against each wall/tire capsule (`OBJ[type].thick`); segment endpoints are tested against the rectangle. On contact: push out by 60 % of penetration along the normal, then

```
j  = −(1+e)·vn / (1/m + (r×n)²/Izz)     normal impulse, e = 0.25 wall / 0.08 tire barrier
jt = clamp(−vt / (1/m + (r×t)²/Izz), ±μ·j)   friction impulse, μ = 0.6 wall / 0.8 tires
```
Tire barriers absorb more (lower e, higher μ). Cones are shoved with a velocity and decay (`updateCones`), and snap back to their original positions at the start of each lap.

## 7. Verified emergent behaviors (see TESTING.md)

Measured with the scripted tests on a wide skidpad, tires pre-warmed, roadster defaults:

| Scenario | Result |
|---|---|
| Full throttle + full steer at 17 m/s (RWD) | body slip grows to >60°, car spins |
| Same speed, 25 % steer, part throttle | yaw ~23°/s, slip ~1°, stable |
| Trail braking (40 % brake + steer) vs steady steer, 30 m/s | peak yaw 69°/s vs 29°/s |
| Lift-off mid-corner | slip 5.7° → 7.9°, yaw 21 → 27°/s |
| Full throttle in 2nd mid-corner | rear κ 0.4–0.7, spin |
| Full lock at 35 m/s | front slip 18° larger than rear (understeer) |
| Open diff, slow corner, full throttle | inside rear κ ≈ 2.4, outside ≈ 0.05 |
| Cold (25 °C) vs warm tires, same input | lateral accel 10.4 vs 11.7 m/s² |
| Steady 11.8 m/s² corner | loads FL/FR/RL/RR ≈ 4936/876/3999/875 N, roll 2.1° |
| 1 g braking | front/rear loads ≈ 3957/1325 N, pitch 1.7° |
| Neutral, no brake, on an 8 % grade | rolls downhill, −0.68 m/s after 1 s, −1.32 m/s after 2 s |
| Full brake on an 8 % grade, 3 s | moves 0.011 m, speed 0 |
| Parked facing uphill / downhill (8 %) | front load share 0.514 / 0.542 (flat 0.528) |
| 35 m/s over 10 m sine hills (R = 300 m circle) | gEff 0.85 g at crest, 1.15 g in dip; load sum 0.86–1.16 mg |
| Parked on 12° banking (left edge high) | right wheels 56 % of load, roll +0.37°, slides 3 cm |
