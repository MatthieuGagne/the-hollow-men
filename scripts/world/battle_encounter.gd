extends Area2D

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"


func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
    SceneManager.change_scene(BATTLE_SCENE)
