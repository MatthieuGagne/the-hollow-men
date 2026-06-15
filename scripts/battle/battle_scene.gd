extends Node2D
class_name BattleScene

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)
signal enemy_added(combatant: Combatant)
signal enemy_target_changed(combatant: Combatant)
signal enemy_group_target_changed(active: bool)
signal player_turn_started(combatant: Combatant)
signal player_turn_ended()
signal party_target_changed(combatant: Combatant)
signal party_group_target_changed(active: bool)
signal pause_toggled(paused: bool)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED, SELECTING_ALLY, SELECTING_ENEMY, PAUSED }

const SPRITE_FRAME_HEIGHT: int = 24
const SPRITE_GAP_PX: int       = 1

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
# FF-style pointing hand, sits left of the target with the index finger toward it.
const TARGET_CURSOR_OFFSET: Vector2 = Vector2(-17.0, 2.0)
# 'X' = black outline, '#' = white fill; baked to a texture at runtime (no asset
# pipeline needed). A generic gloved hand pointing right (index finger extended,
# thumb below) — same size/gesture as a classic JRPG target cursor, not a copy.
const HAND_BITMAP: Array[String] = [
	".....XXXXX.....",
	"....X#####X....",
	"....X#####XXXX.",
	"...X##########X",
	"...X##########X",
	"...X#####XXXXX.",
	"..X#####X......",
	".X######X......",
	"X#######X......",
	".X######X......",
	"..X####X.......",
	"...XXXX........",
]
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
var _target_all: bool = false
var _target_cursors: Array[Sprite2D] = []
var _cursor_layer: Node2D
var _hand_texture: ImageTexture
var _pre_pause_state: BattleState = BattleState.TICKING

@onready var _action_menu: ActionMenu = $UI/HUD/ActionMenu
@onready var _enemy_window: Panel = $UI/HUD/EnemyWindow
@onready var _victory_label: Label = $UI/VictoryLabel
@onready var _defeat_label: Label = $UI/DefeatLabel
@onready var _paused_label: Label = $UI/PausedLabel
@onready var _defeat_menu: DefeatMenu = $UI/DefeatMenu
@onready var _background: Sprite2D = $Background


# Pure: maps target_mode (+ live toggle) to the recipient list. No mutation.
# `expanded` only matters for switchable ONE_* abilities (player toggled single->all).
static func resolve_recipients(mode: int, expanded: bool, user: Combatant, picked: Combatant,
		living_party: Array[Combatant], living_enemies: Array[Combatant]) -> Array[Combatant]:
	match mode:
		Ability.TargetMode.SELF:
			var r: Array[Combatant] = [user]
			return r
		Ability.TargetMode.ONE_ALLY:
			if expanded:
				return living_party
			var r: Array[Combatant] = [picked]
			return r
		Ability.TargetMode.ALL_ALLIES:
			return living_party
		Ability.TargetMode.ONE_ENEMY:
			if expanded:
				return living_enemies
			var r: Array[Combatant] = [picked]
			return r
		Ability.TargetMode.ALL_ENEMIES:
			return living_enemies
	var empty: Array[Combatant] = []
	return empty


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
	# Targeting cursor renders as a finger on the target sprite (not the HUD list).
	_cursor_layer = Node2D.new()
	_cursor_layer.name = "TargetCursors"
	add_child(_cursor_layer)
	_hand_texture = _build_hand_texture()
	enemy_target_changed.connect(_on_enemy_target_cursor)
	party_target_changed.connect(_on_party_target_cursor)
	enemy_group_target_changed.connect(_on_enemy_group_cursor)
	party_group_target_changed.connect(_on_party_group_cursor)


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
		var sprite := Sprite2D.new()
		sprite.vframes = member.sprite_vframes
		sprite.frame = 2
		sprite.flip_h = false
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		sprite.texture = load(member.sprite_path)
		sprite.modulate = Color.WHITE
		$PartyContainer.add_child(sprite)



func add_enemy(combatant: Combatant) -> void:
	enemies.append(combatant)
	var sprite := Sprite2D.new()
	sprite.texture = load(combatant.sprite_path)
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
		elif event.is_action_pressed("move_right"):
			expand_target_to_all()      # party is on the right — push toward it
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left"):
			collapse_target_to_single()
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
		elif event.is_action_pressed("move_left"):
			expand_target_to_all()      # enemies are on the left — push toward them
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right"):
			collapse_target_to_single()
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

	# Abilities route by target_mode through the unified resolution path
	if action_name == "ability" and _active != null and _active.ability != null:
		var ab := _active.ability
		if ab.target_mode == Ability.TargetMode.SELF:
			_cast_self()
			return
		if ab.targets_party_side():
			_begin_party_targeting()
			return
		# Enemy-side: always show the target cursor, even for a lone enemy.
		_begin_enemy_targeting("ability")
		return

	# Attack — always pick a target so the cursor shows (even for a lone enemy).
	_begin_enemy_targeting(action_name)


