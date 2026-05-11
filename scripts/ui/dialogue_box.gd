class_name DialogueBox
extends Control

const CHAR_INTERVAL: float = 0.05

signal opened
signal closed
signal line_advanced
signal option_selected(index: int)

enum State { IDLE, SHOWING_LINE, SHOWING_CHOICES }

var is_typing: bool = false

var _full_text: String = ""
var _char_index: int = 0
var _timer: Timer
var _yarn_mode: bool = false
var _state: State = State.IDLE
var _selected_choice: int = 0
var _choice_count: int = 0


func _ready() -> void:
	visible = false
	_timer = Timer.new()
	_timer.wait_time = CHAR_INTERVAL
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func show_text(text: String) -> void:
	_yarn_mode = false
	_set_speaker("")
	_show_line_internal(text)


func show_line(speaker: String, text: String) -> void:
	_yarn_mode = true
	_set_speaker(speaker)
	_show_line_internal(text)


func show_choices(options: Array) -> void:
	_state = State.SHOWING_CHOICES
	_selected_choice = 0
	_choice_count = options.size()
	var label: Label = get_node_or_null("Label")
	if label:
		label.text = ""
	var choice_list: VBoxContainer = get_node_or_null("ChoiceList")
	if choice_list == null:
		return
	for child in choice_list.get_children():
		child.queue_free()
	for i in range(options.size()):
		var lbl := Label.new()
		lbl.text = ("> " if i == 0 else "  ") + options[i]
		choice_list.add_child(lbl)
	choice_list.visible = true


func skip_or_dismiss() -> void:
	if _state == State.SHOWING_LINE:
		if is_typing:
			_timer.stop()
			_char_index = _full_text.length()
			is_typing = false
			_update_label()
		elif _yarn_mode:
			line_advanced.emit()
		else:
			_dismiss_internal()
	elif _state == State.SHOWING_CHOICES:
		option_selected.emit(_selected_choice)


func dismiss() -> void:
	_dismiss_internal()


func get_displayed_text() -> String:
	return _full_text.left(_char_index)


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.SHOWING_CHOICES:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_selected_choice = (_selected_choice - 1 + _choice_count) % _choice_count
		_update_choice_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_selected_choice = (_selected_choice + 1) % _choice_count
		_update_choice_highlight()
		get_viewport().set_input_as_handled()


func _show_line_internal(text: String) -> void:
	_full_text = text
	_char_index = 0
	is_typing = true
	_state = State.SHOWING_LINE
	visible = true
	var choice_list: VBoxContainer = get_node_or_null("ChoiceList")
	if choice_list:
		choice_list.visible = false
	_timer.start()
	opened.emit()


func _dismiss_internal() -> void:
	_state = State.IDLE
	visible = false
	closed.emit()


func _set_speaker(name: String) -> void:
	var lbl: Label = get_node_or_null("SpeakerLabel")
	if lbl:
		lbl.text = name


func _update_label() -> void:
	var label: Label = get_node_or_null("Label")
	if label:
		label.text = get_displayed_text()


func _update_choice_highlight() -> void:
	var choice_list: VBoxContainer = get_node_or_null("ChoiceList")
	if choice_list == null:
		return
	for i in range(choice_list.get_child_count()):
		var lbl: Label = choice_list.get_child(i)
		var option_text: String = lbl.text.substr(2)
		lbl.text = ("> " if i == _selected_choice else "  ") + option_text


func _on_timer_timeout() -> void:
	if _char_index < _full_text.length():
		_char_index += 1
		_update_label()
		if _char_index == _full_text.length():
			is_typing = false
			_timer.stop()
