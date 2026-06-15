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


func test_clear_flags_empties_store() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.clear_flags()
	assert_eq(GameState._flags, {})


func test_snapshot_returns_independent_copy() -> void:
	GameState.set_flag("intro_complete", true)
	var snap := GameState.snapshot_flags()
	GameState.set_flag("intro_complete", false)
	assert_eq(snap["intro_complete"], true,
		"snapshot must not reflect later mutations")


func test_restore_replaces_flags_with_copy() -> void:
	GameState.set_flag("stale", true)
	var source := {"intro_complete": true}
	GameState.restore_flags(source)
	assert_false(GameState.has_flag("stale"))
	assert_eq(GameState.get_flag("intro_complete"), true)
	source["intro_complete"] = false
	assert_eq(GameState.get_flag("intro_complete"), true,
		"restore must deep-copy, not alias the source dict")
