class_name SecurityCaptainAI
extends EnemyAI

func resolve_action(combatant: Combatant, party: Array[Combatant], enemies: Array[Combatant], add_enemy_fn: Callable) -> Dictionary:
	if not combatant.ai_state.get("authorised_force_used", false):
		combatant.ai_state["authorised_force_used"] = true
		var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
		if not living_party.is_empty():
			var target: Combatant = living_party[randi() % living_party.size()]
			var effect := StatusEffect.new()
			effect.effect_name = "authorised_force"
			effect.stat = StatusEffect.StatAxis.DEF
			effect.modifier = -5
			effect.duration = 2
			target.apply_effect(effect)
		return {}
	var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living_party.is_empty():
		return {}
	var target: Combatant = living_party[randi() % living_party.size()]
	var damage := maxi(1, floori(combatant.get_effective_stat(StatusEffect.StatAxis.STR) * 2.0 * randf_range(0.9, 1.1)))
	target.take_damage(damage)
	return {"action": "attack", "target": target, "damage": damage}
