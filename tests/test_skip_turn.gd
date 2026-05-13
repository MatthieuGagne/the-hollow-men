extends GutTest

var _scene: Node2D
var _hud: Control


func before_each() -> void:
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)
	_hud = _scene.get_node("UI/HUD")


func test_cursor_hidden_at_start() -> void:
	for i in range(_scene.party.size()):
		var panel: Control = _hud._panels[i]
		var cursor: Label = panel.get_node("CursorLabel")
		assert_false(cursor.visible, "cursor must be hidden at battle start")


func test_cursor_visible_on_player_turn_started() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	await get_tree().process_frame
	var panel: Control = _hud._panels[0]
	var cursor: Label = panel.get_node("CursorLabel")
	assert_true(cursor.visible, "cursor must be visible during AWAITING_INPUT")


func test_cursor_hidden_on_player_turn_ended() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	await get_tree().process_frame
	_scene.execute_action("attack")
	await get_tree().process_frame
	var panel: Control = _hud._panels[0]
	var cursor: Label = panel.get_node("CursorLabel")
	assert_false(cursor.visible, "cursor must be hidden after turn ends")


func test_cursor_hidden_on_skip() -> void:
	var reid: Combatant = _scene.party[0]
	reid.atb = Combatant.ATB_MAX
	_scene._begin_player_turn(reid)
	await get_tree().process_frame
	_scene.skip_turn()
	await get_tree().process_frame
	var panel: Control = _hud._panels[0]
	var cursor: Label = panel.get_node("CursorLabel")
	assert_false(cursor.visible, "cursor must be hidden after skip")


func test_only_active_combatant_cursor_visible() -> void:
	var iris: Combatant = _scene.party[1]
	_scene._begin_player_turn(iris)
	await get_tree().process_frame
	var reid_panel: Control = _hud._panels[0]
	var iris_panel: Control = _hud._panels[1]
	assert_false(reid_panel.get_node("CursorLabel").visible, "Reid cursor must be hidden")
	assert_true(iris_panel.get_node("CursorLabel").visible, "Iris cursor must be visible")
