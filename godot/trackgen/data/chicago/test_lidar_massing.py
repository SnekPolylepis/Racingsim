"""Small offline check: measured setbacks survive; missing data is reported, not claimed measured."""
import base64
import warnings

import numpy as np
from build_city import lidar_massing

roof = np.full((12, 12), 10.0)
roof[:, 4:] = 20.0
ring = [(0, 0), (8, 0), (8, 8), (0, 8)]
shape, height, coverage = lidar_massing(ring, [(roof, 0, 0)])
cells = np.frombuffer(base64.b64decode(shape[5]), dtype="<u2").reshape(4, 4)
assert np.all(cells[:, :2] == 100) and np.all(cells[:, 2:] == 200)
assert height == 20.0 and coverage == 1.0
roof[:2, :2] = np.nan
with warnings.catch_warnings():
    warnings.simplefilter("ignore", RuntimeWarning)
    assert lidar_massing(ring, [(roof, 0, 0)])[2] == 15 / 16
    assert lidar_massing(ring, [(np.full_like(roof, np.nan), 0, 0)]) is None
print("LiDAR massing check passed")
