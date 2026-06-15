extends GutTest


func test_registry_has_nine_combatants() -> void:
	assert_gte(GameData._registry.size(), 9)


func test_get_definition_reid() -> void:
	var d: CombatantDefinition = GameData.get_definition("reid")
	assert_not_null(d)
	assert_eq(d.character_name, "Reid")


func test_get_definition_shade() -> void:
	var d: CombatantDefinition = GameData.get_definition("shade")
	assert_not_null(d)
	assert_eq(d.character_name, "Shade")


func test_get_definition_all_party_members() -> void:
	for id: String in ["reid", "iris", "karim", "margot"]:
		assert_not_null(GameData.get_definition(id), "missing party member: %s" % id)


func test_get_definition_all_enemies() -> void:
	for id: String in ["shade", "territory_enforcer", "block_captain",
			"private_security_guard", "security_captain"]:
		assert_not_null(GameData.get_definition(id), "missing enemy: %s" % id)


func test_unknown_id_not_in_registry() -> void:
	assert_false(GameData._registry.has("nonexistent"))


func test_get_player_character_ids_returns_only_characters() -> void:
	var ids := GameData.get_player_character_ids()
	assert_true(ids.has("reid"), "reid is a player character")
	assert_true(ids.has("iris"), "iris is a player character")
	assert_false(ids.has("shade"), "enemies are excluded")
	assert_false(ids.has("territory_enforcer"), "enemies are excluded")
