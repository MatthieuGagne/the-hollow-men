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
	assert_eq(RandomEncounterController.build_comp("shade", "private_security_guard"),
		"shade,private_security_guard")
