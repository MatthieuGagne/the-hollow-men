extends BattleScene

# Smoketest: a caster with a fixed ALL_ENEMIES ability vs. three Shades.
# Cast the ability -> every enemy cursor lights, one lunge, all flash + take
# damage numbers simultaneously.
func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_aoe_caster.tres")))
	super._ready()


func _spawn_enemies() -> void:
	for _i in range(3):
		add_enemy(Combatant.from_definition(GameData.get_definition("shade")))
