@tool
class_name SpawnPoint
extends Node2D

@export var spawn_id: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if spawn_id == "" and has_meta("spawn_id"):
		spawn_id = get_meta("spawn_id")
	add_to_group("spawn_points")
