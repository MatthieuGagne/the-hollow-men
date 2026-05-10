extends GutTest

var _obj: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_obj = Node2D.new()
	_obj.set_script(load("res://scripts/world/world_object.gd"))
	_obj.position = Vector2(80.0, 64.0)  # tile (5, 4)
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
	assert_eq(_obj.object_name, "Desk")
	assert_eq(_obj.sprite_texture, "res://assets/objects/desk_placeholder.png")


func test_single_cell_blocks_on_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_multi_cell_blocks_all_covered_cells_on_ready() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(6, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(7, 4)))


func test_unblocks_cell_on_exit() -> void:
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_multi_cell_unblocks_all_on_exit() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.is_blocked(Vector2i(5, 4)))
	assert_false(CellRegistry.is_blocked(Vector2i(6, 4)))
	assert_false(CellRegistry.is_blocked(Vector2i(7, 4)))


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
