class_name Combatant
extends RefCounted

var def: CombatantDefinition

# Runtime state
var current_hp: int = 0
var current_pp: int = 0
var level: int = 1
var atb: float = 0.0
var limit_gauge: float = 0.0
var skip_cooldown: float = 0.0
var active_effects: Array[StatusEffect] = []
var ai_state: Dictionary = {}

const ATB_MAX: float = 100.0
const LIMIT_MAX: float = 100.0
# Bureau sigils meter the limit break — cap at 80%
const LIMIT_CAP_BUREAU: float = 80.0
# ATB fill rate multiplier — spd_stat=10 fills ATB in ~6.67 s (within the 6–8 s design target)
const ATB_FILL_RATE: float = 1.5

# --- Delegating properties ---

var id: String:
	get: return def.id

var character_name: String:
	get: return def.character_name

var is_player_controlled: bool:
	get: return def.is_player_controlled

# Returns the CharacterDefinition for player characters, else null (enemies don't grow).
func _char_def() -> CharacterDefinition:
	return def as CharacterDefinition

var max_hp: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.max_hp, cd.hp_growth, level) if cd else def.max_hp

var max_pp: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.max_pp, cd.pp_growth, level) if cd else def.max_pp

var str_stat: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.str_stat, cd.str_growth, level) if cd else def.str_stat

var def_stat: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.def_stat, cd.def_growth, level) if cd else def.def_stat

var psy_stat: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.psy_stat, cd.psy_growth, level) if cd else def.psy_stat

var res_stat: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.res_stat, cd.res_growth, level) if cd else def.res_stat

var spd_stat: int:
	get:
		var cd := _char_def()
		return Progression.grown_stat(def.spd_stat, cd.spd_growth, level) if cd else def.spd_stat

var sigil_type: CombatantDefinition.SigilType:
	get: return def.sigil_type

var ability: Ability:
	get: return (def as CharacterDefinition).ability if def is CharacterDefinition else null

var ai: EnemyAI:
	get: return (def as EnemyDefinition).ai if def is EnemyDefinition else null

var summon: SummonEffect:
	get: return (def as EnemyDefinition).summon if def is EnemyDefinition else null

var xp_reward: int:
	get: return (def as EnemyDefinition).xp_reward if def is EnemyDefinition else 0

var sprite_path: String:
	get: return def.sprite_path

var sprite_vframes: int:
	get: return def.sprite_vframes

# --- Factory ---

static func from_definition(d: CombatantDefinition) -> Combatant:
	var c := Combatant.new()
	c.def = d
	c.current_hp = d.max_hp
	c.current_pp = d.max_pp
	return c


# --- Runtime methods (unchanged) ---

func reset_runtime_state() -> void:
	current_hp = max_hp
	current_pp = max_pp
	atb = 0.0
	limit_gauge = 0.0
	skip_cooldown = 0.0
	active_effects = []
	ai_state = {}


# Set the character's level and full-heal to the new (grown) maxima. Used on
# level-up (PRD R6) and when rebuilding a combatant from saved progression.
func set_level(new_level: int) -> void:
	level = new_level
	current_hp = max_hp
	current_pp = max_pp


func apply_effect(effect: StatusEffect) -> void:
	for existing in active_effects:
		if existing.effect_name == effect.effect_name:
			existing.duration = effect.duration
			return
	active_effects.append(effect)


func tick_effects() -> void:
	var i := active_effects.size() - 1
	while i >= 0:
		active_effects[i].duration -= 1
		if active_effects[i].duration <= 0:
			active_effects.remove_at(i)
		i -= 1


func get_effective_stat(stat: StatusEffect.StatAxis) -> int:
	var base := _base_stat(stat)
	for effect in active_effects:
		if effect.stat == stat:
			base += effect.modifier
	return maxi(0, base)


func _base_stat(stat: StatusEffect.StatAxis) -> int:
	match stat:
		StatusEffect.StatAxis.DEF: return def_stat
		StatusEffect.StatAxis.STR: return str_stat
		StatusEffect.StatAxis.PSY: return psy_stat
		StatusEffect.StatAxis.RES: return res_stat
		StatusEffect.StatAxis.SPD: return spd_stat
		StatusEffect.StatAxis.HP:  return max_hp
	return 0


func tick_atb(delta: float) -> void:
	if is_dead():
		return
	atb = minf(atb + float(spd_stat) * delta * ATB_FILL_RATE, ATB_MAX)


func atb_full() -> bool:
	return atb >= ATB_MAX


func consume_atb() -> void:
	atb = 0.0


func is_dead() -> bool:
	return current_hp <= 0


func is_alive() -> bool:
	return current_hp > 0


func is_skipping() -> bool:
	return skip_cooldown > 0.0


func limit_cap() -> float:
	return LIMIT_CAP_BUREAU if sigil_type == CombatantDefinition.SigilType.BUREAU else LIMIT_MAX


func is_limit_ready() -> bool:
	return limit_gauge >= limit_cap()


func take_damage(amount: int) -> void:
	var i := active_effects.size() - 1
	while i >= 0:
		if active_effects[i].effect_name == "mark_target":
			active_effects.remove_at(i)
		i -= 1
	current_hp = maxi(current_hp - amount, 0)
	var ratio: float = float(amount) / float(max_hp)
	limit_gauge = minf(limit_gauge + ratio * LIMIT_MAX, limit_cap())


func drain_pp(amount: int) -> void:
	# PP drain: what the Bureau does administratively made mechanical
	current_pp = maxi(current_pp - amount, 0)


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)


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


# Single source of truth for the +-10% damage roll. Clamps to a minimum of 1.
static func apply_damage_variance(base: int) -> int:
	return maxi(1, floori(base * randf_range(0.9, 1.1)))


static func calculate_damage(attacker: Combatant, target: Combatant) -> int:
	var atk := attacker.get_effective_stat(StatusEffect.StatAxis.STR)
	var def_ := target.get_effective_stat(StatusEffect.StatAxis.DEF)
	return apply_damage_variance(atk - def_)
