extends BattleScene

# Smoketest: a caster with a switchable ONE_ALLY heal in a wounded 3-member party.
# In SELECTING_ALLY, press right to expand the cursor to the whole party (heal all)
# and left to collapse back to a single ally. Single heals one; expanded heals all.
func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_switch_healer.tres")))
	PartyManager.add_temporary(Combatant.from_definition(GameData.get_definition("iris")))
	super._ready()
	# Wound the whole party so the heal (single or all) is visible.
	for member in party:
		member.current_hp = maxi(1, member.max_hp / 3)
		combatant_updated.emit(member)


func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
