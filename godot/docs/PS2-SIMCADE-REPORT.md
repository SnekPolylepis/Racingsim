# PS2-era graphics and Simcade delivery — 2026-09-21

Windows x64, Godot 4.6.2, NVIDIA GeForce RTX 4080. The browser implementation and user racing folders were not edited. Ordinary defaults are Spa / 296 GT3 / Simcade / Afternoon / 480p Soft / dither on / Low speed blur / Medium shadow quality / TCS 3 / ASM 3 / ABS on. Existing saved graphics preferences remain respected.

## Commits

- `f7ca754` — Afterhours baseline, preserving the original working tree as requested.
- `a9fac46` — world viewport, painted scenery and lighting presets.
- `663b358` — separate Simcade model, numbered aids and measured dynamics targets; visual/editor QA fixes.
- Delivery documentation and final verification are recorded in the following commit (see git history).

## Physics measurements

Same 240 Hz solver and named test controllers. Simulation's printed dynamics output matches the baseline exactly; its four circuit times also match to the printed precision. Browser parity remains inside its unchanged tolerances (0.005 state / 0.5 RPM), with maximum recorded state error around 2.21e-7 and RPM error 7.01e-8. No reference fixtures or existing Simulation thresholds were weakened.

| Car | Simulation 0–100 s | Simcade 0–100 s | Simulation 100–0 m | Simcade 100–0 m | Simulation skidpad g | Simcade skidpad g |
|---|---:|---:|---:|---:|---:|---:|
| roadster | 5.454 | 5.363 | 32.170 | 31.416 | 1.182 | 1.201 |
| gt | 4.475 | 4.400 | 29.503 | 28.845 | 1.749 | 1.807 |
| f296gt3 | 4.121 | 4.050 | 28.666 | 28.015 | 1.986 | 2.089 |

| Circuit | Simulation s | Simcade s | Off-track steps / contacts, both models |
|---|---:|---:|---:|
| Ridgeback | 92.350 | 92.308 | 0 / 0 |
| Oval | 41.513 | 41.500 | 0 / 0 |
| Monza | 248.225 | 248.179 | 0 / 0 |
| Spa | 308.429 | 308.367 | 0 / 0 |

Simcade peak mid-corner body slip with ASM 3: Roadster 6.72°, GT 6.80°, 296 6.49°. With all aids off: 15.87° / 19.43° / 17.45°. All recover below 3° after two seconds of neutral inputs (observed final-window maxima ≤0.01°). These transients use 90% of each measured 60 m skidpad lateral limit. Peak thermal conservative multipliers after one minute: 0.9959 / 0.9896 / 0.9931; model-wide thermal floor is 0.952. Measurable lift-off yaw increases: 0.09490 / 0.06496 / 0.09613 rad/s. Setup checks retain large differential torque differences and front load-transfer fractions moving 0.242→0.736, 0.333→0.633 and 0.338→0.615 when anti-roll-bar balance is reversed.

| Car | Keyboard lock 80 km/h | 120 km/h | 160 km/h | 160 km/h with ASM 1 |
|---|---:|---:|---:|---:|
| roadster | 4.10° | 6.92° | 9.12° | 11.22° |
| gt | 2.22° | 2.84° | 3.45° | 3.63° |
| f296gt3 | 2.33° | 2.95° | 3.51° | 3.71° |

These are maximum body-slip angles, using the keyboard ramp and speed falloff. Default aids are used except for the explicit ASM 1 column. Grass coast-down from 30 m/s leaves 21.15–22.29 m/s after three seconds; gravel leaves 4.75–5.81 m/s, with at most 0.008° body slip in the straight coast test. All three glancing-contact tests dissipate speed and yaw.

## Verification table

| Check | Model / renderer | Actual result |
|---|---|---|
| Browser physics parity | parity=true | PASS, unchanged tolerances |
| Native handling | Simulation | 24 checks, 0 failures |
| Dynamics | Simulation | 34 checks, 0 failures; identical printed baseline values |
| Dynamics | Simcade | 87 checks, 0 failures |
| Four-circuit laps | Simulation | PASS, all 4 clean |
| Four-circuit laps | Simcade | PASS, all 4 clean and within ±4% |
| Outline import | model-independent | 9 checks, 0 failures |
| Source features | Forward+ | 156 checks, 0 failures |
| Exported features | Forward+ | 156 checks, 0 failures |
| Art review | Forward+ / OpenGL | 24 captures per backend; final timing table below |
| Fresh-default title launch | Windows export | 7 checks, 0 failures; title screenshot reviewed |
| Ordinary exported startup | Forward+ | Exit 0 after 120 frames; empty stderr |
| Formatting / parser | source | gdformat clean at 110 columns; Godot parser clean |

