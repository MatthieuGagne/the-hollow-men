extends GutTest

var _scene: Node2D


func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager._permanent_members.append(reid)
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)


func test_battle_context_return_scene_defaults_to_empty() -> void:
	assert_eq(BattleContext.return_scene, "", "return_scene should default to empty string")


func test_battle_context_return_spawn_defaults_to_empty() -> void:
	assert_eq(BattleContext.return_spawn, "", "return_spawn should default to empty string")


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
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
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
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before, "Shade HP must decrease after Attack")


func test_execute_action_triggers_win_on_lethal_hit() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1  # any hit kills it (min damage = 1)
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	assert_eq(_scene._state, _scene.BattleState.ENDED,
		"State must be ENDED when all enemies are dead")


func test_battle_ended_signal_emitted_on_win() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1
	var reid: Combatant = _scene.party[0]
	watch_signals(_scene)
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.battle_ended, 2.0)
	assert_signal_emitted_with_parameters(_scene, "battle_ended", [true])


func test_party_sprites_have_1px_vertical_gap() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_member(iris)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var container: Node2D = scene2.get_node("PartyContainer")
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
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
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
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before, "Piercing Strike must deal damage to Shade")


func test_ability_damages_enemy_as_iris() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_member(iris)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var shade: Combatant = scene2.enemies[0]
	var hp_before: int = shade.current_hp
	scene2._begin_player_turn(iris)
	scene2.execute_action("ability")
	scene2.confirm_enemy_target()
	await wait_for_signal(scene2.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before, "Static Touch must deal damage to Shade")


func test_ability_spends_pp() -> void:
	var reid: Combatant = _scene.party[0]
	var pp_before: int = reid.current_pp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	assert_lt(reid.current_pp, pp_before, "Piercing Strike must spend PP")


func test_ability_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	assert_eq(_scene._state, _scene.BattleState.TICKING)


func test_ability_does_not_damage_when_pp_insufficient() -> void:
	var reid: Combatant = _scene.party[0]
	reid.current_pp = 0
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	assert_eq(shade.current_hp, hp_before, "ability must not deal damage when PP is 0")


func _add_karim_to_party() -> Combatant:
	var karim: Combatant = Combatant.from_definition(load("res://characters/karim.tres"))
	_scene.party.append(karim)
	var idx: int = _scene.party.size() - 1
	var sprite := Sprite2D.new()
	sprite.vframes = karim.sprite_vframes
	sprite.frame = 2
	sprite.flip_h = false
	sprite.position = Vector2(0, BattleScene.SLOT_POSITIONS[idx])
	sprite.texture = load(karim.sprite_path)
	sprite.modulate = Color.WHITE
	_scene.get_node("PartyContainer").add_child(sprite)
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


func test_confirm_party_target_heals_exact_effect_amount() -> void:
	var karim := _add_karim_to_party()   # PSY 45 -> heals 38 + 22 = 60
	var reid: Combatant = _scene.party[0]
	reid.current_hp = 100
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(reid)
	assert_eq(reid.current_hp, 160,
		"data-driven HealEffect restores exactly 60 (100 -> 160)")


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


func test_margot_ability_deals_psy_damage() -> void:
	var margot: Combatant = Combatant.from_definition(load("res://characters/margot.tres"))
	PartyManager.add_member(margot)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var shade: Combatant = scene2.enemies[0]
	var hp_before: int = shade.current_hp
	scene2._begin_player_turn(margot)
	scene2.execute_action("ability")
	scene2.confirm_enemy_target()
	await wait_for_signal(scene2.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before,
		"Void Calculus must deal PSY damage to Shade")


func test_margot_ability_spends_pp() -> void:
	var margot: Combatant = Combatant.from_definition(load("res://characters/margot.tres"))
	PartyManager.add_member(margot)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var pp_before: int = margot.current_pp
	scene2._begin_player_turn(margot)
	scene2.execute_action("ability")
	scene2.confirm_enemy_target()
	assert_lt(margot.current_pp, pp_before, "Void Calculus must spend 15 PP")


