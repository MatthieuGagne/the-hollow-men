# scripts/battle/damage_effect.gd
class_name DamageEffect
extends AbilityEffect

enum Kind { PHYSICAL, PIERCING, PSYCHIC }

@export var kind: Kind = Kind.PHYSICAL

# Deterministic base magnitude (pure; no RNG). Variance is applied separately
# by Combatant.apply_damage_variance at resolution time. May be negative.
func compute(user: Combatant, target: Combatant) -> int:
	match kind:
		Kind.PHYSICAL:
			return user.get_effective_stat(StatusEffect.StatAxis.STR) \
				- target.get_effective_stat(StatusEffect.StatAxis.DEF)
		Kind.PIERCING:
			return user.get_effective_stat(StatusEffect.StatAxis.STR)
		Kind.PSYCHIC:
			return user.get_effective_stat(StatusEffect.StatAxis.PSY) \
				- target.get_effective_stat(StatusEffect.StatAxis.RES)
	return 0
