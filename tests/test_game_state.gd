extends GutTest


func before_each() -> void:
	GameState._flags.clear()


func test_set_and_get_flag() -> void:
	GameState.set_flag("met_holloway", true)
	assert_eq(GameState.get_flag("met_holloway"), true)


func test_get_flag_default() -> void:
	assert_eq(GameState.get_flag("missing", false), false)


func test_overwrite_flag() -> void:
	GameState.set_flag("x", 1.0)
	GameState.set_flag("x", 2.0)
	assert_eq(GameState.get_flag("x"), 2.0)


func test_has_flag() -> void:
	assert_false(GameState.has_flag("absent"))
	GameState.set_flag("present", true)
	assert_true(GameState.has_flag("present"))
