extends BattleScene

func _ready() -> void:
	PartyManager.add_temporary(Combatant.from_definition(GameData.get_definition("karim")))
	super._ready()

func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
