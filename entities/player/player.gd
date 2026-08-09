extends CharacterBody3D
class_name Player

@export var static_character : bool = false

@onready var camera_3d: Camera3D = %Camera3D
@onready var camera_cont: Node3D = %camera_cont
@onready var horizontal_cam: Node3D = %horizontal
@onready var submerge_check: Marker3D = %submerge_check
@onready var ground_collider: ShapeCast3D = %ground_collider
@onready var collision_shape = %CollisionShape3D
@onready var underwater_view: MeshInstance3D = %underwater

@export var fake_mesh : MeshInstance3D
@export var sensitivity : float = 0.005

@export_group("Buoyancy Settings")
@export var floating_points : Array[Marker3D]
@export var surface_float_force : float = 15.0 
@export var submerged_float_force : float = 5.0
@export var water_drag : float = 0.05 
@export var swim_drag : float = 0.3
@export var sink_speed : float = -0.5

var current_boat: RigidBody3D = null
var obstacles : Array
var is_climbing : bool = false
var is_driving : bool = false
var is_riding_boat : bool = false

var Rot_x : float = 0.0
var Rot_y : float = 0.0

const WalkSpeed : float = 3.0
const RunSpeed : float = 5.0

var SPEED : float = WalkSpeed
const JUMP_VELOCITY = 4.5

var is_in_water : bool = false
var input_dir : Vector2
var is_reparenting: bool = false


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	underwater_view.visible = false
	add_to_group("player")
	if fake_mesh:
		fake_mesh.queue_free()
	
	if is_multiplayer_authority():
		camera_3d.current = true
		if not static_character:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or static_character:
		return
	
	underwater_view.visible = is_multiplayer_authority()
		
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			return
		Rot_y = -event.relative.x * sensitivity
		Rot_x = -event.relative.y * sensitivity
		
func camera_handler() -> void:
	rotate_y(Rot_y)
	horizontal_cam.rotate_x(Rot_x)
	horizontal_cam.rotation.x = clamp(horizontal_cam.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	Rot_x = 0
	Rot_y = 0

func set_is_driving(value : bool):
	is_driving = value

func set_is_riding_boat(value: bool):
	if is_riding_boat == value:
		return
		
	is_riding_boat = value
	
	if is_riding_boat and current_boat:
		_reparent_with_shield(current_boat)
	else:
		_reparent_with_shield(get_tree().current_scene)
		
func _reparent_with_shield(new_parent: Node) -> void:
	is_reparenting = true        
	reparent(new_parent, true)
	await get_tree().create_timer(0.5).timeout
	is_reparenting = false
 
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if is_driving:
		camera_handler()
		return
	
	WaterMath.tracked_position = global_position
	if static_character:
		input_dir = Vector2.ZERO
	else:
		input_dir = Input.get_vector("a", "d", "w", "s")
		
	vaulting(delta)
	camera_handler()

	if is_climbing:
		return
		
	_handle_buoyancy(delta)
	
	if not is_on_floor() and not is_in_water:
		velocity += get_gravity() * delta

	if not static_character and Input.is_action_just_pressed("jump") and is_on_floor() and not is_in_water:
		velocity.y = JUMP_VELOCITY

	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed = SPEED
	var sample_pos = submerge_check.global_position
	var water_height = WaterMath.get_water_height(sample_pos)

	var depth = water_height - sample_pos.y
	if is_in_water or depth > 0.0:
		current_speed = SPEED * swim_drag
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# The boat velocity math is completely gone! Just move normally.
	move_and_slide()

	#if is_riding_boat and current_boat != null:
		#var boat_vel = current_boat.linear_velocity
		#var distance_from_center = global_position - current_boat.global_position
		#var rotational_vel = current_boat.angular_velocity.cross(distance_from_center)
		#var total_boat_vel = boat_vel + rotational_vel
		#
		#velocity += total_boat_vel
		#move_and_slide()
		#velocity -= total_boat_vel 
	#else:
		#move_and_slide()

	rpc("sync_transform", transform)

#region RPC Syncing
@rpc("any_peer", "call_remote", "unreliable")
func sync_transform(net_transform: Transform3D) -> void:
	if not is_multiplayer_authority():
		# Apply the synced local space
		transform = net_transform

@rpc("any_peer", "call_local", "reliable")
func sync_vault(land_position: Vector3) -> void:
	vault_animation(land_position)
#endregion RPC Syncing

func _handle_buoyancy(delta: float) -> void:
	if floating_points.is_empty():
		return
		
	var sample_pos = floating_points[0].global_position
	var water_height = WaterMath.get_water_height(sample_pos)
	var depth = water_height - sample_pos.y
	
	if depth > 0:
		is_in_water = true
		var current_float_force = submerged_float_force
		if depth < 0.5:
			current_float_force = lerp(submerged_float_force, surface_float_force, 1.0 - (depth / 0.5))
		
		if Input.is_action_pressed("jump"):
			velocity.y += current_float_force * depth * delta
		else:
			velocity.y = move_toward(velocity.y, sink_speed, current_float_force * delta)

		velocity.y = lerp(velocity.y, 0.0, water_drag)
	else:
		is_in_water = false

func raycast(from: Vector3, to: Vector3):
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 2)
	query.collide_with_areas = true
	return space.intersect_ray(query)

