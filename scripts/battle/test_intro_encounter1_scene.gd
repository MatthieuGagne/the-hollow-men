extends BattleScene

func _spawn_enemies() -> void:
	for _i in range(2):
		add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
