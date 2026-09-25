# Physics: the 6-DOF car and its handling models

The vehicle solver is custom, deterministic and fixed at 240 Hz (semi-implicit Euler). `CarBody`
(`scripts/vehicle/car_body.gd`) is the car. The planar `CarModel` it grew from was folded into it
and deleted in P7-01b; its measured figures live on in `docs/rebuild/carmodel-reference.json`. ARCHITECTURE.md covers coordinates
and the tick order. SOLVER-MATH.md derives the shared tyre and drivetrain equations. The REBUILD-LOG
DONE entries (P2-00 to P2-08, P2-comp, P2-comp-b, P4-03, props) carry the measurements behind each
choice below.

## Chassis

- **Body:** a rigid body with total mass, principal inertias `(iroll, izz, ipitch)` from the preset,
  a quaternion attitude and angular velocity in the body frame. The gyroscopic term is advanced by RK4
  (explicit Euler gained energy in a free spin). Position and velocity are 64-bit.
- **Free attitude:** gravity is a world −Y force with no slope term. Crests, flight, landings, banking
  and rollovers all come from the forces; no attitude is assigned.
- **Aero:** downforce acts at each axle along the body's down axis (`clAF`, `clAR`), drag at the CG
  against velocity (`cdA`).
- **Body contact:** a box of sill and roof points (`bodyClearance` sets the sill) is probed only when
  contact is plausible (a lifted wheel, a big tilt, a bottomed corner, a fast fall). Each touching
  point gets a penalty spring and damper with clamped sliding friction, so a rolled or bottomed car
  rests on its body.

## Suspension, tyre compliance and unsprung mass

- **Rays:** each corner's mount sits in the body frame. The suspension ray starts `RAY_LIFT` (0.5 m)
  above it, so ground rising past the mount (a steep wall, a kerb under a bottomed corner) still
  answers continuously.
- **Suspension forces:** spring, bump or rebound damper, and a bump stop at 6x the spring rate past
  8 cm of travel. Anti-roll bars keep acting through a lifted wheel.
- **Wheel mass (P2-comp, `compliance = true`):** each wheel has its own mass (`unsprungMass`
  [front, rear] kg) moving along the suspension axis, between the suspension above and a radial tyre
  spring (`tyreRate` N/m, plus 500 N s/m of hysteresis) below. The tyre cannot pull.
  - **Wheel load:** the tyre force.
  - **Body force along each axis:** the suspension force plus unsprung mass times felt acceleration.
    That is exact at rest and in free fall, and a tyre spike reaches the body only through the wheel.
  - **Integration:** wheel travel uses linearised backward Euler over the spring, damper and tyre
    terms, so 14–17 Hz wheel hop stays stable. The wheel stops at full droop.
  - **Ride height:** the mount sits the static tyre squash higher, so ride height (`cgHeight`) is
    unchanged.
  - **Placing the car:** `place()` seats each wheel where spring (bump stop included) and tyre
    balance on the ground under it.
- **Legacy option:** `compliance = false` keeps the massless wheel on a rigid tyre, used by the
  strict legacy comparisons.

## Tyre footprint and kerbs (P2-06, P2-comp-b)

- **Samples:** a rigid-tyre envelope over 9 samples per wheel (5 on smooth ground), with edge
  bisection. On smooth ground it is bit-identical to the single centre ray.
- **Tread shape:** a crowned tread (0.4 m) and shoulders stand in for camber control and sidewall
  compliance.
- **Steep faces:** surfaces steeper than 60° to the tyre's up locate edges but never carry the tyre.
- **Kerb corners:** with compliance on, a tyre on a sharp edge's corner takes the rigid tread's normal
  along the wheel (the ground normal leaned by the circle's slope, scaled by how squarely the edge
  crosses the wheel). A square step then pushes the car back as well as up. Shaped kerbs (bevel,
  ribbed, sausage) are followed as surfaces.
- **Rough ground:** grass, gravel and runoff add a small random damper excitation, scaled down in
  Simcade.
- **Kerbs in both models:** owner decision D-kerb, 2026-09-23. Kerbs feel the same in Simcade and
  Simulation.

## Tyre forces, drivetrain and static friction

- **Shared modules:** the tyre model (`scripts/vehicle/tyre.gd`) and drivetrain (`drivetrain.gd`) are
  shared with the legacy car.
  - Pacejka curves are combined through a friction ellipse.
  - Load sensitivity is taken relative to each axle's static load.
  - Tyre temperature uses two nodes, a fast surface and a slow core.
  - Wear grows from zero.
  - Self-aligning torque gives `car.steer_torque`.
