extends GutTest


func before_each() -> void:
	CellRegistry.clear()


func test_register_and_query_occupied() -> void:
	var node := Node.new()
	CellRegistry.register(Vector2i(3, 4), node)
	assert_true(CellRegistry.has(Vector2i(3, 4)))
	node.free()


func test_unregistered_cell_is_empty() -> void:
	assert_false(CellRegistry.has(Vector2i(0, 0)))


func test_get_occupant_returns_node() -> void:
	var node := Node.new()
	CellRegistry.register(Vector2i(1, 2), node)
	assert_eq(CellRegistry.get_occupant(Vector2i(1, 2)), node)
	node.free()


func test_get_occupant_returns_null_when_empty() -> void:
	assert_null(CellRegistry.get_occupant(Vector2i(99, 99)))


func test_unregister_removes_cell() -> void:
	var node := Node.new()
	CellRegistry.register(Vector2i(5, 6), node)
	CellRegistry.unregister(Vector2i(5, 6))
	assert_false(CellRegistry.has(Vector2i(5, 6)))
	node.free()


func test_is_blocked_true_when_occupant_blocks_movement() -> void:
	var node := Node.new()
	node.set_meta("blocks_movement", true)
	CellRegistry.register(Vector2i(2, 2), node)
	assert_true(CellRegistry.is_blocked(Vector2i(2, 2)))
	node.free()


func test_is_blocked_false_when_occupant_does_not_block() -> void:
	var node := Node.new()
	node.set_meta("blocks_movement", false)
	CellRegistry.register(Vector2i(2, 3), node)
	assert_false(CellRegistry.is_blocked(Vector2i(2, 3)))
	node.free()


func test_is_blocked_false_when_empty() -> void:
	assert_false(CellRegistry.is_blocked(Vector2i(0, 0)))


func test_clear_empties_registry() -> void:
	var node := Node.new()
	CellRegistry.register(Vector2i(1, 1), node)
	CellRegistry.clear()
	assert_false(CellRegistry.has(Vector2i(1, 1)))
	node.free()
