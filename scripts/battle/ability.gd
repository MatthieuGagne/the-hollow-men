class_name Ability
extends Resource

enum TargetMode { SELF, ONE_ALLY, ALL_ALLIES, ONE_ENEMY, ALL_ENEMIES }

@export var ability_name: String = ""
@export var pp_cost: int = 0
@export var target_mode: TargetMode = TargetMode.ONE_ENEMY
@export var switchable: bool = false
@export var effects: Array[AbilityEffect] = []


func targets_party_side() -> bool:
	return target_mode in [TargetMode.SELF, TargetMode.ONE_ALLY, TargetMode.ALL_ALLIES]


func targets_enemy_side() -> bool:
	return target_mode in [TargetMode.ONE_ENEMY, TargetMode.ALL_ENEMIES]


func is_all() -> bool:
	return target_mode in [TargetMode.ALL_ALLIES, TargetMode.ALL_ENEMIES]
