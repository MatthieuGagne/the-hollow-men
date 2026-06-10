extends GutTest


func test_reset_runtime_state_restores_hp_and_pp() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.max_pp = 50
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
	var reid: Combatant = load("res://characters/reid.tres")
	reid.reset_runtime_state()
	assert_eq(reid.character_name, "Reid")
	assert_eq(reid.max_hp, 350)
	assert_eq(reid.max_pp, 20)
	assert_eq(reid.spd_stat, 30)
	assert_eq(reid.current_hp, 350)
	assert_true(reid.is_player_controlled)


func test_iris_loads_with_correct_stats() -> void:
	var iris: Combatant = load("res://characters/iris.tres")
	iris.reset_runtime_state()
	assert_eq(iris.character_name, "Iris")
	assert_eq(iris.max_hp, 270)
	assert_eq(iris.spd_stat, 50)
	assert_eq(iris.current_hp, 270)
	assert_true(iris.is_player_controlled)


func test_shade_loads_with_correct_stats() -> void:
	var shade: Combatant = load("res://characters/enemies/shade.tres")
	shade.reset_runtime_state()
	assert_eq(shade.character_name, "Shade")
	assert_eq(shade.max_hp, 200)
	assert_eq(shade.spd_stat, 25)
	assert_false(shade.is_player_controlled)


func test_tick_atb_proportional_to_spd() -> void:
	var fast := Combatant.new()
	fast.spd_stat = 50
	fast.reset_runtime_state()

	var slow := Combatant.new()
	slow.spd_stat = 25
	slow.reset_runtime_state()

	fast.tick_atb(0.1)
	slow.tick_atb(0.1)

	assert_gt(fast.atb, slow.atb)


func test_calculate_damage_within_expected_range() -> void:
	# Reid STR=45 vs Shade DEF=15 → floor(30 * [0.9,1.1]) → [27,33]
	var attacker := Combatant.new()
	attacker.str_stat = 45
	var target := Combatant.new()
	target.def_stat = 15
	for _i in range(200):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 27, "damage below minimum expected")
		assert_lte(dmg, 33, "damage above maximum expected")


func test_calculate_damage_minimum_one() -> void:
	# When def > str the formula goes negative — must clamp to 1
	var attacker := Combatant.new()
	attacker.str_stat = 5
	var target := Combatant.new()
	target.def_stat = 100
	for _i in range(50):
		var dmg := Combatant.calculate_damage(attacker, target)
		assert_gte(dmg, 1, "damage must never be below 1")


func test_atb_fills_between_6_and_8_seconds_at_base_speed() -> void:
	var c := Combatant.new()
	c.spd_stat = 10
	c.reset_runtime_state()

	# After 6 seconds, ATB should not yet be full (would be too fast)
	c.tick_atb(6.0)
	assert_lt(c.atb, Combatant.ATB_MAX, "ATB should not be full after 6 seconds")

	# After a further 2 seconds (8 total), ATB must be full
	c.tick_atb(2.0)
	assert_gte(c.atb, Combatant.ATB_MAX, "ATB must be full after 8 seconds at base speed")


func test_is_alive_returns_true_when_hp_positive() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	assert_true(c.is_alive())


func test_is_alive_returns_false_when_hp_zero() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	c.current_hp = 0
	assert_false(c.is_alive())


func test_tick_atb_skips_downed_combatant() -> void:
	var c := Combatant.new()
	c.spd_stat = 50
	c.max_hp = 100
	c.reset_runtime_state()
	c.current_hp = 0
	var atb_before: float = c.atb
	c.tick_atb(1.0)
	assert_eq(c.atb, atb_before, "dead combatant ATB must not advance")


func test_skip_cooldown_initial_value_is_zero() -> void:
	var c := Combatant.new()
	assert_eq(c.skip_cooldown, 0.0)


func test_reset_runtime_state_clears_skip_cooldown() -> void:
	var c := Combatant.new()
	c.skip_cooldown = 3.5
	c.reset_runtime_state()
	assert_eq(c.skip_cooldown, 0.0)


func test_is_skipping_true_when_cooldown_positive() -> void:
	var c := Combatant.new()
	c.skip_cooldown = 1.0
	assert_true(c.is_skipping())


func test_is_skipping_false_when_cooldown_zero() -> void:
	var c := Combatant.new()
	c.skip_cooldown = 0.0
	assert_false(c.is_skipping())


func test_piercing_strike_uses_str_only() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.str_stat = 45
	for _i in range(200):
		var damage: int = Combatant.calculate_piercing_strike(attacker)
		# floor(45 * 0.9) = 40, floor(45 * 1.1) = 49
		assert_gte(damage, 40, "piercing strike with str=45 must be at least 40")
		assert_lte(damage, 49, "piercing strike with str=45 must be at most 49")


