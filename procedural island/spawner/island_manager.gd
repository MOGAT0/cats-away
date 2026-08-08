extends Node3D
class_name IslandSpawner

const ISLAND_GENERATOR = preload("uid://blnohhm7hi5pt")

@export_group("Map Controls")
@export var generate_map: bool = false:
	set(value):
		if value:
			world_seed = randi()
			_editor_generate()
			generate_map = false

@export_group("Player Tracking")
@export var player: Node3D 
@export var render_distance: int = 2 

@export_group("Grid Settings")
@export var world_seed: int = 42
@export var cell_size: float = 500.0
@export var cell_margin: float = 1000.0

@export_group("Spawn Rules")
@export_range(0.0, 1.0) var island_density: float = 0.4
@export_range(0.0, 1.0) var small_island_chance: float = 0.5
@export_range(0.0, 1.0) var medium_island_chance: float = 0.3
@export_range(0.0, 1.0) var large_island_chance: float = 0.2

var spawned_cells: Dictionary = {}
var last_player_cell: Vector2 = Vector2(999999, 999999) 

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_generate()
		return

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p.is_multiplayer_authority():
				player = p
				break
	
	if Engine.is_editor_hint() or not is_instance_valid(player):
		return
		
	var total_spacing = cell_size + cell_margin
	
	var current_x = floor(player.global_position.x / total_spacing)
	var current_z = floor(player.global_position.z / total_spacing)
	var current_cell = Vector2(current_x, current_z)
	
	if current_cell != last_player_cell:
		last_player_cell = current_cell
		_update_world(current_cell, total_spacing)

#region Multiplayer World Sync
func _on_peer_connected(id: int) -> void:
	rpc_id(id, "receive_world_seed", world_seed)

@rpc("authority", "call_remote", "reliable")
func receive_world_seed(server_seed: int) -> void:
	print("Received Host World Seed: ", server_seed)
	world_seed = server_seed

	for child in get_children():
		child.queue_free()
	spawned_cells.clear()
	last_player_cell = Vector2(999999, 999999) 
#endregion

func _editor_generate() -> void:
	for child in get_children():
		child.queue_free()
	spawned_cells.clear()
	last_player_cell = Vector2(999999, 999999) 
	
	var total_spacing = cell_size + cell_margin
	_update_world(Vector2.ZERO, total_spacing)

func _update_world(center_cell: Vector2, total_spacing: float) -> void:
	var cells_in_range = []

	for x in range(-render_distance, render_distance + 1):
		for z in range(-render_distance, render_distance + 1):
			var cell = center_cell + Vector2(x, z)
			cells_in_range.append(cell)
			
			if not spawned_cells.has(cell):
				_attempt_spawn_cell(cell, total_spacing)
			else:
				var island = spawned_cells[cell]
				if is_instance_valid(island):
					if not island.visible:
						island.visible = true
						island.process_mode = Node.PROCESS_MODE_INHERIT
						
						if island.has_method("respawn_foliage"):
							island.respawn_foliage()

	for cell in spawned_cells.keys():
		if not cell in cells_in_range:
			var island = spawned_cells[cell]
			if is_instance_valid(island) and island.visible:
				island.visible = false
				island.process_mode = Node.PROCESS_MODE_DISABLED 

func _attempt_spawn_cell(cell: Vector2, total_spacing: float) -> void:

	var cell_seed = hash(Vector3(cell.x, world_seed, cell.y))
	var rng = RandomNumberGenerator.new()
	rng.seed = cell_seed
	
	var is_origin = (cell == Vector2.ZERO)
	
	if not is_origin and rng.randf() > island_density:
		spawned_cells[cell] = null 
		return
		
	var size_roll = rng.randf()
	var total_chance = small_island_chance + medium_island_chance + large_island_chance
	var normalized_roll = size_roll * total_chance 
	
	var role_name = ""
	if normalized_roll < small_island_chance:
		role_name = "Small_Island"
	elif normalized_roll < small_island_chance + medium_island_chance:
		role_name = "Medium_Island"
	else:
		role_name = "Large_Island"
		
	var spawn_position = Vector3(cell.x * total_spacing, 0, cell.y * total_spacing)
	
	# Pass the matched rng.randi() to guarantee identical foliage and terrain!
	_spawn_island(spawn_position, role_name, rng.randi(), cell)

func _spawn_island(pos: Vector3, role: String, unique_seed: int, cell: Vector2) -> void:
	var island_instance = ISLAND_GENERATOR.instantiate()
	island_instance.name = role + "_" + str(cell.x) + "_" + str(cell.y)
	
	var current_size: float = 0.0
	if role == "Small_Island":
		current_size = cell_size * 0.4 
	elif role == "Medium_Island":
		current_size = cell_size * 0.7 
	elif role == "Large_Island":
		current_size = cell_size * 1.0 
		
	island_instance.island_size = current_size
	island_instance.island_seed = unique_seed
	
	add_child(island_instance)
	island_instance.position = pos
	
	spawned_cells[cell] = island_instance
	
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		island_instance.owner = get_tree().edited_scene_root



