# scripts/battle/drain_effect.gd
class_name DrainEffect
extends AbilityEffect

# Psychic Drain — the entity's damage type. Normally eats PP. Against a target
# with no PP bar there is nothing to skim, so it takes the same amount out of
# HP and ignores DEF: they bleed for it instead of going dry.
#
# Branches are not symmetric: the PP branch only lowers current_pp. The HP
# branch goes through take_damage(), so it also builds limit_gauge and strips
# mark_target — rerouted drain is ordinary incoming damage.
@export var amount: int = 0


func resolve(_user: Combatant, target: Combatant) -> void:
	if target.uses_pp():
		target.drain_pp(amount)
	else:
		target.take_damage(amount)
