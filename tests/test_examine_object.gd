extends GutTest

var _obj: Node2D


func before_each() -> void:
	GameState._flags.clear()
	CellRegistry.clear()
	DialogueManager._dialogue_box.dismiss()
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

	obj.interact()
	DialogueManager.skip_or_dismiss()
	assert_eq(DialogueManager._dialogue_box.get_displayed_text(), "A dusty shelf.")

	obj.free()


func test_interact_with_no_examine_text_does_nothing() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = ""
	add_child(obj)

	obj.interact()
	assert_false(DialogueManager._dialogue_box.visible)

	obj.free()


func test_interact_sets_game_state_flag() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = "A dusty shelf."
	obj.sets_flag = "clue_found"
	add_child(obj)
	obj.interact()
	assert_true(GameState.has_flag("clue_found"))
	obj.free()


func test_interact_does_not_set_flag_when_sets_flag_empty() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = "A dusty shelf."
	obj.sets_flag = ""
	add_child(obj)
	obj.interact()
	assert_eq(GameState._flags.size(), 0)
	obj.free()
