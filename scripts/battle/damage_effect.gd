# scripts/battle/damage_effect.gd
class_name DamageEffect
extends AbilityEffect

enum Kind { PHYSICAL, PIERCING, PSYCHIC }

@export var kind: Kind = Kind.PHYSICAL

# Extra damage per Pressure stack on the target, as a fraction of base damage.
# 0.0 for every ability except Reid's finisher.
@export var pressure_scaling: float = 0.0

# Base damage amplified by Pressure, capped additively at
# Combatant.MAX_DAMAGE_AMPLIFICATION so no single source can exceed +100%.
func compute(user: Combatant, target: Combatant) -> int:
	var base: int = _base_damage(user, target)
	if is_equal_approx(pressure_scaling, 0.0) or target.pressure <= 0:
		return base
	var amplification: float = minf(pressure_scaling * float(target.pressure),
		Combatant.MAX_DAMAGE_AMPLIFICATION)
	return int(round(float(base) * (1.0 + amplification)))


# Deterministic base magnitude (pure; no RNG). Variance is applied separately
# by Combatant.apply_damage_variance at resolution time. May be negative.
func _base_damage(user: Combatant, target: Combatant) -> int:
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
