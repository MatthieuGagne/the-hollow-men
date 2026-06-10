extends GutTest


func test_registry_has_nine_combatants() -> void:
	assert_eq(GameData._registry.size(), 9)


func test_get_combatant_reid() -> void:
	var c: Combatant = GameData.get_combatant("reid")
	assert_not_null(c)
	assert_eq(c.character_name, "Reid")


func test_get_combatant_shade() -> void:
	var c: Combatant = GameData.get_combatant("shade")
	assert_not_null(c)
	assert_eq(c.character_name, "Shade")


func test_get_combatant_all_party_members() -> void:
	for id: String in ["reid", "iris", "karim", "margot"]:
		assert_not_null(GameData.get_combatant(id), "missing party member: %s" % id)


func test_get_combatant_all_enemies() -> void:
	for id: String in ["shade", "territory_enforcer", "block_captain",
			"private_security_guard", "security_captain"]:
		assert_not_null(GameData.get_combatant(id), "missing enemy: %s" % id)


func test_unknown_id_not_in_registry() -> void:
	# Do not call get_combatant("nonexistent") — it asserts in debug builds.
	# Verify the registry does not contain it directly.
	assert_false(GameData._registry.has("nonexistent"))
