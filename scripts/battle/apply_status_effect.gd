class_name ApplyStatusEffect
extends AbilityEffect

enum TargetMode { TARGET, SELF }

@export var status: StatusEffect
@export var target_mode: TargetMode = TargetMode.TARGET


func resolve_recipient(user: Combatant, target: Combatant) -> Combatant:
	return user if target_mode == TargetMode.SELF else target


func make_instance() -> StatusEffect:
	return status.duplicate(true) if status != null else null
