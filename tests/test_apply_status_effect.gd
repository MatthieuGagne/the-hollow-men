extends GutTest

# --- helpers ---

func _make_status(axis: int, mod: int, dur: int, ename := "demo") -> StatusEffect:
	var s := StatusEffect.new()
	s.effect_name = ename
	s.stat = axis
	s.modifier = mod
	s.duration = dur
	return s

func _make_effect(mode: int, status: StatusEffect) -> ApplyStatusEffect:
	var ae := ApplyStatusEffect.new()
	ae.target_mode = mode
	ae.status = status
	return ae

func _make_combatant() -> Combatant:
	return Combatant.from_definition(CombatantDefinition.new())

# --- resolve_recipient ---

func test_resolve_recipient_target_returns_target() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET,
		_make_status(StatusEffect.StatAxis.DEF, -6, 2))
	var user := _make_combatant()
	var target := _make_combatant()
	assert_eq(ae.resolve_recipient(user, target), target,
		"TARGET mode must land on the resolved target")

func test_resolve_recipient_self_returns_user() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.SELF,
		_make_status(StatusEffect.StatAxis.STR, 8, 3))
	var user := _make_combatant()
	var target := _make_combatant()
	assert_eq(ae.resolve_recipient(user, target), user,
		"SELF mode must land on the caster")

# --- make_instance: fresh, correct, non-aliasing ---

func test_make_instance_is_fresh_not_template() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2)
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET, tmpl)
	assert_ne(ae.make_instance(), tmpl,
		"applied instance must NOT be the template object")

func test_make_instance_copies_axis_modifier_duration() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2, "suppress")
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET, tmpl)
	var inst := ae.make_instance()
	assert_eq(inst.effect_name, "suppress")
	assert_eq(inst.stat, StatusEffect.StatAxis.DEF)
	assert_eq(inst.modifier, -6)
	assert_eq(inst.duration, 2)

func test_make_instance_null_status_returns_null() -> void:
	var ae := ApplyStatusEffect.new()  # status left unset
	assert_null(ae.make_instance(), "null template must yield null, not crash")

func test_two_targets_do_not_alias() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET,
		_make_status(StatusEffect.StatAxis.DEF, -6, 2))
	var a := _make_combatant()
	var b := _make_combatant()
	a.apply_effect(ae.make_instance())
	b.apply_effect(ae.make_instance())
	a.tick_effects()  # decrements A's copy only
	assert_eq(a.active_effects[0].duration, 1, "A's duration must drop to 1")
	assert_eq(b.active_effects[0].duration, 2,
		"B's duration must be untouched — proves no shared instance")
