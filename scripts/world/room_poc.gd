extends Node2D

@export var battle_background: String = "alley"


func _ready() -> void:
    AudioManager.play_music("res://assets/audio/music/NoirCafe.ogg")
    $Player.setup($"room_poc/World")
    DialogueManager.dialogue_opened.connect($Player._on_dialogue_opened)
    DialogueManager.dialogue_closed.connect($Player._on_dialogue_closed)
