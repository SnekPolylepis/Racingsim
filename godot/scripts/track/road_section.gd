@tool
class_name RoadSection
extends Resource
## One cross-section key of a RoadPath (REBUILD-PLAN.md P3-02), at `at` metres along the path.
## Between keys, numeric values ease with a smoothstep; kerb types and surfaces switch at the key.
## Lateral convention: right of the direction of travel is positive. Godot axes, metres, degrees.
##
## Cross-section, from the centre outwards on each side:
##   road (crown, bank, optional inset ditch) | kerb band | runoff band | verge band
## A side with no kerb keeps its kerb band, continuing the runoff/verge instead. A runoff of zero width
## keeps a 5 cm band of verge. So every station has the same topology.

## RAMP rises linearly to kerb_height across kerb_width (a bevel); SAUSAGE is a rounded hump
## (kerb_height at mid-width, back to zero at both edges); RIBBED rises to kerb_height in its first
## quarter and carries transverse ridges of rib_height every rib_pitch metres along the road.
enum Kerb { NONE, RAMP, SAUSAGE, RIBBED }

## Distance along the road, metres.
@export var at = 0.0
## Road half-widths to the left and right of the path, metres.
@export var width_left = 5.0
@export var width_right = 5.0
## Rotation of the cross-section about the direction of travel. Positive raises the left edge
## (the project's bank convention; bank a right-hand corner positive, an adverse camber negative).
@export_range(-45.0, 45.0, .1) var bank_deg = 0.0
## Height of the centreline above the straight line between the two edges (parabolic crown), metres.
@export var crown = 0.0
@export_group("Kerbs")
@export var kerb_left: Kerb = Kerb.NONE
@export var kerb_right: Kerb = Kerb.NONE
@export var kerb_width = 1.0
@export var kerb_height = .05
## RIBBED only: ridge height above the kerb top, and ridge spacing along the road.
@export var rib_height = .008
@export var rib_pitch = .5
@export_group("Runoff and verge")
## Runoff band beyond the kerb band on each side (0 = none), and its surface (4 = tarmac runoff).
@export var runoff_left = 0.0
@export var runoff_right = 0.0
@export_range(0, 4) var runoff_surface = 4
## Verge beyond the runoff, falling away from the road at verge_slope_deg (runoff falls at it too).
@export var verge_left = 6.0
@export var verge_right = 6.0
@export_range(0.0, 45.0, .1) var verge_slope_deg = 3.0
## SURF table indices (scripts/track3d.gd): 0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff.
@export_range(0, 4) var road_surface = 0
@export_range(0, 4) var verge_surface = 2
## Per-side verge surface; -1 uses verge_surface.
@export_range(-1, 4) var verge_surface_left = -1
@export_range(-1, 4) var verge_surface_right = -1
@export_group("Ditch")
## An inset trough in the road (the Karussell-style concrete ditch). `ditch` scales its depth from 0
## (none) to 1 and eases between keys, which tapers the entry and exit. `ditch_offset` is the
## trough centre's lateral position (+ right). The profile matches TestSurface.ditch(): a flat floor of
## half-width ditch_floor, smoothstep fillets of ditch_fillet, and walls at ditch_angle_deg over
## ditch_wall of horizontal run. Needs fine road stations (RoadPath.road_stations) to resolve.
@export_range(0.0, 1.0, .01) var ditch = 0.0
@export var ditch_offset = 0.0
@export var ditch_floor = 1.5
@export var ditch_wall = 1.1
@export_range(0.0, 60.0, .1) var ditch_angle_deg = 37.0
@export var ditch_fillet = .5


static func make(offset, values = {}):
	var s = new()
	s.at = offset
	for key in values:
		s.set(key, values[key])
	return s
