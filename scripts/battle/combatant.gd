class_name Combatant
extends Resource

enum SigilType { NONE, BUREAU, JAILBROKEN }

# Identity
@export var character_name: String = ""
@export var is_player_controlled: bool = true

# Base stats
@export var max_hp: int = 100
@export var max_pp: int = 50
@export var str_stat: int = 10   # physical attack
@export var def_stat: int = 10   # physical defense
@export var psy_stat: int = 10   # psychic attack
@export var res_stat: int = 10   # psychic resistance
@export var spd_stat: int = 10   # ATB fill rate

# Sigil
@export var sigil_type: SigilType = SigilType.NONE

# Runtime state
var current_hp: int
var current_pp: int
var atb: float = 0.0
var limit_gauge: float = 0.0

const ATB_MAX: float = 100.0
const LIMIT_MAX: float = 100.0
# Bureau sigils meter the limit break — cap at 80%
const LIMIT_CAP_BUREAU: float = 80.0


func _init() -> void:
	current_hp = max_hp
	current_pp = max_pp


func reset_runtime_state() -> void:
	current_hp = max_hp
	current_pp = max_pp
	atb = 0.0
	limit_gauge = 0.0


func tick_atb(delta: float) -> void:
	if is_dead():
		return
	atb = minf(atb + float(spd_stat) * delta * 10.0, ATB_MAX)


func atb_full() -> bool:
	return atb >= ATB_MAX


func consume_atb() -> void:
	atb = 0.0


func is_dead() -> bool:
	return current_hp <= 0


func limit_cap() -> float:
	return LIMIT_CAP_BUREAU if sigil_type == SigilType.BUREAU else LIMIT_MAX


func is_limit_ready() -> bool:
	return limit_gauge >= limit_cap()


func take_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	# Damage charges the limit gauge
	var ratio: float = float(amount) / float(max_hp)
	limit_gauge = minf(limit_gauge + ratio * LIMIT_MAX, limit_cap())


func drain_pp(amount: int) -> void:
	# PP drain: what the Bureau does administratively made mechanical
	current_pp = maxi(current_pp - amount, 0)


func spend_pp(cost: int) -> bool:
	if current_pp < cost:
		return false
	current_pp -= cost
	return true


func hp_ratio() -> float:
	return float(current_hp) / float(max_hp)


func pp_ratio() -> float:
	return float(current_pp) / float(max_pp)


func atb_ratio() -> float:
	return atb / ATB_MAX


func limit_ratio() -> float:
	return limit_gauge / limit_cap()