# Apply each DamageEffect with variance and sum it (deterministic per call; dead-safe pre-await).
func _compute_damage_for(recipient: Combatant) -> int:
	var dmg: int = 0
	for effect in _active.ability.effects:
		if effect is DamageEffect:
			dmg += Combatant.apply_damage_variance(effect.compute(_active, recipient))
	return dmg


# Apply non-damage effects (heal/status/summon) to a recipient. Called at impact peak.
func _apply_nondamage_effects_to(recipient: Combatant) -> void:
	for effect in _active.ability.effects:
		if effect is HealEffect:
			recipient.heal(effect.compute_heal(_active, recipient))
		elif effect is ApplyStatusEffect:
			var inst: StatusEffect = effect.make_instance()
			if inst != null:
				recipient.apply_effect(inst)
		elif effect is SummonEffect:
			var summoned: Combatant = effect.make_summon()
			if summoned != null:
				add_enemy(summoned)


# SELF abilities resolve with no selection step and no lunge.
func _cast_self() -> void:
	if not _active.spend_pp(_active.ability.pp_cost):
		_end_turn()
		return
	_apply_nondamage_effects_to(_active)
	combatant_updated.emit(_active)
	var idx: int = party.find(_active)
	if idx >= 0:
		_spawn_damage_number(-_active.ability.pp_cost,
			$PartyContainer.get_child(idx), PP_COST_COLOR)
	_end_turn()
	_check_win_loss()


# Resolve an enemy-side ability against its recipient list (1..N). A damaging
# cast plays one shared lunge, then flashes + damages every recipient at once.
func _perform_ability_on(recipients: Array[Combatant]) -> void:
	if recipients.is_empty():
		_end_turn()
		_check_win_loss()
		return
	if _active == null or _active.ability == null:
		_end_turn()
		_check_win_loss()
		return
	if not _active.spend_pp(_active.ability.pp_cost):
		_end_turn()
		_check_win_loss()
		return
	combatant_updated.emit(_active)

	# Pre-await damage map keeps results stable across the animation (dead-safe).
	var dmg: Dictionary = {}
	var any_damage: bool = false
	for r: Combatant in recipients:
		var d: int = _compute_damage_for(r)
		dmg[r] = d
		if d > 0:
			any_damage = true

	var attacker_idx: int = party.find(_active)

	if any_damage:
		var attacker_sprite: Sprite2D = $PartyContainer.get_child(attacker_idx)
		_state = BattleState.ANIMATING

		var origin_x: float = attacker_sprite.position.x
		var lunge_tween := create_tween()
		lunge_tween.tween_property(attacker_sprite, "position:x",
			origin_x - LUNGE_DISTANCE, LUNGE_DURATION)
		await lunge_tween.finished

		for r: Combatant in recipients:
			r.take_damage(dmg[r])
			_apply_nondamage_effects_to(r)
			combatant_updated.emit(r)
			var ridx: int = enemies.find(r)
			if ridx >= 0:
				var rsprite: Sprite2D = $EnemyContainer.get_child(ridx)
				_spawn_damage_number(dmg[r], rsprite)
				_start_enemy_flash(rsprite)
		_spawn_damage_number(-_active.ability.pp_cost,
			$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)

		var return_tween := create_tween()
		return_tween.tween_property(attacker_sprite, "position:x",
			origin_x, LUNGE_RETURN_DUR)
		await return_tween.finished

		await get_tree().create_timer(FLASH_HOLD).timeout
	else:
		# Pure debuff/buff on the enemy side — no lunge, straight to TICKING.
		for r: Combatant in recipients:
			_apply_nondamage_effects_to(r)
			combatant_updated.emit(r)
		if attacker_idx >= 0:
			_spawn_damage_number(-_active.ability.pp_cost,
				$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)

	_end_turn()
	_check_win_loss()


func _begin_party_targeting() -> void:
	_state = BattleState.SELECTING_ALLY
	var living: Array[Combatant] = party.filter(
		func(p: Combatant) -> bool: return p.is_alive())
	if living.is_empty():
		_end_turn()
		return
	# A fixed ALL_ALLIES ability shows the whole party as the group target.
	_target_all = _active != null and _active.ability != null and _active.ability.is_all()
	if _target_all:
		party_group_target_changed.emit(true)
		return
	_party_target_idx = party.find(living[0])
	party_target_changed.emit(party[_party_target_idx])


