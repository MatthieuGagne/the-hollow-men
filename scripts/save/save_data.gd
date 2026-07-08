class_name SaveData
extends Resource

## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.
## v3 (#123): adds party_runtime — per-member volatile state (HP/PP/limit/status).

@export var save_version: int = 3
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""

## Active permanent-party member ids, in order.
@export var roster: Array[String] = []
## Per-character progression: { "<id>": {"level": int, "xp": int} } for all known characters.
@export var progression: Dictionary = {}
## Per-member volatile runtime state, one entry per permanent member (#123).
@export var party_runtime: Array[PartyMemberSave] = []
