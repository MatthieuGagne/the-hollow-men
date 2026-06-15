class_name CharacterDefinition
extends CombatantDefinition

@export var ability: Ability = null

# Per-level stat growth. Effective stat = base + growth * (level - 1); the .tres
# base values are the level-1 stats. Default 0 keeps level-1 behavior unchanged.
@export var hp_growth: int = 0
@export var pp_growth: int = 0
@export var str_growth: int = 0
@export var def_growth: int = 0
@export var psy_growth: int = 0
@export var res_growth: int = 0
@export var spd_growth: int = 0
