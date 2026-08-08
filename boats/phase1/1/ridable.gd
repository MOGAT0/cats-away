#ridable.gd
extends Area3D

@onready var boat: RigidBody3D = get_parent()

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.current_boat = boat

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		if body.current_boat == boat:
			body.current_boat = null
