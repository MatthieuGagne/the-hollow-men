extends Control

const COLOR_HP_FULL          := Color(0.25, 0.85, 0.35)
const COLOR_HP_LOW           := Color(0.85, 0.20, 0.20)
const COLOR_PP               := Color(0.55, 0.20, 0.85)
const COLOR_ATB              := Color(1.00, 1.00, 1.00)
const COLOR_LIMIT_BUREAU     := Color(0.55, 0.55, 0.55)
const COLOR_LIMIT_JAILBROKEN := Color(1.00, 0.80, 0.10)

const NAME_MIN_WIDTH: int = 36
const STAT_NUM_WIDTH: int = 26
const ATB_MIN_WIDTH: int  = 44
const CURSOR_MIN_WIDTH: int = 8
const ATB_DRAIN_DURATION: float = 0.15
const ATB_DRAIN_THRESHOLD: float = 10.0

var _party: Array[Combatant] = []
var _panels: Array[Control] = []
var _draining: Dictionary = {}
var _enemies: Array[Combatant] = []
var _enemy_panels: Array[Control] = []


func setup(party: Array[Combatant], enemies: Array[Combatant], battle: Node) -> void:
	_party = party
	battle.combatant_updated.connect(_on_combatant_updated)
	battle.player_turn_started.connect(_on_player_turn_started)
	battle.player_turn_ended.connect(_on_player_turn_ended)
	battle.party_target_changed.connect(_on_party_target_changed)
	_build_enemy_rows(enemies)
	_build_panels()


func _build_enemy_rows(enemies_list: Array[Combatant]) -> void:
	_enemies = enemies_list
	var container: VBoxContainer = $EnemyWindow/EnemyRows
	for combatant in _enemies:
		var panel := _make_enemy_panel(combatant)
		container.add_child(panel)
		_enemy_panels.append(panel)


func _build_panels() -> void:
	var container: VBoxContainer = $PartyWindow/PartyRows
	for i in range(5):
		var panel: Control
		if i < _party.size():
			panel = _make_panel(_party[i])
		else:
			panel = _make_placeholder_panel()
		container.add_child(panel)
		_panels.append(panel)


func _make_panel(combatant: Combatant) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = combatant.character_name + "Panel"
	row.add_theme_constant_override("separation", 2)
	row.custom_minimum_size = Vector2(0, 6)

	var cursor_label := Label.new()
	cursor_label.name = "CursorLabel"
	cursor_label.text = "▶"
	cursor_label.custom_minimum_size = Vector2(CURSOR_MIN_WIDTH, 0)
	cursor_label.add_theme_font_size_override("font_size", 6)
	cursor_label.modulate.a = 0.0
	row.add_child(cursor_label)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name.to_upper()
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = str(combatant.max_hp)
	hp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.add_theme_font_size_override("font_size", 6)
	row.add_child(hp_label)

	var pp_label := Label.new()
	pp_label.name = "PPLabel"
	pp_label.text = str(combatant.max_pp)
	pp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_label.modulate = COLOR_PP
	pp_label.add_theme_font_size_override("font_size", 6)
	row.add_child(pp_label)

	var atb_bar := ProgressBar.new()
	atb_bar.name = "ATBBar"
	atb_bar.max_value = 100.0
	atb_bar.value = 0.0
	atb_bar.show_percentage = false
	atb_bar.custom_minimum_size = Vector2(ATB_MIN_WIDTH, 4)
	atb_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(atb_bar)

	var effects_label := Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.text = ""
	effects_label.add_theme_font_size_override("font_size", 6)
	row.add_child(effects_label)

	return row


func _make_placeholder_panel() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PlaceholderPanel"
	row.custom_minimum_size = Vector2(0, 6)
	row.add_theme_constant_override("separation", 2)
	row.modulate = Color(0.5, 0.5, 0.5, 0.5)

	var cursor_spacer := Label.new()
	cursor_spacer.custom_minimum_size = Vector2(CURSOR_MIN_WIDTH, 0)
	row.add_child(cursor_spacer)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "---"
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "0"
	hp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.add_theme_font_size_override("font_size", 6)
	row.add_child(hp_label)

	var pp_label := Label.new()
	pp_label.name = "PPLabel"
	pp_label.text = "0"
	pp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_label.modulate = COLOR_PP
	pp_label.add_theme_font_size_override("font_size", 6)
	row.add_child(pp_label)

	var atb_bar := ProgressBar.new()
	atb_bar.name = "ATBBar"
	atb_bar.max_value = 100.0
	atb_bar.value = 0.0
	atb_bar.show_percentage = false
	atb_bar.custom_minimum_size = Vector2(ATB_MIN_WIDTH, 4)
	atb_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(atb_bar)

	return row


