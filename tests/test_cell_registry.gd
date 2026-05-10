extends GutTest


func before_each() -> void:
	CellRegistry.clear()


func test_register_blocking_makes_cell_blocked() -> void:
	var node := Node.new()
	CellRegistry.register_blocking(Vector2i(1, 1), node)
	assert_true(CellRegistry.is_blocked(Vector2i(1, 1)))
	node.free()


func test_unregister_blocking_removes_block() -> void:
	var node := Node.new()
	CellRegistry.register_blocking(Vector2i(2, 2), node)
	CellRegistry.unregister_blocking(Vector2i(2, 2))
	assert_false(CellRegistry.is_blocked(Vector2i(2, 2)))
	node.free()


func test_is_blocked_false_when_empty() -> void:
	assert_false(CellRegistry.is_blocked(Vector2i(0, 0)))


func test_register_interactable_can_be_retrieved() -> void:
	var node := Node.new()
	CellRegistry.register_interactable(Vector2i(3, 3), node)
	assert_eq(CellRegistry.get_interactable(Vector2i(3, 3)), node)
	node.free()


func test_unregister_interactable_removes_entry() -> void:
	var node := Node.new()
	CellRegistry.register_interactable(Vector2i(4, 4), node)
	CellRegistry.unregister_interactable(Vector2i(4, 4))
	assert_null(CellRegistry.get_interactable(Vector2i(4, 4)))
	node.free()


func test_get_interactable_returns_null_when_empty() -> void:
	assert_null(CellRegistry.get_interactable(Vector2i(9, 9)))


func test_dual_registration_same_cell_both_present() -> void:
	var node := Node.new()
	CellRegistry.register_blocking(Vector2i(5, 5), node)
	CellRegistry.register_interactable(Vector2i(5, 5), node)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 5)))
	assert_eq(CellRegistry.get_interactable(Vector2i(5, 5)), node)
	node.free()


func test_blocking_and_interactable_are_independent() -> void:
	var blocker := Node.new()
	var trigger := Node.new()
	CellRegistry.register_blocking(Vector2i(6, 6), blocker)
	CellRegistry.register_interactable(Vector2i(7, 7), trigger)
	assert_true(CellRegistry.is_blocked(Vector2i(6, 6)))
	assert_false(CellRegistry.is_blocked(Vector2i(7, 7)))
	assert_null(CellRegistry.get_interactable(Vector2i(6, 6)))
	assert_eq(CellRegistry.get_interactable(Vector2i(7, 7)), trigger)
	blocker.free()
	trigger.free()


func test_unregister_blocking_does_not_affect_interactable() -> void:
	var node := Node.new()
	CellRegistry.register_blocking(Vector2i(8, 8), node)
	CellRegistry.register_interactable(Vector2i(8, 8), node)
	CellRegistry.unregister_blocking(Vector2i(8, 8))
	assert_false(CellRegistry.is_blocked(Vector2i(8, 8)))
	assert_eq(CellRegistry.get_interactable(Vector2i(8, 8)), node)
	node.free()


func test_clear_resets_both_dictionaries() -> void:
	var node := Node.new()
	CellRegistry.register_blocking(Vector2i(1, 1), node)
	CellRegistry.register_interactable(Vector2i(2, 2), node)
	CellRegistry.clear()
	assert_false(CellRegistry.is_blocked(Vector2i(1, 1)))
	assert_null(CellRegistry.get_interactable(Vector2i(2, 2)))
	node.free()
