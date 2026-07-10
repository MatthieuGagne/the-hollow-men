extends Node

signal pre_scene_change

const FADE_DURATION: float = 0.3

var _overlay: ColorRect
var pending_spawn_point: String = ""
## Set ONLY by SaveManager.apply() before change_scene(); consumed + reset by
## BaseRoom._resolve_spawn(). Never touched by door transitions (#146).
var pending_position: Vector2 = Vector2.ZERO
var pending_facing: Vector2i = Vector2i(0, 1)
var has_pending_position: bool = false


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_overlay)


func change_scene(path: String, spawn_point: String = "") -> void:
	# Changing to an empty path is always a bug; guard early so we never start
	# a fade/transition that resolves to "res://" and fails (and, in tests, so a
	# leaked coroutine can't fire change_scene_to_file("") into a later test).
	if path.is_empty():
		push_warning("SceneManager.change_scene called with empty path — ignoring")
		return
	pending_spawn_point = spawn_point
	pre_scene_change.emit()
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, FADE_DURATION)
