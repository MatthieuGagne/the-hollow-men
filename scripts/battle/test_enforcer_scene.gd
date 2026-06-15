extends BattleScene

# A 2-member party outnumbers the lone Enforcer, so its data-driven Call Backup
# (SummonEffect -> Block Captain) fires mid-fight.
func _ready() -> void:
	PartyManager.add_temporary(Combatant.from_definition(GameData.get_definition("iris")))
	super._ready()


func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("territory_enforcer")))
