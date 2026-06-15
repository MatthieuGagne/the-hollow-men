class_name TestRoom
extends BaseRoom

## Experience-loop harness room. On (re)entry — i.e. returning from a won battle —
## it reconciles the harness flags: a pending random win bumps the win counter;
## a pending boss win marks the harness complete. A victory is the only way back
## to this room (defeat shows the defeat menu), so a set pending flag means a win.

const WINS_FLAG: String = "test_room_random_wins"
const PENDING_RANDOM_FLAG: String = "test_room_pending_random"
const PENDING_BOSS_FLAG: String = "test_room_pending_boss"
const COMPLETE_FLAG: String = "test_room_harness_complete"


func _ready() -> void:
	resolve_return_bookkeeping()
	super._ready()


static func resolve_return_bookkeeping() -> void:
	if bool(GameState.get_flag(PENDING_RANDOM_FLAG, false)):
		GameState.set_flag(PENDING_RANDOM_FLAG, false)
		GameState.set_flag(WINS_FLAG, int(GameState.get_flag(WINS_FLAG, 0)) + 1)
	if bool(GameState.get_flag(PENDING_BOSS_FLAG, false)):
		GameState.set_flag(PENDING_BOSS_FLAG, false)
		GameState.set_flag(COMPLETE_FLAG, true)
