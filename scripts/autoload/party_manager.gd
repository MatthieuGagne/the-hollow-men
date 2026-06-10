extends Node

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

func _ready() -> void:
	_permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))

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
