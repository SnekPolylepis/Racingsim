# Mallers Building — reference work, 2026-10-05

Mapped candidate `w147478105`, 5 South Wabash. Native Grid candidate review
PID77424 previously completed and showed the mapped shell still rendered.
The irregular mapped footprint must be retained when fitting the replacement;
no replacement asset or integration has been made yet.

## Primary sources inspected

- [Council on Vertical Urbanism](https://www.skyscrapercenter.com/building/mallers-building/26978): architectural and tip height 87 m, 21 above-ground floors, Christian A. Eckstorm. This supersedes the unverified mapped height 87.5 m for authoring. Floor module sizes still require photographic evidence.
- [Jewelers Center owner](https://jewelerscenter.com/about-us/): identifies the Mallers Building as built in 1912. The image labelled “Jewelers Center Building” was opened and actually inspected: it is a stylized illustration/logo, not an exterior photograph. It cannot establish exact facade bay counts or entrance dimensions.
- [Chad Davis original photograph](https://chaddavis.photography/jewelers-center-neon-sign-on-wabash-avenue-chicago/), October 2019: actual image opened and visually inspected. Shows a projecting vertical JEWELERS CENTER sign, red neon outline, raised yellow lettering with small lamps and a blue diamond cap; mounting brackets, projecting decorative bands, and recessed street openings are visible. The upward close-up does not establish the full tower facade or roof. Its prose calls the building 1920s-era; owner construction date 1912 is the stronger building-history reference.

## Next authoring step

Find and actually inspect a clear full-height north/west exterior photograph.
Model recessed panes, projecting piers/bands, street openings and the physical
sign using original geometry. Do not infer surveyed dimensions from the logo
or assign the facade of the different Jewelers Building at 15–19 S Wabash.
Reference photos remain external; no downloaded photo is distributed as an asset.
Review from Godot source; do not export a building-specific executable.

## Original architectural drawing inspected

The [archived July 2, 1911 Tribune perspective](https://chicagology.com/wp-content/themes/revolution-20/skyscraper2/chicagotribunegraphic2july1911mallersbuilding.jpg)
was opened and visually inspected on 2026-10-05. It shows separate narrow
window apertures, a four-level base including ground retail, a tall repetitive
shaft, an upper facade band and a deeply projecting bracketed cornice.
This is a preconstruction perspective, not proof of the current built facade.
The archived original article and 1922 directory give 172 ft Madison frontage
and 97.5 ft Wabash frontage (52.4256 m and 29.718 m), white enamel terra cotta,
and a southeast corner location. These dimensions broadly match the candidate's
52 m by 30 m overall footprint.

The [1927 insurance map](https://chicagology.com/wp-content/themes/revolution-20/skyscraper2/mallerbuilding1927map.jpg)
was also actually inspected: the marked 21-story building is east of Wabash
and south of Madison. Verify the modern mapped footprint coordinate orientation
before choosing which local face receives the Wabash sign and entrance; the
previous north/east face assumption is not established by the historical map.
Modern full-height facade verification remains outstanding.

## Mapped orientation resolved

Read the checked-in raw `downtown-buildings.json` and road extracts on
2026-10-05. `w147478105` identifies Mallers/5 South Wabash, 21 levels and 87 m.
The local frame is +X east, +Z south. South Wabash runs approximately x=-148.5
to -144.2 south of Madison; Madison runs z=301.6–302.4 across this frontage.
Thus the mapped north face (z approximately312–313) is Madison and the west
face (x approximately-132) is Wabash. The east face near x=-81 is the rear/alley
side, not the public Wabash frontage. The earlier candidate camera at x=-79
looks from the east side; it proves the shell exists but does not verify the
main entrance. Review north and west street cameras for the replacement.

Raw OSM accessibility text names an alternate entrance at67EastMadison and
revolving doors at the main entrance. This is map metadata, not an inspected
current entrance photograph; use visual evidence before reproducing doors.
