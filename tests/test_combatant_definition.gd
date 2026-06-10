extends GutTest


func test_combatant_definition_instantiates() -> void:
	var d := CombatantDefinition.new()
	assert_not_null(d)


func test_combatant_definition_default_fields() -> void:
	var d := CombatantDefinition.new()
	assert_eq(d.id, "")
	assert_eq(d.character_name, "")
	assert_true(d.is_player_controlled)
	assert_eq(d.max_hp, 100)
	assert_eq(d.max_pp, 50)
	assert_eq(d.str_stat, 10)
	assert_eq(d.def_stat, 10)
	assert_eq(d.psy_stat, 10)
	assert_eq(d.res_stat, 10)
	assert_eq(d.spd_stat, 10)
	assert_eq(d.sigil_type, CombatantDefinition.SigilType.NONE)
	assert_eq(d.sprite_path, "")
	assert_eq(d.sprite_vframes, 1)


func test_character_definition_has_ability_field() -> void:
	var d := CharacterDefinition.new()
	assert_null(d.ability, "ability must default to null")
	assert_true(d.is_player_controlled, "CharacterDefinition defaults is_player_controlled=true")


func test_enemy_definition_has_ai_field() -> void:
	var d := EnemyDefinition.new()
	assert_null(d.ai, "ai must default to null")
	assert_true(d.is_player_controlled, "EnemyDefinition inherits is_player_controlled default")


func test_character_definition_is_combatant_definition() -> void:
	var d := CharacterDefinition.new()
	assert_true(d is CombatantDefinition)


func test_enemy_definition_is_combatant_definition() -> void:
	var d := EnemyDefinition.new()
	assert_true(d is CombatantDefinition)
