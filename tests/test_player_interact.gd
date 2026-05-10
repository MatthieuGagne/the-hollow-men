extends GutTest


func test_get_interactable_exists_on_cell_registry() -> void:
	assert_true(CellRegistry.has_method("get_interactable"), \
		"CellRegistry must expose get_interactable()")


func test_examine_object_has_interact_method() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/examine_object.gd"))
	assert_true(obj.has_method("interact"), "ExamineObject must have interact()")
	obj.free()
