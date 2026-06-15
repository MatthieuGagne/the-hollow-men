class_name SaveData
extends Resource

## Versioned save container. Party runtime is added in PRD G (#123).

@export var save_version: int = 1
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""
