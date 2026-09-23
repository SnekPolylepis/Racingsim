# Native physics: handling models

The native custom solver runs at 240 Hz and is authoritative. The browser-parity path (`car.parity`) has been retired: native physics is no longer required to reproduce the browser solver, and the current `scripts/car.gd` has no parity property. Historical model constructors default to Simulation; the application defaults to Simcade. See ARCHITECTURE for coordinates, solver ordering and clamps.

## Handling models

Simulation (`simcade_enabled=false`) preserves the pre-overhaul tyre, drivetrain, suspension, temperature and contact calculations. Missing optional aid fields preserve original TC intensity, ABS settings and zero ASM. Existing dynamics and lap harnesses run this path unless passed `-- --simcade`.

Simcade is conditional inside the native path. `data/simcade.json` owns shared tuning, with optional `preset.simcade` overrides. No suspension, drivetrain, gearing, differential, aero or need-clamp equations are replaced.

The lateral force curve ramps sinusoidally to peak at 5 degrees, holds peak through 13 degrees, then decays exponentially toward 0.87. Longitudinal slip uses the same shape at 0.78–1.8 times the existing peak ratio. The unchanged combined-force ellipse prevents simultaneous full longitudinal and lateral force. Load sensitivity is multiplied by 0.60. Temperature penalties are scaled by 0.24 (absolute thermal floor 0.952); wear penalties by one third. Temperatures still evolve through the original two-node heat model; Simcade starts at optimum.

Beyond the rear tyre peak body-slip angle, an opposing yaw moment proportional to inertia, yaw rate and excess slip dissipates rotation. It never assigns a heading or clamps lateral velocity. Steering assist caps same-direction lock at the kinematic grip angle plus 0.70 × 5 degrees; countersteering remains available. The shared option applies to keyboard and controller.

Curbs contribute 0.55 of their wheel-height excitation and rough surfaces 0.35 of the random bump. Grass retains slippery grip and drag. Gravel drag increases to 1.25 with symmetric longitudinal/lateral resistance. Simcade contact removes inward normal velocity, retains 0.94 tangential speed and 0.65 yaw rate; contact invalidation is unchanged.

## Numbered aids and compatibility

TCS 0–10 maps to the existing native integral TC intensity; 0 disables it. ASM 0–10 estimates intended yaw from speed and steering, limits it by available grip and compares it with yaw/body slip. It requests a selected wheel's brake torque and an engine-torque reduction. Wheel torques still enter through the existing drivetrain/force loop and ABS can release an ASM brake. The physical yaw damping is separate and remains with ASM off. Simcade defaults are TCS 3 / ASM 3 / ABS on. Simulation defaults retain each preset's previous values and zero ASM.

The 42 original setup fields are retained. Optional tcsLevel/asmLevel fields survive saves, and exported legacy TC fields reflect the effective level. Legacy fractional intensities remain representable; the UI moves in whole levels. Missing ASM in an old setup means off. Effective aids and handling model enter the record hash; graphics and time of day do not. Ghost sample structure remains browser-compatible. Unconfigured legacy ghosts are not automatically adopted into Simcade.

## Measured verification

`tests/dynamics.gd -- --simcade` compares acceleration, stopping distance and skidpad grip with fresh Simulation measurements (±8%), tests 90%-limit transients and recovery, keyboard full lock, ASM 1, tyre plateaus, heat soak and setup/surface/contact authority. `tests/laps.gd -- --simcade` requires clean laps and ±4% of the recorded Simulation bot baseline. These synthetic controllers measure defined cases, not universal spin immunity or real-car validation. Final numbers and output locations are in PS2-SIMCADE-REPORT.md.

## Vertical dynamics and flight

The road beneath the car asks for a normal acceleration of `g·cosθ + v²·kv`: gravity's share along the surface normal plus the centripetal term of following vertical curvature `kv` (negative over a crest). While the car is grounded, `g_eff` is that value clamped to `[0, 3g]` and drives the heave equation, so crests lighten the car and compressions load it.

When `m·(g·cosθ + v²·kv)` plus aerodynamic downforce goes negative, no tyre force can hold the car to the road, and it takes off with the road's own vertical velocity at the lip. In the air, `car.air` is the height above the road beneath and `car.air_vz` the world vertical velocity; gravity and downforce act straight down, slope gravity is removed, every tyre carries zero load (so there is no grip, steering or braking force), and the wheels hang at full droop while pitch and roll hold their takeoff values. When `air` returns to zero, the closing speed into the road becomes suspension compression rate, so the landing is absorbed by the springs, dampers and bump stop.

Simplification: the rendered attitude in flight follows the road beneath the car rather than integrating free rotation. That is close for short jumps and wrong for long ones.

Suspension travel: corner compression beyond 8 cm meets a bump stop at six times the spring rate. A corner's force is clamped so it can never imply negative load, and that clamped value drives both the wheel load and the chassis degrees of freedom. Road deviation per wheel relative to the chassis tangent plane is limited to 0.70 m, above the measured 0.64 m residual in the Caracciola-Karussell.

