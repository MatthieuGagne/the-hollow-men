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


func _ability_of(path: String) -> Ability:
	var c: Combatant = Combatant.from_definition(load(path))
	return c.abilities[0]


func test_reid_ability_has_piercing_effect() -> void:
	var a := _ability_of("res://characters/reid.tres")
	assert_eq(a.ability_name, "Piercing Strike")
	assert_eq(a.hp_cost, 6, "Reid pays HP for Piercing Strike")
	assert_eq(a.effects.size(), 2)
	assert_true(a.effects[0] is DamageEffect)
	assert_eq(a.effects[0].kind, DamageEffect.Kind.PIERCING)
	assert_true(a.effects[1] is PressureEffect)
	assert_eq(a.effects[1].stacks, 1)


func test_reid_ability_set_matches_the_pressure_kit() -> void:
	var c: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	var names: Array[String] = []
	var costs: Array[int] = []
	for a: Ability in c.abilities:
		names.append(a.ability_name)
		costs.append(a.hp_cost)
	assert_eq(names, ["Piercing Strike", "Work the Body", "Heavy Blow", "Close the Case"],
		"ability order is the menu order")
	assert_eq(costs, [6, 0, 12, 18], "each rung costs more HP")
	var stacks: Array[int] = []
	var consumes: Array[bool] = []
	var finisher: DamageEffect = null
	for a: Ability in c.abilities:
		assert_eq(a.target_mode, Ability.TargetMode.ONE_ENEMY)
		var pressure := a.effects[1] as PressureEffect
		assert_not_null(pressure, "every rung carries a PressureEffect second")
		stacks.append(pressure.stacks)
		consumes.append(pressure.consumes)
		var damage := a.effects[0] as DamageEffect
		assert_not_null(damage, "every rung carries a DamageEffect first")
		if not is_equal_approx(damage.pressure_scaling, 0.0):
			finisher = damage
	assert_eq(stacks, [1, 2, 2, 1], "Pressure added per rung; the finisher's stack count is unused")
	assert_eq(consumes, [false, false, false, true], "only Close the Case consumes the stack")
	assert_not_null(finisher, "only the finisher scales with Pressure")
	assert_almost_eq(finisher.pressure_scaling, 0.2, 0.0001,
		"0.2 reaches the +100% cap exactly at MAX_PRESSURE_STACKS")


func test_iris_ability_has_psychic_effect() -> void:
	var a := _ability_of("res://characters/iris.tres")
	assert_eq(a.effects.size(), 1)
	assert_eq(a.effects[0].kind, DamageEffect.Kind.PSYCHIC)


func test_margot_ability_has_psychic_effect() -> void:
	var a := _ability_of("res://characters/margot.tres")
	assert_eq(a.effects.size(), 1)
	assert_eq(a.effects[0].kind, DamageEffect.Kind.PSYCHIC)


func test_pressure_scaled_damage_grows_with_the_stack() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	e.pressure_scaling = 0.5

	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100

	var unpressured := Combatant.from_definition(EnemyDefinition.new())
	var pressured := Combatant.from_definition(EnemyDefinition.new())
	pressured.add_pressure(2)

	assert_gt(e.compute(user, pressured), e.compute(user, unpressured),
		"Consumed Pressure must increase the finisher's damage")
	assert_eq(e.compute(user, pressured), 200,
		"STR 100 at 2 stacks x0.5 is exactly x2.0")


func test_pressure_scaling_defaults_to_no_effect() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100
	var pressured := Combatant.from_definition(EnemyDefinition.new())
	pressured.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	var plain := Combatant.from_definition(EnemyDefinition.new())
	assert_eq(e.compute(user, pressured), e.compute(user, plain),
		"Abilities without pressure_scaling are unaffected by the stack")


func test_pressure_scaled_damage_is_linear_below_the_cap() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	e.pressure_scaling = 0.5
	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100
	var target := Combatant.from_definition(EnemyDefinition.new())
	target.add_pressure(1)
	assert_eq(e.compute(user, target), 150,
		"1 stack at 0.5 is exactly x1.5 — neither ignored nor saturated")


func test_pressure_scaling_is_capped_at_one_hundred_percent() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	e.pressure_scaling = 0.5
	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100
	var target := Combatant.from_definition(EnemyDefinition.new())
	target.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(e.compute(user, target), 200,
		"0.5 x 5 stacks would be x3.5; the cap holds it at x2.0")


func test_physical_pressure_scaling_compounds_with_defence_reduction() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PHYSICAL
	e.pressure_scaling = 0.5
	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100
	var target := Combatant.from_definition(EnemyDefinition.new())
	target.def.def_stat = 50
	target.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(target.get_effective_stat(StatusEffect.StatAxis.DEF), 0,
		"5 stacks must erase the target's 50 DEF")
	# Base is 100 - 0 after DEF erosion; the amplifier then caps at +100%.
	assert_eq(e.compute(user, target), 200,
		"reduced DEF and the capped amplifier apply in the same hit")
