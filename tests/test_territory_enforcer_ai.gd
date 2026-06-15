extends GutTest

func test_enforcer_summons_via_definition_summon() -> void:
	var enforcer := Combatant.from_definition(GameData.get_definition("territory_enforcer"))
	var ai := enforcer.ai
	var party: Array[Combatant] = [
		Combatant.from_definition(GameData.get_definition("reid")),
		Combatant.from_definition(GameData.get_definition("reid")),
	]
	var enemies: Array[Combatant] = [enforcer]          # outnumbered -> should summon
	var added: Array[Combatant] = []
	var add_fn := func(c: Combatant) -> void: added.append(c)
	ai.resolve_action(enforcer, party, enemies, add_fn)
	assert_eq(added.size(), 1, "enforcer must summon exactly one backup when outnumbered")
	assert_eq(added[0].id, "block_captain", "backup id must come from the definition's SummonEffect")

func test_enforcer_summon_id_not_in_script() -> void:
	# Guard against regression to a hardcoded id: the AI script must not name an enemy id.
	var src := FileAccess.get_file_as_string("res://scripts/battle/ai/territory_enforcer_ai.gd")
	assert_false(src.contains("block_captain"),
		"no enemy id may be hardcoded in the AI — it comes from the .tres summon")
