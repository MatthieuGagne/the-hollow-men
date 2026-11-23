extends GutTest


func _make_combatant(hp: int = 100, pp: int = 50) -> Combatant:
	var d := CombatantDefinition.new()
	d.max_hp = hp
	d.max_pp = pp
	return Combatant.from_definition(d)


func _make_combatant_with_stats(str_: int = 10, def_: int = 10, psy: int = 10,
		res: int = 10, spd: int = 10) -> Combatant:
	var d := CombatantDefinition.new()
	d.str_stat = str_
	d.def_stat = def_
	d.psy_stat = psy
	d.res_stat = res
	d.spd_stat = spd
	return Combatant.from_definition(d)


func test_reset_runtime_state_restores_hp_and_pp() -> void:
	var c := _make_combatant(100, 50)
	c.current_hp = 0
	c.current_pp = 0
	c.atb = 99.0
	c.limit_gauge = 50.0
	c.reset_runtime_state()
	assert_eq(c.current_hp, 100)
	assert_eq(c.current_pp, 50)
	assert_eq(c.atb, 0.0)
	assert_eq(c.limit_gauge, 0.0)


func test_reid_loads_with_correct_stats() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	assert_eq(reid.character_name, "Reid")
	assert_eq(reid.max_hp, 350)
	assert_eq(reid.max_pp, 0, "Reid pays HP, never PP")
	assert_eq(reid.spd_stat, 30)
	assert_almost_eq((reid.def as CharacterDefinition).atb_desperation, 1.0, 0.0001,
		"Reid's gauge accelerates as he loses HP")
	assert_eq(reid.current_hp, 350)
	assert_true(reid.is_player_controlled)


func test_iris_loads_with_correct_stats() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	assert_eq(iris.character_name, "Iris")
	assert_eq(iris.max_hp, 270)
	assert_eq(iris.spd_stat, 50)
	assert_eq(iris.current_hp, 270)
	assert_true(iris.is_player_controlled)


func test_shade_loads_with_correct_stats() -> void:
	var shade: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	assert_eq(shade.character_name, "Shade")
	assert_eq(shade.max_hp, 200)
	assert_eq(shade.spd_stat, 25)
	assert_false(shade.is_player_controlled)


func test_tick_atb_proportional_to_spd() -> void:
	var fast := _make_combatant_with_stats(10, 10, 10, 10, 50)
	var slow := _make_combatant_with_stats(10, 10, 10, 10, 25)

	fast.tick_atb(0.1)
	slow.tick_atb(0.1)

	assert_gt(fast.atb, slow.atb)


func test_calculate_damage_within_expected_range() -> void:
	# Reid STR=45 vs Shade DEF=15 → floor(30 * [0.9,1.1]) → [27,33]
	var attacker := _make_combatant_with_stats(45, 0)
	var target := _make_combatant_with_stats(0, 15)
	for _i in range(200):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 27, "damage below minimum expected")
		assert_lte(dmg, 33, "damage above maximum expected")


func test_calculate_damage_minimum_one() -> void:
	var attacker := _make_combatant_with_stats(5, 0)
	var target := _make_combatant_with_stats(0, 100)
	for _i in range(50):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 1, "damage must never be below 1")


func test_atb_fills_between_6_and_8_seconds_at_base_speed() -> void:
	var d := CombatantDefinition.new()
	d.spd_stat = 10
	var c := Combatant.from_definition(d)

	c.tick_atb(6.0)
	assert_lt(c.atb, Combatant.ATB_MAX, "ATB should not be full after 6 seconds")

	c.tick_atb(2.0)
	assert_gte(c.atb, Combatant.ATB_MAX, "ATB must be full after 8 seconds at base speed")


func test_is_alive_returns_true_when_hp_positive() -> void:
	var c := _make_combatant(100)
	assert_true(c.is_alive())


func test_is_alive_returns_false_when_hp_zero() -> void:
	var c := _make_combatant(100)
	c.current_hp = 0
	assert_false(c.is_alive())


