class_name FlickeringLight
extends PointLight2D

@export var min_energy: float = 0.05
@export var max_energy: float = 1.0
@export var flicker_min_duration: float = 0.02
@export var flicker_max_duration: float = 0.5


func _ready() -> void:
	_flicker()


func _next_target() -> float:
	return randf_range(min_energy, max_energy)


func _next_duration() -> float:
	return randf_range(flicker_min_duration, flicker_max_duration)


func _flicker() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "energy", _next_target(), _next_duration())
	tween.tween_callback(_flicker)
