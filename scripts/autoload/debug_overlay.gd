extends Node

const CONFIG_PATH: String = "user://debug.cfg"
const SETTING_KEY: String = "debug/overlay_enabled"

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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_toggle()


func notify_position(pos: Vector2, tile: Vector2i) -> void:
	if not _visible_flag:
		return
	var scene_name: String = ""
	if get_tree().current_scene != null:
		scene_name = get_tree().current_scene.name
	_label.text = "pos: (%.0f, %.0f)\ntile: %s\nscene: %s" % [pos.x, pos.y, tile, scene_name]
