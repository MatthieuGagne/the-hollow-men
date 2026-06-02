class_name CutsceneZone
extends Area2D

@export var dialogue_node: String = ""
@export var next_scene: String = ""

var _fired: bool = false


func _ready() -> void:
	dialogue_node = get_meta("dialogue_node", dialogue_node)
	next_scene = get_meta("next_scene", next_scene)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body is Player:
		return
	_fired = true
	set_deferred("monitoring", false)
	if dialogue_node == "":
		return
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)
	DialogueManager.run_node(dialogue_node)


func _on_dialogue_closed() -> void:
	if next_scene.is_empty():
		return
	SceneManager.change_scene(next_scene)