func test_tick_atb_skips_downed_combatant() -> void:
	var d := CombatantDefinition.new()
	d.spd_stat = 50
	d.max_hp = 100
	var c := Combatant.from_definition(d)
	c.current_hp = 0
	var atb_before: float = c.atb
	c.tick_atb(1.0)
	assert_eq(c.atb, atb_before, "dead combatant ATB must not advance")


func test_atb_fill_multiplier_is_one_by_default() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	var c := Combatant.from_definition(d)
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001,
		"Characters fill at base rate unless configured otherwise")


func test_atb_fill_multiplier_scales_with_missing_hp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.atb_desperation = 1.0
	var c := Combatant.from_definition(d)
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001, "Full HP means no bonus")
	c.current_hp = 25
	assert_almost_eq(c.atb_fill_multiplier(), 1.75, 0.001,
		"75% missing HP at desperation 1.0 means a 1.75x fill rate")


func test_atb_fill_multiplier_never_drops_below_one_when_hp_exceeds_max() -> void:
	# A save restored against a retuned-down max_hp can leave current_hp above
	# max_hp. hp_ratio() then exceeds 1.0; the gauge must not run slower.
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.atb_desperation = 1.0
	var c := Combatant.from_definition(d)
	c.current_hp = 150
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001,
		"HP above max must yield exactly the baseline multiplier, never less")


func test_atb_fill_multiplier_is_one_for_enemies() -> void:
	var e := EnemyDefinition.new()
	e.max_hp = 100
	var c := Combatant.from_definition(e)
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001,
		"Enemies have no CharacterDefinition, so they never accelerate")


func test_tick_atb_honours_the_multiplier() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.spd_stat = 10
	d.atb_desperation = 1.0
	var fast := Combatant.from_definition(d)
	fast.current_hp = 25
	var slow := Combatant.from_definition(d)

	fast.tick_atb(0.1)
	slow.tick_atb(0.1)
	assert_gt(fast.atb, slow.atb,
		"The wounded combatant must gain more ATB over the same delta")


func test_skip_cooldown_initial_value_is_zero() -> void:
	var c := _make_combatant()
	assert_eq(c.skip_cooldown, 0.0)


func test_reset_runtime_state_clears_skip_cooldown() -> void:
	var c := _make_combatant()
	c.skip_cooldown = 3.5
	c.reset_runtime_state()
	assert_eq(c.skip_cooldown, 0.0)


func test_is_skipping_true_when_cooldown_positive() -> void:
	var c := _make_combatant()
	c.skip_cooldown = 1.0
	assert_true(c.is_skipping())


func test_is_skipping_false_when_cooldown_zero() -> void:
	var c := _make_combatant()
	c.skip_cooldown = 0.0
	assert_false(c.is_skipping())


func test_ability_target_mode_defaults_one_enemy() -> void:
	var ab := Ability.new()
	assert_eq(ab.target_mode, Ability.TargetMode.ONE_ENEMY,
		"target_mode must default to ONE_ENEMY")


func test_heal_increases_hp() -> void:
	var c := _make_combatant(100)
	c.current_hp = 40
	c.heal(30)
	assert_eq(c.current_hp, 70)


func test_heal_caps_at_max_hp() -> void:
	var c := _make_combatant(100)
	c.current_hp = 90
	c.heal(60)
	assert_eq(c.current_hp, 100)


func test_heal_exact_max() -> void:
	var c := _make_combatant(100)
	c.heal(9999)
	assert_eq(c.current_hp, 100)


func test_karim_loads_with_correct_stats() -> void:
	var karim: Combatant = Combatant.from_definition(load("res://characters/karim.tres"))
	assert_eq(karim.character_name, "Karim")
	assert_eq(karim.max_hp, 310)
	assert_eq(karim.max_pp, 70)
	assert_eq(karim.spd_stat, 22)
	assert_true(karim.is_player_controlled)
	assert_eq(karim.abilities[0].ability_name, "Field Suture")
	assert_eq(karim.abilities[0].pp_cost, 10)
	assert_eq(karim.abilities[0].target_mode, Ability.TargetMode.ONE_ALLY)