func _make_enemy_panel(combatant: Combatant) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = combatant.character_name.replace(" ", "") + "Panel"
	row.add_theme_constant_override("separation", 2)
	row.custom_minimum_size = Vector2(0, 6)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name.to_upper()
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)

	var effects_label := Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.text = ""
	effects_label.add_theme_font_size_override("font_size", 6)
	row.add_child(effects_label)

	return row


func _on_combatant_updated(combatant: Combatant) -> void:
	var i := _party.find(combatant)
	if i >= 0 and i < _panels.size():
		_update_panel(_panels[i], combatant)
		return
	var j := _enemies.find(combatant)
	if j >= 0 and j < _enemy_panels.size():
		_update_enemy_panel(_enemy_panels[j], combatant)


func _update_panel(panel: Control, combatant: Combatant) -> void:
	var name_label: Label    = panel.get_node("NameLabel")
	var hp_label: Label      = panel.get_node("HPLabel")
	var pp_label: Label      = panel.get_node("PPLabel")
	var atb_bar: ProgressBar = panel.get_node("ATBBar")

	name_label.text = combatant.character_name.to_upper()
	name_label.modulate.a = 1.0

	hp_label.text = str(combatant.current_hp)
	hp_label.modulate = COLOR_HP_FULL.lerp(COLOR_HP_LOW, 1.0 - combatant.hp_ratio())

	pp_label.text = str(combatant.current_pp)
	pp_label.modulate = COLOR_PP

	var target_atb: float = combatant.atb_ratio() * 100.0
	if not _draining.get(panel, false) and atb_bar.value > target_atb + ATB_DRAIN_THRESHOLD:
		_draining[panel] = true
		var tween := create_tween()
		tween.tween_property(atb_bar, "value", target_atb, ATB_DRAIN_DURATION)
		tween.finished.connect(func(): _draining[panel] = false)
	elif not _draining.get(panel, false):
		atb_bar.value = target_atb
	atb_bar.modulate = COLOR_ATB
	panel.modulate.a = 0.4 if combatant.is_dead() else 1.0
	if panel.has_node("EffectsLabel"):
		panel.get_node("EffectsLabel").text = _format_effects(combatant)


func _format_effects(combatant: Combatant) -> String:
	var parts: Array = []
	for effect in combatant.active_effects:
		var axis_name: String = StatusEffect.StatAxis.keys()[effect.stat]
		var sign: String = "+" if effect.modifier >= 0 else ""
		parts.append("%s %s%s%d (%dt)" % [effect.effect_name, axis_name, sign, effect.modifier, effect.duration])
	return "\n".join(parts)


func _update_enemy_panel(panel: Control, combatant: Combatant) -> void:
	var name_label: Label = panel.get_node("NameLabel")
	name_label.modulate.a = 0.4 if combatant.is_dead() else 1.0
	panel.get_node("EffectsLabel").text = _format_effects(combatant)


func _on_player_turn_started(combatant: Combatant) -> void:
	for i in range(mini(_party.size(), _panels.size())):
		if not _panels[i].has_node("CursorLabel"):
			continue
		var cursor: Label = _panels[i].get_node("CursorLabel")
		cursor.modulate.a = 1.0 if _party[i] == combatant else 0.0


func _on_player_turn_ended() -> void:
	for i in range(mini(_party.size(), _panels.size())):
		if not _panels[i].has_node("CursorLabel"):
			continue
		_panels[i].get_node("CursorLabel").modulate.a = 0.0


func _on_party_target_changed(combatant: Combatant) -> void:
	for i in range(mini(_party.size(), _panels.size())):
		if not _panels[i].has_node("CursorLabel"):
			continue
		var cursor: Label = _panels[i].get_node("CursorLabel")
		cursor.modulate.a = 1.0 if _party[i] == combatant else 0.0
