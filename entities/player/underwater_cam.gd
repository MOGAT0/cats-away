extends MeshInstance3D

func _ready() -> void:
	show()

func _process(_delta: float) -> void:
	var mat = material_override as ShaderMaterial
	
	if mat:
		mat.set_shader_parameter("sea_height",WaterMath.sea_height)
		mat.set_shader_parameter("sea_choppy",WaterMath.sea_choppy)
