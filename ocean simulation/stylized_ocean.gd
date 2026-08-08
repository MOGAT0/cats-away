extends Node3D
class_name OceanManager

@export var track_target : Node3D

@export_group("Dynamic LOD Grid")
@export var chunk_size : float = 150.0
@export var lod_count : int = 3 
@export var chunk_subdivision : int = 150
@export var update_region_on : float = 15.0


@export_group("Material & Tools")
@export var ocean_material : Material:
	set(value):
		ocean_material = value
		_update_materials()

@export var rebuild_grid: bool = false:
	set(value):
		_generate_chunks()

func _ready() -> void:
	show()
	if get_child_count() == 0:
		_generate_chunks()

func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("player") is Player:
		track_target = get_tree().get_first_node_in_group("player")
	
	if track_target:
		# 1. Calculate how far the player is from the ocean's current center
		var dist_x = abs(track_target.global_position.x - global_position.x)
		var dist_z = abs(track_target.global_position.z - global_position.z)

		var half_chunk = (chunk_size / 2.0) - update_region_on
		
		
		
		if dist_x > half_chunk or dist_z > half_chunk:
			global_position.x = snapped(track_target.global_position.x, 4.0)
			global_position.z = snapped(track_target.global_position.z, 4.0)
			global_position.y = 0.0

func _generate_chunks() -> void:
	for child in get_children():
		child.queue_free()
	var max_rings = maxi(1, lod_count)
	var half_size = max_rings - 1

	for x in range(-half_size, half_size + 1):
		for z in range(-half_size, half_size + 1):
			_create_single_chunk(x, z)

func _create_single_chunk(grid_x: int, grid_z: int) -> void:
	var ring_index = maxi(abs(grid_x), abs(grid_z))
	
	var chunk = MeshInstance3D.new()
	var plane = PlaneMesh.new()

	plane.size = Vector2(chunk_size, chunk_size)
	
	var current_subdiv = chunk_subdivision / (1 << ring_index)

	current_subdiv = maxi(1, current_subdiv)
	
	plane.subdivide_width = current_subdiv
	plane.subdivide_depth = current_subdiv
	
	if ocean_material:
		plane.material = ocean_material
		
	chunk.mesh = plane
	chunk.position = Vector3(grid_x * chunk_size, 0, grid_z * chunk_size)
	chunk.name = "Chunk_Ring%d_%d_%d" % [ring_index, grid_x, grid_z]
	
	add_child(chunk)

	if Engine.is_editor_hint():
		chunk.owner = get_tree().edited_scene_root

func _update_materials() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:
			child.mesh.material = ocean_material
