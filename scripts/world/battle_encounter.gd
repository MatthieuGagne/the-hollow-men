extends Area2D

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const DEFAULT_ENEMIES := "res://characters/enemies/shade.tres"

@export var battle_background_override: String = ""
## Comma-separated enemy resource paths for this encounter. Empty falls back to a
## single Shade — set explicitly here, never via BattleScene's read-side default.
@export var enemies: String = ""


func _ready() -> void:
    body_entered.connect(_on_body_entered)


static func _resolve_background_id(override: String, room_bg: String) -> String:
    if override != "":
        return override
    if room_bg != "":
        return room_bg
    return "default"


static func _resolve_enemies(custom: String) -> String:
    return custom if custom != "" else DEFAULT_ENEMIES


func _get_background_id() -> String:
    var room_bg := ""
    var scene := get_tree().current_scene if get_tree() else null
    if scene != null and "battle_background" in scene:
        room_bg = scene.battle_background
    return _resolve_background_id(battle_background_override, room_bg)


func _on_body_entered(_body: Node2D) -> void:
    var return_scene := ""
    var scene := get_tree().current_scene
    if scene != null:
        return_scene = scene.scene_file_path
    BattleContext.configure(_resolve_enemies(enemies), _get_background_id(), return_scene, "")
    SceneManager.change_scene(BATTLE_SCENE)
