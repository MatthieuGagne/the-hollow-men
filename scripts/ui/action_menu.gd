class_name ActionMenu
extends Control

signal action_selected(action_name: String)

const CURSOR_INDENT: int = 10  # px reserved for the ▶ column; VBoxContainer offset_left = 6 + CURSOR_INDENT
const GREY_ALPHA: float = 0.4

var _cursor: Label
var _rows: Array[Label] = []
var _selected_idx: int = 0
var _row_count: int = 1
var _ability_affordable: bool = false


func _ready() -> void:
	_cursor = Label.new()
	_cursor.text = "▶"
	_cursor.add_theme_font_size_override("font_size", 6)
	_cursor.modulate.a = 0.0
	add_child(_cursor)

	for child in $VBoxContainer.get_children():
		if child is Label:
			_rows.append(child)


func setup(combatant: Combatant) -> void:
	_selected_idx = 0
	_row_count = 1
	_ability_affordable = false

	if combatant.ability != null:
		_rows[1].text = combatant.ability.ability_name
		_ability_affordable = combatant.current_pp >= combatant.ability.pp_cost
		_rows[1].modulate.a = 1.0 if _ability_affordable else GREY_ALPHA
		_row_count = 2

	for i in range(_rows.size()):
		_rows[i].visible = i < _row_count


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_selected_idx = 0
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


func _navigate(delta: int) -> void:
	_selected_idx = clampi(_selected_idx + delta, 0, _row_count - 1)
	_move_cursor_to(_selected_idx)


func _confirm_selection() -> void:
	if _selected_idx == 0:
		action_selected.emit("attack")
	elif _ability_affordable:
		action_selected.emit("ability")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_up"):
		_navigate(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_navigate(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
