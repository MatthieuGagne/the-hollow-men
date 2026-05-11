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
