# scripts/battle/heal_effect.gd
class_name HealEffect
extends AbilityEffect

# Flat base restored, plus half the healer's effective PSY (status-aware).
# Pure: no RNG, no mutation. battle_scene owns *when*; this owns *what*.
@export var amount: int = 0


func compute_heal(user: Combatant, _target: Combatant) -> int:
	return amount + user.get_effective_stat(StatusEffect.StatAxis.PSY) / 2
