# Gemini task: repair audio, then finish Nordschleife kerbs

Work only in this Preview 10 checkout. Start by reading `AGENTS.md`, `godot/docs/REBUILD-PLAN.md` (especially §9), the latest relevant entries in `godot/docs/REBUILD-LOG.md`, `godot/docs/rebuild/QUEUE.md`, and the relevant portions of `godot/docs/LLM-GUIDE.md`. Claim/log the task using the repository protocol. Do not change the original Preview 10 checkout.

## 1. Fix the audio first

The owner reports: **the new sounds are hard to hear properly; everything sounds high-pitched and tinny.** Reproduce and diagnose the actual sound path before tuning. Inspect `godot/scripts/audio.gd`, generated/imported audio under `godot/assets/audio/` and `audio-source/`, the vehicle audio generation tools, bus/effect setup, and the current audio tests/gates. Trace source sample → import/generation → playback pitch/gain/filtering → output bus. Look for global causes (sample rate, octave/pitch scaling, thin source material, EQ/high-pass, missing low end, excessive layers) before adjusting individual sounds.

Make the smallest root-cause fix that gives the sounds body, warmth and clear separation at normal gameplay volume. Keep engine character and useful road/tyre/kerb cues; do not simply lower every pitch or add a blanket bass boost. Check representative cars, RPM/load ranges, throttle lift, tyre/road/kerb/gravel, impacts and menu sounds. Use the existing tests and add only a small regression check if the root cause needs one. Record what was actually listened to and on what output; automated/spectral checks do not establish subjective hardware acceptance.

## 2. Research and implement the full-lap Nordschleife kerbs

The owner says the current kerbs feel like generic little bumps. They want the track to use the different real kerb forms and place them where those forms belong. Treat this as a real-reference tracing and physics task, not a broad visual polish pass.

Before editing, trace the existing route end to end: `godot/trackgen/nordschleife.gd`, `godot/trackgen/data/nordschleife/kerbs.json`, `godot/scripts/track/road_section.gd`, `godot/scripts/track/road_builder.gd`, `godot/scripts/surface/surface_table.gd`, collision/contact sampling in `godot/scripts/vehicle/`, kerb-related gates and current CACHE_REVISION. Read the relevant K-01/K-02/K-03 and LOOK-21 log entries; earlier work already traced Spa and Nordschleife S1, while the full lap still had a generic stopgap. Preserve verified existing traces unless new evidence corrects them.

### References

First inspect the local reference images and their credits in `godot/docs/art/reference/README.md` and `godot/docs/art/reference/`, especially:

- `real-nordschleife-brunnchen.jpg`
- `real-nordschleife-adenauer-forst.jpg`
- `real-nordschleife-flugplatz.jpg`
- `real-nordschleife-panorama-banking.jpg`
- `real-nordschleife-karussell-capri-1973.jpg` and `real-nordschleife-karussell-lauda-1973.jpg` (the Karussell is a concrete bowl, not a kerb)
- `gt4-nordschleife-chase-kerb-apex.jpg` and `gt4-nordschleife-chase-kerbs-armco.jpg` only as supplemental coverage/layout cues, not evidence of current real-world geometry.

For any unclear or uncovered section, find usable real circuit photographs and a corner/location reference. Useful starting points:

- Nürburgring corner map: https://nring.info/nurburgring-nordschleife-corners/
- Nürburgring photo spots: https://nring.info/nurburgring-photo-spots/
- Wikimedia Nordschleife section photographs: https://commons.wikimedia.org/wiki/Category:Nordschleife_circuit_sections
- Toyota Gazoo Racing Nordschleife booklet (corner descriptions and map): https://toyotagazooracing.com/-/media/TMC/tgr/global/contents/nurburgring/contents/story/data/booklet.pdf

Prefer current real photographs over game screenshots. For every assigned run, record the corner/side, approximate route station or named range, observed shape/paint, confidence, image source and image date if available. Do not infer a physical raised kerb from paint, shadows, old photos or an unclear crop. Mark uncertain cases and leave them unassigned until evidence supports them. Respect source licenses: link/cite reference images in documentation; do not bundle copyrighted downloads into shipped game assets.

### Build and placement requirements

- Cover the complete Nordschleife, not just the removed S1 section. Check both sides and corner exits, including sections where the correct result is only a painted edge line and no raised kerb. Keep the Karussell concrete bowl separate from kerb assignments.
- Build a small, data-driven vocabulary of visibly and physically distinct profiles justified by the evidence. Existing `NONE`, `RAMP`, `SAUSAGE`, and `RIBBED` are starting points, not a requirement to force every real shape into them. Extend the minimal shared profile/baker only where the reference demonstrates a distinct shape; do not add types speculatively.
- Profiles must affect the road mesh **and collision/surface contact** coherently: height, width, ramp/edge transitions, rib or block spacing, and surface feel. A painted texture alone does not count. Avoid sharp seams, snagging, wheel tunnelling, and excessive jolts from the tyre footprint sampler.
- Encode reviewed assignments in the existing kerb data pipeline where possible, with exact start/end stations, side, profile parameters, paint/material, evidence URL/local reference, and confidence. Make transitions follow where the physical kerb begins/ends. Ensure cache invalidation and export inclusion follow existing project patterns.
- Place every assignment against the full-lap route using the data's station convention; cross-check station-to-named-corner mapping and side orientation in rendered views. Do not copy S1 stations onto the full lap without mapping them.
- Keep the route, lap timing, bot line, and unrelated scenery unchanged unless a proven kerb/contact defect requires a narrowly scoped correction.

## Review and completion

Work in this order: audio root cause and correction; reference inventory and kerb map; profiles/contact implementation; full-lap placement; concise visual/drive review; verification and log. Do not make repeated open-ended AI polish passes. Make one evidence-led implementation, inspect the resulting circuit at representative types and transitions, then fix concrete defects found.

Use existing targeted audio, kerb, Nordschleife, parse, and lap checks as appropriate, and report exact commands/results. Capture a concise comparison set showing each kerb type and its location; include audio assets or waveforms only where useful, and clearly say if audio could not be auditioned. Update the rebuild log, queue, source map or docs only where needed. Finish with a short summary of changed files, types and traced locations, source references/confidence gaps, checks run, and any listening/hardware limitations. Do not claim subjective audio or real-hardware validation that did not happen.
