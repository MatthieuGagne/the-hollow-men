extends BattleScene

# Smoketest: a caster with a fixed ALL_ALLIES heal in a wounded 3-member party.
# Cast the ability -> every party cursor lights, all allies' HP rises, no lunge.
func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_aoe_healer.tres")))
	PartyManager.add_temporary(Combatant.from_definition(GameData.get_definition("iris")))
	super._ready()
	# Wound the whole party so the AoE heal is visible.
	for member in party:
		member.current_hp = maxi(1, member.max_hp / 3)
		combatant_updated.emit(member)


func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
