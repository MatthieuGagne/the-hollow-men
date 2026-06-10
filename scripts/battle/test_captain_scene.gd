extends BattleScene


func _spawn_enemies() -> void:
	var captain: Combatant = GameData.get_combatant("block_captain").duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
