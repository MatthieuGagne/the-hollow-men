extends GutTest

func test_make_summon_returns_combatant_for_id() -> void:
	var s := SummonEffect.new()
	s.enemy_id = "block_captain"
	var c := s.make_summon()
	assert_not_null(c, "make_summon must build a Combatant from GameData")
	assert_eq(c.id, "block_captain", "summoned combatant must match the configured id")

func test_make_summon_full_hp() -> void:
	var s := SummonEffect.new()
	s.enemy_id = "block_captain"
	var c := s.make_summon()
	assert_eq(c.current_hp, c.max_hp, "summoned enemy must spawn at full HP")

func test_make_summon_empty_id_returns_null() -> void:
	assert_null(SummonEffect.new().make_summon(), "empty enemy_id must yield null, not crash")

func test_enemy_definition_has_summon_field() -> void:
	assert_true("summon" in EnemyDefinition.new(), "EnemyDefinition must expose a summon slot")

func test_combatant_summon_delegates_to_definition() -> void:
	var def := EnemyDefinition.new()
	var s := SummonEffect.new(); s.enemy_id = "block_captain"
	def.summon = s
	var c := Combatant.from_definition(def)
	assert_eq(c.summon, s, "Combatant.summon must delegate to its EnemyDefinition")

func test_combatant_summon_null_for_character() -> void:
	var c := Combatant.from_definition(CharacterDefinition.new())
	assert_null(c.summon, "non-enemy combatants have no summon")
