extends Area3D

@onready var boat: RigidBody3D = get_parent()
@onready var ridable: Area3D = %ridable

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.current_boat == boat: return
		body.current_boat = boat
		print("enter")
		body.set_is_riding_boat(true)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		if body.is_reparenting:
			return
		if body.current_boat == boat:
			body.current_boat = null
			print("exit")
			body.set_is_riding_boat(false)

##ridable.gd
#extends Area3D
#
#@onready var boat: RigidBody3D = get_parent()
#@onready var ridable: Area3D = %ridable
#
#func _on_body_entered(body: Node3D) -> void:
	#if body is Player:
		#if body.current_boat == boat:return
		#body.current_boat = boat
		#print("enter")
		#body.set_is_riding_boat(true)
#
#func _on_body_exited(body: Node3D) -> void:
	#if body is Player:
		#if body.current_boat == boat and not body.is_riding_boat:
			#body.current_boat = null
			#print("exit")
		#body.set_is_riding_boat(false)
