extends GutTest

var _npc: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_npc = Node2D.new()
	_npc.set_script(load("res://scripts/world/npc.gd"))
	_npc.position = Vector2(0.0, 0.0)  # tile (0, 0)
	add_child(_npc)


func after_each() -> void:
	if is_instance_valid(_npc):
		_npc.free()
	CellRegistry.clear()


func test_interact_calls_start_dialogue_on_bridge() -> void:
	_npc.yarn_node_id = "iris_intro"

	var scr := GDScript.new()
	scr.source_code = """
extends Node
var _calls: Array[String] = []
func start_dialogue(node_id: String) -> void:
	_calls.append(node_id)
"""
	scr.reload()
	var mock_bridge := Node.new()
	mock_bridge.set_script(scr)
	add_child(mock_bridge)

	_npc.interact(null, mock_bridge)
	assert_eq(mock_bridge._calls, ["iris_intro"])

	mock_bridge.free()


func test_interact_does_nothing_when_bridge_is_null() -> void:
	_npc.yarn_node_id = "iris_intro"
	# Should not crash
	_npc.interact(null, null)
	pass_test("no crash with null bridge")


func test_interact_does_nothing_when_node_id_empty() -> void:
	_npc.yarn_node_id = ""
	var mock_bridge := Node.new()
	add_child(mock_bridge)
	_npc.interact(null, mock_bridge)
	pass_test("no crash with empty yarn_node_id")
	mock_bridge.free()


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
