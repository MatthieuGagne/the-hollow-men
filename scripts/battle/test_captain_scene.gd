extends BattleScene

const CAPTAIN_RES := "res://characters/enemies/block_captain.tres"

func _spawn_enemies() -> void:
	var captain: Combatant = load(CAPTAIN_RES).duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
