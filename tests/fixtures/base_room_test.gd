## Base class for tests that need a BaseRoom installed as the current scene.
##
## SaveManager.save() returns false unless get_tree().current_scene is a
## BaseRoom (guard added in #146), so every test that exercises the save path
## must install one. Extends GutTest so subclasses inherit both the GUT
## assertion API and this fixture.
class_name BaseRoomTest
extends GutTest

var _room: BaseRoom = null
var _prev_scene: Node = null


func _install_base_room() -> BaseRoom:
	assert(_room == null,
		"_install_base_room() called twice without an intervening _teardown_base_room() — " +
		"the first room's _prev_scene would be clobbered and leaked")
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""  # set BEFORE add: _ready() runs on entering the tree
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_room = room
	return room


func _teardown_base_room() -> void:
	if _room == null:
		return
	get_tree().current_scene = _prev_scene
	_room.free()
	_room = null
	_prev_scene = null
