extends GutTest

var _obj: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_obj = Node2D.new()
	_obj.set_script(load("res://scripts/world/world_object.gd"))
	_obj.position = Vector2(80.0, 64.0)  # tile (5, 4)
	_obj.set_meta("examine_text", "A cluttered desk.")
	_obj.set_meta("object_name", "Desk")
	_obj.set_meta("sprite_frame", 0)
	_obj.set_meta("blocks_movement", true)


func after_each() -> void:
	if is_instance_valid(_obj):
		_obj.free()
	CellRegistry.clear()


func test_get_cell_returns_correct_tile() -> void:
	assert_eq(_obj.get_cell(), Vector2i(5, 4))


func test_get_cell_at_origin_tile() -> void:
	_obj.position = Vector2(0.0, 0.0)
	assert_eq(_obj.get_cell(), Vector2i(0, 0))


func test_properties_read_from_meta_on_ready() -> void:
	add_child(_obj)
	assert_eq(_obj.examine_text, "A cluttered desk.")
	assert_eq(_obj.object_name, "Desk")
	assert_eq(_obj.sprite_frame, 0)


func test_registers_in_cell_registry_on_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.has(Vector2i(5, 4)))
	assert_eq(CellRegistry.get_occupant(Vector2i(5, 4)), _obj)


func test_unregisters_from_cell_registry_on_exit() -> void:
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.has(Vector2i(5, 4)))
