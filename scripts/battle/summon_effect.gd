class_name SummonEffect
extends AbilityEffect

# Data-driven reinforcement: names the enemy id to add to the battle.
# Resolves the definition via GameData (no resource paths). battle_scene/AI owns *when*.
@export var enemy_id: String = ""


func make_summon() -> Combatant:
	if enemy_id == "":
		return null
	var d := GameData.get_definition(enemy_id)
	return Combatant.from_definition(d) if d != null else null
