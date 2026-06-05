class_name StatusEffect
extends Resource

enum StatAxis { DEF, STR, PSY, RES, SPD, HP }

@export var effect_name: String = ""
@export var stat: StatAxis = StatAxis.DEF
@export var modifier: int = 0
@export var duration: int = 0
