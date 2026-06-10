extends Node2D
class_name BattleScene

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)
signal enemy_added(combatant: Combatant)
signal enemy_target_changed(combatant: Combatant)
signal player_turn_started(combatant: Combatant)
signal player_turn_ended()
signal party_target_changed(combatant: Combatant)
signal pause_toggled(paused: bool)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED, SELECTING_ALLY, SELECTING_ENEMY, PAUSED }

const SHADE_TEX     := "res://assets/sprites/enemies/shade.png"

const ENEMY_SPRITE_DATA: Dictionary = {
	"Shade":                  {"texture": "res://assets/sprites/enemies/shade.png"},
	"Territory Enforcer":     {"texture": "res://assets/sprites/enemies/shade.png"},
	"Block Captain":          {"texture": "res://assets/sprites/enemies/shade.png"},
	"Private Security Guard": {"texture": "res://assets/sprites/enemies/private_security_guard.png"},
	"Security Captain":       {"texture": "res://assets/sprites/enemies/security_captain.png"},
}
const SPRITE_FRAME_HEIGHT: int = 24
const SPRITE_GAP_PX: int       = 1

const PARTY_SPRITE_DATA: Dictionary = {
	"Reid":   {"texture": "res://assets/sprites/characters/reid.png",   "vframes": 8},
	"Iris":   {"texture": "res://assets/sprites/characters/iris.png",   "vframes": 8},
	"Karim":  {"texture": "res://assets/sprites/characters/karim.png",  "vframes": 8},
	"Margot": {"texture": "res://assets/sprites/characters/margot.png", "vframes": 8},
}

const SLOT_POSITIONS: Array[int] = [
	-2 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	-1 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	 0,
	 1 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
	 2 * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX),
]
const DAMAGE_NUMBER_FONT_SIZE:    int     = 8
const DAMAGE_NUMBER_SPAWN_OFFSET: Vector2 = Vector2(0.0, -20.0)
const DAMAGE_NUMBER_FLOAT_DIST:   float   = 20.0
const DAMAGE_NUMBER_DURATION:     float   = 1.0
const SKIP_COOLDOWN:              float   = 2.0
const PP_COST_COLOR := Color(0.55, 0.20, 0.85)
const LUNGE_DISTANCE:      float = 20.0
const LUNGE_DURATION:      float = 0.1
const LUNGE_RETURN_DUR:    float = 0.15
const FLASH_PULSE_HALF:    float = 0.05   # each pulse = 2 × this (up + down)
const FLASH_PULSES:        int   = 3      # 3 pulses × 0.1s = 0.3s total
const FLASH_HOLD:          float = 0.15   # remaining flash after return (0.3 - 0.15)
const OVERBRIGHT:          Color = Color(2.0, 2.0, 2.0, 1.0)
const WORLD_SCENE:   String = "res://scenes/world/Rooftop.tscn"
const BATTLE_SCENE:  String = "res://scenes/battle/BattleScene.tscn"
const VICTORY_DELAY: float  = 1.5

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var _state: BattleState = BattleState.TICKING
var _active: Combatant = null
var _party_target_idx: int = 0
var _enemy_target_idx: int = 0
var _pending_action: String = ""
var _pre_pause_state: BattleState = BattleState.TICKING

@onready var _action_menu: ActionMenu = $UI/HUD/ActionMenu
@onready var _enemy_window: Panel = $UI/HUD/EnemyWindow
@onready var _victory_label: Label = $UI/VictoryLabel
@onready var _defeat_label: Label = $UI/DefeatLabel
@onready var _paused_label: Label = $UI/PausedLabel
@onready var _defeat_menu: DefeatMenu = $UI/DefeatMenu
@onready var _background: Sprite2D = $Background


func _ready() -> void:
	_load_background()
	party = PartyManager.get_active_members()
	_spawn_enemies()
	_setup_sprites()
	$UI/HUD.setup(party, enemies, self)
	_action_menu.action_selected.connect(execute_action)
	pause_toggled.connect(_action_menu._on_pause_toggled)
	battle_ended.connect(_on_battle_ended)
	_defeat_menu.retry_requested.connect(func(): SceneManager.change_scene(BATTLE_SCENE))
	_defeat_menu.quit_requested.connect(func(): get_tree().quit())
	combatant_updated.connect(_on_combatant_updated)


func _spawn_enemies() -> void:
	if BattleContext.enemies != "":
		for id: String in BattleContext.enemies.split(","):
			add_enemy(Combatant.from_definition(GameData.get_definition(id.strip_edges())))
	else:
		add_enemy(Combatant.from_definition(GameData.get_definition("shade")))


func _load_background() -> void:
	var id := BattleContext.background_id if BattleContext.background_id != "" else "default"
	var path := "res://assets/battle_backgrounds/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/battle_backgrounds/default.png"
	_background.texture = load(path)


