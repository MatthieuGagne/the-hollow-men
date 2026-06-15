class_name SaveData
extends Resource

## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.

@export var save_version: int = 2
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""

## Active permanent-party member ids, in order.
@export var roster: Array[String] = []
## Per-character progression: { "<id>": {"level": int, "xp": int} } for all known characters.
@export var progression: Dictionary = {}
