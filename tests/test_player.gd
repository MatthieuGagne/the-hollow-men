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
	# (24, 40) is the center of tile (1, 2) — should be unchanged
	assert_eq(Player.snap_to_grid(Vector2(24.0, 40.0), 16), Vector2(24.0, 40.0))


func test_snap_to_grid_snaps_to_tile_center() -> void:
	# (17, 26) is inside tile (1, 1) — snaps to its center (24, 24)
	assert_eq(Player.snap_to_grid(Vector2(17.0, 26.0), 16), Vector2(24.0, 24.0))
