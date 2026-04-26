extends GutTest


func test_direction_to_offset_up() -> void:
	assert_eq(Player.direction_to_offset("move_up"), Vector2i(0, -1))


func test_direction_to_offset_down() -> void:
	assert_eq(Player.direction_to_offset("move_down"), Vector2i(0, 1))


func test_direction_to_offset_left() -> void:
	assert_eq(Player.direction_to_offset("move_left"), Vector2i(-1, 0))


func test_direction_to_offset_right() -> void:
	assert_eq(Player.direction_to_offset("move_right"), Vector2i(1, 0))


func test_direction_to_offset_unknown_returns_zero() -> void:
	assert_eq(Player.direction_to_offset(""), Vector2i.ZERO)


func test_snap_to_grid_already_aligned() -> void:
	assert_eq(Player.snap_to_grid(Vector2(32.0, 48.0), 16), Vector2(32.0, 48.0))


func test_snap_to_grid_rounds_to_nearest_tile() -> void:
	# 17.0 / 16 = 1.0625 → rounds to 1 → 16.0
	# 26.0 / 16 = 1.625  → rounds to 2 → 32.0
	assert_eq(Player.snap_to_grid(Vector2(17.0, 26.0), 16), Vector2(16.0, 32.0))
