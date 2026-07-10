class_name SaveData
extends Resource

## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.
## v3 (#123): adds party_runtime — per-member volatile state (HP/PP/limit/status).
## v4 (#146): adds player_position/player_facing/has_player_position — exact restore.

@export var save_version: int = 4
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""

## Active permanent-party member ids, in order.
@export var roster: Array[String] = []
## Per-character progression: { "<id>": {"level": int, "xp": int} } for all known characters.
@export var progression: Dictionary = {}
## Per-member volatile runtime state, one entry per permanent member (#123).
@export var party_runtime: Array[PartyMemberSave] = []
## Exact player location at save time (#146). has_player_position is false for
## legacy saves (v3 and earlier) → BaseRoom falls back to default_spawn.
@export var player_position: Vector2 = Vector2.ZERO
@export var player_facing: Vector2i = Vector2i(0, 1)
@export var has_player_position: bool = false
