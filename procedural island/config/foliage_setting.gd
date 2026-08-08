extends Resource
class_name FoliageSetting

@export var name: String = "Foliage"
@export var scene_prefab: PackedScene
@export var placeholder_mesh: Mesh 

@export_group("Spawn Rules")
@export_range(0.0, 1.0) var density: float = 0.05
@export var min_distance: float = 2.0
@export var can_spawn_at_sand: bool = false
@export var spawn_at_sand_only: bool = false

@export_group("Randomization")
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
