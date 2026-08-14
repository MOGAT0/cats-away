extends Area3D
class_name Vaulting

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		set_collision_layer_value(2,false)
		set_collision_mask_value(2,false)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		set_collision_mask_value(2,true)
		set_collision_layer_value(2,true)
