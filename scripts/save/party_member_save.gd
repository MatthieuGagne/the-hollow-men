class_name PartyMemberSave
extends Resource

## Slim snapshot of one permanent party member's volatile runtime state (#123).
## Ephemeral fields (atb, skip_cooldown, ai_state) are deliberately excluded, so
## they reset to defaults on load. active_effects serialize natively as inline
## StatusEffect sub-resources (durations preserved) — no manual rebuild needed.

@export var definition_id: String = ""
@export var current_hp: int = 0
@export var current_pp: int = 0
@export var limit_gauge: float = 0.0
@export var active_effects: Array[StatusEffect] = []
