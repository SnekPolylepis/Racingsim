# Chicago / Spa final visual review

The sheets cover each complete authored lap at 350 m intervals in Daybreak and Afterhours: 24 + 24 Chicago frames, 20 + 20 Spa frames. Parent and separate visual reviewers checked the sheets and enlarged problematic frames; the individual PNGs retain landmark and clearance details.

Run `tests/v2/track_screenshots.gd -- --v2-flow-test --track=chicago --lap-step=350 --out=<folder>` (add `--night`; use `--track=spa` for Spa). `tests/v2/chicago_screenshots.gd -- --v2-flow-test --v2-track=chicago --out=<folder>` records the focused city views; omit `--lap-step` in the general tool for named Spa corners. All commands need a graphical login session and a timeout.

The Spa sheets were recorded before the final canopy-normal fix; `spa-pit-day.png` proves the current solid roof lighting. Chicago sheets and focused pictures include final box-axis, L-column and plaza-tree corrections. The narrow west plaza entrance is an authored park connection; it is not claimed as surveyed geometry. Official references are linked in the adjacent Chicago/Spa polish records.

`manifest.json` records frame counts, engine/platform and artifact hashes. Captures report no script errors but retain an ObjectDB cleanup warning at shutdown.
