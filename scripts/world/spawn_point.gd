@tool
class_name SpawnPoint
extends Node2D

@export var spawn_id: String = ""


func _ready() -> void:
	add_to_group("spawn_points")