##@tool
#extends Node3D
#class_name IslandSpawner
#
#const ISLAND_GENERATOR = preload("uid://blnohhm7hi5pt")
#
#@export_group("Map Controls")
#@export var generate_map: bool = false:
	#set(value):
		#if value:
			#world_seed = randi()
			#_editor_generate()
			#generate_map = false
#
#@export_group("Player Tracking")
### Assign your player character here!
#@export var player: Node3D 
### How many cells in every direction to load around the player.
#@export var render_distance: int = 2 
#
#@export_group("Grid Settings")
#@export var world_seed: int = 42
#@export var cell_size: float = 500.0
#@export var cell_margin: float = 1000.0
#
#@export_group("Spawn Rules")
#@export_range(0.0, 1.0) var island_density: float = 0.4
#@export_range(0.0, 1.0) var small_island_chance: float = 0.5
#@export_range(0.0, 1.0) var medium_island_chance: float = 0.3
#@export_range(0.0, 1.0) var large_island_chance: float = 0.2
#
#
#var spawned_cells: Dictionary = {}
#var last_player_cell: Vector2 = Vector2(999999, 999999) 
#
#func _ready() -> void:
	#if Engine.is_editor_hint():
		#_editor_generate()
#
#func _process(_delta: float) -> void:
	#if get_tree().get_first_node_in_group("player") is Player:
		#player = get_tree().get_first_node_in_group("player")
	#
	#if Engine.is_editor_hint() or not player:
		#return
		#
	#var total_spacing = cell_size + cell_margin
	#
	#var current_x = floor(player.global_position.x / total_spacing)
	#var current_z = floor(player.global_position.z / total_spacing)
	#var current_cell = Vector2(current_x, current_z)
	#
	#if current_cell != last_player_cell:
		#last_player_cell = current_cell
		#_update_world(current_cell, total_spacing)
#
#func _editor_generate() -> void:
	#for child in get_children():
		#child.queue_free()
	#spawned_cells.clear()
	#last_player_cell = Vector2(999999, 999999) 
	#
	#var total_spacing = cell_size + cell_margin
	#_update_world(Vector2.ZERO, total_spacing)
#
#func _update_world(center_cell: Vector2, total_spacing: float) -> void:
	#var cells_in_range = []
	#
	##Spawn or Unhide Islands
	#for x in range(-render_distance, render_distance + 1):
		#for z in range(-render_distance, render_distance + 1):
			#var cell = center_cell + Vector2(x, z)
			#cells_in_range.append(cell)
			#
			#if not spawned_cells.has(cell):
				#_attempt_spawn_cell(cell, total_spacing)
			#else:
				#var island = spawned_cells[cell]
				#if is_instance_valid(island):
					## If the island was hidden, the player is returning!
					#if not island.visible:
						#island.visible = true
						#island.process_mode = Node.PROCESS_MODE_INHERIT
						#
						## Trigger our new function to respawn chopped trees
						#if island.has_method("respawn_foliage"):
							#island.respawn_foliage()
							#
	##Hide out-of-range Islands
	#for cell in spawned_cells.keys():
		#if not cell in cells_in_range:
			#var island = spawned_cells[cell]
			#if is_instance_valid(island) and island.visible:
				#island.visible = false
				#island.process_mode = Node.PROCESS_MODE_DISABLED 
#
#func _attempt_spawn_cell(cell: Vector2, total_spacing: float) -> void:
	#var cell_seed = hash(Vector3(cell.x, world_seed, cell.y))
	#var rng = RandomNumberGenerator.new()
	#rng.seed = cell_seed
	#
	#var is_origin = (cell == Vector2.ZERO)
	#
	#if not is_origin and rng.randf() > island_density:
		#spawned_cells[cell] = null 
		#return
		#
	#var size_roll = rng.randf()
	#var total_chance = small_island_chance + medium_island_chance + large_island_chance
	#var normalized_roll = size_roll * total_chance 
	#
	#var role_name = ""
	#if normalized_roll < small_island_chance:
		#role_name = "Small_Island"
	#elif normalized_roll < small_island_chance + medium_island_chance:
		#role_name = "Medium_Island"
	#else:
		#role_name = "Large_Island"
		#
	#var spawn_position = Vector3(cell.x * total_spacing, 0, cell.y * total_spacing)
	#_spawn_island(spawn_position, role_name, rng.randi(), cell)
#
#func _spawn_island(pos: Vector3, role: String, unique_seed: int, cell: Vector2) -> void:
	#var island_instance = ISLAND_GENERATOR.instantiate()
	#island_instance.name = role + "_" + str(cell.x) + "_" + str(cell.y)
	#
	#var current_size: float = 0.0
	#if role == "Small_Island":
		#current_size = cell_size * 0.4 
	#elif role == "Medium_Island":
		#current_size = cell_size * 0.7 
	#elif role == "Large_Island":
		#current_size = cell_size * 1.0 
		#
	#island_instance.island_size = current_size
	#island_instance.island_seed = unique_seed
	#
	#add_child(island_instance)
	#island_instance.position = pos
	##island_instance.generate = true
	#
	#spawned_cells[cell] = island_instance
	#
	#if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		#island_instance.owner = get_tree().edited_scene_root
