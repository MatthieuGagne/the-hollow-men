extends Node2D
class_name BattleScene

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)
signal player_turn_started(combatant: Combatant)
signal player_turn_ended()
signal party_target_changed(combatant: Combatant)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED, SELECTING_ALLY }

const REID_RES   := "res://characters/reid.tres"
const IRIS_RES   := "res://characters/iris.tres"
const KARIM_RES  := "res://characters/karim.tres"
const MARGOT_RES := "res://characters/margot.tres"
const SHADE_RES  := "res://characters/enemies/shade.tres"
const REID_TEX  := "res://assets/sprites/characters/reid.png"
const IRIS_TEX  := "res://assets/sprites/characters/iris.png"
const SPRITE_FRAME_HEIGHT: int = 24  # reid.png / iris.png: 144px sheet, vframes=6
const SPRITE_GAP_PX: int       = 1

const SLOT_POSITIONS: Array[int] = [
	-2 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	-1 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	 0,
	 1 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	 2 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
]
const PLACEHOLDER_MODULATE := Color(0.4, 0.4, 0.4, 0.5)
const KARIM_MODULATE       := Color(0.6, 0.85, 1.0, 1.0)
const MARGOT_MODULATE      := Color(0.85, 0.6, 1.0, 1.0)
const DAMAGE_NUMBER_FONT_SIZE:    int     = 8
const DAMAGE_NUMBER_SPAWN_OFFSET: Vector2 = Vector2(0.0, -20.0)
const DAMAGE_NUMBER_FLOAT_DIST:   float   = 20.0
const DAMAGE_NUMBER_DURATION:     float   = 1.0
const SKIP_COOLDOWN:              float   = 2.0

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var _state: BattleState = BattleState.TICKING
var _active: Combatant = null
var _party_target_idx: int = 0

@onready var _action_menu: ActionMenu = $UI/HUD/ActionMenu
@onready var _enemy_window: Panel = $UI/HUD/EnemyWindow
@onready var _victory_label: Label = $UI/VictoryLabel
@onready var _defeat_label: Label = $UI/DefeatLabel


func _ready() -> void:
	var reid: Combatant = load(REID_RES)
	reid.reset_runtime_state()

	var iris: Combatant = load(IRIS_RES)
	iris.reset_runtime_state()

	var karim: Combatant = load(KARIM_RES)
	karim.reset_runtime_state()

	var margot: Combatant = load(MARGOT_RES)
	margot.reset_runtime_state()

	var shade: Combatant = load(SHADE_RES)
	shade.reset_runtime_state()

	party = [reid, iris, karim, margot]
	enemies = [shade]

	_setup_sprites()
	$UI/HUD.setup(party, enemies, self)
	_action_menu.action_selected.connect(execute_action)
	battle_ended.connect(_on_battle_ended)
	combatant_updated.connect(_on_combatant_updated)


func _setup_sprites() -> void:
	var party_textures: Array = [
		load(REID_TEX), load(IRIS_TEX), load(REID_TEX), load(REID_TEX)
	]
	var party_modulates: Array[Color] = [
		Color.WHITE, Color.WHITE, KARIM_MODULATE, MARGOT_MODULATE
	]

	for i in range(5):
		var sprite := Sprite2D.new()
		sprite.vframes = 6
		sprite.frame = 0
		sprite.flip_h = true
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		if i < party_textures.size():
			sprite.texture = party_textures[i]
			sprite.modulate = party_modulates[i]
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
	_tick_skip_cooldowns(delta)
	if _state == BattleState.TICKING:
		_tick_atb(delta)
		_check_win_loss()
	elif _state == BattleState.AWAITING_INPUT:
		for combatant in enemies:
			combatant.tick_atb(delta)
			combatant_updated.emit(combatant)
			if combatant.atb_full() and not combatant.is_dead():
				_begin_enemy_turn(combatant)
				return


