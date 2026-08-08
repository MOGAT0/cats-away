@tool
extends Node3D

@onready var leg_marker_l: Marker3D = %leg_L
@onready var leg_marker_r: Marker3D = %leg_R
@onready var shape_cast_l: ShapeCast3D = %ShapeCast_L
@onready var shape_cast_r: ShapeCast3D = %ShapeCast_R


func _process(_delta: float) -> void:
	shape_cast_l.global_position.x = leg_marker_l.global_position.x
	shape_cast_l.global_position.z = leg_marker_l.global_position.z
	
	shape_cast_r.global_position.x = leg_marker_r.global_position.x
	shape_cast_r.global_position.z = leg_marker_r.global_position.z
	
	
	if shape_cast_l.is_colliding():
		leg_marker_l.global_position.y = shape_cast_l.get_collision_point(0).y
	
	if shape_cast_r.is_colliding():
		leg_marker_r.global_position.y = shape_cast_r.get_collision_point(0).y
