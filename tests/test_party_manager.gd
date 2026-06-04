extends GutTest

func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()

func test_get_active_members_returns_permanent_and_temporary() -> void:
	var a: Combatant = Combatant.new()
	a.character_name = "A"
	var b: Combatant = Combatant.new()
	b.character_name = "B"
	PartyManager.add_member(a)
	PartyManager.add_temporary(b)
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 2)
	assert_eq(members[0].character_name, "A")
	assert_eq(members[1].character_name, "B")

func test_add_member_persists_across_calls() -> void:
	var c: Combatant = Combatant.new()
	c.character_name = "C"
	PartyManager.add_member(c)
	assert_eq(PartyManager.get_active_members().size(), 1)

func test_add_temporary_appears_in_active_members() -> void:
	var guest: Combatant = Combatant.new()
	guest.character_name = "Guest"
	PartyManager.add_temporary(guest)
	assert_true(PartyManager.has_member("Guest"))

func test_remove_temporary_members_clears_guests_only() -> void:
	var perm: Combatant = Combatant.new()
	perm.character_name = "Perm"
	var temp: Combatant = Combatant.new()
	temp.character_name = "Temp"
	PartyManager.add_member(perm)
	PartyManager.add_temporary(temp)
	PartyManager.remove_temporary_members()
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].character_name, "Perm")

func test_has_member_returns_false_when_absent() -> void:
	assert_false(PartyManager.has_member("Nobody"))

func test_has_member_finds_temporary_member() -> void:
	var g: Combatant = Combatant.new()
	g.character_name = "Iris"
	PartyManager.add_temporary(g)
	assert_true(PartyManager.has_member("Iris"))

func test_remove_temporary_does_not_affect_permanent() -> void:
	var perm: Combatant = Combatant.new()
	perm.character_name = "Reid"
	PartyManager.add_member(perm)
	PartyManager.remove_temporary_members()
	assert_true(PartyManager.has_member("Reid"))
