extends BattleScene


func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("block_captain")))