Headless stdout/stderr: `tests/logs/final-{simulation,simcade}-{physics,handling,dynamics,laps,import}.{log,err}` (only applicable combinations exist). The initial sandbox launches crashed before Godot startup; approved runs outside the restricted Windows user produced these results. Empty stderr was required on final runs, not just zero assertion failures.

Rendered logs are `tests/logs/final-source-features`, `release-features`, `release-title`, `normal-launch` and `final-art-{forward_plus,gl_compatibility}`, with `.log` and `.err` extensions. Baseline suites passed before editing: parity, handling 24, dynamics 34, four clean laps and import 9.

## Measured frame times

1280×800 window, RTX 4080, VSync off, normal physics and rendering enabled. Each final case records 180 frames after warm-up. The last four stress cases start the car at 40 m/s in fourth gear to exercise High speed blur. Quality means Low / Medium / High; High enables the optional directional shadow map. The 480p world is 717×448 at this window aspect; all UI remains 1280×800. GPU values below are the mean sum for the world, glow and active history viewports, excluding UI; wall-frame time is the primary comparison.

| Lighting / resolution / quality | Forward+ median ms | p95 ms | GPU mean ms | OpenGL median ms | p95 ms | GPU mean ms |
|---|---:|---:|---:|---:|---:|---:|
| Afternoon / 480p / Low | 2.219 | 2.808 | 0.607 | 3.034 | 3.537 | 0.615 |
| Afternoon / 480p / Medium | 2.499 | 3.239 | 0.523 | 2.999 | 3.644 | 0.594 |
| Afternoon / 480p / High | 2.583 | 3.121 | 0.567 | 3.445 | 4.070 | 0.772 |
| Afternoon / Native / Low | 2.180 | 2.745 | 0.416 | 2.920 | 3.465 | 0.588 |
| Afternoon / Native / Medium | 2.193 | 2.696 | 0.405 | 2.874 | 3.464 | 0.581 |
| Afternoon / Native / High | 2.455 | 2.917 | 0.518 | 3.408 | 3.956 | 0.778 |
| Afterhours / 480p / Low | 2.969 | 3.851 | 0.516 | 3.151 | 3.809 | 0.629 |
| Afterhours / 480p / Medium | 2.439 | 3.162 | 0.507 | 3.204 | 3.809 | 0.657 |
| Afterhours / 480p / High | 2.814 | 3.316 | 0.595 | 3.611 | 4.415 | 0.902 |
| Afterhours / Native / Low | 2.581 | 3.155 | 0.480 | 3.245 | 4.073 | 0.365 |
| Afterhours / Native / Medium | 2.410 | 2.980 | 0.484 | 3.181 | 4.026 | 0.364 |
| Afterhours / Native / High | 2.803 | 3.381 | 0.580 | 3.709 | 4.513 | 0.537 |
| Afternoon / 720p / High / High blur | 2.669 | 3.209 | 0.552 | 3.589 | 4.405 | 0.536 |
| Afternoon / Native MSAA 2× / High / High blur | 2.787 | 3.464 | 0.601 | 3.761 | 5.138 | 0.591 |
| Afterhours / 720p / High / High blur | 2.927 | 3.635 | 0.542 | 3.862 | 4.777 | 0.591 |
| Afterhours / Native MSAA 2× / High / High blur | 3.015 | 3.758 | 0.715 | 4.093 | 4.972 | 0.618 |

All sampled p95 values are below the 16.67 ms budget for 60 fps. This is evidence for the tested scenes and settings, not a guarantee across every scene, setting combination or hardware configuration. The new 480p mode is **not consistently faster than the new Native mode** on this CPU-limited workload; sub-millisecond variation and viewport overhead dominate at this window size.