func _setup_sprites() -> void:
	for i in range(party.size()):
		var member := party[i]
		if not PARTY_SPRITE_DATA.has(member.character_name):
			push_warning("BattleScene: no sprite data for '%s'" % member.character_name)
			continue
		var data: Dictionary = PARTY_SPRITE_DATA[member.character_name]
		var sprite := Sprite2D.new()
		sprite.vframes = data["vframes"]
		sprite.frame = 2
		sprite.flip_h = false
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		sprite.texture = load(data["texture"])
		sprite.modulate = Color.WHITE
		$PartyContainer.add_child(sprite)



func add_enemy(combatant: Combatant) -> void:
	enemies.append(combatant)
	var sprite := Sprite2D.new()
	var data: Dictionary = ENEMY_SPRITE_DATA.get(combatant.character_name,
		{"texture": SHADE_TEX})
	sprite.texture = load(data["texture"])
	var idx := enemies.size() - 1
	sprite.position = Vector2(0, idx * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX))
	$EnemyContainer.add_child(sprite)
	enemy_added.emit(combatant)


func _process(delta: float) -> void:
	_tick_skip_cooldowns(delta)
	if _state == BattleState.PAUSED:
		return
	if _state == BattleState.TICKING:
		_tick_atb(delta)
		_check_win_loss()
	elif _state == BattleState.AWAITING_INPUT or _state == BattleState.SELECTING_ALLY \
			or _state == BattleState.SELECTING_ENEMY:
		for combatant in enemies:
			combatant.tick_atb(delta)
			combatant_updated.emit(combatant)
			if combatant.atb_full() and not combatant.is_dead():
				_enemy_attack_without_interrupting(combatant)
				_check_win_loss()
				if _state == BattleState.ENDED:
					return
				if _active != null and _active.is_dead():
					_end_turn()
				return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_battle"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _state == BattleState.PAUSED:
		return
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
	if _state == BattleState.SELECTING_ENEMY:
		if event.is_action_pressed("move_up"):
			_navigate_enemy_target(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down"):
			_navigate_enemy_target(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			confirm_enemy_target()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("skip_turn"):
		skip_turn()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _state == BattleState.PAUSED:
		_state = _pre_pause_state
		pause_toggled.emit(false)
		_paused_label.hide()
	elif _state in [BattleState.TICKING, BattleState.AWAITING_INPUT, BattleState.SELECTING_ALLY, BattleState.SELECTING_ENEMY]:
		_pre_pause_state = _state
		_state = BattleState.PAUSED
		pause_toggled.emit(true)
		_paused_label.show()


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
	var result := _resolve_enemy_action(combatant)
	if result.get("action") == "attack":
		var target: Combatant = result["target"]
		var damage: int = result["damage"]
		combatant_updated.emit(target)
		var idx: int = party.find(target)
		_spawn_damage_number(damage, $PartyContainer.get_child(idx))
	await get_tree().create_timer(0.3).timeout
	_end_turn()
	_check_win_loss()


func _enemy_attack_without_interrupting(combatant: Combatant) -> void:
	var result := _resolve_enemy_action(combatant)
	if result.get("action") == "attack":
		var target: Combatant = result["target"]
		var damage: int = result["damage"]
		combatant_updated.emit(target)
		var idx: int = party.find(target)
		_spawn_damage_number(damage, $PartyContainer.get_child(idx))
	combatant.tick_effects()
	combatant.consume_atb()


func _resolve_enemy_action(combatant: Combatant) -> Dictionary:
	if combatant.ai == null:
		return {}
	return combatant.ai.resolve_action(combatant, party, enemies, Callable(self, "add_enemy"))


func _select_enemy_target() -> Combatant:
	var living: Array[Combatant] = party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		return null
	return living[randi() % living.size()]


func execute_action(action_name: String) -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_action_menu.hide()

	# Healing abilities route through party targeting — no animation
	if action_name == "ability" \
			and _active != null \
			and _active.ability != null \
			and _active.ability.targets_party:
		_begin_party_targeting()
		return

	# Multiple living enemies — enter selection UI
	var living_enemies: Array[Combatant] = enemies.filter(
		func(e: Combatant) -> bool: return e.is_alive())
	if living_enemies.size() > 1:
		_begin_enemy_targeting(action_name)
		return

	# Resolve damage and PP cost synchronously before any await (dead-enemy safe)
	var damage: int = 0
	var target: Combatant = null
	if not living_enemies.is_empty():
		target = living_enemies[0]
		match action_name:
			"attack":
				damage = Combatant.calculate_damage(_active, target)
			"ability":
				damage = _resolve_ability(_active, target)

	# Emit PP HUD update now — PP was already spent by _resolve_ability
	if action_name == "ability" and _active != null and _active.ability != null:
		combatant_updated.emit(_active)

	if damage > 0 and target != null:
		var attacker_idx: int = party.find(_active)
		var attacker_sprite: Sprite2D = $PartyContainer.get_child(attacker_idx)
		var enemy_idx: int = enemies.find(target)
		var target_sprite: Sprite2D = $EnemyContainer.get_child(enemy_idx)
		_state = BattleState.ANIMATING

		# Lunge toward enemy (negative x = left toward EnemyContainer)
		var origin_x: float = attacker_sprite.position.x
		var lunge_tween := create_tween()
		lunge_tween.tween_property(attacker_sprite, "position:x",
			origin_x - LUNGE_DISTANCE, LUNGE_DURATION)
		await lunge_tween.finished

		# Impact peak: apply damage, spawn numbers, start flash
		target.take_damage(damage)
		combatant_updated.emit(target)
		_spawn_damage_number(damage, target_sprite)
		if action_name == "ability" and _active != null and _active.ability != null:
			_spawn_damage_number(-_active.ability.pp_cost,
				$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
		_start_enemy_flash(target_sprite)

		# Return to origin — runs concurrently with flash
		var return_tween := create_tween()
		return_tween.tween_property(attacker_sprite, "position:x",
			origin_x, LUNGE_RETURN_DUR)
		await return_tween.finished

		# Wait for the remaining flash time before ending turn (flash = 0.3s, return = 0.15s)
		await get_tree().create_timer(FLASH_HOLD).timeout

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
	var attacker_idx: int = party.find(_active)
	if attacker_idx >= 0:
		_spawn_damage_number(-_active.ability.pp_cost,
			$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
	_end_turn()
	_check_win_loss()


func _begin_enemy_targeting(action_name: String) -> void:
	_pending_action = action_name
	var living: Array[Combatant] = enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
	if living.is_empty():
		_end_turn()
		return
	_enemy_target_idx = enemies.find(living[0])
	_state = BattleState.SELECTING_ENEMY
	enemy_target_changed.emit(enemies[_enemy_target_idx])


func _navigate_enemy_target(delta: int) -> void:
	var living: Array[Combatant] = enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
	if living.is_empty():
		return
	var living_idx: int = living.find(enemies[_enemy_target_idx])
	if living_idx < 0:
		living_idx = 0
	living_idx = clampi(living_idx + delta, 0, living.size() - 1)
	_enemy_target_idx = enemies.find(living[living_idx])
	enemy_target_changed.emit(enemies[_enemy_target_idx])


func confirm_enemy_target() -> void:
	if _state != BattleState.SELECTING_ENEMY:
		return
	var target: Combatant = enemies[_enemy_target_idx]
	if not target.is_alive():
		return

	enemy_target_changed.emit(null)

	# Resolve damage and PP cost synchronously before any await
	var damage: int = 0
	match _pending_action:
		"attack":
			damage = Combatant.calculate_damage(_active, target)
		"ability":
			damage = _resolve_ability(_active, target)

	if _pending_action == "ability" and _active != null and _active.ability != null:
		combatant_updated.emit(_active)

	if damage > 0:
		var attacker_idx: int = party.find(_active)
		var attacker_sprite: Sprite2D = $PartyContainer.get_child(attacker_idx)
		var target_sprite: Sprite2D = $EnemyContainer.get_child(_enemy_target_idx)
		_state = BattleState.ANIMATING

		var origin_x: float = attacker_sprite.position.x
		var lunge_tween := create_tween()
		lunge_tween.tween_property(attacker_sprite, "position:x",
			origin_x - LUNGE_DISTANCE, LUNGE_DURATION)
		await lunge_tween.finished

		target.take_damage(damage)
		combatant_updated.emit(target)
		_spawn_damage_number(damage, target_sprite)
		if _pending_action == "ability" and _active != null and _active.ability != null:
			_spawn_damage_number(-_active.ability.pp_cost,
				$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
		_start_enemy_flash(target_sprite)

		var return_tween := create_tween()
		return_tween.tween_property(attacker_sprite, "position:x",
			origin_x, LUNGE_RETURN_DUR)
		await return_tween.finished

		await get_tree().create_timer(FLASH_HOLD).timeout
	else:
		_state = BattleState.TICKING

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
		"Margot":
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
		_active.tick_effects()
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


func _spawn_damage_number(amount: int, container: Node2D, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.modulate = color
	label.position = DAMAGE_NUMBER_SPAWN_OFFSET
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	container.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y",
		DAMAGE_NUMBER_SPAWN_OFFSET.y - DAMAGE_NUMBER_FLOAT_DIST, DAMAGE_NUMBER_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_DURATION)
	tween.finished.connect(label.queue_free)


func _start_enemy_flash(sprite: Sprite2D) -> void:
	var flash_tween := create_tween()
	for _i in range(FLASH_PULSES):
		flash_tween.tween_property(sprite, "modulate", OVERBRIGHT, FLASH_PULSE_HALF)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, FLASH_PULSE_HALF)


func _on_combatant_updated(combatant: Combatant) -> void:
	var idx := party.find(combatant)
	if idx < 0:
		return
	$PartyContainer.get_child(idx).modulate.a = 0.4 if combatant.is_dead() else 1.0


func _on_battle_ended(victory: bool) -> void:
	_action_menu.hide()
	if victory:
		PartyManager.remove_temporary_members()
		_victory_label.show()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		if is_inside_tree():
			var target := BattleContext.return_scene if BattleContext.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target, BattleContext.return_spawn)
	else:
		_defeat_label.show()
		_defeat_menu.show()
