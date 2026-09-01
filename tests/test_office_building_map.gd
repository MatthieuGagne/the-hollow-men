extends GutTest

## Guards the Intro Beats 3-6 zone wiring in maps/office_building.tmx.
## The gating chain is: zone 1 (no required_flag, forbidden by its own
## completion flag) -> zone 2 (requires zone 1's flag) -> zone 3 (requires
## zone 2's flag). A break anywhere here is an infinite battle loop or a
## dead end, neither of which any other test would catch.
##
## YATI instances every interaction object (spawn points, NPCs, examinables,
## cutscene zones) as a child of the "Interactions" node, not the map root
## (verified against .godot/imported/office_building.tmx-*.tscn).

const MAP := "res://maps/office_building.tmx"


func _zone_by_dialogue_node(root: Node, node_id: String) -> Node:
	var interactions := root.get_node("Interactions")
	for child: Node in interactions.get_children():
		if child.get_meta("dialogue_node", "") == node_id:
			return child
	return null


func test_dev_marker_is_gone() -> void:
	var packed: PackedScene = load(MAP)
	var root := packed.instantiate()
	var interactions := root.get_node("Interactions")
	assert_not_null(interactions, "map root must have an Interactions node")
	assert_gt(interactions.get_child_count(), 0, "Interactions must contain objects for this test to mean anything")
	for child: Node in interactions.get_children():
		var text: String = child.get_meta("examine_text", "")
		assert_false(text.contains("DEV MARKER"), "the #93 dev marker must be deleted")
	root.free()


func test_backroom_spawn_exists() -> void:
	var packed: PackedScene = load(MAP)
	var root := packed.instantiate()
	var interactions := root.get_node("Interactions")
	var found := false
	for child: Node in interactions.get_children():
		if child.get_meta("spawn_id", "") == "office_backroom":
			found = true
	assert_true(found, "Encounter 1 must have a back-room return spawn")
	root.free()


func test_encounter1_zone_is_self_disarming() -> void:
	var packed: PackedScene = load(MAP)
	var root := packed.instantiate()
	var zone := _zone_by_dialogue_node(root, "iris_intro_encounter")
	assert_not_null(zone, "back-room encounter zone must exist")
	assert_eq(zone.get_meta("required_flag", ""), "",
		"Encounter 1 must fire on first entry with no gate")
	assert_eq(zone.get_meta("forbidden_flag", ""), "office_encounter1_complete",
		"without this the zone re-fires on battle return and loops forever")
	assert_eq(zone.get_meta("pre_battle_guests", ""), "iris")
	assert_eq(zone.get_meta("battle_return_spawn_point", ""), "office_backroom",
		"returning to the lobby would trip Encounter 2 immediately")
	root.free()


func test_encounter2_zone_is_gated_on_encounter1() -> void:
	var packed: PackedScene = load(MAP)
	var root := packed.instantiate()
	var zone := _zone_by_dialogue_node(root, "iris_intro_lobby_ambush")
	assert_not_null(zone, "lobby ambush zone must exist")
	assert_eq(zone.get_meta("required_flag", ""), "office_encounter1_complete",
		"the lobby fight must be blocked until Encounter 1 is won")
	assert_eq(zone.get_meta("forbidden_flag", ""), "office_encounter2_complete")
	assert_eq(zone.get_meta("pre_battle_guests", ""), "iris",
		"BattleScene drops temporaries on victory; Iris must be re-added")
	assert_eq(zone.get_meta("pre_battle_enemies", ""),
		"private_security_guard,security_captain")
	assert_eq(zone.get_meta("battle_return_spawn_point", ""), "office_entrance",
		"Encounter 2 must return the player to the lobby entrance")
	root.free()


func test_exit_zone_is_gated_and_targets_the_bar() -> void:
	var packed: PackedScene = load(MAP)
	var root := packed.instantiate()
	var zone := _zone_by_dialogue_node(root, "iris_intro_exit")
	assert_not_null(zone, "exit zone must exist")
	assert_eq(zone.get_meta("required_flag", ""), "office_encounter2_complete")
	assert_true(zone.get_meta("fire_on_scene_load", false),
		"the player returns from battle already inside this zone")
	assert_eq(zone.get_meta("next_scene", ""), "res://scenes/world/FourWindsBar.tscn")
	assert_eq(zone.get_meta("next_spawn_point", ""), "four_winds_entrance")
	root.free()
