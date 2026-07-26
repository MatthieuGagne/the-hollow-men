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


func test_narration_defaults_to_false() -> void:
	add_child(_obj)
	assert_false(_obj.narration)


func test_narration_read_from_meta_on_ready() -> void:
	_obj.set_meta("narration", true)
	add_child(_obj)
	assert_true(_obj.narration)


func test_interact_with_narration_renders_italic() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = "Active when it shouldn't be."
	obj.narration = true
	add_child(obj)

	obj.interact()
	DialogueManager.skip_or_dismiss()
	assert_true(DialogueManager._dialogue_box._is_narration, "narration mode must set _is_narration")
	assert_eq(DialogueManager._dialogue_box.get_displayed_text(), "Active when it shouldn't be.")

	obj.free()


func test_interact_without_narration_is_plain_text() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = "A dusty shelf."
	obj.narration = false
	add_child(obj)

	obj.interact()
	DialogueManager.skip_or_dismiss()
	assert_false(DialogueManager._dialogue_box._is_narration, "default must stay plain text")

	obj.free()


func test_narration_still_sets_flag() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	obj.examine_text = "Active when it shouldn't be."
	obj.narration = true
	obj.sets_flag = "ley_terminal_noticed"
	add_child(obj)
	obj.interact()
	assert_true(GameState.has_flag("ley_terminal_noticed"))
	obj.free()


func test_sprite_texture_defaults_to_empty() -> void:
	add_child(_obj)
	assert_eq(_obj.sprite_texture, "")


func test_sprite_texture_read_from_meta_on_ready() -> void:
	_obj.set_meta("sprite_texture", "res://assets/objects/notice_placeholder.png")
	add_child(_obj)
	assert_eq(_obj.sprite_texture, "res://assets/objects/notice_placeholder.png")


func test_sprite_texture_loads_into_sprite_node() -> void:
	var obj := preload("res://scenes/world/ExamineObject.tscn").instantiate()
	obj.position = Vector2(80.0, 64.0)
	obj.set_meta("sprite_texture", "res://assets/objects/notice_placeholder.png")
	add_child(obj)
	var spr: Sprite2D = obj.get_node("Sprite2D")
	assert_not_null(spr.texture, "sprite_texture must be loaded into the Sprite2D")
	obj.free()


func test_no_sprite_texture_leaves_texture_null() -> void:
	var obj := preload("res://scenes/world/ExamineObject.tscn").instantiate()
	obj.position = Vector2(80.0, 64.0)
	add_child(obj)
	var spr: Sprite2D = obj.get_node("Sprite2D")
	assert_null(spr.texture, "an examinable with no sprite_texture must stay invisible")
	obj.free()