func test_margot_loads_with_correct_stats() -> void:
	var margot: Combatant = Combatant.from_definition(load("res://characters/margot.tres"))
	assert_eq(margot.character_name, "Margot")
	assert_eq(margot.max_hp, 240)
	assert_eq(margot.max_pp, 90)
	assert_eq(margot.spd_stat, 40)
	assert_true(margot.is_player_controlled)
	assert_eq(margot.abilities[0].ability_name, "Void Calculus")
	assert_eq(margot.abilities[0].pp_cost, 15)
	assert_eq(margot.abilities[0].target_mode, Ability.TargetMode.ONE_ENEMY)


func test_status_effect_fields_have_correct_defaults() -> void:
	var effect := StatusEffect.new()
	assert_eq(effect.effect_name, "")
	assert_eq(effect.modifier, 0)
	assert_eq(effect.duration, 0)


func test_status_effect_stat_axis_has_all_axes() -> void:
	assert_ne(StatusEffect.StatAxis.DEF, StatusEffect.StatAxis.STR)
	assert_ne(StatusEffect.StatAxis.PSY, StatusEffect.StatAxis.RES)
	assert_ne(StatusEffect.StatAxis.SPD, StatusEffect.StatAxis.HP)


func test_apply_effect_adds_to_active_effects() -> void:
	var c := _make_combatant()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	assert_eq(c.active_effects.size(), 1)


func test_apply_effect_reapply_refreshes_duration_not_stacks() -> void:
	var c := _make_combatant()
	var e1 := StatusEffect.new()
	e1.effect_name = "hold_the_line"
	e1.stat = StatusEffect.StatAxis.DEF
	e1.modifier = 8
	e1.duration = 1
	c.apply_effect(e1)
	var e2 := StatusEffect.new()
	e2.effect_name = "hold_the_line"
	e2.stat = StatusEffect.StatAxis.DEF
	e2.modifier = 8
	e2.duration = 2
	c.apply_effect(e2)
	assert_eq(c.active_effects.size(), 1, "reapply must not stack a second instance")
	assert_eq(c.active_effects[0].duration, 2, "reapply must refresh duration to new value")


func test_reset_runtime_state_clears_active_effects() -> void:
	var c := _make_combatant()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.duration = 2
	c.apply_effect(effect)
	c.reset_runtime_state()
	assert_eq(c.active_effects.size(), 0, "reset_runtime_state must clear active effects")


func test_tick_effects_decrements_duration() -> void:
	var c := _make_combatant()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 3
	c.apply_effect(effect)
	c.tick_effects()
	assert_eq(c.active_effects[0].duration, 2, "duration must decrement by 1 per tick")


func test_tick_effects_removes_expired_effect() -> void:
	var c := _make_combatant()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 1
	c.apply_effect(effect)
	c.tick_effects()
	assert_eq(c.active_effects.size(), 0, "expired effect must be removed after tick")


func test_tick_effects_only_removes_expired_leaves_others() -> void:
	var c := _make_combatant()
	var short := StatusEffect.new()
	short.effect_name = "short"
	short.stat = StatusEffect.StatAxis.DEF
	short.modifier = 1
	short.duration = 1
	var long_eff := StatusEffect.new()
	long_eff.effect_name = "long"
	long_eff.stat = StatusEffect.StatAxis.STR
	long_eff.modifier = 2
	long_eff.duration = 3
	c.apply_effect(short)
	c.apply_effect(long_eff)
	c.tick_effects()
	assert_eq(c.active_effects.size(), 1, "only expired effects must be removed")
	assert_eq(c.active_effects[0].effect_name, "long")


func test_get_effective_stat_no_effects_returns_base() -> void:
	var d := CombatantDefinition.new()
	d.def_stat = 10
	var c := Combatant.from_definition(d)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 10)


func test_get_effective_stat_with_buff() -> void:
	var d := CombatantDefinition.new()
	d.def_stat = 10
	var c := Combatant.from_definition(d)
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 18)


func test_get_effective_stat_with_debuff() -> void:
	var d := CombatantDefinition.new()
	d.def_stat = 10
	var c := Combatant.from_definition(d)
	var effect := StatusEffect.new()
	effect.effect_name = "mark_target"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -6
	effect.duration = 99
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 4)


