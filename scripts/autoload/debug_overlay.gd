extends Node

const CONFIG_PATH: String = "user://debug.cfg"
const SETTING_KEY: String = "debug/overlay_enabled"
const SAVE_SLOT: int = 0

var _visible_flag: bool = false
var _canvas: CanvasLayer
var _label: Label


func _ready() -> void:
	_setup_ui()
	_load_config()


func _setup_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	_label = Label.new()
	_label.position = Vector2(4, 4)
	_label.add_theme_font_size_override("font_size", 8)
	_canvas.add_child(_label)
	_canvas.visible = false


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_visible_flag = cfg.get_value("debug", "overlay_enabled", false)
	else:
		_visible_flag = ProjectSettings.get_setting(SETTING_KEY, false)
	_canvas.visible = _visible_flag


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("debug", "overlay_enabled", _visible_flag)
	cfg.save(CONFIG_PATH)


func _toggle() -> void:
	_visible_flag = not _visible_flag
	_canvas.visible = _visible_flag
	_save_config()


func _debug_save() -> void:
	var scene := _current_scene_path()
	var ok := SaveManager.save(SAVE_SLOT)
	print("[debug] save slot %d: %s (scene=%s)" % [SAVE_SLOT, "OK" if ok else "FAILED", scene])


func _debug_load() -> void:
	if SaveManager.load(SAVE_SLOT):
		print("[debug] loaded slot %d (scene=%s)" % [SAVE_SLOT, _current_scene_path()])
	else:
		print("[debug] no save in slot %d" % SAVE_SLOT)


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current else "<none>"


func _debug_new_game() -> void:
	SaveManager.new_game()
	print("[debug] new game")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_toggle()
	elif event.is_action_pressed("debug_save"):
		_debug_save()
	elif event.is_action_pressed("debug_load"):
		_debug_load()
	elif event.is_action_pressed("debug_new_game"):
		_debug_new_game()


func notify_position(pos: Vector2, tile: Vector2i) -> void:
	if not _visible_flag:
		return
	var scene_name: String = ""
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name
	_label.text = "pos: (%.0f, %.0f)\ntile: %s\nscene: %s" % [pos.x, pos.y, tile, scene_name]
