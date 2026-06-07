extends GutTest

var _zone: Area2D
var _player: CharacterBody2D


func before_each() -> void:
	GameState._flags.clear()
	DialogueManager._dialogue_box.dismiss()
	PartyManager.remove_temporary_members()
	BattleParams.return_scene = ""
	BattleParams.enemies = ""
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
	assert_eq(shape_node.position, Vector2(112, 64), "shape must be offset so top-left aligns with Tiled origin")


func test_required_flag_blocks_zone_when_flag_absent() -> void:
	_zone.required_flag = "case_1_beat3_complete"
	_zone._on_body_entered(_player)
	assert_false(_zone._fired)


func test_required_flag_allows_zone_when_flag_set() -> void:
	GameState.set_flag("case_1_beat3_complete", true)
	_zone.required_flag = "case_1_beat3_complete"
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_required_flag_empty_allows_zone_unconditionally() -> void:
	_zone.required_flag = ""
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_forbidden_flag_blocks_zone_when_flag_set() -> void:
	GameState.set_flag("case_1_beat3_complete", true)
	_zone.forbidden_flag = "case_1_beat3_complete"
	_zone._on_body_entered(_player)
	assert_false(_zone._fired)


func test_forbidden_flag_allows_zone_when_flag_absent() -> void:
	_zone.forbidden_flag = "case_1_beat3_complete"
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_forbidden_flag_empty_allows_zone_unconditionally() -> void:
	_zone.forbidden_flag = ""
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_pre_battle_guests_empty_does_not_add_temporary_members() -> void:
	_zone.pre_battle_guests = ""
	_zone._on_dialogue_closed()
	assert_eq(PartyManager._temporary_members.size(), 0)


func test_pre_battle_guests_adds_iris_to_party() -> void:
	_zone.pre_battle_guests = "res://characters/iris.tres"
	_zone._on_dialogue_closed()
	assert_true(PartyManager.has_member("Iris"))


func test_pre_battle_guests_does_not_modify_permanent_members() -> void:
	var before_count: int = PartyManager._permanent_members.size()
	_zone.pre_battle_guests = "res://characters/iris.tres"
	_zone._on_dialogue_closed()
	assert_eq(PartyManager._permanent_members.size(), before_count)


func test_battle_return_scene_sets_battle_params() -> void:
	_zone.battle_return_scene = "res://scenes/world/SprawlSafehouse.tscn"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_scene, "res://scenes/world/SprawlSafehouse.tscn")


func test_battle_return_scene_empty_does_not_overwrite_battle_params() -> void:
	BattleParams.return_scene = "res://scenes/world/SomeOtherScene.tscn"
	_zone.battle_return_scene = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_scene, "res://scenes/world/SomeOtherScene.tscn")


func test_battle_return_spawn_point_defaults_empty() -> void:
	assert_eq(_zone.battle_return_spawn_point, "")


func test_battle_return_spawn_point_sets_battle_params_return_spawn() -> void:
	_zone.battle_return_spawn_point = "battle_return"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_spawn, "battle_return")


func test_pre_battle_enemies_empty_does_not_set_battle_params() -> void:
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "")


func test_pre_battle_enemies_sets_battle_params_enemies() -> void:
	_zone.pre_battle_enemies = "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres")


func test_pre_battle_enemies_empty_does_not_overwrite_existing_battle_params() -> void:
	BattleParams.enemies = "res://characters/enemies/shade.tres"
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "res://characters/enemies/shade.tres")


func test_walk_in_zone_fires_on_body_entered() -> void:
	_zone.required_flag = ""
	_zone._on_body_entered(_player)
	assert_true(_zone._fired)


func test_fire_on_scene_load_defaults_to_false() -> void:
	assert_false(_zone.fire_on_scene_load)


func test_check_load_trigger_fires_when_no_flags_set() -> void:
	_zone._check_load_trigger()
	assert_true(_zone._fired)


func test_check_load_trigger_fires_when_required_flag_set() -> void:
	GameState.set_flag("case_1_beat3_complete", true)
	_zone.required_flag = "case_1_beat3_complete"
	_zone._check_load_trigger()
	assert_true(_zone._fired)


func test_check_load_trigger_blocked_when_required_flag_absent() -> void:
	_zone.required_flag = "case_1_beat3_complete"
	_zone._check_load_trigger()
	assert_false(_zone._fired)


func test_check_load_trigger_blocked_when_forbidden_flag_set() -> void:
	GameState.set_flag("case_1_beat3_complete", true)
	_zone.forbidden_flag = "case_1_beat3_complete"
	_zone._check_load_trigger()
	assert_false(_zone._fired)


func test_check_load_trigger_does_not_double_fire() -> void:
	_zone._fired = true
	_zone._check_load_trigger()
	# monitoring is still true — _fire() returned early
	assert_true(_zone.monitoring)


func test_shape_offset_aligns_topleft_with_tiled_origin() -> void:
	_zone.set_meta("width", 224.0)
	_zone.set_meta("height", 160.0)
	var col_shape := CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	_zone.add_child(col_shape)
	_zone._ready()
	var shape_node: CollisionShape2D = _zone.get_node("CollisionShape2D")
	assert_eq(shape_node.position, Vector2(112.0, 80.0), "offset must be w/2,h/2 so top-left aligns with Tiled origin")
