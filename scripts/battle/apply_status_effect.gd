class_name ApplyStatusEffect
extends AbilityEffect

@export var status: StatusEffect


func make_instance() -> StatusEffect:
	return status.duplicate(true) if status != null else null
