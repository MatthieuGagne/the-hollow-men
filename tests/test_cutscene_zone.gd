extends GutTest

var _zone: Area2D
var _player: CharacterBody2D


func before_each() -> void:
	GameState._flags.clear()
	DialogueManager._dialogue_box.dismiss()
	_zone = Area2D.new()
	_zone.set_script(load("res://scripts/world/cutscene_zone.gd"))
	_player = CharacterBody2D.new()
	_player.set_script(load("res://scripts/world/player.gd"))
	add_child(_zone)
	add_child(_player)


func after_each() -> void:
	if is_instance_valid(_zone):
		_zone.free()
	if is_instance_valid(_player):
		_player.free()
	GameState._flags.clear()


func test_zone_is_area2d() -> void:
	assert_true(_zone is Area2D)


func test_dialogue_node_defaults_to_empty() -> void:
	assert_eq(_zone.dialogue_node, "")


func test_next_scene_defaults_to_empty() -> void:
	assert_eq(_zone.next_scene, "")


func test_fired_starts_false() -> void:
	assert_false(_zone._fired)
