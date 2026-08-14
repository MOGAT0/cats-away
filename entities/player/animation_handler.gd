extends Node3D
class_name AnimationHandler

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var player: Player = $"../.."

@export var blend_speed: float = 5.0 

var current_blend_position: Vector2 = Vector2.ZERO
var last_known_direction: Vector2 = Vector2.DOWN

const CONDITIONS: Array[String] = ["idle", "move", "run", "jump"]

# We use this to track what state remote clients should be playing
var current_synced_state: String = "idle"

func _process(delta: float) -> void:
	# 1. Authority logic: Calculate what the player is actually doing
	if player.is_multiplayer_authority():
		var target_state: String = "idle"

		if player.input_dir != Vector2.ZERO:
			last_known_direction = player.input_dir
			
		if player.is_driving:
			target_state = "idle"
<<<<<<< HEAD
		#elif Input.is_action_just_pressed("attack"):
			#target_state = "attack"
=======
>>>>>>> parent of 419b7ef (attack and draggable objects)
		elif !player.ground_collider.is_colliding() and !player.is_on_floor():
			target_state = "jump"
		elif Input.is_action_pressed("run") and player.velocity.length() != 0.0 and player.input_dir.y < -0.1:
			target_state = "run"
			player.SPEED = player.RunSpeed
		elif player.input_dir.length() != 0.0:
			target_state = "move"
			player.SPEED = player.WalkSpeed

		# Shout the exact state and direction to all remote peers over the network
		rpc("sync_animation_state", target_state, last_known_direction)
		
		# Apply it immediately for the local screen
		apply_animation(target_state, delta)
		
	# 2. Remote logic: Just do what the RPC told you to do
	else:
		apply_animation(current_synced_state, delta)


func apply_animation(target_state: String, delta: float) -> void:
	# Lerp the blend position smoothly (This runs for BOTH authority and remotes!)
	current_blend_position = current_blend_position.lerp(last_known_direction, delta * blend_speed)
	animation_tree["parameters/move/blend_position"] = current_blend_position

	_set_active_condition(target_state)


func _set_active_condition(active: String) -> void:
	for condition in CONDITIONS:
		var path = "parameters/conditions/" + condition
		animation_tree[path] = (condition == active)

#region RPC Syncing
@rpc("any_peer", "call_remote", "unreliable")
func sync_animation_state(net_state: String, net_direction: Vector2) -> void:
	if not player.is_multiplayer_authority():
		current_synced_state = net_state
		last_known_direction = net_direction
#endregion
