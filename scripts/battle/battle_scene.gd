extends Node2D

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED }

const REID_RES  := "res://characters/reid.tres"
const IRIS_RES  := "res://characters/iris.tres"
const SHADE_RES := "res://characters/enemies/shade.tres"
const REID_TEX  := "res://assets/sprites/characters/reid.png"
const IRIS_TEX  := "res://assets/sprites/characters/iris.png"

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var _state: BattleState = BattleState.TICKING
var _active: Combatant = null


func _ready() -> void:
	var reid: Combatant = load(REID_RES)
	reid.reset_runtime_state()

	var iris: Combatant = load(IRIS_RES)
	iris.reset_runtime_state()

	var shade: Combatant = load(SHADE_RES)
	shade.reset_runtime_state()

	party = [reid, iris]
	enemies = [shade]

	_setup_sprites()
	$UI/HUD.setup(party, self)


func _setup_sprites() -> void:
	var reid_sprite := Sprite2D.new()
	reid_sprite.texture = load(REID_TEX)
	reid_sprite.vframes = 6
	reid_sprite.frame = 0
	reid_sprite.flip_h = true
	reid_sprite.position = Vector2(0, -16)
	$PartyContainer.add_child(reid_sprite)

	var iris_sprite := Sprite2D.new()
	iris_sprite.texture = load(IRIS_TEX)
	iris_sprite.vframes = 6
	iris_sprite.frame = 0
	iris_sprite.flip_h = true
	iris_sprite.position = Vector2(0, 16)
	$PartyContainer.add_child(iris_sprite)

	var shade_rect := ColorRect.new()
	shade_rect.color = Color(0.5, 0.5, 0.5)
	shade_rect.size = Vector2(32, 32)
	shade_rect.position = Vector2(-16, -16)
	$EnemyContainer.add_child(shade_rect)

	var shade_label := Label.new()
	shade_label.text = "Shade"
	shade_label.position = Vector2(-16, -12)
	$EnemyContainer.add_child(shade_label)


func _process(delta: float) -> void:
	if _state != BattleState.TICKING:
		return
	_tick_atb(delta)
	_check_win_loss()


func _tick_atb(delta: float) -> void:
	for combatant in party + enemies:
		combatant.tick_atb(delta)
		combatant_updated.emit(combatant)

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


func _begin_enemy_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.ANIMATING
	_end_turn()


func execute_action(action: Dictionary) -> void:
	_state = BattleState.ANIMATING
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
