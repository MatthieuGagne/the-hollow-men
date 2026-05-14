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
	# Down Reid (party[0]); remaining living members must be the only valid targets
	var reid: Combatant = _scene.party[0]
	reid.current_hp = 0

	for _i in range(50):
		var target: Combatant = _scene._select_enemy_target()
		assert_ne(target, reid, "downed Reid must never be selected as target")


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


func test_ability_damages_enemy_as_reid() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Piercing Strike must deal damage to Shade")


func test_ability_damages_enemy_as_iris() -> void:
	var iris: Combatant = _scene.party[1]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(iris)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Static Touch must deal damage to Shade")


func test_ability_spends_pp() -> void:
	var reid: Combatant = _scene.party[0]
	var pp_before: int = reid.current_pp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_lt(reid.current_pp, pp_before, "Piercing Strike must spend PP")


func test_ability_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_ability_does_not_damage_when_pp_insufficient() -> void:
	var reid: Combatant = _scene.party[0]
	reid.current_pp = 0
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_eq(shade.current_hp, hp_before, "ability must not deal damage when PP is 0")


func _add_karim_to_party() -> Combatant:
	var karim: Combatant = load("res://characters/karim.tres")
	karim.reset_runtime_state()
	_scene.party.append(karim)
	return karim


func test_party_targeting_ability_sets_selecting_ally() -> void:
	var karim := _add_karim_to_party()
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.SELECTING_ALLY)


func test_confirm_party_target_heals_target() -> void:
	var karim := _add_karim_to_party()
	var reid: Combatant = _scene.party[0]
	reid.current_hp = 100
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(reid)
	assert_gt(reid.current_hp, 100, "Reid HP must increase after Field Suture")


func test_confirm_party_target_caps_at_max_hp() -> void:
	var karim := _add_karim_to_party()
	var reid: Combatant = _scene.party[0]
	reid.current_hp = reid.max_hp
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(reid)
	assert_eq(reid.current_hp, reid.max_hp, "HP must not exceed max_hp after heal")


func test_confirm_party_target_spends_karim_pp() -> void:
	var karim := _add_karim_to_party()
	var pp_before: int = karim.current_pp
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(_scene.party[0])
	assert_lt(karim.current_pp, pp_before, "Karim must spend PP on Field Suture")


func test_confirm_party_target_returns_to_ticking() -> void:
	var karim := _add_karim_to_party()
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(_scene.party[0])
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_navigate_party_target_advances_cursor() -> void:
	var karim := _add_karim_to_party()
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	var idx_before: int = _scene._party_target_idx
	_scene._navigate_party_target(1)
	assert_ne(_scene._party_target_idx, idx_before,
		"navigating down must change target index when multiple living members exist")


func test_navigate_party_target_skips_dead_members() -> void:
	var karim := _add_karim_to_party()
	_scene.party[0].current_hp = 0
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	var target: Combatant = _scene.party[_scene._party_target_idx]
	assert_true(target.is_alive(), "initial target must be a living party member")


func test_confirm_party_target_ignores_dead_target() -> void:
	var karim := _add_karim_to_party()
	var reid: Combatant = _scene.party[0]
	reid.current_hp = 0
	var hp_before: int = reid.current_hp
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(reid)
	assert_eq(reid.current_hp, hp_before, "dead target must not be healed")
	assert_eq(_scene._state, _scene.BattleState.SELECTING_ALLY,
		"state must remain SELECTING_ALLY when dead target is confirmed")


func test_party_size_is_four() -> void:
	assert_eq(_scene.party.size(), 4, "party must contain exactly 4 members")


func test_party_contains_karim() -> void:
	var names: Array = _scene.party.map(func(p: Combatant) -> String: return p.character_name)
	assert_true(names.has("Karim"), "party must include Karim")


func test_party_contains_margot() -> void:
	var names: Array = _scene.party.map(func(p: Combatant) -> String: return p.character_name)
	assert_true(names.has("Margot"), "party must include Margot")


func test_margot_ability_deals_psy_damage() -> void:
	var margot: Combatant = _scene.party[3]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(margot)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before,
		"Void Calculus must deal PSY damage to Shade")


func test_margot_ability_spends_pp() -> void:
	var margot: Combatant = _scene.party[3]
	var pp_before: int = margot.current_pp
	_scene._begin_player_turn(margot)
	_scene.execute_action("ability")
	assert_lt(margot.current_pp, pp_before, "Void Calculus must spend 15 PP")


func test_margot_ability_does_not_damage_when_pp_insufficient() -> void:
	var margot: Combatant = _scene.party[3]
	margot.current_pp = 0
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(margot)
	_scene.execute_action("ability")
	assert_eq(shade.current_hp, hp_before,
		"Void Calculus must not deal damage when PP is 0")


# --- Pause tests ---

func test_toggle_pause_from_ticking_enters_paused() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.PAUSED)


func test_toggle_pause_stores_pre_pause_state_ticking() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	assert_eq(_scene._pre_pause_state, _scene.BattleState.TICKING)


func test_toggle_pause_from_awaiting_input_enters_paused() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.PAUSED)


func test_toggle_pause_stores_pre_pause_state_awaiting_input() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene._toggle_pause()
	assert_eq(_scene._pre_pause_state, _scene.BattleState.AWAITING_INPUT)


func test_toggle_pause_from_selecting_ally_enters_paused() -> void:
	_scene._state = _scene.BattleState.SELECTING_ALLY
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.PAUSED)


func test_toggle_pause_ignored_from_animating() -> void:
	_scene._state = _scene.BattleState.ANIMATING
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.ANIMATING)


func test_toggle_pause_ignored_from_ended() -> void:
	_scene._state = _scene.BattleState.ENDED
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.ENDED)


func test_unpause_restores_ticking() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_unpause_restores_awaiting_input() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene._toggle_pause()
	_scene._toggle_pause()
	assert_eq(_scene._state, _scene.BattleState.AWAITING_INPUT)


func test_atb_frozen_while_paused() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.atb = 0.0
	_scene._state = _scene.BattleState.PAUSED
	_scene._process(1.0)
	assert_eq(shade.atb, 0.0, "ATB must not advance while paused")


func test_pause_emits_pause_toggled_true() -> void:
	_scene._state = _scene.BattleState.TICKING
	watch_signals(_scene)
	_scene._toggle_pause()
	assert_signal_emitted_with_parameters(_scene, "pause_toggled", [true])


func test_unpause_emits_pause_toggled_false() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	watch_signals(_scene)
	_scene._toggle_pause()
	assert_signal_emitted_with_parameters(_scene, "pause_toggled", [false])
