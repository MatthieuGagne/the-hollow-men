# scripts/battle/ability_effect.gd
class_name AbilityEffect
extends Resource

# Abstract base for ability effects (descriptor + pure-calculator model).
# Subclasses (DamageEffect, future HealEffect/ApplyStatusEffect/SummonEffect)
# define how they resolve. battle_scene owns *when*; effects own *what*.