func vaulting(_delta):
	if is_climbing:
		return
		
	if Input.is_action_just_pressed("jump"):
		var start_hit = raycast(camera_3d.global_position, camera_3d.to_global(Vector3(0, 0, -1.5)))
		if start_hit and obstacles.is_empty():
			var forward_dir = -global_transform.basis.z 
			var height_offset = Vector3.UP * collision_shape.shape.height
			var cast_start = start_hit.position + (forward_dir * collision_shape.shape.radius) + height_offset
			var cast_end = cast_start + (Vector3.DOWN * collision_shape.shape.height * 1.5)
			
			var place_to_land = raycast(cast_start, cast_end)
			if place_to_land:
				rpc("sync_vault", place_to_land.position)

func vault_animation(land_position: Vector3):
	is_climbing = true

	var vertical_climb = Vector3(global_transform.origin.x, land_position.y, global_transform.origin.z)
	var vertical_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	vertical_tween.tween_property(self, "global_transform:origin", vertical_climb, 0.4)

	await vertical_tween.finished

	var forward = global_transform.origin + (-self.basis.z * 1.2)
	var forward_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	forward_tween.tween_property(self, "global_transform:origin", forward, 0.3)

	await forward_tween.finished

	is_climbing = false

func _on_vaulting_detector_body_entered(body: Node3D) -> void:
	if body != self:
		obstacles.append(body)

func _on_vaulting_detector_body_exited(body: Node3D) -> void:
	if body != self:
		obstacles.erase(body)

##player.gd
#extends CharacterBody3D
#class_name Player
#
#@export var static_character : bool = false
#
#@onready var camera_3d: Camera3D = %Camera3D
#@onready var camera_cont: Node3D = %camera_cont
#@onready var horizontal_cam: Node3D = %horizontal
#@onready var submerge_check: Marker3D = %submerge_check
#@onready var ground_collider: ShapeCast3D = %ground_collider
#@onready var collision_shape = %CollisionShape3D
#@onready var underwater_view: MeshInstance3D = %underwater
#
#@export var fake_mesh : MeshInstance3D
#@export var sensitivity : float = 0.005
#
#@export_group("Buoyancy Settings")
#@export var floating_points : Array[Marker3D]
#@export var surface_float_force : float = 15.0 
#@export var submerged_float_force : float = 5.0
#@export var water_drag : float = 0.05 
#@export var swim_drag : float = 0.3
#@export var sink_speed : float = -0.5
#
#var current_boat: RigidBody3D = null
#var obstacles : Array
#var is_climbing : bool = false
#var is_driving : bool = false
#var is_riding_boat : bool = false
#
#var Rot_x : float = 0.0
#var Rot_y : float = 0.0
#
#const WalkSpeed : float = 3.0
#const RunSpeed : float = 5.0
#
#var SPEED : float = WalkSpeed
#const JUMP_VELOCITY = 4.5
#
#var is_in_water : bool = false
#var input_dir : Vector2
#
#func _enter_tree() -> void:
	#set_multiplayer_authority(name.to_int())
#
#func _ready() -> void:
	#underwater_view.visible = false
	#add_to_group("player")
	#if fake_mesh:
		#fake_mesh.queue_free()
	#
	#if is_multiplayer_authority():
		#camera_3d.current = true
		#if not static_character:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#
#func _input(event: InputEvent) -> void:
	#if not is_multiplayer_authority() or static_character:
		#return
	#
	#underwater_view.visible = is_multiplayer_authority()
		#
	#if event is InputEventMouseMotion:
		#if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			#return
		#Rot_y = -event.relative.x * sensitivity
		#Rot_x = -event.relative.y * sensitivity
#
#func camera_handler() -> void:
	#rotate_y(Rot_y)
	#horizontal_cam.rotate_x(Rot_x)
	#horizontal_cam.rotation.x = clamp(horizontal_cam.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	#Rot_x = 0
	#Rot_y = 0
#
#func set_is_driving(value : bool):
	#is_driving = value
#func set_is_riding_boat(value : bool):
	#is_riding_boat = value
