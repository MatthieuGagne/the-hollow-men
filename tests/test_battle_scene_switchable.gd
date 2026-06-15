extends GutTest

const SWITCH_CASTER := "res://tests/fixtures/test_switch_caster.tres"  # ONE_ENEMY, switchable

func _scene(enemy_ids: Array) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = ",".join(PackedStringArray(enemy_ids))
	PartyManager._permanent_members.append(Combatant.from_definition(load(SWITCH_CASTER)))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s


func test_toggle_to_all_hits_every_enemy() -> void:
	var s := _scene(["shade", "shade"])
	var caster: Combatant = s.party[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")     # enters SELECTING_ENEMY, single
	s.expand_target_to_all()        # simulate push toward enemy side
	assert_true(s._target_all, "pushing toward the enemy group must expand to all")
	var hp_before: Array = s.enemies.map(func(e): return e.current_hp)
	s.confirm_enemy_target()
	await wait_for_signal(s.player_turn_ended, 3.0)
	for i in range(s.enemies.size()):
		assert_lt(s.enemies[i].current_hp, hp_before[i], "expanded cast must hit all enemies")


func test_collapse_back_to_single() -> void:
	var s := _scene(["shade", "shade"])
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")
	s.expand_target_to_all()
	s.collapse_target_to_single()
	assert_false(s._target_all, "pushing back must collapse to single")


func test_single_cast_hits_only_one_enemy() -> void:
	var s := _scene(["shade", "shade"])
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")     # single by default (not expanded)
	var hp_before: Array = s.enemies.map(func(e): return e.current_hp)
	s.confirm_enemy_target()        # targets the highlighted single enemy
	await wait_for_signal(s.player_turn_ended, 3.0)
	var hit := 0
	for i in range(s.enemies.size()):
		if s.enemies[i].current_hp < hp_before[i]:
			hit += 1
	assert_eq(hit, 1, "a non-expanded switchable cast must hit exactly one enemy")


func test_switchable_heal_single_then_expanded_heals_all() -> void:
	# A switchable ONE_ALLY heal: single by default, expands to the whole party.
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(
		Combatant.from_definition(load("res://tests/fixtures/test_switch_healer.tres")))
	PartyManager.add_temporary(Combatant.from_definition(load("res://characters/reid.tres")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	for p in s.party:
		p.current_hp = 1
	var hp_before: Array = s.party.map(func(p): return p.current_hp)
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")     # ONE_ALLY switchable -> SELECTING_ALLY, single
	assert_false(s._target_all, "switchable heal starts single")
	s.expand_target_to_all()        # push toward the party group
	assert_true(s._target_all, "switchable heal must expand to the whole party")
	s.confirm_party_target(s.party[0])
	for i in range(s.party.size()):
		assert_gt(s.party[i].current_hp, hp_before[i], "expanded heal must restore every ally")


func test_expand_noop_for_non_switchable() -> void:
	# Reid's ability is ONE_ENEMY but NOT switchable — expand must be ignored.
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = "shade,shade"
	PartyManager._permanent_members.append(
		Combatant.from_definition(load("res://characters/reid.tres")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")
	s.expand_target_to_all()
	assert_false(s._target_all, "non-switchable ability must not expand to all")
