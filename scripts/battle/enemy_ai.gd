class_name EnemyAI
extends Resource

func resolve_action(combatant: Combatant, party: Array[Combatant], enemies: Array[Combatant], add_enemy_fn: Callable) -> Dictionary:
	var living: Array[Combatant] = party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		return {}
	var target: Combatant = living[randi() % living.size()]
	var damage := Combatant.calculate_damage(combatant, target)
	target.take_damage(damage)
	return {"action": "attack", "target": target, "damage": damage}
