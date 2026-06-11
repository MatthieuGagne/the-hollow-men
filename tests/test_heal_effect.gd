# tests/test_heal_effect.gd
extends GutTest


func _healer(psy: int) -> Combatant:
	var d := CombatantDefinition.new()
	d.psy_stat = psy
	return Combatant.from_definition(d)


func test_heal_effect_is_ability_effect() -> void:
	assert_true(HealEffect.new() is AbilityEffect,
		"HealEffect must extend AbilityEffect")


func test_compute_heal_is_amount_plus_half_psy() -> void:
	var e := HealEffect.new()
	e.amount = 38
	var user := _healer(45)            # PSY 45 -> 45/2 = 22
	assert_eq(e.compute_heal(user, user), 60,
		"compute_heal = amount + floor(PSY/2) = 38 + 22")


func test_compute_heal_floors_odd_psy() -> void:
	var e := HealEffect.new()
	e.amount = 0
	var user := _healer(45)            # 45/2 floors to 22
	assert_eq(e.compute_heal(user, user), 22,
		"integer division floors odd PSY")


func test_compute_heal_scales_with_psy() -> void:
	var e := HealEffect.new()
	e.amount = 38
	var weak := _healer(0)             # 38 + 0
	var strong := _healer(100)         # 38 + 50
	assert_eq(e.compute_heal(weak, weak), 38, "no PSY -> just amount")
	assert_eq(e.compute_heal(strong, strong), 88, "PSY 100 -> 38 + 50")


func test_compute_heal_uses_effective_psy() -> void:
	# A PSY debuff must lower the heal (effect reads effective, not base, stat).
	var e := HealEffect.new()
	e.amount = 0
	var user := _healer(45)
	var debuff := StatusEffect.new()
	debuff.effect_name = "weaken_psy"
	debuff.stat = StatusEffect.StatAxis.PSY
	debuff.modifier = -10
	debuff.duration = 3
	user.apply_effect(debuff)
	var base_half: int = 45 / 2
	assert_lt(e.compute_heal(user, user), base_half,
		"effective PSY (debuffed) must reduce the heal below base PSY/2")
