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
	var damage: int = Combatant.calculate_piercing_strike(attacker)
	# floor(45 * 0.9) = 40, floor(45 * 1.1) = 49
	assert_gte(damage, 40, "piercing strike with str=45 must be at least 40")
	assert_lte(damage, 50, "piercing strike with str=45 must be at most 50")


func test_static_touch_uses_psy_minus_res() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.psy_stat = 50
	var target: Combatant = Combatant.new()
	target.res_stat = 10
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
