@tool
class_name RoadSection
extends Resource
## One cross-section key of a RoadPath (REBUILD-PLAN.md P3-02), at `at` metres along the path.
## Between keys, numeric values ease with a smoothstep; kerb types and surfaces switch at the key.
## Lateral convention: right of the direction of travel is positive. Godot axes, metres, degrees.

enum Kerb { NONE, RAMP }

## Distance along the road, metres.
@export var at = 0.0
## Road half-widths to the left and right of the path, metres.
@export var width_left = 5.0
@export var width_right = 5.0
## Rotation of the cross-section about the direction of travel. Positive raises the left edge
## (the project's bank convention; bank a right-hand corner positive).
@export_range(-45.0, 45.0, .1) var bank_deg = 0.0
## Height of the centreline above the straight line between the two edges (parabolic crown), metres.
@export var crown = 0.0
## Kerb on each side: NONE continues the verge from the road edge; RAMP rises to kerb_height across
## kerb_width from the road edge outwards.
@export var kerb_left: Kerb = Kerb.NONE
@export var kerb_right: Kerb = Kerb.NONE
@export var kerb_width = 1.0
@export var kerb_height = .05
## Verge beyond the kerb band, falling away from the road at verge_slope_deg.
@export var verge_left = 6.0
@export var verge_right = 6.0
@export_range(0.0, 45.0, .1) var verge_slope_deg = 3.0
## SURF table indices (scripts/track3d.gd): 0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff.
@export_range(0, 4) var road_surface = 0
@export_range(0, 4) var verge_surface = 2


static func make(offset, values = {}):
	var s = new()
	s.at = offset
	for key in values:
		s.set(key, values[key])
	return s
