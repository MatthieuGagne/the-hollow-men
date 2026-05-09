extends GutTest

var _obj: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_obj = Node2D.new()
	_obj.set_script(load("res://scripts/world/world_object.gd"))
	_obj.position = Vector2(80.0, 64.0)  # tile (5, 4)
	_obj.set_meta("examine_text", "A cluttered desk.")
	_obj.set_meta("object_name", "Desk")
	_obj.set_meta("sprite_texture", "res://assets/objects/desk_placeholder.png")
	_obj.set_meta("blocks_movement", true)
	# tile_cols/tile_rows not set → defaults to 1×1
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	_obj.add_child(sprite)


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
	assert_eq(_obj.sprite_texture, "res://assets/objects/desk_placeholder.png")


func test_single_cell_registers_in_cell_registry_on_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.has(Vector2i(5, 4)))
	assert_eq(CellRegistry.get_occupant(Vector2i(5, 4)), _obj)


func test_multi_cell_registers_all_covered_cells() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	# Desk at (5,4) with tile_cols=3 → covers (5,4), (6,4), (7,4)
	assert_true(CellRegistry.has(Vector2i(5, 4)))
	assert_true(CellRegistry.has(Vector2i(6, 4)))
	assert_true(CellRegistry.has(Vector2i(7, 4)))
	assert_eq(CellRegistry.get_occupant(Vector2i(6, 4)), _obj)


func test_multi_cell_all_covered_cells_are_blocked() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(6, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(7, 4)))


func test_multi_cell_unregisters_all_on_exit() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.has(Vector2i(5, 4)))
	assert_false(CellRegistry.has(Vector2i(6, 4)))
	assert_false(CellRegistry.has(Vector2i(7, 4)))


func test_unregisters_from_cell_registry_on_exit() -> void:
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.has(Vector2i(5, 4)))


func test_is_blocked_true_via_registry_after_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_is_blocked_true_from_export_property_without_preset_meta() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/world_object.gd"))
	obj.position = Vector2(80.0, 64.0)
	obj.blocks_movement = true
	add_child(obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	obj.free()


func test_sprite_texture_loads_texture_on_ready() -> void:
	add_child(_obj)
	var sprite: Sprite2D = _obj.get_node("Sprite2D")
	assert_not_null(sprite, "WorldObject must have a Sprite2D child")
	assert_not_null(sprite.texture, "Sprite2D.texture must be set when sprite_texture meta is a valid path")


func test_empty_sprite_texture_leaves_texture_null() -> void:
	_obj.set_meta("sprite_texture", "")
	add_child(_obj)
	var sprite: Sprite2D = _obj.get_node("Sprite2D")
	assert_not_null(sprite)
	assert_null(sprite.texture, "Sprite2D.texture must remain null when sprite_texture is empty")


func test_interact_with_examine_text_calls_show_text() -> void:
	var obj := WorldObject.new()
	obj.examine_text = "A dusty shelf."
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	mock_box.skip_or_dismiss()
	assert_eq(mock_box.get_displayed_text(), "A dusty shelf.")

	mock_box.free()
	obj.free()


func test_interact_with_no_examine_text_does_nothing() -> void:
	var obj := WorldObject.new()
	obj.examine_text = ""
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	assert_false(mock_box.visible)

	mock_box.free()
	obj.free()
