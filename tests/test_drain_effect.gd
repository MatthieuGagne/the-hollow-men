extends GutTest


func _combatant(max_hp: int, max_pp: int, def_stat: int) -> Combatant:
	var d := CharacterDefinition.new()
	d.max_hp = max_hp
	d.max_pp = max_pp
	d.def_stat = def_stat
	return Combatant.from_definition(d)


func _caster(psy: int) -> Combatant:
	var d := EnemyDefinition.new()
	d.max_hp = 100
	d.psy_stat = psy
	return Combatant.from_definition(d)


func test_drain_reduces_pp_on_a_normal_character() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 40, 10)
	e.resolve(_caster(0), target)
	assert_eq(target.current_pp, 25, "PP is drained")
	assert_eq(target.current_hp, 100, "HP is untouched")


func test_drain_hits_hp_when_the_target_has_no_pp_bar() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 0, 999)
	e.resolve(_caster(0), target)
	assert_eq(target.current_hp, 85,
		"A zero-PP target bleeds for the drain instead of going dry")


func test_drain_against_a_zero_pp_target_ignores_def() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var armoured: Combatant = _combatant(100, 0, 999)
	var naked: Combatant = _combatant(100, 0, 0)
	e.resolve(_caster(0), armoured)
	e.resolve(_caster(0), naked)
	assert_eq(armoured.current_hp, naked.current_hp,
		"DEF must not reduce rerouted drain damage")
