extends Node

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

# Per-character progression for ALL known player characters, keyed by id:
#   { "<id>": {"level": int, "xp": int} }
# Tracked even for characters not currently in the party (PRD R1).
var _progression: Dictionary = {}


func _ready() -> void:
	reset_to_new_game()


func _seed_progression() -> void:
	for id: String in GameData.get_player_character_ids():
		if not _progression.has(id):
			_progression[id] = {"level": 1, "xp": 0}


# Wipe all party runtime to a clean new-game state: no progression, Reid-only
# roster at Lv1. Called on boot and by SaveManager.new_game().
func reset_to_new_game() -> void:
	_permanent_members.clear()
	_temporary_members.clear()
	_progression.clear()
	_seed_progression()
	_permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))


# --- Roster ---

func add_member(combatant: Combatant) -> void:
	_permanent_members.append(combatant)


func add_temporary(combatant: Combatant) -> void:
	_temporary_members.append(combatant)


func remove_temporary_members() -> void:
	_temporary_members.clear()


func get_active_members() -> Array[Combatant]:
	var result: Array[Combatant] = []
	result.append_array(_permanent_members)
	result.append_array(_temporary_members)
	return result


func has_member(character_name: String) -> bool:
	for member in get_active_members():
		if member.character_name == character_name:
			return true
	return false


# Add a permanent member at a specific level (level-matched joins, e.g. Iris at
# Reid's level). Seeds the progression store and full-heals the new combatant.
func add_member_at_level(id: String, level: int) -> void:
	set_progression(id, level, 0)
	var c := Combatant.from_definition(GameData.get_definition(id))
	c.set_level(level)
	_permanent_members.append(c)


# --- Progression ---

func get_level(id: String) -> int:
	return _progression.get(id, {"level": 1, "xp": 0})["level"]


func get_xp(id: String) -> int:
	return _progression.get(id, {"level": 1, "xp": 0})["xp"]


func set_progression(id: String, level: int, xp: int) -> void:
	_progression[id] = {"level": level, "xp": xp}


# Award `amount` XP to each given (alive) member. Updates the store and syncs the
# live combatant's level, full-healing on a level-up (PRD R5/R6). Returns one
# {"name": String, "to": int} entry per member who leveled up.
func award_xp(members: Array[Combatant], amount: int) -> Array[Dictionary]:
	var leveled: Array[Dictionary] = []
	for m: Combatant in members:
		var rec: Dictionary = _progression.get(m.id, {"level": 1, "xp": 0})
		var before: int = rec["level"]
		var result := Progression.apply_xp(rec["level"], rec["xp"], amount)
		_progression[m.id] = result
		if result["level"] > before:
			m.set_level(result["level"])
			leveled.append({"name": m.character_name, "to": result["level"]})
		else:
			m.level = result["level"]
	return leveled


# --- Save/restore ---

func snapshot_progression() -> Dictionary:
	return _progression.duplicate(true)


func restore_progression(data: Dictionary) -> void:
	_seed_progression()  # ensure every known character has a Lv 1 baseline
	for id: String in data:
		_progression[id] = {"level": data[id]["level"], "xp": data[id]["xp"]}


func snapshot_roster() -> Array[String]:
	var ids: Array[String] = []
	for m: Combatant in _permanent_members:
		ids.append(m.id)
	return ids


# Rebuild the permanent roster from stored ids at their stored levels. An empty
# roster (legacy save) falls back to Reid. Call AFTER restore_progression().
func restore_roster(ids: Array) -> void:
	_permanent_members.clear()
	_temporary_members.clear()
	var effective: Array = ids if not ids.is_empty() else ["reid"]
	for id: String in effective:
		var c := Combatant.from_definition(GameData.get_definition(id))
		c.set_level(get_level(id))
		_permanent_members.append(c)


# Snapshot volatile runtime state (HP/PP/limit/status) for each permanent member.
# Ephemeral fields (atb, skip_cooldown, ai_state) are intentionally excluded, so
# they reset to defaults on the next load.
func snapshot_party_runtime() -> Array[PartyMemberSave]:
	var result: Array[PartyMemberSave] = []
	for m: Combatant in _permanent_members:
		var pms := PartyMemberSave.new()
		pms.definition_id = m.id
		pms.current_hp = m.current_hp
		pms.current_pp = m.current_pp
		pms.limit_gauge = m.limit_gauge
		pms.active_effects = m.active_effects.duplicate()
		result.append(pms)
	return result


# Overlay saved runtime state onto already-rebuilt permanent members, matched by
# definition_id. Call AFTER restore_roster(). Entries with no matching member are
# skipped; members with no entry keep their full-HP rebuilt state (legacy saves).
func restore_party_runtime(runtime: Array) -> void:
	for entry: PartyMemberSave in runtime:
		for m: Combatant in _permanent_members:
			if m.id == entry.definition_id:
				m.current_hp = entry.current_hp
				m.current_pp = entry.current_pp
				m.limit_gauge = entry.limit_gauge
				m.active_effects = entry.active_effects
				break
