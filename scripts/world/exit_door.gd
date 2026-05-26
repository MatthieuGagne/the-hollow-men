class_name ExitDoor
extends Area2D

@export var target_path: String = ""
@export var spawn_point: String = ""


func _ready() -> void:
	target_path = get_meta("target_path", target_path)
	spawn_point  = get_meta("spawn_point",  spawn_point)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	SceneManager.change_scene(target_path, spawn_point)
