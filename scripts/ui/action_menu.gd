extends Control

signal action_selected(action_name: String)


func _ready() -> void:
	$AttackButton.pressed.connect(_on_attack_pressed)


func _on_attack_pressed() -> void:
	action_selected.emit("attack")
