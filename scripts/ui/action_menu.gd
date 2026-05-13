class_name ActionMenu
extends Control

signal action_selected(action_name: String)

var _cursor: Label


func _ready() -> void:
	_cursor = Label.new()
	_cursor.text = "►"
	_cursor.add_theme_font_size_override("font_size", 6)
	_cursor.modulate.a = 0.0
	add_child(_cursor)

	var attack_btn: Button = $VBoxContainer/AttackButton
	attack_btn.focus_entered.connect(_show_cursor_at.bind(attack_btn))
	attack_btn.focus_exited.connect(func(): _cursor.modulate.a = 0.0)


func _show_cursor_at(button: Button) -> void:
	var btn_pos: Vector2 = $VBoxContainer.position + button.position
	_cursor.position = Vector2(btn_pos.x - 8, btn_pos.y)
	_cursor.modulate.a = 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		$VBoxContainer/AttackButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		action_selected.emit("attack")
		get_viewport().set_input_as_handled()
