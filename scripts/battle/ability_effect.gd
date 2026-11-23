# scripts/battle/ability_effect.gd
class_name AbilityEffect
extends Resource

# Abstract base for ability effects. Two conventions coexist:
#
#  * Calculator/data effects — DamageEffect, HealEffect, ApplyStatusEffect and
#    SummonEffect — own *what* a hit is worth and never mutate on their own;
#    battle_scene owns *when* and applies their result.
#  * Resolving effects — DrainEffect and PressureEffect — mutate the recipient
#    themselves when battle_scene hands them a target.
