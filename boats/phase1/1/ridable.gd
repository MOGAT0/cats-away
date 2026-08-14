extends Area3D

@onready var boat: RigidBody3D = get_parent()
@onready var ridable: Area3D = %ridable

var players_inside : Array[Player] = []

func has_passengers() -> bool:
	return false if players_inside.is_empty() else true

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.current_boat == boat: return
		body.current_boat = boat

		if not players_inside.has(body):
			players_inside.append(body)
			
		if players_inside.size() > 0:
			add_to_group("draggable")
		
		body.set_is_riding_boat(true)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		if body.is_reparenting:
			return
		if body.current_boat == boat:
			body.current_boat = null
			players_inside.erase(body)

			if players_inside.is_empty():
				remove_from_group("draggable")

			body.set_is_riding_boat(false)
