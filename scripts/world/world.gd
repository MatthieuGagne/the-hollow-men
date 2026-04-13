extends Node2D

enum Mode { INVESTIGATION, HOT_ZONE, RUINS }

# Encounters per step, per mode
const ENCOUNTER_RATE: Dictionary = {
	Mode.INVESTIGATION: 0.0,
	Mode.HOT_ZONE: 0.02,
	Mode.RUINS: 0.04,
}

var _mode: Mode = Mode.INVESTIGATION

@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_apply_mode(_mode)


# Called by area triggers embedded in the Tiled map (via TileMap metadata or Area2D nodes)
func set_mode(new_mode: Mode) -> void:
	if new_mode == _mode:
		return
	_mode = new_mode
	_apply_mode(_mode)


func _apply_mode(mode: Mode) -> void:
	# TODO: crossfade audio layers based on mode
	pass


# Called by the Player node on each tile step
func on_player_stepped() -> void:
	var rate: float = ENCOUNTER_RATE.get(_mode, 0.0)
	if rate > 0.0 and randf() < rate:
		_trigger_encounter()


func _trigger_encounter() -> void:
	# Flash → palette invert → load BattleScene
	var tween := create_tween()
	# White flash via a full-screen ColorRect (see UI scene)
	# TODO: get flash overlay from UI and animate it
	tween.tween_callback(_load_battle_scene)


func _load_battle_scene() -> void:
	# TODO: pass current enemy table to BattleScene
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")
