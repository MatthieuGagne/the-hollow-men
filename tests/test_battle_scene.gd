extends GutTest

var _scene: Node2D


func before_each() -> void:
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)


func test_begin_player_turn_sets_awaiting_input() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	assert_eq(_scene._state, _scene.BattleState.AWAITING_INPUT)


func test_begin_player_turn_shows_action_menu() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	assert_true(_scene._action_menu.visible, "ActionMenu should be visible during AWAITING_INPUT")
	assert_true(_scene._enemy_window.visible, "EnemyWindow should remain visible during AWAITING_INPUT")


func test_execute_action_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_execute_action_hides_action_menu() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_false(_scene._action_menu.visible, "ActionMenu should be hidden after action resolves")
	assert_true(_scene._enemy_window.visible, "EnemyWindow should reappear after action resolves")


func test_execute_action_damages_enemy() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_lt(shade.current_hp, hp_before, "Shade HP must decrease after Attack")


func test_execute_action_triggers_win_on_lethal_hit() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1  # any hit kills it (min damage = 1)
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_eq(_scene._state, _scene.BattleState.ENDED,
		"State must be ENDED when all enemies are dead")


func test_battle_ended_signal_emitted_on_win() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1
	var reid: Combatant = _scene.party[0]
	watch_signals(_scene)
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_signal_emitted_with_parameters(_scene, "battle_ended", [true])


func test_party_sprites_have_1px_vertical_gap() -> void:
	var container: Node2D = _scene.get_node("PartyContainer")
	var sprites := container.get_children()
	assert_gte(sprites.size(), 2, "need at least 2 sprites to check gap")

	var half_h: float = float(BattleScene.SPRITE_FRAME_HEIGHT) / 2.0
	for i in range(sprites.size() - 1):
		var bottom_of_upper: float = sprites[i].position.y + half_h
		var top_of_lower: float    = sprites[i + 1].position.y - half_h
		var gap: float = top_of_lower - bottom_of_upper
		assert_eq(gap, 1.0, "gap between sprites %d and %d must be 1px" % [i, i + 1])


func test_select_enemy_target_excludes_downed_members() -> void:
	# Down Reid (party[0]), Iris (party[1]) remains alive
	var reid: Combatant = _scene.party[0]
	var iris: Combatant = _scene.party[1]
	reid.current_hp = 0

	for _i in range(50):
		var target: Combatant = _scene._select_enemy_target()
		assert_eq(target, iris, "downed Reid must never be selected as target")


func test_select_enemy_target_returns_null_when_all_downed() -> void:
	for p in _scene.party:
		p.current_hp = 0
	var target = _scene._select_enemy_target()
	assert_null(target, "must return null when no living party members remain")


func test_defeat_condition_triggers_when_all_party_downed() -> void:
	for p in _scene.party:
		p.current_hp = 0
	_scene._check_win_loss()
	assert_eq(_scene._state, _scene.BattleState.ENDED,
		"state must be ENDED when all party HP = 0")


func test_defeat_signal_emitted_when_all_party_downed() -> void:
	watch_signals(_scene)
	for p in _scene.party:
		p.current_hp = 0
	_scene._check_win_loss()
	assert_signal_emitted_with_parameters(_scene, "battle_ended", [false])


func test_skip_turn_does_not_consume_atb() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	_scene._begin_player_turn(reid)
	_scene.skip_turn()
	assert_eq(reid.atb, Combatant.ATB_MAX, "skip must not consume ATB")


func test_skip_turn_sets_skip_cooldown() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	_scene._begin_player_turn(reid)
	_scene.skip_turn()
	assert_gt(reid.skip_cooldown, 0.0, "skip_cooldown must be > 0 after skip")


func test_skip_turn_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	_scene._begin_player_turn(reid)
	_scene.skip_turn()
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_skip_cooldown_ticks_down_in_process() -> void:
	var reid: Combatant = _scene.party[0]
	reid.skip_cooldown = 2.0
	_scene._process(1.0)
	assert_lt(reid.skip_cooldown, 2.0, "skip_cooldown must decrease after _process")


func test_skip_cooldown_clears_when_expired() -> void:
	var reid: Combatant = _scene.party[0]
	reid.skip_cooldown = 0.1
	_scene._process(0.2)
	assert_false(reid.is_skipping(), "skip_cooldown must be 0 after expiry")


func test_skipping_combatant_does_not_get_new_turn() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	reid.skip_cooldown = 2.0
	_scene._tick_atb(0.0)
	assert_ne(_scene._state, _scene.BattleState.AWAITING_INPUT,
		"skipping combatant must not trigger a new turn")


func test_player_turn_started_signal_emitted() -> void:
	var reid: Combatant = _scene.party[0]
	watch_signals(_scene)
	_scene._begin_player_turn(reid)
	assert_signal_emitted_with_parameters(_scene, "player_turn_started", [reid])


func test_player_turn_ended_signal_emitted_after_skip() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	_scene._begin_player_turn(reid)
	watch_signals(_scene)
	_scene.skip_turn()
	assert_signal_emitted(_scene, "player_turn_ended")


func test_player_turn_ended_signal_emitted_after_action() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	watch_signals(_scene)
	_scene.execute_action("attack")
	assert_signal_emitted(_scene, "player_turn_ended")


func test_player_turn_ended_not_emitted_after_enemy_turn() -> void:
	var shade: Combatant = _scene.enemies[0]
	_scene._begin_enemy_turn(shade)
	watch_signals(_scene)
	_scene._end_turn()
	assert_signal_not_emitted(_scene, "player_turn_ended")
