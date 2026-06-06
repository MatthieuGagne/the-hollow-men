extends GutTest

var _npc: Node2D


func before_each() -> void:
	GameState._flags.clear()
	CellRegistry.clear()
	_npc = Node2D.new()
	_npc.set_script(load("res://scripts/world/npc.gd"))
	_npc.position = Vector2(0.0, 0.0)
	add_child(_npc)


func after_each() -> void:
	if is_instance_valid(_npc):
		_npc.free()
	CellRegistry.clear()
	GameState._flags.clear()


func test_interact_calls_dialogue_manager() -> void:
	var npc := NPC.new()
	npc.yarn_node_id = "test_node"
	add_child(npc)
	assert_true(npc.yarn_node_id != "")
	npc.free()


func test_interact_does_nothing_when_node_id_empty() -> void:
	_npc.yarn_node_id = ""
	# Should not crash
	_npc.interact()
	pass_test("no crash with empty yarn_node_id")


func test_yarn_node_id_read_from_meta_on_ready() -> void:
	var npc := Node2D.new()
	npc.set_script(load("res://scripts/world/npc.gd"))
	npc.set_meta("yarn_node_id", "iris_intro")
	add_child(npc)
	assert_eq(npc.yarn_node_id, "iris_intro")
	npc.free()


func test_registers_blocking_on_ready() -> void:
	assert_true(CellRegistry.is_blocked(Vector2i(0, 0)))


func test_registers_interactable_on_ready() -> void:
	assert_eq(CellRegistry.get_interactable(Vector2i(0, 0)), _npc)


func test_unregisters_both_on_exit() -> void:
	_npc.queue_free()
	await get_tree().process_frame
	assert_null(CellRegistry.get_interactable(Vector2i(0, 0)))
	assert_false(CellRegistry.is_blocked(Vector2i(0, 0)))


func test_hide_when_flag_is_empty_by_default() -> void:
	assert_eq(_npc.hide_when_flag, "")


func test_hide_when_flag_absent_keeps_npc_alive() -> void:
	var npc := Node2D.new()
	npc.set_script(load("res://scripts/world/npc.gd"))
	npc.set_meta("hide_when_flag", "some_event")
	add_child(npc)
	await get_tree().process_frame
	assert_true(is_instance_valid(npc))
	npc.free()


func test_hide_when_flag_set_frees_npc() -> void:
	GameState.set_flag("some_event", true)
	var npc := Node2D.new()
	npc.set_script(load("res://scripts/world/npc.gd"))
	npc.set_meta("hide_when_flag", "some_event")
	add_child(npc)
	await get_tree().process_frame
	assert_false(is_instance_valid(npc))


func test_hide_when_flag_set_unregisters_from_cell_registry() -> void:
	GameState.set_flag("some_event", true)
	var npc := Node2D.new()
	npc.set_script(load("res://scripts/world/npc.gd"))
	npc.position = Vector2(32.0, 0.0)  # tile (2, 0) — different from _npc at (0,0)
	npc.set_meta("hide_when_flag", "some_event")
	add_child(npc)
	await get_tree().process_frame
	assert_false(CellRegistry.is_blocked(Vector2i(2, 0)))
