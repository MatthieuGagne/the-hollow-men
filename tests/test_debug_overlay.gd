extends GutTest


const _SAVE_SLOT_PATH: String = "user://hollow_men_save_0.tres"


func after_each() -> void:
	if FileAccess.file_exists("user://debug.cfg"):
		DirAccess.remove_absolute("user://debug.cfg")
	_remove_save_slot()
	GameState.clear_flags()


func _remove_save_slot() -> void:
	if FileAccess.file_exists(_SAVE_SLOT_PATH):
		DirAccess.remove_absolute(_SAVE_SLOT_PATH)


func test_debug_overlay_is_accessible() -> void:
	assert_not_null(DebugOverlay)


func test_has_canvas_layer() -> void:
	assert_not_null(DebugOverlay._canvas)


func test_has_label() -> void:
	assert_not_null(DebugOverlay._label)


func test_toggle_flips_visible_flag() -> void:
	var original: bool = DebugOverlay._visible_flag
	DebugOverlay._toggle()
	assert_eq(DebugOverlay._visible_flag, not original)
	DebugOverlay._toggle()  # restore


func test_toggle_updates_canvas_visibility() -> void:
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false
	DebugOverlay._toggle()
	assert_true(DebugOverlay._canvas.visible)
	DebugOverlay._toggle()  # restore


func test_notify_position_no_op_when_hidden() -> void:
	# 100px position, tile (3,4)
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false
	DebugOverlay._label.text = ""
	DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
	assert_eq(DebugOverlay._label.text, "")


func test_notify_position_updates_label_when_visible() -> void:
	# 100px position, tile (3,4)
	DebugOverlay._visible_flag = true
	DebugOverlay._canvas.visible = true
	DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
	assert_true(DebugOverlay._label.text.contains("100"),
		"label must show x position")
	assert_true(DebugOverlay._label.text.contains("3"),
		"label must show tile x coordinate")
	DebugOverlay._visible_flag = false  # restore
	DebugOverlay._canvas.visible = false
	DebugOverlay._label.text = ""


func test_save_and_load_config_round_trip() -> void:
	DebugOverlay._visible_flag = true
	DebugOverlay._save_config()
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false
	DebugOverlay._load_config()
	assert_true(DebugOverlay._visible_flag,
		"after saving true, _load_config must restore true")
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false


func test_load_config_falls_back_to_project_setting_when_no_file() -> void:
	DebugOverlay._load_config()
	# ProjectSettings default is false
	assert_false(DebugOverlay._visible_flag,
		"without a saved config file, overlay must default to ProjectSettings value (false)")
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false


func test_debug_save_emits_and_writes_slot() -> void:
	_remove_save_slot()
	GameState.clear_flags()
	GameState.set_flag("intro_complete", true)
	watch_signals(SaveManager)
	# SaveManager.save() now guards on current_scene being a BaseRoom (#146) —
	# install one so this F5-path test still exercises the real save.
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""
	var prev_scene := get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	DebugOverlay._debug_save()
	get_tree().current_scene = prev_scene
	room.free()
	assert_signal_emitted_with_parameters(SaveManager, "game_saved", [0])
	assert_true(FileAccess.file_exists(_SAVE_SLOT_PATH),
		"debug save must write the slot file")
	_remove_save_slot()
	GameState.clear_flags()


func test_debug_load_missing_save_is_safe_noop() -> void:
	# No save file present -> load() returns false before navigating. No flake.
	_remove_save_slot()
	watch_signals(SaveManager)
	DebugOverlay._debug_load()
	assert_signal_not_emitted(SaveManager, "game_loaded",
		"loading a missing slot must not emit game_loaded or navigate")


func test_debug_new_game_clears_flags() -> void:
	GameState.set_flag("intro_complete", true)
	DebugOverlay._debug_new_game()
	# Kill the SceneManager fade tween so the leaked change_scene coroutine
	# never swaps the runner scene mid-suite. Flags are already cleared.
	for t in get_tree().get_processed_tweens():
		t.kill()
	assert_eq(GameState._flags, {})
	GameState.clear_flags()
