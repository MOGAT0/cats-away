extends Node3D
class_name ObjectLifter

@onready var object_collider: RayCast3D = %object_collider
@onready var grab_anchor: Marker3D = %grab_anchor

var grabbed_object : RigidBody3D = null
var grab_offset : Vector3 = Vector3.ZERO

func _physics_process(_delta: float) -> void:
		
	if Input.is_action_just_pressed("hold"):
		
		grab_anchor.global_position = object_collider.get_collision_point()
		if object_collider.is_colliding():
			#specific for boat
			if object_collider.get_collider() is not RigidBody3D:
				var target = object_collider.get_collider().get("boat")
				if target is BoatMain:
					if target.is_in_group("draggable"):
						grabbed_object = target
			else:
				grabbed_object = object_collider.get_collider()
				
			if grabbed_object:
				grab_offset = grabbed_object.global_position - object_collider.get_collision_point()
				for node in get_tree().get_nodes_in_group("obj_collider"):
					if grabbed_object.is_ancestor_of(node):
						var shape = node as CollisionShape3D
						if shape:
							shape.disabled = true
							print("Grab: ",shape)

	elif Input.is_action_just_released("hold"):
		if grabbed_object:
			for node in get_tree().get_nodes_in_group("obj_collider"):
				if grabbed_object.is_ancestor_of(node):
					var shape = node as CollisionShape3D
					if shape:
						shape.disabled = false
						print("Released: ",shape)
						
		grabbed_object = null
	
	if grabbed_object:
		var rotation_step = 0.1 
		var move_step = 0.5
		
		if Input.is_action_just_pressed("scroll_up"):
			if Input.is_key_pressed(KEY_SHIFT):
				grab_anchor.position.z -= move_step 
			elif Input.is_key_pressed(KEY_CTRL):
				grabbed_object.rotate_y(rotation_step)
			else:
				grabbed_object.rotate_x(rotation_step)
				
		elif Input.is_action_just_pressed("scroll_down"):
			if Input.is_key_pressed(KEY_SHIFT):
				grab_anchor.position.z += move_step 
			elif Input.is_key_pressed(KEY_CTRL):
				grabbed_object.rotate_y(-rotation_step)
			else:
				grabbed_object.rotate_x(-rotation_step)
				
		grabbed_object.global_position = grab_anchor.global_position + grab_offset
