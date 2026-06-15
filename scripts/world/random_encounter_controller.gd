class_name RandomEncounterController
extends Node

## Drives step-based random encounters in the test room. Connects to the sibling
## Player's `stepped` signal; after a grace window, each step has a chance to start
## a battle against 2 enemies randomly drawn from POOL. Stops once the required
## number of random victories has been reached (boss phase).

const POOL: Array[String] = ["security_rookie"]
const GRACE_STEPS: int = 3
const TRIGGER_CHANCE: float = 0.25
const BATTLE_SCENE: String = "res://scenes/battle/BattleScene.tscn"
const WINS_FLAG: String = "test_room_random_wins"
const PENDING_FLAG: String = "test_room_pending_random"

@export var battle_background: String = "alley"
@export var return_scene: String = ""
@export var return_spawn: String = "default"
@export var required_wins: int = 3

var _steps: int = 0


func _ready() -> void:
	var player := get_parent().get_node_or_null("Player")
	if player != null and player.has_signal("stepped"):
		player.stepped.connect(_on_stepped)


# Pure trigger decision: no trigger within the grace window; past it, trigger when
# the roll falls under the chance.
static func should_trigger(steps: int, grace: int, chance: float, roll: float) -> bool:
	if steps <= grace:
		return false
	return roll < chance


static func build_comp(a: String, b: String) -> String:
	return "%s,%s" % [a, b]


func _on_stepped(_cell: Vector2i) -> void:
	if int(GameState.get_flag(WINS_FLAG, 0)) >= required_wins:
		return  # random phase over — boss is available
	_steps += 1
	if not should_trigger(_steps, GRACE_STEPS, TRIGGER_CHANCE, randf()):
		return
	_steps = 0
	var comp := build_comp(POOL[randi() % POOL.size()], POOL[randi() % POOL.size()])
	GameState.set_flag(PENDING_FLAG, true)
	BattleContext.configure(comp, battle_background, return_scene, return_spawn)
	SceneManager.change_scene(BATTLE_SCENE)
