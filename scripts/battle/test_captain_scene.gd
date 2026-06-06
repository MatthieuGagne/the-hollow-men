extends BattleScene

func _spawn_enemies() -> void:
	var captain: Combatant = load(CAPTAIN_RES).duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
