extends BattleScene

const GUARD_RES := "res://characters/enemies/private_security_guard.tres"

func _spawn_enemies() -> void:
	for _i in range(2):
		var guard: Combatant = load(GUARD_RES).duplicate()
		guard.reset_runtime_state()
		add_enemy(guard)
