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
	assert_false(_scene._enemy_window.visible, "EnemyWindow should be hidden during AWAITING_INPUT")


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
