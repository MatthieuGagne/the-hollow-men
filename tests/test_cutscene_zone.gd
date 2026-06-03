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


func test_non_player_body_does_not_set_fired() -> void:
	var other := CharacterBody2D.new()
	add_child_autofree(other)
	_zone._on_body_entered(other)
	assert_false(_zone._fired)


func test_player_body_sets_fired() -> void:
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_player_body_with_empty_dialogue_node_does_not_crash() -> void:
	_zone.dialogue_node = ""
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_player_body_disables_monitoring_after_deferred() -> void:
	_zone._on_body_entered(_player)
	await get_tree().process_frame
	assert_false(_zone.monitoring)


func test_second_entry_does_not_reset_fired() -> void:
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_on_dialogue_closed_with_empty_next_scene_does_not_crash() -> void:
	_zone.next_scene = ""
	_zone._on_dialogue_closed()
	assert_true(true)  # assert_true(true) is the GUT idiom for "assert no exception thrown"


func test_shape_resizes_from_meta_in_ready() -> void:
	_zone.set_meta("width", 224.0)
	_zone.set_meta("height", 128.0)
	var col_shape := CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	_zone.add_child(col_shape)
	_zone._ready()
	var shape_node: CollisionShape2D = _zone.get_node("CollisionShape2D")
	var rect: RectangleShape2D = shape_node.shape as RectangleShape2D
	assert_eq(rect.size, Vector2(224, 128))
