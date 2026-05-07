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


func test_is_blocked_true_via_registry_after_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_is_blocked_true_from_export_property_without_preset_meta() -> void:
	# Simulates a manually-placed NPC: export property set, no node metadata pre-set.
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/world_object.gd"))
	obj.position = Vector2(80.0, 64.0)
	obj.blocks_movement = true  # export property, not metadata
	add_child(obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	obj.free()


func test_interact_with_examine_text_calls_show_text() -> void:
	var obj := WorldObject.new()
	obj.examine_text = "A dusty shelf."
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	# show_text() starts the typewriter at _char_index=0; skip to reveal full text
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
