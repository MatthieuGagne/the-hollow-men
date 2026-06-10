extends BattleScene


func _spawn_enemies() -> void:
	var guard: Combatant = GameData.get_combatant("private_security_guard").duplicate()
	guard.reset_runtime_state()
	add_enemy(guard)
	var captain: Combatant = GameData.get_combatant("security_captain").duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
