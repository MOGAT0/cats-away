extends Control
class_name LoadingScreen

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var load_percentage: Label = %load_percentage

var progress : Array = []
var req_scene_path : String
var scene_load_status = 0

func _ready() -> void:
	req_scene_path = GlobalScript.next_scene
	ResourceLoader.load_threaded_request(req_scene_path)
	#print(req_scene_path)

func _process(delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(req_scene_path,progress)
	progress_bar.value = floor(progress[0]*100)
	load_percentage.text = str(delta)
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var new_scene = ResourceLoader.load_threaded_get(req_scene_path)
		#await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_packed(new_scene)
