extends GutTest

var _scene: Node2D
var _hud: Control


func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager._permanent_members.append(reid)
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)
	_hud = _scene.get_node("UI/HUD")


func _combatant(pp: int) -> Combatant:
	var d := CharacterDefinition.new()
	d.character_name = "PP%d" % pp
	d.max_hp = 100
	d.max_pp = pp
	return Combatant.from_definition(d)


func test_panel_blanks_pp_text_for_zero_pp_character() -> void:
	var panel: Control = _hud._make_panel(_combatant(0))
	add_child_autofree(panel)
	assert_eq(panel.get_node("PPLabel").text, "",
		"A character with no PP bar shows no PP value")


func test_panel_shows_pp_text_for_a_normal_character() -> void:
	var panel: Control = _hud._make_panel(_combatant(40))
	add_child_autofree(panel)
	assert_eq(panel.get_node("PPLabel").text, "40",
		"A character with a PP bar still shows its PP value")


func test_update_panel_blanks_pp_text_when_rebound_to_zero_pp() -> void:
	var panel: Control = _hud._make_panel(_combatant(40))
	add_child_autofree(panel)
	_hud._update_panel(panel, _combatant(0))
	assert_eq(panel.get_node("PPLabel").text, "",
		"Rebinding a PP panel to a zero-PP character must clear the value")


func test_update_panel_restores_pp_text_when_rebound_to_pp_character() -> void:
	var panel: Control = _hud._make_panel(_combatant(0))
	add_child_autofree(panel)
	_hud._update_panel(panel, _combatant(40))
	assert_eq(panel.get_node("PPLabel").text, "40",
		"Rebinding a blank PP panel to a PP character must show the value")
