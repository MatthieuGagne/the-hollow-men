extends Node

signal pre_scene_change

const FADE_DURATION: float = 0.3

var _overlay: ColorRect


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_overlay)


func change_scene(path: String) -> void:
	pre_scene_change.emit()
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, FADE_DURATION)
