extends Node2D

signal battle_ended(victory: bool)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED }

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var _state: BattleState = BattleState.TICKING
var _active: Combatant = null


func _ready() -> void:
	# TODO: receive party + enemy data from World on scene load
	pass


func _process(delta: float) -> void:
	if _state != BattleState.TICKING:
		return

	_tick_atb(delta)
	_check_win_loss()


func _tick_atb(delta: float) -> void:
	for combatant in party + enemies:
		combatant.tick_atb(delta)

	# First combatant with full ATB acts next (player-controlled priority)
	for combatant in party:
		if combatant.atb_full() and not combatant.is_dead():
			_begin_player_turn(combatant)
			return

	for combatant in enemies:
		if combatant.atb_full() and not combatant.is_dead():
			_begin_enemy_turn(combatant)
			return


func _begin_player_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.AWAITING_INPUT
	# TODO: notify HUD to open action menu for this combatant


func _begin_enemy_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.ANIMATING
	# TODO: run enemy AI, then call _end_turn()
	_end_turn()


func execute_action(action: Dictionary) -> void:
	# Called by HUD when player selects an action
	# action = { type: "attack"|"ability"|"item"|"limit", target: Combatant, ... }
	_state = BattleState.ANIMATING
	# TODO: resolve action, play animation, apply effects
	_end_turn()


func _end_turn() -> void:
	if _active:
		_active.consume_atb()
		_active = null
	_state = BattleState.TICKING


func _check_win_loss() -> void:
	var all_enemies_dead := enemies.all(func(e): return e.is_dead())
	var all_party_dead := party.all(func(p): return p.is_dead())

	if all_enemies_dead:
		_state = BattleState.ENDED
		battle_ended.emit(true)
	elif all_party_dead:
		_state = BattleState.ENDED
		battle_ended.emit(false)
