extends Node2D

@export var battle_background: String = "alley"


func _ready() -> void:
    AudioManager.play_music("res://assets/audio/music/NoirCafe.ogg")
