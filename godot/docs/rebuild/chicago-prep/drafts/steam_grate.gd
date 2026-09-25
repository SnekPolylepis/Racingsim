@tool
class_name ChicagoSteamGrateDraft
extends Node3D
## DRAFT — unintegrated, staged on rb/CHI-assets-prep. Not autoloaded, not referenced by any trackgen
## generator, not part of any gate. A starting point for a future task (a CHI-01 follow-up) that wants
## the classic Chicago sidewalk steam vent — Lower/Upper Wacker's tunnel grates and Loop manholes read
## as faintly glowing haze at night in most street-level city references. Follows this repo's @tool
## Node3D + @export + bake() house style (see scripts/track/road_scatter.gd, scenery_builder.gd) so it
## can be dropped into a generator's add_scenery_kit() and called the same way once adapted; it does not
## follow that pattern for MultiMesh batching, since particle emitters can't share one GPUParticles3D
## node the way static meshes share one MultiMesh — a real integration should place a handful by hand
## at named stations (grate positions from a generator's `corners`/`positions` dict), not scatter
## hundreds like RoadScatter's cards.

@export var rise_height := 2.5
@export var particle_count := 24
@export var emission_rate := 6.0
@export var tint: Color = Color(0.85, 0.87, 0.9, 0.35)
@export_tool_button("Build (draft, unverified)", "Callable") var build_button = build

var _particles: GPUParticles3D


func build() -> void:
	if _particles != null and is_instance_valid(_particles):
		_particles.queue_free()
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 12.0
	mat.gravity = Vector3(0.0, 0.4, 0.0)
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.1
	mat.scale_min = 0.4
	mat.scale_max = 1.2
	mat.color = tint
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.6, 0.02, 0.4)

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	var surf = StandardMaterial3D.new()
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	surf.albedo_color = tint
	mesh.material = surf

	_particles = GPUParticles3D.new()
	_particles.name = "SteamGrate"
	_particles.amount = particle_count
	_particles.lifetime = rise_height / max(mat.initial_velocity_min, 0.1)
	_particles.process_material = mat
	_particles.draw_pass_1 = mesh
	_particles.emitting = true
	add_child(_particles)
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root != null:
		_particles.owner = get_tree().edited_scene_root
