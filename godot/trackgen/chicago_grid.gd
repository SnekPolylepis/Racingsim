extends SceneTree
## Route I variant; shared Chicago scenery and current Wacker geometry.
const Chicago = preload("res://trackgen/chicago.gd")


static func build_asset() -> Node3D:
	return Chicago.build_asset(true)
