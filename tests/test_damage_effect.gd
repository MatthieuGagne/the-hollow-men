extends GutTest


func _stats(str_: int = 10, def_: int = 10, psy: int = 10, res: int = 10) -> Combatant:
	var d := CombatantDefinition.new()
	d.str_stat = str_
	d.def_stat = def_
	d.psy_stat = psy
	d.res_stat = res
	return Combatant.from_definition(d)


func test_damage_effect_is_ability_effect() -> void:
	assert_true(DamageEffect.new() is AbilityEffect,
		"DamageEffect must extend AbilityEffect")


func test_physical_compute_is_str_minus_def() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PHYSICAL
	var user := _stats(45, 0)          # STR 45
	var target := _stats(0, 30)        # DEF 30
	assert_eq(e.compute(user, target), 15, "physical base = STR - DEF = 45 - 30")


func test_piercing_compute_is_str_only() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	var user := _stats(45, 0)
	var target := _stats(0, 30)        # DEF ignored
	assert_eq(e.compute(user, target), 45, "piercing base = STR, ignores DEF")


func test_psychic_compute_is_psy_minus_res() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PSYCHIC
	var user := _stats(0, 0, 50, 0)    # PSY 50
	var target := _stats(0, 0, 0, 10)  # RES 10
	assert_eq(e.compute(user, target), 40, "psychic base = PSY - RES = 50 - 10")


func test_psychic_compute_can_be_negative() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PSYCHIC
	var user := _stats(0, 0, 5, 0)     # PSY 5
	var target := _stats(0, 0, 0, 100) # RES 100
	assert_eq(e.compute(user, target), -95,
		"compute returns raw base (un-clamped); variance clamps to 1 later")


func test_variance_within_plus_minus_10_percent() -> void:
	# base 40 -> floor(40*0.9)=36 .. floor(40*1.1)=44
	for _i in range(200):
		var d: int = Combatant.apply_damage_variance(40)
		assert_gte(d, 36, "variance floor for base 40")
		assert_lte(d, 44, "variance ceil for base 40")


func test_variance_clamps_to_minimum_1() -> void:
	assert_eq(Combatant.apply_damage_variance(0), 1, "base 0 clamps to 1")


func test_variance_negative_base_clamps_to_1() -> void:
	assert_eq(Combatant.apply_damage_variance(-95), 1, "negative base clamps to 1")


func test_ability_holds_effects_array() -> void:
	var a := Ability.new()
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	a.effects = [e]
	assert_eq(a.effects.size(), 1)
	assert_true(a.effects[0] is DamageEffect)
