extends GutTest

const GREY_ALPHA: float = 0.4

var _menu: ActionMenu


func before_each() -> void:
	_menu = load("res://scenes/ui/ActionMenu.tscn").instantiate()
	add_child_autofree(_menu)


func _make_combatant_with(costs: Array, current_pp: int) -> Combatant:
	var list: Array[Ability] = []
	for i in range(costs.size()):
		var ab := Ability.new()
		ab.ability_name = "Ability %d" % i
		ab.pp_cost = costs[i]
		list.append(ab)
	var d := CharacterDefinition.new()
	d.max_pp = 100
	d.abilities = list
	var c := Combatant.from_definition(d)
	c.current_pp = current_pp
	return c


func test_setup_shows_one_row_per_ability() -> void:
	var c: Combatant = _make_combatant_with([5, 5, 5], 100)
	_menu.setup(c)
	assert_eq(_menu._row_count, 4, "Attack row plus three ability rows")
	assert_eq(_menu._rows[3].text, "Ability 2", "Row 3 shows the third ability")
	assert_false(_menu._rows[4].visible, "Unused rows stay hidden")


func test_setup_shows_four_ability_rows_for_four_abilities() -> void:
	var c: Combatant = _make_combatant_with([5, 5, 5, 5], 100)
	_menu.setup(c)
	assert_eq(_menu._row_count, 5, "Attack row plus four ability rows")
	for i in range(1, 5):
		assert_true(_menu._rows[i].visible, "Ability row %d is visible" % i)


func test_setup_clamps_abilities_to_available_rows() -> void:
	var c: Combatant = _make_combatant_with([5, 5, 5, 5, 5], 100)
	_menu.setup(c)
	assert_eq(_menu._row_count, 5, "Only five rows exist; the fifth ability is dropped")
	assert_eq(_menu._rows[4].text, "Ability 3", "Last row shows the fourth ability")


func test_setup_greys_only_unaffordable_rows() -> void:
	var c: Combatant = _make_combatant_with([5, 90], 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].modulate.a, 1.0, "Affordable ability is full alpha")
	assert_almost_eq(_menu._rows[2].modulate.a, GREY_ALPHA, 0.001,
		"Unaffordable ability is greyed")


func test_selected_ability_index_is_row_minus_one() -> void:
	var c: Combatant = _make_combatant_with([5, 5], 100)
	_menu.setup(c)
	_menu._selected_idx = 2
	assert_eq(_menu.selected_ability_index, 1,
		"Row 2 maps to abilities[1]")


func test_confirm_on_unaffordable_row_emits_nothing() -> void:
	var c: Combatant = _make_combatant_with([90], 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_not_emitted(_menu, "action_selected",
		"An unaffordable ability must not be selectable")


func test_confirm_emits_attack_at_row_0() -> void:
	var c: Combatant = _make_combatant_with([5], 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["attack"])


func test_confirm_emits_ability_at_row_1_when_pp_sufficient() -> void:
	var c: Combatant = _make_combatant_with([5], 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["ability"])


func test_confirm_blocks_silently_at_row_1_when_pp_insufficient() -> void:
	var c: Combatant = _make_combatant_with([10], 5)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_not_emitted(_menu, "action_selected",
		"must not emit action_selected when PP is insufficient")


func test_navigate_down_increments_selected_idx() -> void:
	var c: Combatant = _make_combatant_with([5], 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1)


func test_navigate_clamps_at_last_row() -> void:
	var c: Combatant = _make_combatant_with([5], 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1, "must not exceed last row index")


func test_navigate_clamps_at_first_row() -> void:
	var c: Combatant = _make_combatant_with([5], 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(-1)
	assert_eq(_menu._selected_idx, 0, "must not go below row 0")
