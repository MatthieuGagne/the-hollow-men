extends GutTest


func test_scene_manager_is_accessible() -> void:
	assert_not_null(SceneManager)


func test_scene_manager_has_pre_scene_change_signal() -> void:
	assert_true(SceneManager.has_signal("pre_scene_change"))


func test_scene_manager_has_change_scene_method() -> void:
	assert_true(SceneManager.has_method("change_scene"))
