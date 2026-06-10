extends BattleScene


func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
	add_enemy(Combatant.from_definition(GameData.get_definition("security_captain")))
