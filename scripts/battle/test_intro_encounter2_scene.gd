extends BattleScene

const GUARD_RES       := "res://characters/enemies/private_security_guard.tres"
const SEC_CAPTAIN_RES := "res://characters/enemies/security_captain.tres"

func _spawn_enemies() -> void:
	var guard: Combatant = load(GUARD_RES).duplicate()
	guard.reset_runtime_state()
	add_enemy(guard)
	var captain: Combatant = load(SEC_CAPTAIN_RES).duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