func test_get_effective_stat_clamps_at_zero() -> void:
	var d := CombatantDefinition.new()
	d.def_stat = 5
	var c := Combatant.from_definition(d)
	var effect := StatusEffect.new()
	effect.effect_name = "mark_target"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -20
	effect.duration = 99
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0, "effective stat must clamp at 0")


func test_take_damage_clears_mark_target() -> void:
	var c := _make_combatant(100)
	var effect := StatusEffect.new()
	effect.effect_name = "mark_target"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -6
	effect.duration = 99
	c.apply_effect(effect)
	assert_eq(c.active_effects.size(), 1)
	c.take_damage(10)
	assert_eq(c.active_effects.size(), 0, "mark_target must be cleared on first hit")


func test_take_damage_does_not_clear_other_effects() -> void:
	var c := _make_combatant(100)
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	c.take_damage(10)
	assert_eq(c.active_effects.size(), 1, "take_damage must not clear non-mark_target effects")


func test_calculate_damage_uses_effective_stats() -> void:
	var ad := CombatantDefinition.new()
	ad.str_stat = 40
	var attacker := Combatant.from_definition(ad)
	var td := CombatantDefinition.new()
	td.def_stat = 10
	var target := Combatant.from_definition(td)
	var buff := StatusEffect.new()
	buff.effect_name = "hold_the_line"
	buff.stat = StatusEffect.StatAxis.DEF
	buff.modifier = 20
	buff.duration = 2
	target.apply_effect(buff)
	for _i in range(100):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 9, "buffed DEF must reduce incoming damage (min)")
		assert_lte(dmg, 11, "buffed DEF must reduce incoming damage (max)")


func test_calculate_damage_mark_target_increases_damage() -> void:
	var ad := CombatantDefinition.new()
	ad.str_stat = 40
	var attacker := Combatant.from_definition(ad)
	var td := CombatantDefinition.new()
	td.def_stat = 10
	var target := Combatant.from_definition(td)
	var debuff := StatusEffect.new()
	debuff.effect_name = "mark_target"
	debuff.stat = StatusEffect.StatAxis.DEF
	debuff.modifier = -6
	debuff.duration = 99
	target.apply_effect(debuff)
	for _i in range(100):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 32, "marked DEF must increase incoming damage (min)")
		assert_lte(dmg, 40, "marked DEF must increase incoming damage (max)")


func test_territory_enforcer_loads_with_correct_stats() -> void:
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	assert_eq(enforcer.character_name, "Territory Enforcer")
	assert_false(enforcer.is_player_controlled)
	assert_eq(enforcer.max_hp, 150)
	assert_eq(enforcer.str_stat, 35)
	assert_eq(enforcer.def_stat, 10)
	assert_eq(enforcer.spd_stat, 20)
	assert_eq(enforcer.current_hp, 150)


func test_block_captain_loads_with_correct_stats() -> void:
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	assert_eq(captain.character_name, "Block Captain")
	assert_false(captain.is_player_controlled)
	assert_eq(captain.max_hp, 200)
	assert_eq(captain.str_stat, 35)
	assert_eq(captain.def_stat, 15)
	assert_eq(captain.spd_stat, 15)
	assert_eq(captain.current_hp, 200)


func test_combatant_ai_state_defaults_empty() -> void:
	var c := _make_combatant()
	assert_eq(c.ai_state, {}, "ai_state must be empty dict by default")


func test_reset_runtime_state_clears_ai_state() -> void:
	var c := _make_combatant()
	c.ai_state["foo"] = true
	c.reset_runtime_state()
	assert_eq(c.ai_state, {}, "reset_runtime_state must clear ai_state")


func test_combatant_ai_defaults_null_for_character() -> void:
	var d := CharacterDefinition.new()
	var c := Combatant.from_definition(d)
	assert_null(c.ai, "ai must be null for CharacterDefinition combatant")


func test_shade_has_ai() -> void:
	var shade: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	assert_not_null(shade.ai, "Shade must have an ai resource")


func test_territory_enforcer_has_ai() -> void:
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	assert_not_null(enforcer.ai, "Territory Enforcer must have an ai resource")


func test_block_captain_has_ai() -> void:
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	assert_not_null(captain.ai, "Block Captain must have an ai resource")


