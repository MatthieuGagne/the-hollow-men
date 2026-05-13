class_name ActionMenu
extends Control

signal action_selected(action_name: String)

const CURSOR_INDENT: int = 10  # px reserved for the ▶ column; VBoxContainer offset_left = 6 + CURSOR_INDENT

var _cursor: Label
var _rows: Array[Label] = []


func _ready() -> void:
	_cursor = Label.new()
	_cursor.text = "▶"
	_cursor.add_theme_font_size_override("font_size", 6)
	_cursor.modulate.a = 0.0
	add_child(_cursor)

	for child in $VBoxContainer.get_children():
		if child is Label:
			_rows.append(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_move_cursor_to(0)


func _move_cursor_to(idx: int) -> void:
	if _rows.is_empty():
		return
	await get_tree().process_frame
	var row: Label = _rows[idx]
	var vbox_pos: Vector2 = $VBoxContainer.position
	var row_rect: Rect2 = row.get_rect()
	_cursor.position = Vector2(
		vbox_pos.x - CURSOR_INDENT,
		vbox_pos.y + row_rect.position.y + (row_rect.size.y - _cursor.size.y) * 0.5
	)
	_cursor.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		action_selected.emit("attack")
		get_viewport().set_input_as_handled()
