extends GutTest

var _obj: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_obj = Node2D.new()
	_obj.set_script(load("res://scripts/world/examine_object.gd"))
	_obj.position = Vector2(80.0, 64.0)  # tile (5, 4)


func after_each() -> void:
	if is_instance_valid(_obj):
		_obj.free()
	CellRegistry.clear()


func test_registers_interactable_on_ready() -> void:
	_obj.examine_text = "A dusty shelf."
	add_child(_obj)
	assert_eq(CellRegistry.get_interactable(Vector2i(5, 4)), _obj)


func test_does_not_register_blocking() -> void:
	add_child(_obj)
	assert_false(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_unregisters_interactable_on_exit() -> void:
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_null(CellRegistry.get_interactable(Vector2i(5, 4)))


func test_examine_text_read_from_meta_on_ready() -> void:
	_obj.set_meta("examine_text", "A rusted cabinet.")
	add_child(_obj)
	assert_eq(_obj.examine_text, "A rusted cabinet.")


func test_interact_shows_examine_text() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
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
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = ""
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	assert_false(mock_box.visible)

	mock_box.free()
	obj.free()