func test_margot_ability_does_not_damage_when_pp_insufficient() -> void:
	var margot: Combatant = Combatant.from_definition(load("res://characters/margot.tres"))
	margot.current_pp = 0
	PartyManager.add_member(margot)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var shade: Combatant = scene2.enemies[0]
	var hp_before: int = shade.current_hp
	scene2._begin_player_turn(margot)
	scene2.execute_action("ability")
	scene2.confirm_enemy_target()
	assert_eq(shade.current_hp, hp_before,
		"Void Calculus must not deal damage when PP is 0")


func test_ability_emits_combatant_updated_for_attacker() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	watch_signals(_scene)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	assert_signal_emitted_with_parameters(_scene, "combatant_updated", [reid])


func test_enemy_attacks_during_awaiting_input_state_unchanged() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	_scene._begin_player_turn(reid)
	shade.atb = Combatant.ATB_MAX
	_scene._process(0.0)
	assert_eq(_scene._state, _scene.BattleState.AWAITING_INPUT,
		"state must remain AWAITING_INPUT when enemy attacks during player's action menu")


func test_enemy_atb_consumed_after_attacking_during_awaiting_input() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	_scene._begin_player_turn(reid)
	shade.atb = Combatant.ATB_MAX
	_scene._process(0.0)
	assert_eq(shade.atb, 0.0,
		"enemy ATB must be consumed after attacking during player's turn")


func test_enemy_attacks_during_selecting_ally_state_unchanged() -> void:
	var karim := _add_karim_to_party()
	var shade: Combatant = _scene.enemies[0]
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	shade.atb = Combatant.ATB_MAX
	_scene._process(0.0)
	assert_eq(_scene._state, _scene.BattleState.SELECTING_ALLY,
		"state must remain SELECTING_ALLY when enemy attacks during party targeting")


func test_enemies_tick_during_selecting_ally() -> void:
	var karim := _add_karim_to_party()
	var shade: Combatant = _scene.enemies[0]
	shade.atb = 0.0
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.SELECTING_ALLY)
	_scene._process(1.0)
	assert_gt(shade.atb, 0.0,
		"enemy ATB must advance during SELECTING_ALLY so enemies can still attack")


func test_ability_spawns_pp_cost_label_over_attacker() -> void:
	var reid: Combatant = _scene.party[0]
	var reid_sprite: Node2D = _scene.get_node("PartyContainer").get_child(0)
	var child_count_before: int = reid_sprite.get_child_count()
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	assert_gt(reid_sprite.get_child_count(), child_count_before,
		"a floating PP cost label must be spawned over the attacker's sprite after ability use")


func test_party_ability_spawns_pp_cost_label_over_attacker() -> void:
	var karim := _add_karim_to_party()
	var karim_idx: int = _scene.party.find(karim)
	var karim_sprite: Node2D = _scene.get_node("PartyContainer").get_child(karim_idx)
	var child_count_before: int = karim_sprite.get_child_count()
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(_scene.party[0])
	assert_gt(karim_sprite.get_child_count(), child_count_before,
		"a floating PP cost label must be spawned over Karim's sprite after Field Suture")


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


# --- ActionMenu pause guard test ---

func test_interact_blocked_while_paused() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)   # AWAITING_INPUT, ActionMenu visible
	_scene._toggle_pause()            # → PAUSED; signal fires → ActionMenu._is_paused = true

	watch_signals(_scene._action_menu)

	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	_scene._action_menu._unhandled_input(ev)

	assert_signal_not_emitted(_scene._action_menu, "action_selected",
		"action_selected must not fire while paused")


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


# --- PausedLabel visibility tests ---

func test_paused_label_hidden_by_default() -> void:
	assert_false(_scene._paused_label.visible, "PausedLabel must be hidden at start")


func test_paused_label_shown_on_pause() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	assert_true(_scene._paused_label.visible, "PausedLabel must be visible while paused")


