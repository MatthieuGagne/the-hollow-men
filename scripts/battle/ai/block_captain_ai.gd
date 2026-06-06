class_name BlockCaptainAI
extends EnemyAI

func resolve_action(combatant: Combatant, party: Array[Combatant], enemies: Array[Combatant], add_enemy_fn: Callable) -> Dictionary:
	var htl_active := enemies.any(func(e: Combatant) -> bool:
		return e.is_alive() and e.active_effects.any(func(ef: StatusEffect) -> bool:
			return ef.effect_name == "hold_the_line"))
	if not htl_active:
		for e in enemies:
			if e.is_alive():
				var effect := StatusEffect.new()
				effect.effect_name = "hold_the_line"
				effect.stat = StatusEffect.StatAxis.DEF
				effect.modifier = 8
				effect.duration = 2
				e.apply_effect(effect)
		return {}
	var marked_exists := party.any(func(p: Combatant) -> bool:
		return p.is_alive() and p.active_effects.any(func(ef: StatusEffect) -> bool:
			return ef.effect_name == "mark_target"))
	if not marked_exists:
		var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
		if not living_party.is_empty():
			var effect := StatusEffect.new()
			effect.effect_name = "mark_target"
			effect.stat = StatusEffect.StatAxis.DEF
			effect.modifier = -6
			effect.duration = 99
			living_party[randi() % living_party.size()].apply_effect(effect)
		return {}
	var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living_party.is_empty():
		return {}
	var target: Combatant = living_party[randi() % living_party.size()]
	var damage := Combatant.calculate_damage(combatant, target)
	target.take_damage(damage)
	return {"action": "attack", "target": target, "damage": damage}
