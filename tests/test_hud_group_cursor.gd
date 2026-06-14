extends GutTest

# Instantiate the real BattleScene so HUD.setup wires the signals, then assert
# every enemy panel's cursor lights when the group-target signal fires.
func _scene() -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

func test_enemy_group_signal_lights_all_enemy_cursors() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_group_target_changed.emit(true)
	var rows := s.get_node("UI/HUD/EnemyWindow/EnemyRows")
	for row in rows.get_children():
		if row.has_node("CursorLabel"):
			assert_almost_eq(row.get_node("CursorLabel").modulate.a, 1.0, 0.01,
				"every enemy cursor must light under group targeting")

func test_enemy_group_signal_clears_all_enemy_cursors() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_group_target_changed.emit(true)
	s.enemy_group_target_changed.emit(false)
	var rows := s.get_node("UI/HUD/EnemyWindow/EnemyRows")
	for row in rows.get_children():
		if row.has_node("CursorLabel"):
			assert_almost_eq(row.get_node("CursorLabel").modulate.a, 0.0, 0.01,
				"clearing group targeting must dim every enemy cursor")

func test_party_group_signal_lights_party_cursor() -> void:
	var s := _scene()
	await wait_frames(2)
	s.party_group_target_changed.emit(true)
	var rows := s.get_node("UI/HUD/PartyWindow/PartyRows")
	assert_almost_eq(rows.get_child(0).get_node("CursorLabel").modulate.a, 1.0, 0.01,
		"living party member's cursor must light under group targeting")