func test_paused_label_hidden_on_unpause() -> void:
	_scene._state = _scene.BattleState.TICKING
	_scene._toggle_pause()
	_scene._toggle_pause()
	assert_false(_scene._paused_label.visible, "PausedLabel must be hidden after unpausing")


func test_victory_shows_victory_label() -> void:
	_scene._on_battle_ended(true)
	assert_true(_scene._victory_label.visible,
		"VictoryLabel must be visible immediately after victory")

func test_defeat_shows_defeat_label() -> void:
	_scene._on_battle_ended(false)
	assert_true(_scene._defeat_label.visible,
		"DefeatLabel must be visible after defeat")

func test_defeat_menu_hidden_by_default() -> void:
	assert_false(_scene._defeat_menu.visible,
		"DefeatMenu must be hidden at battle start")


func test_defeat_menu_visible_after_defeat() -> void:
	_scene._on_battle_ended(false)
	assert_true(_scene._defeat_menu.visible,
		"DefeatMenu must be visible after defeat")


func test_action_menu_hidden_on_defeat() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene._on_battle_ended(false)
	assert_false(_scene._action_menu.visible,
		"ActionMenu must be hidden when defeat fires")


func test_action_menu_hidden_on_victory() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene._on_battle_ended(true)
	assert_false(_scene._action_menu.visible,
		"ActionMenu must be hidden when victory fires")


func test_execute_action_enters_animating_state() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	_scene.confirm_enemy_target()
	assert_eq(_scene._state, _scene.BattleState.ANIMATING,
		"confirming a target must immediately enter ANIMATING before tween completes")


func test_offensive_ability_enters_animating_state() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	assert_eq(_scene._state, _scene.BattleState.ANIMATING,
		"offensive ability must enter ANIMATING state when attacker has enough PP")


func test_healing_confirm_skips_animating_state() -> void:
	var karim := _add_karim_to_party()
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")  # enters SELECTING_ALLY (party-targeting path)
	_scene.confirm_party_target(reid)  # healing — must NOT go through ANIMATING
	assert_eq(_scene._state, _scene.BattleState.TICKING,
		"healing via confirm_party_target must go directly to TICKING, never ANIMATING")


func test_party_comes_from_party_manager() -> void:
	assert_eq(_scene.party.size(), 1)
	assert_eq(_scene.party[0].character_name, "Reid")


func test_party_includes_temporary_members() -> void:
	PartyManager._temporary_members.clear()
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_temporary(iris)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(scene2.party.size(), 2)
	assert_eq(scene2.party[1].character_name, "Iris")


func test_victory_removes_temporary_members() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_temporary(iris)
	_scene._on_battle_ended(true)
	assert_false(PartyManager.has_member("Iris"))


func test_victory_uses_return_scene_when_set() -> void:
	BattleContext.return_scene = "res://scenes/world/FourWindsBar.tscn"
	assert_eq(BattleContext.return_scene, "res://scenes/world/FourWindsBar.tscn")


func test_add_enemy_appends_to_enemies_array() -> void:
	var count_before: int = _scene.enemies.size()
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	_scene.add_enemy(enforcer)
	assert_eq(_scene.enemies.size(), count_before + 1, "add_enemy must append to enemies array")
	assert_eq(_scene.enemies.back().character_name, "Territory Enforcer")


func test_add_enemy_adds_sprite_to_enemy_container() -> void:
	var container: Node2D = _scene.get_node("EnemyContainer")
	var sprites_before: int = container.get_child_count()
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	_scene.add_enemy(captain)
	assert_eq(container.get_child_count(), sprites_before + 1,
		"add_enemy must add a sprite to EnemyContainer")


func test_call_backup_adds_captain_when_enemies_outnumbered() -> void:
	# Party: Reid + Iris (2 living). Enemy: 1 Enforcer. → Call Backup fires, spawns Captain.
	PartyManager._temporary_members.clear()
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_member(iris)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	scene2.enemies.clear()
	scene2.enemies.append(enforcer)
	var count_before: int = scene2.enemies.size()
	scene2._resolve_enemy_action(enforcer)
	assert_eq(scene2.enemies.size(), count_before + 1,
		"Call Backup must add one enemy when enemies < living party")
	assert_eq(scene2.enemies.back().character_name, "Block Captain",
		"Call Backup must spawn the Block Captain, not another Enforcer")


