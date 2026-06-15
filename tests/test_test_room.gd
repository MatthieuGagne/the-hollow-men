extends GutTest


func before_each() -> void:
	GameState.clear_flags()


func test_returning_from_random_fight_increments_wins_and_clears_pending() -> void:
	GameState.set_flag("test_room_random_wins", 1)
	GameState.set_flag("test_room_pending_random", true)
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins"), 2)
	assert_false(bool(GameState.get_flag("test_room_pending_random")))


func test_first_random_win_initializes_counter() -> void:
	GameState.set_flag("test_room_pending_random", true)
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins"), 1)


func test_returning_from_boss_sets_complete_and_clears_pending() -> void:
	GameState.set_flag("test_room_pending_boss", true)
	TestRoom.resolve_return_bookkeeping()
	assert_true(bool(GameState.get_flag("test_room_harness_complete")))
	assert_false(bool(GameState.get_flag("test_room_pending_boss")))


func test_no_pending_flags_is_noop() -> void:
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins", 0), 0)
	assert_false(bool(GameState.get_flag("test_room_harness_complete", false)))
