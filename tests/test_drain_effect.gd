extends GutTest


func _combatant(max_hp: int, max_pp: int, def_stat: int) -> Combatant:
	var d := CharacterDefinition.new()
	d.max_hp = max_hp
	d.max_pp = max_pp
	d.def_stat = def_stat
	return Combatant.from_definition(d)


func _caster() -> Combatant:
	var d := EnemyDefinition.new()
	d.max_hp = 100
	return Combatant.from_definition(d)


func test_drain_reduces_pp_on_a_normal_character() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 40, 10)
	e.resolve(_caster(), target)
	assert_eq(target.current_pp, 25, "PP is drained")
	assert_eq(target.current_hp, 100, "HP is untouched")


func test_drain_hits_hp_when_the_target_has_no_pp_bar() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 0, 999)
	e.resolve(_caster(), target)
	assert_eq(target.current_hp, 85,
		"A zero-PP target bleeds for the drain instead of going dry")


func test_drain_against_a_zero_pp_target_ignores_def() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var armoured: Combatant = _combatant(100, 0, 999)
	var naked: Combatant = _combatant(100, 0, 0)
	e.resolve(_caster(), armoured)
	e.resolve(_caster(), naked)
	assert_eq(armoured.current_hp, 85, "DEF 999 must not reduce rerouted drain damage")
	assert_eq(naked.current_hp, 85, "DEF 0 target takes the same rerouted drain")


func test_drain_clamps_pp_at_zero_and_never_overflows_into_hp() -> void:
	var e := DrainEffect.new()
	e.amount = 50
	var target: Combatant = _combatant(100, 20, 10)
	e.resolve(_caster(), target)
	assert_eq(target.current_pp, 0, "PP floors at zero, it does not go negative")
	assert_eq(target.current_hp, 100, "overkill drain must not spill into HP")