func test_call_backup_only_fires_once_per_enforcer() -> void:
	# Second call when already outnumbered should not spawn a second captain.
	PartyManager._temporary_members.clear()
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_member(iris)
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	scene2.enemies.clear()
	scene2.enemies.append(enforcer)
	scene2._resolve_enemy_action(enforcer)
	var count_after_first: int = scene2.enemies.size()
	scene2._resolve_enemy_action(enforcer)
	assert_eq(scene2.enemies.size(), count_after_first,
		"Call Backup must not fire a second time for the same Enforcer")


func test_call_backup_not_called_when_enemies_equal_party() -> void:
	# Party: 1 Reid. Enemies: 1 Enforcer. → no backup.
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	_scene.enemies.clear()
	_scene.enemies.append(enforcer)
	var count_before: int = _scene.enemies.size()
	_scene._resolve_enemy_action(enforcer)
	assert_eq(_scene.enemies.size(), count_before,
		"Call Backup must not fire when enemy count >= living party count")


func test_enforcer_shakedown_deals_damage_when_not_outnumbered() -> void:
	var reid: Combatant = _scene.party[0]
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	_scene.enemies.clear()
	_scene.enemies.append(enforcer)
	var hp_before: int = reid.current_hp
	_scene._resolve_enemy_action(enforcer)
	assert_lt(reid.current_hp, hp_before,
		"Shakedown must deal damage to a party member when enemies >= living party")


func test_resolve_enemy_action_default_attacks_party() -> void:
	# Shade (default path) must still deal damage
	var shade: Combatant = _scene.enemies[0]
	var reid: Combatant = _scene.party[0]
	var hp_before: int = reid.current_hp
	_scene._resolve_enemy_action(shade)
	assert_lt(reid.current_hp, hp_before,
		"Default enemy (Shade) must attack a party member via _resolve_enemy_action")


# --- Captain AI tests ---

func _make_captain_scene() -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager._permanent_members.append(reid)
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	s.enemies.clear()
	s.enemies.append(captain)
	return s


func test_captain_hold_the_line_buffs_enemy_def() -> void:
	var s := _make_captain_scene()
	var captain: Combatant = s.enemies[0]
	var def_before := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
	s._resolve_enemy_action(captain)
	assert_gt(captain.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
		"Hold the Line must raise Captain's effective DEF")


func test_captain_hold_the_line_not_repeated_while_active() -> void:
	var s := _make_captain_scene()
	var captain: Combatant = s.enemies[0]
	# First action: Hold the Line fires
	s._resolve_enemy_action(captain)
	# Second action: Hold the Line is already active → goes to Mark Target path
	s._resolve_enemy_action(captain)
	# Party member should be marked now (no mark existed before)
	var reid: Combatant = s.party[0]
	var marked := reid.active_effects.any(func(ef: StatusEffect) -> bool:
		return ef.effect_name == "mark_target")
	assert_true(marked,
		"Captain must use Mark Target on second action when Hold the Line is already active")


func test_captain_mark_target_applies_def_debuff() -> void:
	var s := _make_captain_scene()
	var captain: Combatant = s.enemies[0]
	# Seed Hold the Line so it's already active
	var htl := StatusEffect.new()
	htl.effect_name = "hold_the_line"
	htl.stat = StatusEffect.StatAxis.DEF
	htl.modifier = 8
	htl.duration = 2
	captain.apply_effect(htl)
	var reid: Combatant = s.party[0]
	var def_before := reid.get_effective_stat(StatusEffect.StatAxis.DEF)
	s._resolve_enemy_action(captain)
	assert_lt(reid.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
		"Mark Target must lower the target party member's effective DEF")


