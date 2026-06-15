extends GutTest

const AOE_CASTER := "res://tests/fixtures/test_aoe_caster.tres"   # ALL_ENEMIES damage
const AOE_HEALER := "res://tests/fixtures/test_aoe_healer.tres"   # ALL_ALLIES heal

func _scene_with(caster_path: String, enemy_ids: Array) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = ",".join(PackedStringArray(enemy_ids))
	PartyManager._permanent_members.append(Combatant.from_definition(load(caster_path)))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s


func test_all_enemies_damages_every_living_enemy() -> void:
	var s := _scene_with(AOE_CASTER, ["shade", "shade"])
	var caster: Combatant = s.party[0]
	var hp_before: Array = s.enemies.map(func(e): return e.current_hp)
	s._begin_player_turn(caster)
	s.execute_action("ability")          # ALL_ENEMIES -> group selection
	s.confirm_enemy_target()             # confirm the group
	await wait_for_signal(s.player_turn_ended, 3.0)
	for i in range(s.enemies.size()):
		assert_lt(s.enemies[i].current_hp, hp_before[i],
			"every living enemy must take AoE damage")


func test_all_enemies_sets_target_all_on_targeting() -> void:
	var s := _scene_with(AOE_CASTER, ["shade", "shade"])
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")
	assert_true(s._target_all,
		"a fixed ALL_ENEMIES ability must enter group targeting (_target_all)")
	assert_eq(s._state, s.BattleState.SELECTING_ENEMY)


func test_all_allies_heals_every_living_ally() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(Combatant.from_definition(load(AOE_HEALER)))
	PartyManager.add_temporary(Combatant.from_definition(load("res://characters/reid.tres")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	var caster: Combatant = s.party[0]
	for p in s.party:
		p.current_hp = 1
	var hp_before: Array = s.party.map(func(p): return p.current_hp)
	s._begin_player_turn(caster)
	s.execute_action("ability")          # ALL_ALLIES -> party group targeting
	s.confirm_party_target(s.party[0])   # ALL_ALLIES ignores the pick, heals all
	for i in range(s.party.size()):
		assert_gt(s.party[i].current_hp, hp_before[i],
			"every living ally must be healed by the AoE heal")


func test_all_allies_sets_target_all_on_targeting() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(Combatant.from_definition(load(AOE_HEALER)))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")
	assert_true(s._target_all,
		"a fixed ALL_ALLIES ability must enter group targeting (_target_all)")
	assert_eq(s._state, s.BattleState.SELECTING_ALLY)
