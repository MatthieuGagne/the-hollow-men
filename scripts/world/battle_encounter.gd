extends Area2D

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"

@export var battle_background_override: String = ""


func _ready() -> void:
    body_entered.connect(_on_body_entered)


static func _resolve_background_id(override: String, room_bg: String) -> String:
    if override != "":
        return override
    if room_bg != "":
        return room_bg
    return "default"


func _get_background_id() -> String:
    var room_bg := ""
    var scene := get_tree().current_scene
    if "battle_background" in scene:
        room_bg = scene.battle_background
    return _resolve_background_id(battle_background_override, room_bg)


func _on_body_entered(_body: Node2D) -> void:
    BattleParams.background_id = _get_background_id()
    SceneManager.change_scene(BATTLE_SCENE)
