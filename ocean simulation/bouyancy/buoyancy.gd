extends RigidBody3D


@export var float_force: float = 50.0
@export var water_drag: float = 0.05
@export var water_angular_drag: float = 0.05

@export var float_points: Array[NodePath] 
var _points: Array[Marker3D] = []

func _ready() -> void:
	for path in float_points:
		_points.append(get_node(path))

func _physics_process(delta: float) -> void:	
	if _points.is_empty():
		apply_buoyancy(global_position, delta)
	else:
		for point in _points:
			apply_buoyancy(point.global_position, delta)

func apply_buoyancy(sample_pos: Vector3, _delta: float) -> void:
	var water_height = WaterMath.get_water_height(sample_pos)

	var depth = water_height - sample_pos.y
	
	if depth > 0:
		var force_multiplier = max(1.0, _points.size())
		var upward_force = Vector3.UP * float_force * depth * mass / force_multiplier

		apply_force(upward_force, sample_pos - global_position)

		linear_velocity *= 1.0 - water_drag
		angular_velocity *= 1.0 - water_angular_drag



#original code
#extends RigidBody3D
#class_name BoatMain
#
#@onready var animation_player: AnimationPlayer = %AnimationPlayer
#@onready var driver_pos: Marker3D = %driver_pos
#
#@export var float_force: float = 50.0
#@export var water_drag: float = 0.05
#@export var water_angular_drag: float = 0.05
#
#@export var float_points: Array[NodePath] 
#var _points: Array[Marker3D] = []
#
#func _ready() -> void:
	#for path in float_points:
		#_points.append(get_node(path))
#
#func _physics_process(delta: float) -> void:	
	#if _points.is_empty():
		#apply_buoyancy(global_position, delta)
	#else:
		#for point in _points:
			#apply_buoyancy(point.global_position, delta)
#
#func apply_buoyancy(sample_pos: Vector3, _delta: float) -> void:
	#var water_height = WaterMath.get_water_height(sample_pos)
#
	#var depth = water_height - sample_pos.y
	#
	#if depth > 0:
		#var force_multiplier = max(1.0, _points.size())
		#var upward_force = Vector3.UP * float_force * depth * mass / force_multiplier
#
		#apply_force(upward_force, sample_pos - global_position)
#
		#linear_velocity *= 1.0 - water_drag
		#angular_velocity *= 1.0 - water_angular_drag
#
#
#
##place the driver in designated position, if interact is pressed while in driver position exit driver position
#func _on_drive_body_entered(body: Node3D) -> void:
	#if body is Player:
		#if Input.is_action_just_pressed("interact"):
			#body.global_position = driver_pos.global_position
#
#func _on_drive_body_exited(body: Node3D) -> void:
	#if body is Player:
		#pass
