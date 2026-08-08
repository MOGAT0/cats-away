extends Camera3D
class_name CameraInspector

@onready var fps: Label = %fps

@export var move_speed: float = 10.0
@export var look_sensitivity: float = 0.005

@export var speed_step: float = 2.0
@export var min_speed: float = 2.0
@export var max_speed: float = 100.0

var _is_right_clicking: bool = false
var _rotation_x: float = 0.0
var _rotation_y: float = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
	
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_right_clicking = event.pressed
			if _is_right_clicking:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if _is_right_clicking:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				move_speed = clamp(move_speed + speed_step, min_speed, max_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				move_speed = clamp(move_speed - speed_step, min_speed, max_speed)

	if event is InputEventMouseMotion and _is_right_clicking:
		_rotation_y -= event.relative.x * look_sensitivity
		_rotation_x -= event.relative.y * look_sensitivity
		_rotation_x = clamp(_rotation_x, -PI/2, PI/2)

		transform.basis = Basis()
		rotate_object_local(Vector3.UP, _rotation_y)
		rotate_object_local(Vector3.RIGHT, _rotation_x)

func _process(delta: float) -> void:
	
	fps.text = str(Engine.get_frames_per_second())
	
	if not _is_right_clicking:
		return
		
	var input_dir := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_E): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1.0

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	translate_object_local(input_dir * move_speed * delta)
