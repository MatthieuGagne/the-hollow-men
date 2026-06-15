extends GutTest


func test_no_trigger_during_grace_steps() -> void:
	# steps within the grace window never trigger, even on a low roll
	assert_false(RandomEncounterController.should_trigger(1, 3, 0.25, 0.0))
	assert_false(RandomEncounterController.should_trigger(3, 3, 0.25, 0.0))


func test_trigger_after_grace_when_roll_below_chance() -> void:
	assert_true(RandomEncounterController.should_trigger(4, 3, 0.25, 0.1))


func test_no_trigger_after_grace_when_roll_above_chance() -> void:
	assert_false(RandomEncounterController.should_trigger(4, 3, 0.25, 0.5))


func test_build_comp_joins_two_ids() -> void:
	assert_eq(RandomEncounterController.build_comp("security_rookie", "security_rookie"),
		"security_rookie,security_rookie")


func test_pool_is_security_rookie_only() -> void:
	assert_eq(RandomEncounterController.POOL.size(), 1)
	assert_eq(RandomEncounterController.POOL[0], "security_rookie")


# Regression: the harness return-bookkeeping must run on (re)entry. It lives in
# this controller's _ready (a reliable child-node script) because a script
# override on the instanced room root does not bind. Entering with a pending
# random-win flag set must bump the win counter.
func test_ready_runs_return_bookkeeping_and_bumps_wins() -> void:
	GameState.clear_flags()
	GameState.set_flag(TestRoom.PENDING_RANDOM_FLAG, true)
	var ctrl := RandomEncounterController.new()
	add_child_autofree(ctrl)  # entering the tree triggers _ready
	await wait_frames(1)
	assert_eq(int(GameState.get_flag(TestRoom.WINS_FLAG, 0)), 1,
		"controller._ready must run TestRoom.resolve_return_bookkeeping()")
	GameState.clear_flags()
