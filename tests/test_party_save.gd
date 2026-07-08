extends GutTest

const SLOT: int = 0


func before_each() -> void:
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func after_each() -> void:
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_snapshot_captures_runtime_for_permanent_members_only() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	reid.current_hp = 7
	reid.current_pp = 3
	reid.limit_gauge = 42.0
	PartyManager.add_member(reid)

	var temp: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_temporary(temp)

	var snap := PartyManager.snapshot_party_runtime()
	assert_eq(snap.size(), 1, "only permanent members are snapshotted")
	assert_eq(snap[0].definition_id, "reid")
	assert_eq(snap[0].current_hp, 7)
	assert_eq(snap[0].current_pp, 3)
	assert_eq(snap[0].limit_gauge, 42.0)


func test_snapshot_active_effects_array_is_decoupled_from_live_member() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.duration = 2
	reid.active_effects = [effect]
	PartyManager.add_member(reid)

	var snap := PartyManager.snapshot_party_runtime()
	assert_eq(snap[0].active_effects.size(), 1)

	# Mutating the live member's array must not affect the snapshot (.duplicate()).
	reid.active_effects.append(StatusEffect.new())
	assert_eq(snap[0].active_effects.size(), 1, "snapshot array is decoupled")


func test_restore_overlays_runtime_onto_rebuilt_member_by_id() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_member(reid)
	var full_hp := reid.max_hp

	var entry := PartyMemberSave.new()
	entry.definition_id = "reid"
	entry.current_hp = 9
	entry.current_pp = 2
	entry.limit_gauge = 30.0
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -4
	effect.duration = 3
	entry.active_effects = [effect]

	PartyManager.restore_party_runtime([entry])

	var m := PartyManager.get_active_members()[0]
	assert_ne(full_hp, 9, "precondition: saved HP differs from full HP")
	assert_eq(m.current_hp, 9)
	assert_eq(m.current_pp, 2)
	assert_eq(m.limit_gauge, 30.0)
	assert_eq(m.active_effects.size(), 1)
	assert_eq(m.active_effects[0].effect_name, "weakened")
	assert_eq(m.active_effects[0].duration, 3)


func test_restore_skips_entry_with_no_matching_member() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_member(reid)
	var full_hp := reid.max_hp

	var entry := PartyMemberSave.new()
	entry.definition_id = "iris"  # not in the roster
	entry.current_hp = 1
	PartyManager.restore_party_runtime([entry])

	assert_eq(PartyManager.get_active_members().size(), 1)
	assert_eq(PartyManager.get_active_members()[0].current_hp, full_hp, "unmatched entry skipped")
