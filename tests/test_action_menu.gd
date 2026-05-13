extends GutTest

const GREY_ALPHA: float = 0.4

var _menu: ActionMenu


func before_each() -> void:
	_menu = load("res://scenes/ui/ActionMenu.tscn").instantiate()
	add_child_autofree(_menu)


func _make_combatant(pp_cost: int, current_pp: int) -> Combatant:
	var ab: Ability = Ability.new()
	ab.ability_name = "Test Ability"
	ab.pp_cost = pp_cost
	var c: Combatant = Combatant.new()
	c.ability = ab
	c.max_pp = 100
	c.current_pp = current_pp
	return c


func test_setup_sets_ability_row_text() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].text, "Test Ability",
		"Row1 must show ability_name after setup()")


func test_setup_hides_extra_rows() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	for i in range(2, _menu._rows.size()):
		assert_false(_menu._rows[i].visible, "Row %d must be hidden after setup()" % i)


func test_setup_greys_out_row_when_pp_insufficient() -> void:
	var c: Combatant = _make_combatant(10, 5)
	_menu.setup(c)
	assert_almost_eq(_menu._rows[1].modulate.a, GREY_ALPHA, 0.001,
		"Row1 alpha must be GREY_ALPHA when current_pp < pp_cost")


func test_setup_full_alpha_when_pp_sufficient() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].modulate.a, 1.0,
		"Row1 alpha must be 1.0 when current_pp >= pp_cost")


func test_confirm_emits_attack_at_row_0() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["attack"])


func test_confirm_emits_ability_at_row_1_when_pp_sufficient() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["ability"])


func test_confirm_blocks_silently_at_row_1_when_pp_insufficient() -> void:
	var c: Combatant = _make_combatant(10, 5)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_not_emitted(_menu, "action_selected",
		"must not emit action_selected when PP is insufficient")


func test_navigate_down_increments_selected_idx() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1)


func test_navigate_clamps_at_last_row() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1, "must not exceed last row index")


func test_navigate_clamps_at_first_row() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(-1)
	assert_eq(_menu._selected_idx, 0, "must not go below row 0")
