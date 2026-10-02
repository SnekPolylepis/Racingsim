# Chicago Theatre / Page Brothers exterior models

Original Blender-authored interpretations for Racing Sim, 2026-10-01.
No full-building photograph is used as a runtime material. The editable sources
are `tools/blender/authored/chicago_theatre.blend` and `page_brothers.blend`;
rebuild both with `tools/blender/chicago_theatre.py` (see its command header).

Theatre: 99,142 triangles, 11 material surfaces. Page Brothers: 14,424 triangles,
5 material surfaces. Repeated details are joined by material at export.
Origins are the State Street frontage midpoint, ground at zero, glTF +Y up.
Footprint IDs are OSM w124873919 and w124873930; frontage roof medians are
27.5 m in the existing USGS data. Ornament and backstage massing are authored
approximations, not an architectural survey. Interiors are not modelled.

References:

- [Chicago Architecture Center: Chicago Theatre](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-theatre)
- [Daniel Schwen: Chicago Theatre blend](https://commons.wikimedia.org/wiki/File:Chicago_Theatre_blend.jpg), CC BY-SA 4.0, already credited; visual reference only, no pixels copied into these models.
- [Chicago Landmarks: Page Brothers](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1393)
- Existing `trackgen/data/chicago/city.json` footprints and measured roof returns;
  provenance is in the Chicago data README.

Online acquisition checked first: the Free3D Theatre asset covers only the signs
and is paid; the Polycam scan's usable download was not verified. Neither is used.

## Cultural Center

Original Blender-authored exterior (`cultural_center.glb`, 65,300 triangles,
7 surfaces), editable `tools/blender/authored/cultural_center.blend`; regenerate
with `tools/blender/chicago_cultural_center.py`. Mapped footprint r15899437,
28.5 m frontage cornice and measured higher roof returns retained. Recessed
arched glazing, paired upper/ground windows, pilasters, cornices and side
porticos replace the complete photo panel. Ornament is an approximation.

References: [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-cultural-center),
[Chicago Landmarks](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1274),
[UIC: 65 Michigan Avenue windows](https://today.uic.edu/windows-mirror-styles-seen-across-city/),
and the existing credited w_lemay Cultural Center east elevation photograph
(visual reference only). The checked online scan was an interior point cloud;
no third-party model or photo pixels are included in the exterior.

## Railway Exchange

Original Blender-authored exterior (`railway_exchange.glb`, 169,588 triangles,
5 surfaces), editable
`tools/blender/authored/railway_exchange.blend`; regenerate with
`tools/blender/chicago_railway_exchange.py`. Footprint w124873931 and 75 m
measured roof median; small rooftop office is an authored approximation.
Four facades have projecting window reveals, terra-cotta piers, sash glazing,
round top-floor windows and cornices. Wings surround a central light well
with a low glazed atrium roof. Ornamental details are stylized approximations.

Primary reference: [Chicago Architecture Center: Railway Exchange](https://www.architecture.org/online-resources/buildings-of-chicago/railway-exchange-building).
Existing Vincent Desjardins CC BY 2.0 rx_east.jpg used for visual reference only;
no photo pixels are included. Online asset search found no usable building
exterior download, so this is original Blender geometry.

## Chicago Athletic Association

Original Blender-authored Venetian Gothic exterior (`athletic_association.glb`,
98,020 triangles, six surfaces), editable source
`tools/blender/authored/athletic_association.blend`; regenerate with
`tools/blender/chicago_athletic_association.py`. Mapped footprint w147476152;
52 m roof uses the building's measured median. The isolated 84–92.5 m cells
along the north boundary are treated as neighbouring roof contamination, rather than a Gothic
facade height. Three front galleries, real curved tracery/columns, circular and
pointed stone arches, quoins, raised lettering and the arched entrance replace
the full photograph. Rear elevations and tiny sculptural motifs are stylized
approximations; the flat roof and concave annex footprint are retained.

References: [HABS IL-1226, National Park Service](https://tile.loc.gov/storage-services/master/pnp/habshaer/il/il0900/il0935/data/il0935data.pdf),
[Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-athletic-association-hotel),
and existing Beyond My Ken CC BY-SA 4.0 caa_east.jpg (reference only, no pixels
rendered). Online search found no usable building exterior model; the mesh is
original Blender geometry.

## University Club

Original Blender Gothic exterior (university_club.glb, 40,659 triangles, six
surfaces), editable tools/blender/authored/university_club.blend; rebuild with
tools/blender/chicago_university_club.py. Mapped w126982632 footprint; 52 m main
cornice, 58 m eave/top gallery and 69 m gable ridge follow the measured profile.
Steep roof, triangular gables, pinnacles, simplified owl, oriels, balconies and
curved Gothic windows are meshes. Sculpture and secondary elevations are
approximations. Reference: [official club history](https://www.ucco.com/about/history)
and existing David Brossard CC BY-SA 2.0 photo; no photo pixels render. No usable
exterior model download was found.

## Orchestra Hall

Original Blender Georgian exterior (orchestra_hall.glb, 78,075 triangles, six
surfaces), editable tools/blender/authored/orchestra_hall.blend; rebuild with
tools/blender/chicago_orchestra_hall.py. Mapped w145493030 footprint; 42 m front
and 33.5 m annex roof use measured returns away from adjacent boundary peaks.
Three monumental arched windows have curved glazing, deep archivolts, radial
fanlights, jambs and balcony balusters. Upper sashes, quoins, pediments, cornices,
roof balustrade and lettering are meshes. Rear annexes/sculpture are approximations.
Reference: [CSO Rosenthal Archives](https://chicagosymphony.org/about/rosenthal-archives/orchestra-hall-at-chicago-symphony-center/)
and existing Beyond My Ken CC BY-SA 4.0 sym_east.jpg; no photo pixels render.
The dated advertising banner is omitted. No usable building model was found.
