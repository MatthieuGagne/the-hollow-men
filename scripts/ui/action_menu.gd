class_name ActionMenu
extends Control

signal action_selected(action_name: String)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		$VBoxContainer/AttackButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		action_selected.emit("attack")
		get_viewport().set_input_as_handled()
