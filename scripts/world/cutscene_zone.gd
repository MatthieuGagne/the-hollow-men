class_name CutsceneZone
extends Area2D

@export var dialogue_node: String = ""
@export var next_scene: String = ""

var _fired: bool = false


func _ready() -> void:
	dialogue_node = get_meta("dialogue_node", dialogue_node)
	next_scene = get_meta("next_scene", next_scene)
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_dialogue_closed() -> void:
	pass
