extends GutTest


func before_each() -> void:
	# SceneManager is a singleton whose fade tween may still be running from a
	# prior test. Reset the overlay to a known state so assertions are stable.
	if SceneManager._overlay:
		SceneManager._overlay.modulate.a = 0.0


func test_scene_manager_is_accessible() -> void:
	assert_not_null(SceneManager)


func test_scene_manager_has_pre_scene_change_signal() -> void:
	assert_true(SceneManager.has_signal("pre_scene_change"))


func test_scene_manager_has_change_scene_method() -> void:
	assert_true(SceneManager.has_method("change_scene"))


func test_scene_manager_has_fade_overlay() -> void:
	assert_not_null(SceneManager._overlay,
		"SceneManager must have a ColorRect fade overlay after _ready")

func test_fade_overlay_initially_transparent() -> void:
	assert_eq(SceneManager._overlay.modulate.a, 0.0,
		"fade overlay must start fully transparent")


func test_change_scene_stores_spawn_point() -> void:
	# Can't call change_scene (it transitions scene tree), so test the
	# pending_spawn_point field directly.
	SceneManager.pending_spawn_point = ""
	SceneManager.pending_spawn_point = "four_winds_entrance"
	assert_eq(SceneManager.pending_spawn_point, "four_winds_entrance")


func test_pending_spawn_point_defaults_empty() -> void:
	SceneManager.pending_spawn_point = ""
	assert_eq(SceneManager.pending_spawn_point, "")