- **Contact frame:** forces act at each contact point, in a frame built from the ground normal and
  the wheel's heading.
- **Need clamps (keep them):** the tyre force "need" clamps and the clutch and differential
  equalisation clamps limit each stiff coupling to the change needed in one tick. Removing them brings
  back standstill jitter and drivetrain oscillation.
- **Static friction (P2-04):** below 0.3 m/s the tyre also cancels its share of gravity along the
  contact plane, shared by wheel load. A parked car holds on a 20° grade and a 37° side slope without
  creeping.

## Walls and props

- **Walls (`wall_contact.gd`, P4-03):**
  - The chassis hull box is swept against wall collision (layer 2) each tick, so nothing tunnels at
    300 km/h.
  - Contacts come from intersect and collide queries, one collide query per touching wall body, so
    every contact carries its own wall's kind and that wall's face normal (a ray to its deepest point).
    In a corner of two walls, push-out clears each normal in turn and each contact uses its own
    kind's restitution and friction; Simcade removes the closing speed along every normal touched.
    One wall body reports one normal, so a sharp bend inside a single freehand wall is handled as one
    face (tested: no pass-through at 150 km/h into a 90° bend).
  - Sequential impulses with friction resolve them, with a restitution threshold of 0.5 m/s. Response
    varies by wall kind (tyre, armco, concrete).
  - In Simcade the car keeps more of its speed along the wall.
- **Props (`scripts/props/`):** cones, bollards and marker boards (`data/props.json`) are small
  rigid bodies that sleep until touched.
  - They exchange impulses with the car hull, the ground and walls, conserving momentum. A 4 kg cone
    at 100 km/h costs the car about 0.35 km/h.
  - Prop-to-prop collisions are not modelled.

## Handling models

`car.simcade_enabled` picks the model; the app defaults to Simcade.

- **Simulation** keeps the base tyre, drivetrain, temperature and contact calculations. Missing
  optional aid fields keep the original TC intensity and ABS settings, and zero ASM.
- **Simcade** is conditional inside the same solver. `data/simcade.json` holds the shared tuning, then
  the `carbody` section for the 6-DOF car (`asm_slip_cut_gain` 18, `sliding_grip_long` 0.84), then
  optional per-preset overrides.
  - The lateral curve ramps to its peak at 5°, holds it to 13°, then decays toward 0.87. Longitudinal
    slip uses the same shape.
  - Load sensitivity is x0.60. Temperature penalties are x0.24 and wear penalties a third.
  - Beyond the rear peak slip angle, a dissipative yaw moment damps rotation. It never assigns a
    heading.
  - The steering assist caps same-direction lock at the kinematic grip angle plus a margin, and
    countersteer stays available.
  - Gravel drag is higher.

## Numbered aids

- **TCS 0–10** maps to the integral traction-control intensity; 0 is off.
- **ASM 0–10** estimates the intended yaw from speed and steering, limited by grip, and compares it
  with the body-frame yaw rate and slip. On the 6-DOF car it reads the body frame, so it sees a bank
  or crest the way the driver feels it. It requests brake torque on one wheel and an engine torque
  cut; ABS can release an ASM brake.
- **Defaults:** Simcade TCS 3 / ASM 3 / ABS on. Simulation keeps each preset's values and zero ASM.
- **Records:** the effective aids and handling model are part of the record identity.

## Flight and landing

No special case is needed. With no ground within wheel reach, the tyres carry no load and the body
flies ballistically with free attitude. Landing compresses the tyre springs and suspension, and the
body box takes a hard landing.

The proving ground's crest takes off from about 149 km/h (152.5 km/h approach) with the 296 GT3.
`tests/v2/proving_ground.gd` measures it.

## Bot

`bot_driver.gd` drives any asset's BotLine at a fraction (0.85) of the car's own grip, which a quick
virtual skidpad measures and caches per configuration.

- **Speed plan:** the banked-turn limit from the line's curvature (measured over ±8 m) with load
  sensitivity, a crest limit, and a backward braking pass that shares grip with cornering.
- **Steering:** pure pursuit with a small capped cross-track term and yaw damping.
- **Pedals:** they release as body slip passes 3–8°.

It is a validation driver for `tests/v2/laps.gd` and `--v2-present`, not AI opponents.

## Verification

The headless suites in `tests/v2/` (TESTING.md) gate all of this: suspension statics, flat
equivalence with the recorded CarModel figures (±3 % massless, ±5 % compliant), energy, footprint and kerbs, static
friction, aids and Simcade bands, walls, props, the proving ground's features and clean bot laps on
every track, car and model within 2 % of the recorded baseline.
