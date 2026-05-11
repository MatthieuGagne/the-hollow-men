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
