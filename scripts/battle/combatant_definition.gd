class_name CombatantDefinition
extends Resource

enum SigilType { NONE, BUREAU, JAILBROKEN }

@export var id: String = ""
@export var character_name: String = ""
@export var is_player_controlled: bool = true

@export var max_hp: int = 100
@export var max_pp: int = 50
@export var str_stat: int = 10
@export var def_stat: int = 10
@export var psy_stat: int = 10
@export var res_stat: int = 10
@export var spd_stat: int = 10

@export var sigil_type: SigilType = SigilType.NONE

@export var sprite_path: String = ""
@export var sprite_vframes: int = 1
