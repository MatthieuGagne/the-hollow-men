class_name CharacterDefinition
extends CombatantDefinition

@export var abilities: Array[Ability] = []

# Per-level stat growth. Effective stat = base + growth * (level - 1); the .tres
# base values are the level-1 stats. Default 0 keeps level-1 behavior unchanged.
@export var hp_growth: int = 0
@export var pp_growth: int = 0
@export var str_growth: int = 0
@export var def_growth: int = 0
@export var psy_growth: int = 0
@export var res_growth: int = 0
@export var spd_growth: int = 0

# How strongly missing HP accelerates the ATB gauge. 0.0 = no effect (everyone
# except Reid). 1.0 = at 0 HP the gauge would fill at 2x. Data-driven so no
# character id is ever hardcoded in combat logic.
@export var atb_desperation: float = 0.0
