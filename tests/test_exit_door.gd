extends GutTest

var _door: Area2D
var _player: CharacterBody2D


func before_each() -> void:
	GameState._flags.clear()
	DialogueManager._dialogue_box.dismiss()
	_door = Area2D.new()
	_door.set_script(load("res://scripts/world/exit_door.gd"))
	_player = CharacterBody2D.new()
	_player.set_script(load("res://scripts/world/player.gd"))
	add_child(_door)


func after_each() -> void:
	if is_instance_valid(_door):
		_door.free()
	if is_instance_valid(_player):
		_player.free()
	GameState._flags.clear()


func test_blocked_when_required_flag_absent() -> void:
	_door.required_flag = "vera_lead_obtained"
	_door._on_body_entered(_player)
	assert_true(DialogueManager._dialogue_box.visible)


func test_not_blocked_when_required_flag_present() -> void:
	_door.required_flag = "vera_lead_obtained"
	GameState.set_flag("vera_lead_obtained", true)
	_door._on_body_entered(_player)
	assert_false(DialogueManager._dialogue_box.visible)


func test_ungated_door_always_passes() -> void:
	# required_flag is "" (default) — gate is inactive
	_door._on_body_entered(_player)
	assert_false(DialogueManager._dialogue_box.visible)
