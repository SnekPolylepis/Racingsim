"""Offline check: raster thinning retains a pipe crossing and the generated survey frame."""
import json
import math
from pathlib import Path

import numpy as np
from build_city import thin_pipes, supported_pipes

cross = np.zeros((15, 15), bool)
cross[6:9, 2:13] = True
cross[2:13, 6:9] = True
line = thin_pipes(cross)
assert line[7, 7] and line.sum() < cross.sum()
assert all(line[7, 3:11]) and all(line[3:11, 7])
assert np.array_equal(line, thin_pipes(line))
# An unsupported hanging spur disappears; the measured path between two mapped supports survives.
nodes, edges = supported_pipes([[0, 5, 200], [2, 5, 200], [4, 5, 200], [2, 6, 202]],
                              [[0, 1], [1, 2], [1, 3]], [[0, 200, "a"], [4, 200, "b"]], .25)
assert len(nodes) == 3 and len(edges) == 2 and all(p[2] == 200 for p in nodes)
doc = json.loads(Path(__file__).with_name("city.json").read_text())
pavilion = doc["pavilion"]
assert len({p[2] for p in pavilion["pylons"]}) == 24
trellis = pavilion["trellis"]
assert trellis["cell"] == .25
assert 186 < trellis["ground"] < 188 and len(trellis["edges"]) > 1000
assert all(3.65 <= p[1] <= 18.29 for p in trellis["nodes"])
assert all(a != b and max(a, b) < len(trellis["nodes"]) for a, b in trellis["edges"])
assert all(math.dist(trellis["nodes"][a], trellis["nodes"][b]) > .001 for a, b in trellis["edges"])
assert len(doc["shells"]) == 1  # no second overlapping raster trellis
print("Pavilion crossing, local height frame and generated links passed")
