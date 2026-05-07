extends Node

signal pre_scene_change


func change_scene(path: String) -> void:
	pre_scene_change.emit()
	get_tree().change_scene_to_file(path)