For the requested before/after comparison, baseline commit `f7ca754` was extracted into an isolated temporary project. Only timing instrumentation changed: 600 frames after 180 warm-up frames, normal physics/rendering, Afterhours, Native, 40 m/s in fourth gear. Original materials and import settings were retained. The temporary project was removed after retaining the JSON reports in `tests/baseline/baseline-timing-{forward_plus,gl_compatibility}.json`.

| Renderer / quality | Before Native median / p95 ms | After 480p median / p95 ms | Median change |
|---|---:|---:|---:|
| Forward+ / Medium | 2.872 / 3.454 | 2.439 / 3.162 | 15.1% faster |
| OpenGL / Medium | 3.484 / 4.031 | 3.204 / 3.809 | 8.0% faster |
| Forward+ / High | 2.853 / 3.577 | 2.814 / 3.316 | 1.4% faster |
| OpenGL / High | 3.530 / 4.161 | 3.611 / 4.415 | 2.3% slower |

The default Medium path improved against the original Native baseline on both backends. High OpenGL did not improve in this sample; the universal low-resolution speedup target is therefore not claimed. These are short capture windows, not a controlled long-duration hardware benchmark.

## Screenshots and visual review

Before: `tests/baseline/style-front.png`, `style-rear.png`, `style-profile.png`, `style-eau-rouge.png`, `style-menu.png`. Those files were captured from f7ca754 before editing. Older `style-gl-*` copies in that folder are not used as new baseline evidence.

After: `tests/ps2-forward/` and `tests/ps2-gl/`. In each folder the complete naming matrix is `{afternoon,afterhours}-{480p,native}-{front,rear,profile,eau-rouge,menu,hud-motion}.png`. Runtime reports are `art-results.json` beside the images. Exported screenshots/reports go to `user://native-tests/`; fresh title is `native-title-defaults.png`.

Convenient local copies of the packaged title evidence are `tests/release-title.png`, `tests/release-title-results.json` and `tests/release-feature-results.json`. Four `review-{afternoon,afterhours}-{480p,native}.png` contact sheets per renderer show all 48 final views. The untouched individual PNGs remain the full-resolution evidence.

Images were inspected for car shape, glass/reflection saturation, tyre/wing visibility, forest cards, glow, fog, UI legibility and backend differences. Review iterations reduced paint washout, replaced periodic tree noise with painted fractal variation, corrected OpenGL paint colour handling, retained blue sky under glow and fixed editor strip triangulation. The look is original procedural art, not copied game assets or a claim of exact PS2 hardware emulation.

## Five principal feel controls

All are in `data/simcade.json`; optional per-car `simcade` overrides are supported.

| Constant | Value | Effect |
|---|---:|---|
| peak_end_deg | 13 | Holds the lateral-force plateau before grip begins to fall; peak_start_deg is 5. |
| sliding_grip | 0.87 | Sets the large-slip grip floor and makes an established slide more recoverable. |
| load_sensitivity_scale | 0.60 | Retains weight transfer while reducing its total-grip penalty. |
| yaw_damping | 3.5 | Adds dissipative yaw moment only beyond the rear peak body-slip angle, even with ASM off. |
| steering_peak_fraction | 0.70 | Limits assisted same-direction lock to the kinematic grip angle plus 3.5°; lower values feel calmer. |

ASM gains, curb excitation, heat/wear compression and contact retention are separately named in the same table. TCS/ASM/ABS are driver-selected aids, distinct from the physical model.

## Boundaries

No core visual or handling feature was deferred. The remaining performance qualification is the High OpenGL comparison above; further CPU-side optimization and a longer benchmark are deferred because the sampled frame times already have substantial margin to 60 fps and the short timing windows do not establish a reliable resolution-only speedup.

No requested platform port, external assets, plugins or network dependency was added. The editor remains a native-resolution 2D canvas; it has no 3D ray picking to move into the SubViewport. Tests exercise both its actual point selection and the new camera pixel mapping. Ground paint masks intentionally retain their exact data-grid resolution and nearest cell lookup; they are not visual textures to downsample. Directional shadow maps are optional High; blob shadows and vertex-colour ground darkening cover the default path. Low and Medium currently share the same shadow-free pipeline.

Physical controller hardware and subjective human driving feel have not been playtested. Synthetic tests and screenshots are recorded evidence, not universal stability/performance guarantees. Frame timing is measured on this PC at 1280×800, not on other hardware or every possible window size. No visual or physics reference fixture was altered to manufacture a pass.