func test_private_security_guard_loads_with_correct_stats() -> void:
	var guard: Combatant = Combatant.from_definition(load("res://characters/enemies/private_security_guard.tres"))
	assert_eq(guard.character_name, "Private Security Guard")
	assert_false(guard.is_player_controlled)
	assert_eq(guard.max_hp, 150)
	assert_eq(guard.str_stat, 40)
	assert_eq(guard.def_stat, 28)
	assert_eq(guard.spd_stat, 32)
	assert_not_null(guard.ai, "Guard must have an ai resource")


func test_security_captain_loads_with_correct_stats() -> void:
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/security_captain.tres"))
	assert_eq(captain.character_name, "Security Captain")
	assert_false(captain.is_player_controlled)
	assert_eq(captain.max_hp, 220)
	assert_eq(captain.str_stat, 38)
	assert_eq(captain.def_stat, 38)
	assert_eq(captain.spd_stat, 14)
	assert_not_null(captain.ai, "Security Captain must have an ai resource")


func test_id_defaults_to_empty_string() -> void:
	var d := CombatantDefinition.new()
	var c := Combatant.from_definition(d)
	assert_eq(c.id, "")


func test_reid_has_correct_id() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	assert_eq(reid.id, "reid")


func _make_growing_character() -> Combatant:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 20
	d.str_stat = 10
	d.def_stat = 8
	d.psy_stat = 6
	d.res_stat = 4
	d.spd_stat = 12
	d.hp_growth = 30
	d.pp_growth = 5
	d.str_growth = 4
	d.def_growth = 3
	d.psy_growth = 2
	d.res_growth = 1
	d.spd_growth = 2
	return Combatant.from_definition(d)


func test_combatant_level_defaults_to_one() -> void:
	var c := _make_growing_character()
	assert_eq(c.level, 1)


func test_level_one_stats_equal_base() -> void:
	var c := _make_growing_character()
	assert_eq(c.max_hp, 100)
	assert_eq(c.str_stat, 10)
	assert_eq(c.spd_stat, 12)


func test_set_level_applies_growth_to_stats() -> void:
	var c := _make_growing_character()
	c.set_level(3)
	# base + growth * (3 - 1)
	assert_eq(c.max_hp, 100 + 30 * 2)
	assert_eq(c.max_pp, 20 + 5 * 2)
	assert_eq(c.str_stat, 10 + 4 * 2)
	assert_eq(c.def_stat, 8 + 3 * 2)
	assert_eq(c.spd_stat, 12 + 2 * 2)


func test_set_level_full_heals_to_grown_max() -> void:
	var c := _make_growing_character()
	c.current_hp = 5
	c.current_pp = 1
	c.set_level(2)
	assert_eq(c.current_hp, c.max_hp, "set_level must full-heal HP to the grown max")
	assert_eq(c.current_pp, c.max_pp, "set_level must full-heal PP to the grown max")


func test_enemy_stats_unaffected_by_level() -> void:
	# EnemyDefinition has no growth fields; an enemy stays at its base stats.
	var enemy: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	enemy.level = 5
	assert_eq(enemy.max_hp, 200, "enemy stats must not scale with level")


func test_enemy_definition_xp_reward_defaults_zero() -> void:
	var d := EnemyDefinition.new()
	assert_eq(d.xp_reward, 0)


func test_character_combatant_xp_reward_is_zero() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	assert_eq(reid.xp_reward, 0, "player characters carry no bounty")


func test_shade_xp_reward() -> void:
	var shade: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	assert_eq(shade.xp_reward, 18)


func test_guard_xp_reward() -> void:
	var guard: Combatant = Combatant.from_definition(load("res://characters/enemies/private_security_guard.tres"))
	assert_eq(guard.xp_reward, 22)


func test_boss_xp_rewards() -> void:
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	assert_eq(enforcer.xp_reward, 60)
	assert_eq(captain.xp_reward, 45)


func test_reid_levels_up_stats_from_tres_growth() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	reid.set_level(2)
	# Reid Lv1 max_hp=350, hp_growth=35 -> Lv2 = 385
	assert_eq(reid.max_hp, 385)
	# Reid Lv1 str=45, str_growth=5 -> Lv2 = 50
	assert_eq(reid.str_stat, 50)


