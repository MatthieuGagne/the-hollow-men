extends BattleScene

# Smoketest: a caster with a switchable ONE_ENEMY ability vs. three Shades.
# In SELECTING_ENEMY, press right to expand the cursor to the whole group and
# left to collapse back to a single target. Single cast hits one; expanded hits all.
func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_switch_caster.tres")))
	super._ready()


func _spawn_enemies() -> void:
	for _i in range(3):
		add_enemy(Combatant.from_definition(GameData.get_definition("shade")))
