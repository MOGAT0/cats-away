extends Control

const LOADING_SCREEN = preload("res://scenes/loading_screen/loading_screen.tscn")

func _ready() -> void:
	GlobalScript.next_scene = "res://multiplayer/loby.tscn"

func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(LOADING_SCREEN)


func _on_quit_pressed() -> void:
	get_tree().quit(0)
