extends GutTest


func test_defaults() -> void:
	var pms := PartyMemberSave.new()
	assert_eq(pms.definition_id, "")
	assert_eq(pms.current_hp, 0)
	assert_eq(pms.current_pp, 0)
	assert_eq(pms.limit_gauge, 0.0)
	assert_eq(pms.active_effects, [])


func test_holds_assigned_values_including_active_effects() -> void:
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -3
	effect.duration = 2

	var pms := PartyMemberSave.new()
	pms.definition_id = "reid"
	pms.current_hp = 12
	pms.current_pp = 4
	pms.limit_gauge = 55.0
	pms.active_effects = [effect]

	assert_eq(pms.definition_id, "reid")
	assert_eq(pms.current_hp, 12)
	assert_eq(pms.current_pp, 4)
	assert_eq(pms.limit_gauge, 55.0)
	assert_eq(pms.active_effects.size(), 1)
	assert_eq(pms.active_effects[0].effect_name, "weakened")
	assert_eq(pms.active_effects[0].duration, 2)
