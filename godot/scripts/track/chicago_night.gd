extends RefCounted
## Toggle original Chicago accent fixtures, including materials embedded in packed track caches.


static func set_night(root: Node, on: bool) -> void:
	var scenery = root.get_node_or_null("Scenery")
	if scenery == null:
		return
	for node in scenery.find_children("*", "", true, false):
		if node is Light3D and node.has_meta("chicago_night"):
			node.visible = on
		if node is MeshInstance3D and node.mesh != null:
			for i in node.mesh.get_surface_count():
				var mat = node.mesh.surface_get_material(i)
				if mat is StandardMaterial3D and mat.has_meta("chicago_night"):
					mat.emission_enabled = on
