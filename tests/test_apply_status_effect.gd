extends GutTest

# --- helpers ---

func _make_status(axis: int, mod: int, dur: int, ename := "demo") -> StatusEffect:
	var s := StatusEffect.new()
	s.effect_name = ename
	s.stat = axis
	s.modifier = mod
	s.duration = dur
	return s

func _make_effect(status: StatusEffect) -> ApplyStatusEffect:
	var ae := ApplyStatusEffect.new()
	ae.status = status
	return ae

func _make_combatant() -> Combatant:
	return Combatant.from_definition(CombatantDefinition.new())

# --- make_instance: fresh, correct, non-aliasing ---

func test_make_instance_is_fresh_not_template() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2)
	var ae := _make_effect(tmpl)
	assert_ne(ae.make_instance(), tmpl,
		"applied instance must NOT be the template object")

func test_make_instance_copies_axis_modifier_duration() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2, "suppress")
	var ae := _make_effect(tmpl)
	var inst := ae.make_instance()
	assert_eq(inst.effect_name, "suppress")
	assert_eq(inst.stat, StatusEffect.StatAxis.DEF)
	assert_eq(inst.modifier, -6)
	assert_eq(inst.duration, 2)

func test_make_instance_null_status_returns_null() -> void:
	var ae := ApplyStatusEffect.new()  # status left unset
	assert_null(ae.make_instance(), "null template must yield null, not crash")

func test_two_targets_do_not_alias() -> void:
	var ae := _make_effect(_make_status(StatusEffect.StatAxis.DEF, -6, 2))
	var a := _make_combatant()
	var b := _make_combatant()
	a.apply_effect(ae.make_instance())
	b.apply_effect(ae.make_instance())
	a.tick_effects()  # decrements A's copy only
	assert_eq(a.active_effects[0].duration, 1, "A's duration must drop to 1")
	assert_eq(b.active_effects[0].duration, 2,
		"B's duration must be untouched — proves no shared instance")

# --- integration: wired through battle_scene enemy path ---

const SUPPRESSOR_DEF := "res://tests/fixtures/test_suppressor.tres"

func _make_scene_with(caster_def_path: String) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	var caster := Combatant.from_definition(load(caster_def_path))
	PartyManager._permanent_members.append(caster)
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

func test_offensive_ability_applies_status_to_enemy() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	var debuffed := shade.active_effects.any(func(ef: StatusEffect) -> bool:
		return ef.effect_name == "suppress")
	assert_true(debuffed,
		"Suppressing Strike must apply the 'suppress' debuff to the struck enemy")

func test_offensive_ability_lowers_enemy_effective_def() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	var def_before := shade.get_effective_stat(StatusEffect.StatAxis.DEF)
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(shade.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
		"applied DEF debuff must reduce the enemy's effective DEF")

func test_offensive_ability_also_deals_damage() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	var hp_before := shade.current_hp
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before,
		"Suppressing Strike composes DamageEffect + ApplyStatusEffect in one cast")

func test_status_ability_spends_pp() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var pp_before := caster.current_pp
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(caster.current_pp, pp_before,
		"status ability must still spend PP exactly once via _resolve_ability")
