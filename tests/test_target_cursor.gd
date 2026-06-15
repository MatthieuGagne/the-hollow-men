extends GutTest

# The targeting cursor is a finger rendered on the target sprite (FF-style),
# tracked in BattleScene._target_cursors — not the HUD name list.
func _scene(enemy_ids := ["shade", "shade"]) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = ",".join(PackedStringArray(enemy_ids))
	PartyManager._permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s


func test_single_enemy_target_places_one_finger() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_target_changed.emit(s.enemies[0])
	assert_eq(s._target_cursors.size(), 1, "a single enemy target shows exactly one finger")


func test_single_finger_sits_on_targeted_sprite() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_target_changed.emit(s.enemies[1])
	var container: Node2D = s.get_node("EnemyContainer")
	var sprite: Node2D = container.get_child(1)
	var expected: Vector2 = container.position + sprite.position + BattleScene.TARGET_CURSOR_OFFSET
	assert_almost_eq(s._target_cursors[0].position.y, expected.y, 0.01,
		"the finger must line up with the targeted enemy's sprite")


func test_enemy_group_target_places_finger_per_living_enemy() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_group_target_changed.emit(true)
	assert_eq(s._target_cursors.size(), s.enemies.size(),
		"group targeting shows a finger on every living enemy")


func test_clearing_enemy_target_removes_fingers() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_target_changed.emit(s.enemies[0])
	s.enemy_target_changed.emit(null)
	assert_eq(s._target_cursors.size(), 0, "clearing the target removes the finger")


func test_party_group_target_places_finger_per_living_ally() -> void:
	var s := _scene()
	await wait_frames(2)
	s.party_group_target_changed.emit(true)
	var living := 0
	for p in s.party:
		if p.is_alive():
			living += 1
	assert_eq(s._target_cursors.size(), living,
		"party group targeting shows a finger on every living ally")
