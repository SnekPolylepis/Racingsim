extends RefCounted
## Surface classification: the ids a TrackAsset's Surfaces bodies carry as metadata "surface" and
## TrackSurface.contact() returns. 0 tarmac, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff. `grip` scales
## the tyre's friction, `rr` is the rolling-resistance coefficient, `drag` a speed-proportional
## retarding coefficient, `bump` the random road-noise amplitude (kerbs are real geometry instead).
const SURF = [
	{"id": 0, "grip": 1.0, "rr": 0.012, "drag": 0.0, "bump": 0.0},
	{"id": 1, "grip": 1.03, "rr": 0.016, "drag": 0.0, "bump": 0.55},
	{"id": 2, "grip": 0.55, "rr": 0.060, "drag": 0.006, "bump": 0.22},
	{"id": 3, "grip": 0.62, "rr": 0.220, "drag": 0.030, "bump": 0.30},
	{"id": 4, "grip": 0.97, "rr": 0.013, "drag": 0.0, "bump": 0.03}
]