func test_captain_heavy_strike_when_both_active() -> void:
	var s := _make_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	# Seed Hold the Line (active) and Mark Target (active on Reid)
	var htl := StatusEffect.new()
	htl.effect_name = "hold_the_line"
	htl.stat = StatusEffect.StatAxis.DEF
	htl.modifier = 8
	htl.duration = 2
	captain.apply_effect(htl)
	var mark := StatusEffect.new()
	mark.effect_name = "mark_target"
	mark.stat = StatusEffect.StatAxis.DEF
	mark.modifier = -6
	mark.duration = 99
	reid.apply_effect(mark)
	var hp_before: int = reid.current_hp
	s._resolve_enemy_action(captain)
	assert_lt(reid.current_hp, hp_before,
		"Captain must use Heavy Strike when both Hold the Line and Mark Target are already active")


func test_hold_the_line_raises_effective_def_during_combat() -> void:
	# AC1: attacks during Hold the Line window deal less damage
	var s := _make_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	var def_no_buff := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
	# Apply Hold the Line
	var htl := StatusEffect.new()
	htl.effect_name = "hold_the_line"
	htl.stat = StatusEffect.StatAxis.DEF
	htl.modifier = 8
	htl.duration = 2
	captain.apply_effect(htl)
	var def_with_buff := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
	assert_gt(def_with_buff, def_no_buff,
		"Hold the Line must increase effective DEF above base")
	# Damage from Reid against buffed Captain must be lower
	# Use a zero-def combatant as baseline for unbuffed comparison
	var d_zero := CombatantDefinition.new()
	var unbuffed_target := Combatant.from_definition(d_zero)
	for _i in range(50):
		var dmg_buffed := Combatant.calculate_damage(reid, captain)
		captain.current_hp = captain.max_hp  # reset so we can sample repeatedly
		assert_lte(dmg_buffed, Combatant.calculate_damage(reid, unbuffed_target) + 1,
			"damage against buffed enemy must be lower than against unbuffed")


func test_end_turn_ticks_active_combatant_effects() -> void:
	var reid: Combatant = _scene.party[0]
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 2
	reid.apply_effect(effect)
	_scene._active = reid
	_scene._end_turn()
	assert_eq(reid.active_effects[0].duration, 1,
		"effect duration must decrement by 1 when _end_turn is called")


func test_end_turn_removes_expired_effects() -> void:
	var reid: Combatant = _scene.party[0]
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 1
	reid.apply_effect(effect)
	_scene._active = reid
	_scene._end_turn()
	assert_eq(reid.active_effects.size(), 0,
		"expired effect must be removed when _end_turn is called")


func test_enemy_attack_without_interrupting_ticks_effects() -> void:
	var shade: Combatant = _scene.enemies[0]
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 2
	shade.apply_effect(effect)
	_scene._enemy_attack_without_interrupting(shade)
	assert_eq(shade.active_effects[0].duration, 1,
		"enemy effect must tick after _enemy_attack_without_interrupting")


func test_shade_ai_delegates_to_resource() -> void:
	var shade: Combatant = _scene.enemies[0]
	assert_not_null(shade.ai, "Shade must have an ai resource set in its .tres")


func _make_security_captain_scene() -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager._permanent_members.append(reid)
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/security_captain.tres"))
	s.enemies.clear()
	s.enemies.append(captain)
	return s


func test_security_captain_authorised_force_applies_def_debuff() -> void:
	var s := _make_security_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	var def_before := reid.get_effective_stat(StatusEffect.StatAxis.DEF)
	s._resolve_enemy_action(captain)
	assert_lt(reid.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
		"Authorised Force must apply DEF debuff to a party member on first action")


func test_security_captain_uses_override_on_subsequent_turns() -> void:
	var s := _make_security_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	s._resolve_enemy_action(captain)
	var hp_before := reid.current_hp
	s._resolve_enemy_action(captain)
	assert_lt(reid.current_hp, hp_before,
		"Security Captain must deal damage (Override) on turn 2+")


