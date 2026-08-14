extends RigidBody3D
class_name BoatMain

@onready var fps: Label = %fps
@onready var steering_animation: AnimationPlayer = %steering_animation
@onready var sail_animation: AnimationPlayer = %sail_animation

@onready var driver_pos: Marker3D = %driver_pos
@onready var driver_dismout_pos: Marker3D = %driver_dismout_pos
@onready var interact: Label = %interact

@export_group("Buoyancy Settings")
@export var float_force: float = 50.0
@export var water_drag: float = 0.05
@export var water_angular_drag: float = 0.05
@export var float_points: Array[NodePath]
@export var water_damping: float = 3.0
@export var max_buoyancy_depth: float = 2.0

@export_group("Sailing Settings")
@export var sail_speed: float = 2.0
@export var turn_speed: float = 0.2
@export var max_speed: float = 5.0
@export var lateral_drag: float = 5.0

var _points: Array[Marker3D] = []
@onready var points_cont: Node3D = %points_cont

var current_driver: Player = null

var local_in_drive_zone: bool = false
var local_in_sail_zone: bool = false

@export var driver_id: int = 0

@export var target_sail_val: float = 0.2
var current_sail_val: float = 0.2 

@export var target_steer_val: float = 0.05 
var current_steer_val: float = 0.05

var submerged_points: int = 0

func _ready() -> void:
	interact.hide()
	for p in points_cont.get_children():
		_points.append(p)
	
	sail_animation.play("sail")
	sail_animation.pause()
	steering_animation.play("steering")
	steering_animation.pause()


func _physics_process(delta: float) -> void:
	print(%ridable.has_passengers())
	
	
	fps.text = str(Engine.get_frames_per_second())

	if not is_multiplayer_authority():
		return
		
	submerged_points = 0
	
	if _points.is_empty():
		apply_buoyancy(global_position, delta)
	else:
		for point in _points:
			apply_buoyancy(point.global_position, delta)

	apply_driving_forces()
	
	if submerged_points > 0:
		var submerge_ratio = float(submerged_points) / max(1.0, _points.size())
		linear_velocity = linear_velocity.lerp(Vector3.ZERO, water_drag * submerge_ratio * delta)
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, water_angular_drag * submerge_ratio * delta)
		
	var horizontal_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
		linear_velocity.x = horizontal_velocity.x
		linear_velocity.z = horizontal_velocity.z
		
		
func _process(delta: float) -> void:
	_animate_sail(delta)
	_animate_steering(delta)

	if current_driver:
		current_driver.global_position = driver_pos.global_position
		
		if driver_id == multiplayer.get_unique_id() and Input.is_action_just_pressed("interact"):
			rpc_id(1, "server_dismount_driver")

	else:
		if local_in_drive_zone and Input.is_action_just_pressed("interact"):
			rpc_id(1, "server_mount_driver", multiplayer.get_unique_id())

	if local_in_sail_zone and Input.is_action_just_pressed("interact"):
		rpc_id(1, "server_toggle_sail")


func apply_driving_forces() -> void:
	if target_sail_val == 0.0:
		var forward_dir = -global_transform.basis.z
		apply_central_force(forward_dir * sail_speed * mass)

		var turn_input = (target_steer_val - 0.05) * 20.0
		var local_ang_vel = global_transform.basis.inverse() * angular_velocity
		local_ang_vel.y = turn_input * turn_speed
		angular_velocity = global_transform.basis * local_ang_vel

		var local_velocity = global_transform.basis.inverse() * linear_velocity
		var anti_drift_force = -local_velocity.x * lateral_drag * mass
		apply_central_force(global_transform.basis.x * anti_drift_force)


func apply_buoyancy(sample_pos: Vector3, _delta: float) -> void:
	var water_height = WaterMath.get_water_height(sample_pos)
	var depth = water_height - sample_pos.y
	
	if depth > 0:
		submerged_points += 1
		var clamped_depth = min(depth, max_buoyancy_depth)
		var force_multiplier = max(1.0, _points.size())
		var upward_force_y = float_force * clamped_depth
		var offset = sample_pos - global_position
		var point_velocity = linear_velocity + angular_velocity.cross(offset)
		upward_force_y -= point_velocity.y * water_damping
		var final_force = Vector3.UP * upward_force_y * mass / force_multiplier
		apply_force(final_force, offset)


func _animate_sail(delta: float) -> void:
	current_sail_val = lerp(current_sail_val, target_sail_val, 5.0 * delta)
	sail_animation.seek(current_sail_val, true)


func _animate_steering(delta: float) -> void:
	if driver_id == multiplayer.get_unique_id():
		var new_steer = 0.05
		if Input.is_physical_key_pressed(KEY_A):
			new_steer = 0.1
		elif Input.is_physical_key_pressed(KEY_D):
			new_steer = 0.0
			
		if new_steer != target_steer_val:
			rpc_id(1, "server_steer", new_steer)

	current_steer_val = lerp(current_steer_val, target_steer_val, 20.0 * delta)
	steering_animation.seek(current_steer_val, true)


@rpc("any_peer", "call_local", "reliable")
func server_mount_driver(peer_id: int) -> void:
	if not is_multiplayer_authority() or driver_id != 0:
		return
	driver_id = peer_id
	rpc("sync_driver_state", peer_id)


@rpc("any_peer", "call_local", "reliable")
func server_dismount_driver() -> void:
	if not is_multiplayer_authority(): 
		return
	if multiplayer.get_remote_sender_id() == driver_id:
		driver_id = 0
		rpc("sync_driver_state", 0)


@rpc("any_peer", "call_local", "reliable")
func server_toggle_sail() -> void:
	if not is_multiplayer_authority(): 
		return
	target_sail_val = 0.0 if target_sail_val == 0.2 else 0.2


@rpc("any_peer", "call_local", "unreliable")
func server_steer(steer_val: float) -> void:
	if multiplayer.get_remote_sender_id() == driver_id:
		target_steer_val = steer_val


@rpc("authority", "call_local", "reliable")
func sync_driver_state(peer_id: int) -> void:
	driver_id = peer_id
	if driver_id == 0:
		if current_driver:
			if current_driver.has_method("set_is_driving"):
				current_driver.set_is_driving(false)
			current_driver.global_position = driver_dismout_pos.global_position
			current_driver = null
		if local_in_drive_zone:
			interact.show()
	else:
		if not local_in_sail_zone:
			interact.hide()
			
		for p in get_tree().get_nodes_in_group("player"):
			if p.name == str(peer_id):
				current_driver = p
				if current_driver.has_method("set_is_driving"):
					current_driver.set_is_driving(true)
				break

func _on_drive_body_entered(body: Node3D) -> void:
	if body is Player and body.name.to_int() == multiplayer.get_unique_id():
		local_in_drive_zone = true
		if driver_id == 0:
			interact.show()

func _on_drive_body_exited(body: Node3D) -> void:
	if body is Player and body.name.to_int() == multiplayer.get_unique_id():
		local_in_drive_zone = false
		if not local_in_sail_zone:
			interact.hide()

func _on_sail_body_entered(body: Node3D) -> void:
	if body is Player and body.name.to_int() == multiplayer.get_unique_id():
		local_in_sail_zone = true
		interact.show()

func _on_sail_body_exited(body: Node3D) -> void:
	if body is Player and body.name.to_int() == multiplayer.get_unique_id():
		local_in_sail_zone = false
		if not local_in_drive_zone:
			interact.hide()
