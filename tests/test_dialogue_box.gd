extends GutTest

var _box: Control


func before_each() -> void:
	_box = preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(_box)


func after_each() -> void:
	if is_instance_valid(_box):
		_box.free()


# --- examine_text (non-yarn) mode ---

func test_initially_hidden() -> void:
	assert_false(_box.visible)


func test_show_text_makes_visible_and_starts_typing() -> void:
	_box.show_text("Hello world")
	assert_true(_box.visible)
	assert_true(_box.is_typing)


func test_skip_during_typing_shows_full_text() -> void:
	_box.show_text("Hello world")
	_box.skip_or_dismiss()
	assert_false(_box.is_typing)
	assert_eq(_box.get_displayed_text(), "Hello world")


func test_dismiss_after_skip_hides_box() -> void:
	_box.show_text("Hello world")
	_box.skip_or_dismiss()
	_box.skip_or_dismiss()
	assert_false(_box.visible)


func test_opened_signal_emitted_on_show_text() -> void:
	watch_signals(_box)
	_box.show_text("Test")
	assert_signal_emitted(_box, "opened")


func test_closed_signal_emitted_on_dismiss() -> void:
	watch_signals(_box)
	_box.show_text("Test")
	_box.skip_or_dismiss()
	_box.skip_or_dismiss()
	assert_signal_emitted(_box, "closed")


func test_advance_typewriter_adds_character() -> void:
	_box.show_text("AB")
	_box._on_timer_timeout()
	assert_eq(_box.get_displayed_text(), "A")
	_box._on_timer_timeout()
	assert_eq(_box.get_displayed_text(), "AB")


func test_typewriter_completes_on_last_char() -> void:
	_box.show_text("X")
	_box._on_timer_timeout()
	assert_false(_box.is_typing)


# --- yarn mode ---

func test_show_line_enters_yarn_mode() -> void:
	_box.show_line("Iris", "Hello.")
	assert_true(_box.visible)
	assert_true(_box.is_typing)


func test_skip_in_yarn_mode_does_not_dismiss() -> void:
	_box.show_line("Iris", "Hello.")
	_box.skip_or_dismiss()  # skip typewriter
	_box.skip_or_dismiss()  # should emit line_advanced, not dismiss
	assert_true(_box.visible)


func test_line_advanced_emitted_in_yarn_mode() -> void:
	watch_signals(_box)
	_box.show_line("Iris", "Hello.")
	_box.skip_or_dismiss()  # skip
	_box.skip_or_dismiss()  # advance
	assert_signal_emitted(_box, "line_advanced")
	assert_signal_not_emitted(_box, "closed")


func test_dismiss_hides_box_in_yarn_mode() -> void:
	_box.show_line("Iris", "Hello.")
	_box.dismiss()
	assert_false(_box.visible)


func test_closed_emitted_on_dismiss() -> void:
	watch_signals(_box)
	_box.show_line("Iris", "Hello.")
	_box.dismiss()
	assert_signal_emitted(_box, "closed")


# --- choices ---

func test_show_choices_makes_choice_list_visible() -> void:
	_box.show_line("Iris", "Well?")
	_box.show_choices(["Option A", "Option B"])
	var choice_list: VBoxContainer = _box.get_node_or_null("ChoiceList")
	assert_not_null(choice_list)
	assert_true(choice_list.visible)
	assert_eq(choice_list.get_child_count(), 2)


func test_skip_or_dismiss_in_choices_emits_option_selected() -> void:
	watch_signals(_box)
	_box.show_line("Iris", "Well?")
	_box.show_choices(["Option A", "Option B"])
	_box.skip_or_dismiss()
	assert_signal_emitted(_box, "option_selected")


func test_option_selected_index_is_zero_by_default() -> void:
	watch_signals(_box)
	_box.show_line("Iris", "Well?")
	_box.show_choices(["Option A", "Option B"])
	_box.skip_or_dismiss()
	assert_signal_emitted_with_parameters(_box, "option_selected", [0])


func test_state_returns_to_idle_after_dismiss() -> void:
	_box.show_line("Iris", "Hello.")
	_box.dismiss()
	assert_false(_box.visible)
	assert_eq(_box._state, _box.State.IDLE)