func test_security_captain_authorised_force_not_reapplied() -> void:
	var s := _make_security_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	s._resolve_enemy_action(captain)
	var effects_after_first := reid.active_effects.size()
	s._resolve_enemy_action(captain)
	assert_eq(reid.active_effects.size(), effects_after_first,
		"Authorised Force must not reapply on second or later actions")


func test_authorised_force_debuff_expires_after_2_turns() -> void:
	var s := _make_security_captain_scene()
	var captain: Combatant = s.enemies[0]
	var reid: Combatant = s.party[0]
	s._resolve_enemy_action(captain)
	assert_lt(reid.get_effective_stat(StatusEffect.StatAxis.DEF), reid.def_stat,
		"DEF must be debuffed after Authorised Force")
	reid.tick_effects()
	reid.tick_effects()
	assert_eq(reid.get_effective_stat(StatusEffect.StatAxis.DEF), reid.def_stat,
		"DEF must return to base after 2 tick_effects calls")


func test_spawn_enemies_defaults_to_one_shade_when_params_empty() -> void:
	assert_eq(_scene.enemies.size(), 1, "default spawn must produce exactly 1 enemy")
	assert_eq(_scene.enemies[0].character_name, "Shade",
		"default enemy must be a Shade when BattleContext.enemies is empty")


func test_spawn_enemies_uses_context_enemies_when_set() -> void:
	BattleContext.enemies = "territory_enforcer,territory_enforcer"
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(scene2.enemies.size(), 2,
		"must spawn 2 enemies when BattleContext.enemies has 2 ids")
	assert_eq(scene2.enemies[0].character_name, "Territory Enforcer")
	assert_eq(scene2.enemies[1].character_name, "Territory Enforcer")


func test_spawn_enemies_does_not_clear_context_enemies() -> void:
	BattleContext.enemies = "territory_enforcer"
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(BattleContext.enemies, "territory_enforcer",
		"BattleContext.enemies must survive a read so defeat→retry reuses it (AC2)")


func test_ability_uses_effects_data_not_character_name() -> void:
	# Reid with his piercing effect removed deals no ability damage,
	# proving _resolve_ability reads effects (data), not character_name.
	# Save and restore effects to avoid polluting the shared CharacterDefinition
	# cache (ability is a getter that returns def.ability directly — no setter).
	var reid: Combatant = _scene.party[0]
	var saved_effects := reid.ability.effects.duplicate()
	reid.ability.effects = []
	var shade: Combatant = _scene.enemies[0]
	var hp_before := shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	_scene.confirm_enemy_target()
	await wait_for_signal(_scene.player_turn_ended, 2.0)
	reid.ability.effects = saved_effects
	assert_eq(shade.current_hp, hp_before,
		"with no DamageEffect, ability deals no damage — dispatch is data-driven, not name-driven")


# --- SELF target_mode ---

func _make_scene_with_self_buffer() -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(
		Combatant.from_definition(load("res://tests/fixtures/test_self_buffer.tres")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s


func test_self_buff_ability_applies_to_caster() -> void:
	# A SELF ability (status on self) resolves with no target picker.
	var s := _make_scene_with_self_buffer()
	var caster: Combatant = s.party[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_true(caster.active_effects.any(func(e): return e.effect_name == "guard"),
		"SELF ability must apply its status to the caster with no selection step")


func test_build_victory_text_no_levelups() -> void:
	var text := BattleScene.build_victory_text(36, [])
	assert_eq(text, "Victory!\nGained 36 XP")


func test_build_victory_text_with_levelup() -> void:
	var text := BattleScene.build_victory_text(40, [{"name": "Reid", "to": 2}])
	assert_eq(text, "Victory!\nGained 40 XP\nReid reached Lv 2!")


func test_build_victory_text_multiple_levelups() -> void:
	var text := BattleScene.build_victory_text(105,
		[{"name": "Reid", "to": 2}, {"name": "Iris", "to": 2}])
	assert_eq(text,
		"Victory!\nGained 105 XP\nReid reached Lv 2!\nIris reached Lv 2!")
