extends GutTest

func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()

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


func test_seed_progression_defaults_all_characters_level_one() -> void:
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_xp("reid"), 0)
	assert_eq(PartyManager.get_level("iris"), 1, "non-party characters are tracked too")


func test_award_xp_to_living_member_levels_up() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	var leveled := PartyManager.award_xp([reid], 100)  # exactly the 1->2 threshold
	assert_eq(PartyManager.get_level("reid"), 2)
	assert_eq(reid.level, 2, "the live combatant's level is synced")
	assert_eq(leveled.size(), 1)
	assert_eq(leveled[0]["name"], "Reid")
	assert_eq(leveled[0]["to"], 2)


func test_award_xp_below_threshold_no_levelup() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	var leveled := PartyManager.award_xp([reid], 50)
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_xp("reid"), 50)
	assert_eq(leveled.size(), 0)


func test_add_member_at_level_seeds_progression_and_syncs_combatant() -> void:
	PartyManager.add_member_at_level("iris", 4)
	assert_eq(PartyManager.get_level("iris"), 4)
	assert_eq(PartyManager.get_xp("iris"), 0)
	assert_true(PartyManager.has_member("Iris"))
	var members := PartyManager.get_active_members()
	assert_eq(members[members.size() - 1].level, 4, "the joined combatant is at the matched level")


func test_snapshot_and_restore_progression_round_trips() -> void:
	PartyManager.set_progression("reid", 5, 42)
	PartyManager.set_progression("iris", 3, 7)
	var snap := PartyManager.snapshot_progression()
	PartyManager._progression.clear()
	PartyManager.restore_progression(snap)
	assert_eq(PartyManager.get_level("reid"), 5)
	assert_eq(PartyManager.get_xp("reid"), 42)
	assert_eq(PartyManager.get_level("iris"), 3)


func test_snapshot_roster_lists_permanent_ids() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	assert_eq(PartyManager.snapshot_roster(), ["reid"])


func test_restore_roster_rebuilds_combatants_at_stored_level() -> void:
	PartyManager.set_progression("reid", 3, 0)
	PartyManager.restore_roster(["reid"])
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].id, "reid")
	assert_eq(members[0].level, 3, "restored combatant uses stored level")


func test_restore_roster_empty_defaults_to_reid() -> void:
	PartyManager.restore_roster([])
	assert_true(PartyManager.has_member("Reid"), "a legacy/empty roster falls back to Reid")


func test_award_xp_multi_member_only_levelers_reported() -> void:
	# Two members, same XP grant: one crosses the 1->2 threshold (100), one doesn't.
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	PartyManager.add_member(reid)
	PartyManager.add_member(iris)
	PartyManager.set_progression("iris", 1, 60)  # iris starts 60 into level 1
	var leveled := PartyManager.award_xp([reid, iris], 50)
	# reid: 0+50 = 50 -> still level 1; iris: 60+50 = 110 -> level 2 (xp 10)
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_level("iris"), 2)
	assert_eq(PartyManager.get_xp("iris"), 10)
	assert_eq(leveled.size(), 1, "only the member who leveled up is reported")
	assert_eq(leveled[0]["name"], "Iris")
	assert_eq(leveled[0]["to"], 2)


func test_snapshot_progression_is_isolated_from_later_mutation() -> void:
	PartyManager.set_progression("reid", 4, 20)
	var snap := PartyManager.snapshot_progression()
	# Mutating the store after snapshotting must not change the snapshot (deep copy).
	PartyManager.set_progression("reid", 9, 99)
	assert_eq(snap["reid"]["level"], 4, "snapshot must be isolated from later store mutation")
	assert_eq(snap["reid"]["xp"], 20)
