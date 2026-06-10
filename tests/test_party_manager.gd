extends GutTest

func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()

func _make_named_combatant(name: String) -> Combatant:
	var d := CombatantDefinition.new()
	d.character_name = name
	return Combatant.from_definition(d)

func test_get_active_members_returns_permanent_and_temporary() -> void:
	var a: Combatant = _make_named_combatant("A")
	var b: Combatant = _make_named_combatant("B")
	PartyManager.add_member(a)
	PartyManager.add_temporary(b)
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 2)
	assert_eq(members[0].character_name, "A")
	assert_eq(members[1].character_name, "B")

func test_add_member_persists_across_calls() -> void:
	var c: Combatant = _make_named_combatant("C")
	PartyManager.add_member(c)
	assert_eq(PartyManager.get_active_members().size(), 1)

func test_add_temporary_appears_in_active_members() -> void:
	var guest: Combatant = _make_named_combatant("Guest")
	PartyManager.add_temporary(guest)
	assert_true(PartyManager.has_member("Guest"))

func test_remove_temporary_members_clears_guests_only() -> void:
	var perm: Combatant = _make_named_combatant("Perm")
	var temp: Combatant = _make_named_combatant("Temp")
	PartyManager.add_member(perm)
	PartyManager.add_temporary(temp)
	PartyManager.remove_temporary_members()
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].character_name, "Perm")

func test_has_member_returns_false_when_absent() -> void:
	assert_false(PartyManager.has_member("Nobody"))

func test_has_member_finds_temporary_member() -> void:
	var g: Combatant = _make_named_combatant("Iris")
	PartyManager.add_temporary(g)
	assert_true(PartyManager.has_member("Iris"))

func test_remove_temporary_does_not_affect_permanent() -> void:
	var perm: Combatant = _make_named_combatant("Reid")
	PartyManager.add_member(perm)
	PartyManager.remove_temporary_members()
	assert_true(PartyManager.has_member("Reid"))