#
#func _physics_process(delta: float) -> void:
	#if not is_multiplayer_authority():
		#
		#return
	#
	#WaterMath.tracked_position = global_position
	#if static_character:
		#input_dir = Vector2.ZERO
	#else:
		#input_dir = Input.get_vector("a", "d", "w", "s")
		#
	#if is_on_floor():
		#var collision = get_last_slide_collision()
		#if collision:
			#var collider = collision.get_collider()
			#if collider is BoatMain:
				#velocity += collider.linear_velocity
		#
	#vaulting(delta)
	#camera_handler()
#
	#if is_climbing:
		#return
		#
	#_handle_buoyancy(delta)
	#
	#if not is_on_floor() and not is_in_water:
		#velocity += get_gravity() * delta
#
	#if not static_character and Input.is_action_just_pressed("jump") and is_on_floor() and not is_in_water:
		#velocity.y = JUMP_VELOCITY
#
	#var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
#
	#var current_speed = SPEED
	#var sample_pos = submerge_check.global_position
	#var water_height = WaterMath.get_water_height(sample_pos)
#
	#var depth = water_height - sample_pos.y
	#if is_in_water or depth > 0.0:
		#current_speed = SPEED * swim_drag
	#
	#if direction:
		#velocity.x = direction.x * current_speed
		#velocity.z = direction.z * current_speed
	#else:
		#velocity.x = move_toward(velocity.x, 0, current_speed)
		#velocity.z = move_toward(velocity.z, 0, current_speed)
	#
	#if current_boat != null:
		#var boat_vel = current_boat.linear_velocity
		#var distance_from_center = global_position - current_boat.global_position
		#var rotational_vel = current_boat.angular_velocity.cross(distance_from_center)
		#var total_boat_vel = boat_vel + rotational_vel
		#velocity += total_boat_vel
		#move_and_slide()
		#velocity -= total_boat_vel 
	#else:
		#move_and_slide()
#
	#rpc("sync_transform", global_transform)
#
##region RPC Syncing
#@rpc("any_peer", "call_remote", "unreliable")
#func sync_transform(net_transform: Transform3D) -> void:
	#if not is_multiplayer_authority():
		#global_transform = net_transform
#
#@rpc("any_peer", "call_local", "reliable")
#func sync_vault(land_position: Vector3) -> void:
	#vault_animation(land_position)
##endregion RPC Syncing
#
#func _handle_buoyancy(delta: float) -> void:
	#if floating_points.is_empty():
		#return
		#
	#var sample_pos = floating_points[0].global_position
	#var water_height = WaterMath.get_water_height(sample_pos)
	#var depth = water_height - sample_pos.y
	#
	#if depth > 0:
		#is_in_water = true
		#var current_float_force = submerged_float_force
		#if depth < 0.5:
			#current_float_force = lerp(submerged_float_force, surface_float_force, 1.0 - (depth / 0.5))
		#
		#if Input.is_action_pressed("jump"):
			#velocity.y += current_float_force * depth * delta
		#else:
			#velocity.y = move_toward(velocity.y, sink_speed, current_float_force * delta)
#
		#velocity.y = lerp(velocity.y, 0.0, water_drag)
	#else:
		#is_in_water = false
#
#func raycast(from: Vector3, to: Vector3):
	#var space = get_world_3d().direct_space_state
	#var query = PhysicsRayQueryParameters3D.create(from, to, 2)
	#query.collide_with_areas = true
	#return space.intersect_ray(query)
#
#func vaulting(_delta):
	#if is_climbing:
		#return
		#
	#if Input.is_action_just_pressed("jump"):
		#var start_hit = raycast(camera_3d.global_position, camera_3d.to_global(Vector3(0, 0, -1.5)))
		#if start_hit and obstacles.is_empty():
			#var forward_dir = -global_transform.basis.z 
			#var height_offset = Vector3.UP * collision_shape.shape.height
			#var cast_start = start_hit.position + (forward_dir * collision_shape.shape.radius) + height_offset
			#var cast_end = cast_start + (Vector3.DOWN * collision_shape.shape.height * 1.5)
			#
			#var place_to_land = raycast(cast_start, cast_end)
			#if place_to_land:
				#rpc("sync_vault", place_to_land.position)
#
#func vault_animation(land_position: Vector3):
	#is_climbing = true
#
	#var vertical_climb = Vector3(global_transform.origin.x, land_position.y, global_transform.origin.z)
	#var vertical_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	#vertical_tween.tween_property(self, "global_transform:origin", vertical_climb, 0.4)
#
	#await vertical_tween.finished
#
	#var forward = global_transform.origin + (-self.basis.z * 1.2)
	#var forward_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	#forward_tween.tween_property(self, "global_transform:origin", forward, 0.3)
#
	#await forward_tween.finished
#
	#is_climbing = false
#
#func _on_vaulting_detector_body_entered(body: Node3D) -> void:
	#if body != self:
		#obstacles.append(body)
#
#func _on_vaulting_detector_body_exited(body: Node3D) -> void:
	#if body != self:
		#obstacles.erase(body)