func test_iris_levels_up_stats_from_tres_growth() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	iris.set_level(2)
	# Iris Lv1 max_hp=270, hp_growth=28 -> Lv2 = 298
	assert_eq(iris.max_hp, 298)
	# Iris Lv1 psy=50, psy_growth=5 -> Lv2 = 55
	assert_eq(iris.psy_stat, 55)


func test_security_rookie_loads_with_correct_stats() -> void:
	var rookie: Combatant = Combatant.from_definition(load("res://characters/enemies/security_rookie.tres"))
	assert_eq(rookie.character_name, "Security Rookie")
	assert_false(rookie.is_player_controlled)
	assert_eq(rookie.max_hp, 65)
	assert_eq(rookie.str_stat, 38)
	assert_eq(rookie.def_stat, 12)
	assert_eq(rookie.spd_stat, 20)
	assert_eq(rookie.xp_reward, 22)
	assert_not_null(rookie.ai, "rookie must have an ai resource")


func test_abilities_returns_empty_array_for_enemy_definition() -> void:
	var d := EnemyDefinition.new()
	var c := Combatant.from_definition(d)
	assert_eq(c.abilities.size(), 0,
		"Enemies have no CharacterDefinition, so abilities must be empty")


func test_abilities_returns_all_character_abilities() -> void:
	var a1 := Ability.new()
	a1.ability_name = "First"
	var a2 := Ability.new()
	a2.ability_name = "Second"
	var d := CharacterDefinition.new()
	d.abilities = [a1, a2] as Array[Ability]
	var c := Combatant.from_definition(d)
	assert_eq(c.abilities.size(), 2, "Both abilities must be exposed")
	assert_eq(c.abilities[1].ability_name, "Second", "Order must be preserved")


func _ability_costing(pp: int, hp: int) -> Ability:
	var ab := Ability.new()
	ab.pp_cost = pp
	ab.hp_cost = hp
	return ab


func test_can_pay_rejects_insufficient_pp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 10
	var c := Combatant.from_definition(d)
	assert_false(c.can_pay(_ability_costing(20, 0)), "20 PP is unaffordable at 10 PP")


func test_can_pay_rejects_lethal_hp_cost() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 30
	var c := Combatant.from_definition(d)
	assert_false(c.can_pay(_ability_costing(0, 30)),
		"An HP cost that would reduce the user to 0 is not payable")
	assert_true(c.can_pay(_ability_costing(0, 29)),
		"An HP cost leaving 1 HP is payable")


func test_pay_cost_deducts_hp_not_pp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_true(c.pay_cost(_ability_costing(0, 10)), "Payment succeeds")
	assert_eq(c.current_hp, 90, "HP is deducted")
	assert_eq(c.current_pp, 50, "PP is untouched")


func test_pay_cost_of_free_ability_changes_nothing() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_true(c.pay_cost(_ability_costing(0, 0)), "Free abilities are always payable")
	assert_eq(c.current_hp, 100, "HP unchanged")
	assert_eq(c.current_pp, 50, "PP unchanged")


func test_pay_cost_is_atomic_when_hp_leg_is_lethal() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 30
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_false(c.pay_cost(_ability_costing(10, 30)),
		"A lethal HP leg fails the whole payment")
	assert_eq(c.current_pp, 50, "PP must not be spent when the HP leg is rejected")
	assert_eq(c.current_hp, 30, "HP must not be spent when the HP leg is rejected")


func test_pay_cost_is_atomic_when_pp_leg_is_short() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 30
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_false(c.pay_cost(_ability_costing(60, 5)),
		"An unaffordable PP leg fails the whole payment")
	assert_eq(c.current_pp, 50, "PP must not be spent when the PP leg is rejected")
	assert_eq(c.current_hp, 30, "HP must not be spent when the PP leg is rejected")


func test_can_pay_null_is_false() -> void:
	var d := CharacterDefinition.new()
	var c := Combatant.from_definition(d)
	assert_false(c.can_pay(null), "No ability means no payable cost")


func test_pp_ratio_is_zero_for_a_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	assert_eq(c.pp_ratio(), 0.0,
		"A character with no PP bar must report 0.0, never NaN or INF")


