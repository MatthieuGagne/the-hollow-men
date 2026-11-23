# scripts/battle/pressure_effect.gd
class_name PressureEffect
extends AbilityEffect

# Adds stacks, or spends the whole stack when `consumes` is set (Close the Case).
@export var stacks: int = 1
@export var consumes: bool = false


func resolve(target: Combatant) -> void:
	if consumes:
		target.consume_pressure()
	else:
		target.add_pressure(stacks)
