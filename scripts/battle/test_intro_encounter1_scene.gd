extends BattleScene

func _spawn_enemies() -> void:
	for _i in range(2):
		var guard: Combatant = GameData.get_combatant("private_security_guard").duplicate()
		guard.reset_runtime_state()
		add_enemy(guard)
