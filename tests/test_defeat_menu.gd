extends GutTest

var _menu: DefeatMenu


func before_each() -> void:
	_menu = load("res://scenes/ui/DefeatMenu.tscn").instantiate()
	add_child_autofree(_menu)


func test_hidden_by_default() -> void:
	assert_false(_menu.visible, "DefeatMenu must be hidden at start")


func test_interact_on_try_again_emits_retry_requested() -> void:
	_menu.show()
	watch_signals(_menu)
	_menu._selected_idx = 0
	_menu._confirm_selection()
	assert_signal_emitted(_menu, "retry_requested")


func test_interact_on_quit_emits_quit_requested() -> void:
	_menu.show()
	watch_signals(_menu)
	_menu._selected_idx = 1
	_menu._confirm_selection()
	assert_signal_emitted(_menu, "quit_requested")


func test_ignores_interact_when_hidden() -> void:
	_menu.hide()
	watch_signals(_menu)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	_menu._unhandled_input(ev)
	assert_signal_not_emitted(_menu, "retry_requested")
	assert_signal_not_emitted(_menu, "quit_requested")


func test_navigate_down_selects_quit() -> void:
	_menu.show()
	_menu._selected_idx = 0
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1)


func test_navigate_up_returns_to_try_again() -> void:
	_menu.show()
	_menu._selected_idx = 1
	_menu._navigate(-1)
	assert_eq(_menu._selected_idx, 0)


func test_navigate_clamps_at_top() -> void:
	_menu.show()
	_menu._selected_idx = 0
	_menu._navigate(-1)
	assert_eq(_menu._selected_idx, 0, "must not go below row 0")


func test_navigate_clamps_at_bottom() -> void:
	_menu.show()
	_menu._selected_idx = 1
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1, "must not exceed last row index")
