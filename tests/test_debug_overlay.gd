extends GutTest


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
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false
	DebugOverlay._label.text = ""
	DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
	assert_eq(DebugOverlay._label.text, "")


func test_notify_position_updates_label_when_visible() -> void:
	DebugOverlay._visible_flag = true
	DebugOverlay._canvas.visible = true
	DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
	assert_true(DebugOverlay._label.text.contains("100"),
		"label must show x position")
	assert_true(DebugOverlay._label.text.contains("3"),
		"label must show tile x coordinate")
	DebugOverlay._visible_flag = false  # restore
	DebugOverlay._canvas.visible = false


func test_save_and_load_config_round_trip() -> void:
	DebugOverlay._visible_flag = true
	DebugOverlay._save_config()
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false
	DebugOverlay._load_config()
	assert_true(DebugOverlay._visible_flag,
		"after saving true, _load_config must restore true")
	# Cleanup
	DirAccess.remove_absolute("user://debug.cfg")
	DebugOverlay._visible_flag = false
	DebugOverlay._canvas.visible = false


func test_load_config_falls_back_to_project_setting_when_no_file() -> void:
	if FileAccess.file_exists("user://debug.cfg"):
		DirAccess.remove_absolute("user://debug.cfg")
	DebugOverlay._load_config()
	# ProjectSettings default is false
	assert_false(DebugOverlay._visible_flag,
		"without a saved config file, overlay must default to ProjectSettings value (false)")
