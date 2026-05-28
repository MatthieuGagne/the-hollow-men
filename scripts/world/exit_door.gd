class_name ExitDoor
extends Area2D

@export var target_path: String = ""
@export var spawn_point: String = ""
@export var required_flag: String = ""
@export var blocked_narration: String = "I'm not ready to leave yet."


func _ready() -> void:
	target_path = get_meta("target_path", target_path)
	spawn_point = get_meta("spawn_point", spawn_point)
	required_flag = get_meta("required_flag", required_flag)
	blocked_narration = get_meta("blocked_narration", blocked_narration)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if required_flag != "" and not GameState.has_flag(required_flag):
		DialogueManager.show_narration(blocked_narration)
		return
	SceneManager.change_scene(target_path, spawn_point)