func test_static_touch_uses_psy_minus_res() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.psy_stat = 50
	var target: Combatant = Combatant.new()
	target.res_stat = 10
	for _i in range(200):
		var damage: int = Combatant.calculate_static_touch(attacker, target)
		# floor((50-10) * 0.9) = 36, floor((50-10) * 1.1) = 44
		assert_gte(damage, 36, "static touch with psy=50, res=10 must be at least 36")
		assert_lte(damage, 44, "static touch with psy=50, res=10 must be at most 44")


func test_piercing_strike_minimum_1() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.str_stat = 0
	assert_eq(Combatant.calculate_piercing_strike(attacker), 1,
		"piercing strike minimum damage must be 1")


func test_static_touch_minimum_1() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.psy_stat = 5
	var target: Combatant = Combatant.new()
	target.res_stat = 100
	assert_eq(Combatant.calculate_static_touch(attacker, target), 1,
		"static touch minimum damage must be 1 when PSY < RES")


func test_ability_targets_party_defaults_false() -> void:
	var ab := Ability.new()
	assert_false(ab.targets_party, "targets_party must default to false")


func test_heal_increases_hp() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	c.current_hp = 40
	c.heal(30)
	assert_eq(c.current_hp, 70)


func test_heal_caps_at_max_hp() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	c.current_hp = 90
	c.heal(60)
	assert_eq(c.current_hp, 100)


func test_heal_exact_max() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	c.heal(9999)
	assert_eq(c.current_hp, 100)


func test_karim_loads_with_correct_stats() -> void:
	var karim: Combatant = load("res://characters/karim.tres")
	karim.reset_runtime_state()
	assert_eq(karim.character_name, "Karim")
	assert_eq(karim.max_hp, 310)
	assert_eq(karim.max_pp, 70)
	assert_eq(karim.spd_stat, 22)
	assert_true(karim.is_player_controlled)
	assert_eq(karim.ability.ability_name, "Field Suture")
	assert_eq(karim.ability.pp_cost, 10)
	assert_true(karim.ability.targets_party)


func test_margot_loads_with_correct_stats() -> void:
	var margot: Combatant = load("res://characters/margot.tres")
	margot.reset_runtime_state()
	assert_eq(margot.character_name, "Margot")
	assert_eq(margot.max_hp, 240)
	assert_eq(margot.max_pp, 90)
	assert_eq(margot.spd_stat, 40)
	assert_true(margot.is_player_controlled)
	assert_eq(margot.ability.ability_name, "Void Calculus")
	assert_eq(margot.ability.pp_cost, 15)
	assert_false(margot.ability.targets_party)


func test_status_effect_fields_have_correct_defaults() -> void:
	var effect := StatusEffect.new()
	assert_eq(effect.effect_name, "")
	assert_eq(effect.modifier, 0)
	assert_eq(effect.duration, 0)


func test_status_effect_stat_axis_has_all_axes() -> void:
	# Verify the enum members exist and are distinct
	assert_ne(StatusEffect.StatAxis.DEF, StatusEffect.StatAxis.STR)
	assert_ne(StatusEffect.StatAxis.PSY, StatusEffect.StatAxis.RES)
	assert_ne(StatusEffect.StatAxis.SPD, StatusEffect.StatAxis.HP)


func test_apply_effect_adds_to_active_effects() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	assert_eq(c.active_effects.size(), 1)


func test_apply_effect_reapply_refreshes_duration_not_stacks() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
	var e1 := StatusEffect.new()
	e1.effect_name = "hold_the_line"
	e1.stat = StatusEffect.StatAxis.DEF
	e1.modifier = 8
	e1.duration = 1  # nearly expired
	c.apply_effect(e1)
	var e2 := StatusEffect.new()
	e2.effect_name = "hold_the_line"
	e2.stat = StatusEffect.StatAxis.DEF
	e2.modifier = 8
	e2.duration = 2  # fresh application
	c.apply_effect(e2)
	assert_eq(c.active_effects.size(), 1, "reapply must not stack a second instance")
	assert_eq(c.active_effects[0].duration, 2, "reapply must refresh duration to new value")


func test_reset_runtime_state_clears_active_effects() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.duration = 2
	c.apply_effect(effect)
	c.reset_runtime_state()
	assert_eq(c.active_effects.size(), 0, "reset_runtime_state must clear active effects")


func test_tick_effects_decrements_duration() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 3
	c.apply_effect(effect)
	c.tick_effects()
	assert_eq(c.active_effects[0].duration, 2, "duration must decrement by 1 per tick")


func test_tick_effects_removes_expired_effect() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 5
	effect.duration = 1
	c.apply_effect(effect)
	c.tick_effects()
	assert_eq(c.active_effects.size(), 0, "expired effect must be removed after tick")


func test_tick_effects_only_removes_expired_leaves_others() -> void:
	var c := Combatant.new()
	c.reset_runtime_state()
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
	var c := Combatant.new()
	c.def_stat = 10
	c.reset_runtime_state()
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 10)


