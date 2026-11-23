extends GutTest


func test_effect_adds_its_configured_stacks() -> void:
	var e := PressureEffect.new()
	e.stacks = 2
	var target := Combatant.from_definition(EnemyDefinition.new())
	e.resolve(target)
	assert_eq(target.pressure, 2, "Applies the configured stack count")


func test_consuming_effect_clears_the_stack() -> void:
	var e := PressureEffect.new()
	e.consumes = true
	var target := Combatant.from_definition(EnemyDefinition.new())
	target.add_pressure(4)
	e.resolve(target)
	assert_eq(target.pressure, 0, "A consuming effect spends the whole stack")