func _navigate_party_target(delta: int) -> void:
	if _target_all:
		return
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
	# For a group cast the picked ally is ignored, so only the single-target
	# path requires a living pick.
	if not _target_all and not target.is_alive():
		return
	if _active == null or _active.ability == null:
		return
	if not _active.spend_pp(_active.ability.pp_cost):
		return
	var living_party: Array[Combatant] = party.filter(
		func(p: Combatant) -> bool: return p.is_alive())
	var recipients := resolve_recipients(_active.ability.target_mode, _target_all,
		_active, target, living_party, [])
	if _target_all:
		party_group_target_changed.emit(false)
	for r: Combatant in recipients:
		_apply_nondamage_effects_to(r)
		combatant_updated.emit(r)
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
	# A fixed ALL_ENEMIES ability shows the whole enemy group as the target.
	_target_all = action_name == "ability" and _active != null \
		and _active.ability != null and _active.ability.is_all()
	if _target_all:
		enemy_group_target_changed.emit(true)
		return
	enemy_target_changed.emit(enemies[_enemy_target_idx])


func _navigate_enemy_target(delta: int) -> void:
	if _target_all:
		return
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
	if _target_all:
		enemy_group_target_changed.emit(false)

	# Ability: unified recipient resolution (single, AoE, or switchable-expanded)
	if _pending_action == "ability" and _active != null and _active.ability != null:
		var living: Array[Combatant] = enemies.filter(
			func(e: Combatant) -> bool: return e.is_alive())
		var recipients := resolve_recipients(_active.ability.target_mode, _target_all,
			_active, target, [], living)
		_perform_ability_on(recipients)
		return

	# Attack: single-target lunge (attack never AoEs)
	var damage: int = Combatant.calculate_damage(_active, target)
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


# Switchable ONE_* abilities expand to their matching ALL_* live during selection.
func expand_target_to_all() -> void:
	if _active == null or _active.ability == null or not _active.ability.switchable:
		return
	if _target_all:
		return
	_target_all = true
	if _active.ability.targets_enemy_side():
		enemy_target_changed.emit(null)          # clear single cursor
		enemy_group_target_changed.emit(true)
	else:
		party_target_changed.emit(null)
		party_group_target_changed.emit(true)


func collapse_target_to_single() -> void:
	# Only a switchable ability can collapse; a fixed ALL_* stays grouped.
	if not _target_all or _active == null or _active.ability == null \
			or not _active.ability.switchable:
		return
	_target_all = false
	if _active.ability.targets_enemy_side():
		enemy_group_target_changed.emit(false)
		enemy_target_changed.emit(enemies[_enemy_target_idx])
	else:
		party_group_target_changed.emit(false)
		party_target_changed.emit(party[_party_target_idx])


func skip_turn() -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_active.skip_cooldown = SKIP_COOLDOWN
	_active = null
	_action_menu.hide()
	_state = BattleState.TICKING
	player_turn_ended.emit()


func _end_turn() -> void:
	_target_all = false
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


# --- Target cursor: a finger rendered on the targeted sprite (FF-style) ---

func _clear_target_cursors() -> void:
	for cursor in _target_cursors:
		cursor.queue_free()
	_target_cursors.clear()


func _build_hand_texture() -> ImageTexture:
	var h: int = HAND_BITMAP.size()
	var w: int = HAND_BITMAP[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(h):
		var row: String = HAND_BITMAP[y]
		for x in range(row.length()):
			match row[x]:
				"#":
					img.set_pixel(x, y, Color.WHITE)
				"X":
					img.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(img)


func _add_target_cursor(container: Node2D, idx: int) -> void:
	if idx < 0 or idx >= container.get_child_count():
		return
	var sprite: Node2D = container.get_child(idx)
	var hand := Sprite2D.new()
	hand.texture = _hand_texture
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Parent to a dedicated layer (not the sprite container, whose child order the
	# damage-number/flash code indexes by enemy index).
	hand.position = container.position + sprite.position + TARGET_CURSOR_OFFSET
	_cursor_layer.add_child(hand)
	_target_cursors.append(hand)


func _on_enemy_target_cursor(combatant: Combatant) -> void:
	_clear_target_cursors()
	if combatant != null:
		_add_target_cursor($EnemyContainer, enemies.find(combatant))


func _on_party_target_cursor(combatant: Combatant) -> void:
	_clear_target_cursors()
	if combatant != null:
		_add_target_cursor($PartyContainer, party.find(combatant))


func _on_enemy_group_cursor(active: bool) -> void:
	_clear_target_cursors()
	if active:
		for i in range(enemies.size()):
			if enemies[i].is_alive():
				_add_target_cursor($EnemyContainer, i)


func _on_party_group_cursor(active: bool) -> void:
	_clear_target_cursors()
	if active:
		for i in range(mini(party.size(), $PartyContainer.get_child_count())):
			if party[i].is_alive():
				_add_target_cursor($PartyContainer, i)


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