func test_uses_pp_is_false_for_a_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	assert_false(c.uses_pp(), "max_pp 0 means the character has no PP bar")


func test_pp_ratio_is_one_for_a_full_pp_character() -> void:
	var c := _make_combatant(100, 50)
	assert_almost_eq(c.pp_ratio(), 1.0, 0.001,
		"A full PP bar still reports 1.0, so the guard cannot invert")


func test_pressure_starts_at_zero() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	assert_eq(c.pressure, 0, "Enemies start unpressured")


func test_add_pressure_caps_at_max_stacks() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(99)
	assert_eq(c.pressure, Combatant.MAX_PRESSURE_STACKS,
		"Pressure never exceeds the stack cap")


func test_pressure_reduces_def_and_res() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	d.res_stat = 100
	var c := Combatant.from_definition(d)
	c.add_pressure(1)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 80,
		"One stack removes 20% of DEF")
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.RES), 80,
		"One stack removes 20% of RES")


func test_pressure_reduction_never_exceeds_the_cap() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	var c := Combatant.from_definition(d)
	c.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0,
		"Full stacks remove at most 100% of DEF, never more")


func test_pressure_does_not_affect_other_stats() -> void:
	var d := EnemyDefinition.new()
	d.str_stat = 50
	var c := Combatant.from_definition(d)
	c.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.STR), 50,
		"Pressure erodes defences only")


func test_consume_pressure_returns_and_clears_the_stack() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(3)
	assert_eq(c.consume_pressure(), 3, "Returns the stack that was held")
	assert_eq(c.pressure, 0, "Stack is cleared")


func test_pressure_survives_tick_effects() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(2)
	c.tick_effects()
	c.tick_effects()
	assert_eq(c.pressure, 2, "Pressure persists for the whole battle")


func test_reset_runtime_state_clears_pressure() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(2)
	c.reset_runtime_state()
	assert_eq(c.pressure, 0, "Pressure does not leak between battles")


func test_pressure_reduction_steps_down_per_stack() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	var c := Combatant.from_definition(d)
	var expected := [80, 60, 40, 20, 0]
	for i in range(Combatant.MAX_PRESSURE_STACKS):
		c.add_pressure(1)
		assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), expected[i],
			"%d stacks must remove %d%% of DEF" % [i + 1, (i + 1) * 20])


func test_consume_pressure_on_empty_stack_returns_zero() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	assert_eq(c.consume_pressure(), 0, "Nothing held means nothing returned")
	assert_eq(c.pressure, 0, "Consuming an empty stack leaves it empty")


func test_pressure_composes_multiplicatively_with_a_def_debuff() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	var c := Combatant.from_definition(d)
	var debuff := StatusEffect.new()
	debuff.effect_name = "sunder"
	debuff.stat = StatusEffect.StatAxis.DEF
	debuff.modifier = -50
	debuff.duration = 3
	c.apply_effect(debuff)
	c.add_pressure(3)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 20,
		"additive debuff lands first (100-50), then 3 stacks remove 60% -> 20")


func test_pressure_applied_to_a_target_raises_every_attackers_damage() -> void:
	var unpressured := _make_combatant_with_stats(0, 30, 0, 30)
	var pressured := _make_combatant_with_stats(0, 30, 0, 30)
	var pressure := PressureEffect.new()
	pressure.resolve(pressured)
	assert_eq(pressured.pressure, 1, "fixture requires one stack of Pressure")

	var physical := DamageEffect.new()
	physical.kind = DamageEffect.Kind.PHYSICAL
	var psychic := DamageEffect.new()
	psychic.kind = DamageEffect.Kind.PSYCHIC
	var bruiser := _make_combatant_with_stats(45, 0, 0, 0)
	var caster := _make_combatant_with_stats(0, 0, 45, 0)

	assert_gt(physical.compute(bruiser, pressured), physical.compute(bruiser, unpressured),
		"an attacker that applied no Pressure still hits harder through DEF")
	assert_gt(psychic.compute(caster, pressured), psychic.compute(caster, unpressured),
		"a different attacker hits harder through RES")
