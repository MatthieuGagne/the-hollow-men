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


func test_facing_defaults_to_down() -> void:
	assert_eq(Player.facing_from_action("move_down"), Vector2i(0, 1))


func test_facing_from_action_up() -> void:
	assert_eq(Player.facing_from_action("move_up"), Vector2i(0, -1))


func test_facing_from_action_left() -> void:
	assert_eq(Player.facing_from_action("move_left"), Vector2i(-1, 0))


func test_facing_from_action_right() -> void:
	assert_eq(Player.facing_from_action("move_right"), Vector2i(1, 0))


func test_setup_assigns_world_layer() -> void:
	var player := Player.new()
	add_child(player)
	var mock_layer := TileMapLayer.new()
	player.setup(mock_layer)
	assert_eq(player._world_layer, mock_layer)
	player.free()
	mock_layer.free()


func test_dismiss_press_sets_awaiting_release() -> void:
	# When E is pressed (non-echo) while dialogue is open, the dismiss path must
	# set _interact_awaiting_release so the user has to release before re-interacting.
	var player := Player.new()
	add_child(player)
	DialogueManager._dialogue_box.dismiss()  # ensure dialogue box starts idle
	player._input_blocked = true
	player._interact_awaiting_release = false

	var event := InputEventKey.new()
	event.physical_keycode = 69  # E key — mapped to "interact" in project.godot
	event.pressed = true
	event.echo = false
	player._unhandled_input(event)

	assert_true(player._interact_awaiting_release,
		"dismiss press must set _interact_awaiting_release=true")
	player.free()


func test_echo_press_does_not_trigger_dismiss_path() -> void:
	# An echo event (key held) must NOT trigger skip_or_dismiss while dialogue is open.
	# Verified by checking that _interact_awaiting_release stays false — the dismiss
	# path would set it to true after the fix.
	var player := Player.new()
	add_child(player)
	DialogueManager._dialogue_box.dismiss()
	player._input_blocked = true
	player._interact_awaiting_release = false

	var event := InputEventKey.new()
	event.physical_keycode = 69  # E key
	event.pressed = true
	event.echo = true  # echo event — should be ignored
	player._unhandled_input(event)

	assert_false(player._interact_awaiting_release,
		"echo press must NOT set _interact_awaiting_release (dismiss path must be skipped)")
	player.free()
