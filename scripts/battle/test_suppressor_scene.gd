extends BattleScene

func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_suppressor.tres")))
	super._ready()

func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
