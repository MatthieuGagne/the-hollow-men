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


func test_interact_with_no_dialogue_does_not_block_input() -> void:
	# Regression: _try_interact() must NOT set _input_blocked=true when the
	# interactable's interact() does nothing (no dialogue opened). If it did,
	# _on_dialogue_closed() would never fire and the player would be frozen forever.
	var player := Player.new()
	var layer := TileMapLayer.new()
	# TileMapLayer.local_to_map() requires a TileSet; assign a default 16×16 one.
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	layer.tile_set = tile_set
	add_child(layer)
	add_child(player)
	player.setup(layer)
	# Player snapped to tile center; default _facing is (0,1) → down.
	# Position (8,8) maps to tile (0,0); facing cell = (0,0)+(0,1) = (0,1).
	player.position = Vector2(8.0, 8.0)
	player._input_blocked = false

	# Register a mock interactable that does nothing on interact() (simulates empty yarn_node_id)
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc interact() -> void:\n\tpass\n"
	script.reload()
	var mock_npc := Node.new()
	mock_npc.set_script(script)
	add_child(mock_npc)

	var facing_cell: Vector2i = layer.local_to_map(player.position) + player._facing
	CellRegistry.register_interactable(facing_cell, mock_npc)

	player._try_interact()

	assert_false(player._input_blocked,
		"_input_blocked must stay false when interact() opens no dialogue")

	CellRegistry.unregister_interactable(facing_cell)
	mock_npc.free()
	player.free()
	layer.free()
