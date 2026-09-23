# Ferrari 296 GT3: model authoring guide

The Windows game's `gt3` presentation now uses a dedicated exterior in `scripts/ferrari_296.gd`. It replaces the generic loft and the old add-on round tail lamps. The goal is a recognizable 2023 Ferrari 296 GT3 in the existing PS2-inspired night presentation. This is original procedural game geometry built by studying reference images, not a manufacturer-supplied CAD model or a dimensionally certified reproduction. It is not the road-going GTB/GTS or the later GT3 Evo.

## Entry points and ownership

`Visuals.make_car(p, ghost)` selects the builder when `p.body == "gt3"`. Other cars retain the generic loft. The builder creates a root and a sprung body, authors the static exterior, then calls `Visuals.finish_car`. That shared function creates the four steering/suspension pivots and spin nodes and returns the established dictionary:

| Key | Meaning |
|---|---|
| `root` | Road position, bank/gradient orientation and heading |
| `body` | Sprung exterior; local heave, roll and pitch |
| `pivots` | `[FL, FR, RL, RR]`, steering and wheel suspension height |
| `spins` | Children of pivots; wheel phase rotation |
| `brakes` | Per-car material shared by rear lamps and rain lamp |
| `wheel_r` | Visual contact radius from the preset |

`pose_car` still accepts a snapshot dictionary. Geometry must never read or advance physics. Tires, rims, rotors and lettering are under the spin nodes; calipers are under the pivots. Moving the calipers under a spin node makes them rotate with the wheels. The ghost uses the same geometry but overrides every mesh with the ghost material, hides labels and emits no headlights. Night-gated headlights are no longer specific to this builder; all three cars have them.

## Geometry and coordinates

Local +X points forward, +Y points up, and +Z points right. Units are metres. The current 296 preset puts the front axle at +1.54 and rear at -1.11, with a 1.68 m track and 0.345 m wheel radius. The authored 296 body geometry is built around exactly those numbers, so preserve them when editing this artwork. That is a constraint on the 296's hand-authored exterior, not a ban on retuning a car: the roadster preset's wheelbase, mass and drivetrain were deliberately changed when it became the MX-5, and it uses the generic parametric loft. The authored exterior spans X -2.01 to +2.62 before splitter and wing extensions. Roof height is about 1.22 m, maximum body half-width about 1.035 m. These are visual authoring dimensions, not a specification claim.

The builder is specific to the current 296 preset. Several body coordinates are deliberately authored in absolute metres. Changing wheelbase, track or wheel radius requires reviewing the body clearances; it is not an arbitrary parametric car generator.

| Function | Geometry it owns |
|---|---|
| `width_at`, `crown` | Longitudinal width, central deck and raised shoulder profiles |
| `arch_bottom`, `shell` | Upper body, cut side skins, rolled wheel-arch lips |
| `cockpit` | Roof, raked screen, side glazing, window slider, pillars, flying buttresses, engine cover |
| `front_clip` | Swept lamp recesses, LEDs/projectors, radiator opening, corner ducts, S-duct, canards and splitter |
| `sides` | Sculpted door/channel, seams, sill, tricolour, mirrors and small shield fields |
| `rear_clip` | Black fascia, inset pill-shaped lamps, exhausts, diffuser, wing and swan-neck supports |
| `livery` | Geometry conforming to the rear crown rather than floating flat decals |
| `wheel_details` | Forged ten-spoke/Y-fork rim, lip, rotor, centre lock, caliper and tire lettering |

The upper shell samples 64 longitudinal intervals and 13 lateral stations. Only the side skin rises over a tire: the previous generic method raised the entire bottom cross-section, which distorted the nose and wheel arches. `face` checks the geometric cross product against an explicit outward vector and emits clockwise Godot faces. Mirrored sides must pass their own outward direction. `finish(..., smooth=true)` indexes shared vertices before generating normals. Separate panel edges stay hard. The first body child remains the crown mesh for the exterior-normal integration check.

The wing's named geometry is lowered 0.12 m in `build`, bringing its aerofoil close to roof height. The wing text is positioned at the corresponding height. If changing the wing, edit this adjustment and the text together. Do not infer model scale from an individual screenshot's camera perspective.

## Materials and details

The shell and painted panels retain `retro_paint.gdshader`: a generated environment reflection, Fresnel highlights and a sharp view-dependent sweep with Gouraud base lighting. The red preset and darker lower-flank vertex colours preserve shape under the saturated night grade. Standard materials shade the mechanical parts, mirrors, seams and wheels. Reduced headlight emission retains visible lamp clusters instead of two oversized glowing bars. Rear lamps share the independently animated brake material.

Labels use bundled engine text rendering. The Ferrari word labels request installed Georgia/Times New Roman through `SystemFont`, falling back through Godot if unavailable; no Windows font file is bundled. This lettering and the small shield fields are simplified representations. The exterior does not include an exact prancing-horse badge, sponsor decal package, detailed cockpit interior, damage states or opening panels. No reference photograph is shipped as a game texture.

## References and validation

The model was compared against the original launch-car front, side and rear images, including the headlamp recesses, central hood extraction, wheel openings, short cabin, door air channel, rear fascia and wing supports. Reference starting points: [Ferrari's 296 GT3 unveiling](https://www.ferrari.com/en-US/competizioni-gt/articles/ferrari-296-gt3-unveiled), [launch gallery](https://www.caricos.com/cars/f/ferrari/2023_ferrari_296_gt3/), and [front/side/rear photo collage](https://media.techeblog.com/images/ferrari-296-gt3.jpg). These are visual references, not assets included in the executable.

Run `-- --art-review` and inspect all three car angles, chase views and the menu. Check wheel openings at the axles, lamp visibility, aero silhouettes, panel intersections and text placement. The feature runner also checks steering, spin, suspension, sprung-body motion, changing brake emission and ghost material/light behavior. This verifies the animation contract; it does not measure geometric resemblance. Rebuild the Windows executable after source changes, and run the exported feature suite. See [TESTING.md](TESTING.md) for commands and [ART-DIRECTION.md](ART-DIRECTION.md) for the night renderer.

## Console geometry budget

The follow-up 296 has 11,546 mesh triangles across 361 mesh nodes (glyph geometry and drop shadow counted separately). Wheel cylinders use 16 radial sections, and rim/tyre tori use 24 rings with four ring segments. This preserves the silhouette and pose interface while reducing the previous 21,498 triangles. The budget is an authored working target, not a verified proprietary GT4 car count.
