extends GutTest


func before_each() -> void:
	GameState.clear_flags()


func test_can_trigger_requires_enough_wins() -> void:
	assert_false(BossTrigger.can_trigger(2, 3, false), "fewer than required wins -> no boss")
	assert_true(BossTrigger.can_trigger(3, 3, false), "exactly required wins -> boss unlocks")
	assert_true(BossTrigger.can_trigger(5, 3, false))


func test_can_trigger_blocked_when_complete() -> void:
	assert_false(BossTrigger.can_trigger(3, 3, true), "completed harness must not re-trigger")


func test_default_boss_enemies_is_captain_and_rookie() -> void:
	var bt := BossTrigger.new()
	assert_eq(bt.boss_enemies, "security_captain,security_rookie")
	bt.free()
