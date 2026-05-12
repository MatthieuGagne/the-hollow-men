extends Node2D

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED }

const REID_RES  := "res://characters/reid.tres"
const IRIS_RES  := "res://characters/iris.tres"
const SHADE_RES := "res://characters/enemies/shade.tres"
const REID_TEX  := "res://assets/sprites/characters/reid.png"
const IRIS_TEX  := "res://assets/sprites/characters/iris.png"
const SLOT_POSITIONS: Array[int] = [-64, -32, 0, 32, 64]
const PLACEHOLDER_MODULATE := Color(0.4, 0.4, 0.4, 0.5)

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
	$UI/HUD.setup(party, enemies, self)


func _setup_sprites() -> void:
	var party_textures: Array = [load(REID_TEX), load(IRIS_TEX)]

	for i in range(5):
		var sprite := Sprite2D.new()
		sprite.vframes = 6
		sprite.frame = 0
		sprite.flip_h = true
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		if i < party_textures.size():
			sprite.texture = party_textures[i]
		else:
			sprite.texture = load(REID_TEX)
			sprite.modulate = PLACEHOLDER_MODULATE
		$PartyContainer.add_child(sprite)

	var shade_rect := ColorRect.new()
	shade_rect.color = Color(0.5, 0.5, 0.5)
	shade_rect.size = Vector2(32, 32)
	shade_rect.position = Vector2(-16, -16)
	$EnemyContainer.add_child(shade_rect)


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
