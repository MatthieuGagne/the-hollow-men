extends GutTest


func test_xp_to_next_level_1_is_base() -> void:
	assert_eq(Progression.xp_to_next(1), 100)


func test_xp_to_next_level_2() -> void:
	# round(100 * 2 ^ 1.5) = round(282.84) = 283
	assert_eq(Progression.xp_to_next(2), 283)


func test_xp_to_next_at_cap_is_zero() -> void:
	assert_eq(Progression.xp_to_next(Progression.MAX_LEVEL), 0,
		"no XP is needed past the level cap")


func test_apply_xp_no_levelup_accumulates() -> void:
	var r := Progression.apply_xp(1, 0, 50)
	assert_eq(r["level"], 1)
	assert_eq(r["xp"], 50)


func test_apply_xp_single_levelup_zeroes_remainder() -> void:
	var r := Progression.apply_xp(1, 0, 100)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 0)


func test_apply_xp_carries_remainder() -> void:
	var r := Progression.apply_xp(1, 0, 120)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 20)


func test_apply_xp_crosses_multiple_levels() -> void:
	# 100 (1->2) + 283 (2->3) = 383 lands exactly at level 3 with 0 leftover
	var r := Progression.apply_xp(1, 0, 383)
	assert_eq(r["level"], 3)
	assert_eq(r["xp"], 0)


func test_apply_xp_clamps_at_max_level() -> void:
	var r := Progression.apply_xp(Progression.MAX_LEVEL, 0, 999999)
	assert_eq(r["level"], Progression.MAX_LEVEL)
	assert_eq(r["xp"], 0, "xp is zeroed at the cap")


func test_grown_stat_level_1_is_base() -> void:
	assert_eq(Progression.grown_stat(100, 10, 1), 100)


func test_grown_stat_scales_linearly_per_level() -> void:
	# 100 + 10 * (3 - 1) = 120
	assert_eq(Progression.grown_stat(100, 10, 3), 120)


func test_apply_xp_from_mid_level_progress_carries() -> void:
	# Starting partway into level 1 (50/100), a 60 gain reaches level 2 with 10 carried.
	var r := Progression.apply_xp(1, 50, 60)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 10)