func test_get_effective_stat_with_buff() -> void:
	var c := Combatant.new()
	c.def_stat = 10
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 18)


func test_get_effective_stat_with_debuff() -> void:
	var c := Combatant.new()
	c.def_stat = 10
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "mark_target"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -6
	effect.duration = 99
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 4)


func test_get_effective_stat_clamps_at_zero() -> void:
	var c := Combatant.new()
	c.def_stat = 5
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "mark_target"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -20
	effect.duration = 99
	c.apply_effect(effect)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0, "effective stat must clamp at 0")


func test_take_damage_clears_mark_target() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
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
	var c := Combatant.new()
	c.max_hp = 100
	c.reset_runtime_state()
	var effect := StatusEffect.new()
	effect.effect_name = "hold_the_line"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = 8
	effect.duration = 2
	c.apply_effect(effect)
	c.take_damage(10)
	assert_eq(c.active_effects.size(), 1, "take_damage must not clear non-mark_target effects")


func test_calculate_damage_uses_effective_stats() -> void:
	# DEF buff on target reduces damage
	var attacker := Combatant.new()
	attacker.str_stat = 40
	var target := Combatant.new()
	target.def_stat = 10
	# With buff: effective DEF = 30, so damage = floor((40-30)*[0.9,1.1]) = [9,11]
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
	# DEF debuff on target increases damage
	var attacker := Combatant.new()
	attacker.str_stat = 40
	var target := Combatant.new()
	target.def_stat = 10
	# With debuff: effective DEF = 4, so damage = floor((40-4)*[0.9,1.1]) = [32,39]
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
	var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres")
	enforcer.reset_runtime_state()
	assert_eq(enforcer.character_name, "Territory Enforcer")
	assert_false(enforcer.is_player_controlled)
	assert_eq(enforcer.max_hp, 150)
	assert_eq(enforcer.str_stat, 35)
	assert_eq(enforcer.def_stat, 10)
	assert_eq(enforcer.spd_stat, 20)
	assert_eq(enforcer.current_hp, 150)


func test_block_captain_loads_with_correct_stats() -> void:
	var captain: Combatant = load("res://characters/enemies/block_captain.tres")
	captain.reset_runtime_state()
	assert_eq(captain.character_name, "Block Captain")
	assert_false(captain.is_player_controlled)
	assert_eq(captain.max_hp, 200)
	assert_eq(captain.str_stat, 35)
	assert_eq(captain.def_stat, 15)
	assert_eq(captain.spd_stat, 15)
	assert_eq(captain.current_hp, 200)


func test_combatant_ai_state_defaults_empty() -> void:
	var c := Combatant.new()
	assert_eq(c.ai_state, {}, "ai_state must be empty dict by default")


func test_reset_runtime_state_clears_ai_state() -> void:
	var c := Combatant.new()
	c.ai_state["foo"] = true
	c.reset_runtime_state()
	assert_eq(c.ai_state, {}, "reset_runtime_state must clear ai_state")


func test_combatant_ai_property_defaults_null() -> void:
	var c := Combatant.new()
	assert_null(c.ai, "ai must default to null")


func test_shade_has_ai() -> void:
	var shade: Combatant = load("res://characters/enemies/shade.tres")
	assert_not_null(shade.ai, "Shade must have an ai resource")


func test_territory_enforcer_has_ai() -> void:
	var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres")
	assert_not_null(enforcer.ai, "Territory Enforcer must have an ai resource")


func test_block_captain_has_ai() -> void:
	var captain: Combatant = load("res://characters/enemies/block_captain.tres")
	assert_not_null(captain.ai, "Block Captain must have an ai resource")


func test_private_security_guard_loads_with_correct_stats() -> void:
	var guard: Combatant = load("res://characters/enemies/private_security_guard.tres")
	guard.reset_runtime_state()
	assert_eq(guard.character_name, "Private Security Guard")
	assert_false(guard.is_player_controlled)
	assert_eq(guard.max_hp, 150)
	assert_eq(guard.str_stat, 40)
	assert_eq(guard.def_stat, 28)
	assert_eq(guard.spd_stat, 32)
	assert_not_null(guard.ai, "Guard must have an ai resource")


func test_security_captain_loads_with_correct_stats() -> void:
	var captain: Combatant = load("res://characters/enemies/security_captain.tres")
	captain.reset_runtime_state()
	assert_eq(captain.character_name, "Security Captain")
	assert_false(captain.is_player_controlled)
	assert_eq(captain.max_hp, 220)
	assert_eq(captain.str_stat, 38)
	assert_eq(captain.def_stat, 38)
	assert_eq(captain.spd_stat, 14)
	assert_not_null(captain.ai, "Security Captain must have an ai resource")


func test_id_defaults_to_empty_string() -> void:
	var c := Combatant.new()
	assert_eq(c.id, "")


func test_reid_has_correct_id() -> void:
	var reid: Combatant = load("res://characters/reid.tres")
	assert_eq(reid.id, "reid")
