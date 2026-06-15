class_name BossTrigger
extends Area2D

## Gated boss-fight trigger in the test room. Once the player has won the required
## number of random fights (and the harness isn't already complete), entering this
## zone adds Iris (level-matched to Reid) and starts the Territory Enforcer fight.
## The Enforcer summons the Block Captain mid-fight via its existing SummonEffect.

const BATTLE_SCENE: String = "res://scenes/battle/BattleScene.tscn"
const WINS_FLAG: String = "test_room_random_wins"
const PENDING_BOSS_FLAG: String = "test_room_pending_boss"
const COMPLETE_FLAG: String = "test_room_harness_complete"

@export var required_wins: int = 3
@export var battle_background: String = "alley"
@export var return_scene: String = ""
@export var return_spawn: String = "default"

var _fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# Pure gate: boss is available once wins meet the requirement and the harness
# isn't already complete.
static func can_trigger(wins: int, required: int, complete: bool) -> bool:
	if complete:
		return false
	return wins >= required


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body is Player:
		return
	var wins := int(GameState.get_flag(WINS_FLAG, 0))
	var complete := bool(GameState.get_flag(COMPLETE_FLAG, false))
	if not can_trigger(wins, required_wins, complete):
		return
	_fired = true
	if not PartyManager.has_member("Iris"):
		PartyManager.add_member_at_level("iris", PartyManager.get_level("reid"))
	GameState.set_flag(PENDING_BOSS_FLAG, true)
	BattleContext.configure("territory_enforcer", battle_background, return_scene, return_spawn)
	SceneManager.change_scene(BATTLE_SCENE)
