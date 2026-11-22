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


func test_panel_hides_pp_label_for_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.character_name = "NoPP"
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	var panel: Control = _hud._make_panel(c)
	add_child_autofree(panel)
	assert_false(panel.get_node("PPLabel").visible,
		"A character with no PP bar shows no PP value")


func test_panel_shows_pp_label_for_a_normal_character() -> void:
	var d := CharacterDefinition.new()
	d.character_name = "HasPP"
	d.max_hp = 100
	d.max_pp = 40
	var c := Combatant.from_definition(d)
	var panel: Control = _hud._make_panel(c)
	add_child_autofree(panel)
	assert_true(panel.get_node("PPLabel").visible,
		"A character with a PP bar still shows its PP value")
