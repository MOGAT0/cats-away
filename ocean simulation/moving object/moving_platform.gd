extends AnimatableBody3D

@export var float_force: float = 50.0
@export var water_drag: float = 0.05
@export var water_angular_drag: float = 0.05
@export var mass: float = 1.0 
@export var forward_thrust: float = 15.0
@export var steering_torque: float = 3.0

@onready var points_cont: Node3D = %points_cont
@onready var driver_pos: Marker3D = %driver_pos

var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _points: Array[Marker3D] = []

var is_driving: bool = false
var player_in_area: Node3D = null
var current_driver: Node3D = null

func _ready() -> void:
	sync_to_physics = false
	for p in points_cont.get_children():
		_points.append(p)

func _physics_process(delta: float) -> void:
	linear_velocity += Vector3.DOWN * gravity * delta

	if _points.is_empty():
		apply_buoyancy(global_position, delta)
	else:
		for point in _points:
			apply_buoyancy(point.global_position, delta)
			
	if is_driving:
		var forward_dir = -global_transform.basis.z
		linear_velocity += forward_dir * forward_thrust * delta
		
		var steer_input = Input.get_axis("move_right", "move_left")
		angular_velocity.y += steer_input * steering_torque * delta

	linear_velocity *= 1.0 - water_drag
	angular_velocity *= 1.0 - water_angular_drag

	constant_linear_velocity = linear_velocity
	constant_angular_velocity = angular_velocity

	move_and_collide(linear_velocity * delta)
	global_rotation += angular_velocity * delta
	
	if is_driving and current_driver:
		current_driver.global_position = driver_pos.global_position
		current_driver.global_rotation.y = global_rotation.y

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if is_driving:
			dismount_player()
		elif player_in_area:
			mount_player(player_in_area)

func apply_buoyancy(sample_pos: Vector3, delta: float) -> void:
	var water_height = WaterMath.get_water_height(sample_pos)
	var depth = water_height - sample_pos.y
	
	if depth > 0:
		var force_multiplier = max(1.0, _points.size())
		var upward_force = Vector3.UP * float_force * depth * mass / force_multiplier

		var linear_acceleration = upward_force / mass
		linear_velocity += linear_acceleration * delta

		var offset = sample_pos - global_position
		var torque = offset.cross(upward_force)
		angular_velocity += (torque / mass) * delta

func _on_drive_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_area = body

func _on_drive_body_exited(body: Node3D) -> void:
	if body == player_in_area:
		player_in_area = null

func mount_player(player: Node3D) -> void:
	is_driving = true
	#current_driver = player
	# {to-do} Disable player's internal movement logic/gravity here

func dismount_player() -> void:
	is_driving = false
	# {to-do} Re-enable player's movement logic here
	# {to-do} Apply a small positional offset to the player so they don't clip into the geometry upon exit
	current_driver = null
