extends BattleScene

const ENFORCER_RES := "res://characters/enemies/territory_enforcer.tres"

func _spawn_enemies() -> void:
	var enforcer: Combatant = load(ENFORCER_RES).duplicate()
	enforcer.reset_runtime_state()
	add_enemy(enforcer)
