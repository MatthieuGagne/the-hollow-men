class_name TerritoryEnforcerAI
extends EnemyAI

const ENFORCER_RES := "res://characters/enemies/territory_enforcer.tres"

func resolve_action(combatant: Combatant, party: Array[Combatant], enemies: Array[Combatant], add_enemy_fn: Callable) -> Dictionary:
	var living_enemies := enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
	var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living_enemies.size() < living_party.size():
		var backup: Combatant = load(ENFORCER_RES).duplicate()
		backup.reset_runtime_state()
		add_enemy_fn.call(backup)
		return {}
	if living_party.is_empty():
		return {}
	var target: Combatant = living_party[randi() % living_party.size()]
	var damage := maxi(1, floori(combatant.get_effective_stat(StatusEffect.StatAxis.STR) * 1.5 * randf_range(0.9, 1.1)))
	target.take_damage(damage)
	return {"action": "attack", "target": target, "damage": damage}
