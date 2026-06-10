extends BattleScene


func _spawn_enemies() -> void:
	var enforcer: Combatant = GameData.get_combatant("territory_enforcer").duplicate()
	enforcer.reset_runtime_state()
	add_enemy(enforcer)