func _unhandled_input(event: InputEvent) -> void:
	if _state == BattleState.SELECTING_ALLY:
		if event.is_action_pressed("move_up"):
			_navigate_party_target(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down"):
			_navigate_party_target(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			confirm_party_target(party[_party_target_idx])
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skip_turn"):
		skip_turn()
		get_viewport().set_input_as_handled()


func _tick_skip_cooldowns(delta: float) -> void:
	for combatant in party + enemies:
		if combatant.is_skipping():
			combatant.skip_cooldown = maxf(combatant.skip_cooldown - delta, 0.0)


func _tick_atb(delta: float) -> void:
	for combatant in party + enemies:
		combatant.tick_atb(delta)
		combatant_updated.emit(combatant)

	for combatant in party:
		if combatant.atb_full() and not combatant.is_dead() and not combatant.is_skipping():
			_begin_player_turn(combatant)
			return

	for combatant in enemies:
		if combatant.atb_full() and not combatant.is_dead() and not combatant.is_skipping():
			_begin_enemy_turn(combatant)
			return


func _begin_player_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.AWAITING_INPUT
	_action_menu.setup(_active)
	_action_menu.show()
	player_turn_started.emit(combatant)


func _begin_enemy_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.ANIMATING
	var target: Combatant = _select_enemy_target()
	if target:
		var damage: int = Combatant.calculate_damage(combatant, target)
		target.take_damage(damage)
		combatant_updated.emit(target)
		var idx: int = party.find(target)
		_spawn_damage_number(damage, $PartyContainer.get_child(idx))
	await get_tree().create_timer(0.3).timeout
	_end_turn()
	_check_win_loss()


func _select_enemy_target() -> Combatant:
	var living: Array[Combatant] = party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		return null
	return living[randi() % living.size()]


func execute_action(action_name: String) -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_action_menu.hide()
	if action_name == "ability" \
			and _active != null \
			and _active.ability != null \
			and _active.ability.targets_party:
		_begin_party_targeting()
		return
	if not enemies.is_empty():
		var target: Combatant = enemies[0]
		var damage: int = 0
		match action_name:
			"attack":
				damage = Combatant.calculate_damage(_active, target)
			"ability":
				damage = _resolve_ability(_active, target)
		if damage > 0:
			target.take_damage(damage)
			_spawn_damage_number(damage, $EnemyContainer)
	_end_turn()
	_check_win_loss()


func _begin_party_targeting() -> void:
	_state = BattleState.SELECTING_ALLY
	var living: Array[Combatant] = party.filter(
		func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		_end_turn()
		return
	_party_target_idx = party.find(living[0])
	party_target_changed.emit(party[_party_target_idx])


func _navigate_party_target(delta: int) -> void:
	var living: Array[Combatant] = party.filter(
		func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		return
	var living_idx: int = living.find(party[_party_target_idx])
	if living_idx < 0:
		living_idx = 0
	living_idx = clampi(living_idx + delta, 0, living.size() - 1)
	_party_target_idx = party.find(living[living_idx])
	party_target_changed.emit(party[_party_target_idx])


func confirm_party_target(target: Combatant) -> void:
	if not target.is_alive():
		return
	if _active == null or _active.ability == null:
		return
	if not _active.spend_pp(_active.ability.pp_cost):
		return
	target.heal(60)
	combatant_updated.emit(target)
	combatant_updated.emit(_active)
	_end_turn()
	_check_win_loss()


func _resolve_ability(attacker: Combatant, target: Combatant) -> int:
	if attacker.ability == null:
		return 0
	if not attacker.spend_pp(attacker.ability.pp_cost):
		return 0
	match attacker.character_name:
		"Reid":
			return Combatant.calculate_piercing_strike(attacker)
		"Iris":
			return Combatant.calculate_static_touch(attacker, target)
	return 0  # unknown character — ability not implemented


func skip_turn() -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_active.skip_cooldown = SKIP_COOLDOWN
	_active = null
	_action_menu.hide()
	_state = BattleState.TICKING
	player_turn_ended.emit()


func _end_turn() -> void:
	if _active and _active.is_player_controlled:
		player_turn_ended.emit()
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


func _spawn_damage_number(amount: int, container: Node2D) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.position = DAMAGE_NUMBER_SPAWN_OFFSET
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	container.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y",
		DAMAGE_NUMBER_SPAWN_OFFSET.y - DAMAGE_NUMBER_FLOAT_DIST, DAMAGE_NUMBER_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_DURATION)
	tween.finished.connect(label.queue_free)


func _on_combatant_updated(combatant: Combatant) -> void:
	var idx := party.find(combatant)
	if idx < 0:
		return
	$PartyContainer.get_child(idx).modulate.a = 0.4 if combatant.is_dead() else 1.0


func _on_battle_ended(victory: bool) -> void:
	if victory:
		_victory_label.show()
	else:
		_defeat_label.show()
