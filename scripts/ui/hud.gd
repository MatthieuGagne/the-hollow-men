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

var _party: Array[Combatant] = []
var _panels: Array[Control] = []


func setup(party: Array[Combatant], battle: Node) -> void:
	_party = party
	battle.combatant_updated.connect(_on_combatant_updated)
	_build_panels()


func _build_panels() -> void:
	var container: VBoxContainer = $PartyPanel
	for combatant in _party:
		var panel := _make_panel(combatant)
		container.add_child(panel)
		_panels.append(panel)


func _make_panel(combatant: Combatant) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = combatant.character_name + "Panel"
	row.add_theme_constant_override("separation", 3)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name.to_upper()
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	row.add_child(name_label)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = str(combatant.max_hp)
	hp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hp_label)

	var pp_label := Label.new()
	pp_label.name = "PPLabel"
	pp_label.text = str(combatant.max_pp)
	pp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_label.modulate = COLOR_PP
	row.add_child(pp_label)

	var atb_bar := ProgressBar.new()
	atb_bar.name = "ATBBar"
	atb_bar.max_value = 100.0
	atb_bar.value = 0.0
	atb_bar.show_percentage = false
	atb_bar.custom_minimum_size = Vector2(ATB_MIN_WIDTH, 6)
	atb_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(atb_bar)

	return row


func _on_combatant_updated(combatant: Combatant) -> void:
	var i := _party.find(combatant)
	if i < 0 or i >= _panels.size():
		return
	_update_panel(_panels[i], combatant)


func _update_panel(panel: Control, combatant: Combatant) -> void:
	var name_label: Label    = panel.get_node("NameLabel")
	var hp_label: Label      = panel.get_node("HPLabel")
	var pp_label: Label      = panel.get_node("PPLabel")
	var atb_bar: ProgressBar = panel.get_node("ATBBar")

	name_label.text = combatant.character_name.to_upper()
	name_label.modulate.a = 1.0 if not combatant.atb_full() else \
		(0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))

	hp_label.text = str(combatant.current_hp)
	hp_label.modulate = COLOR_HP_FULL.lerp(COLOR_HP_LOW, 1.0 - combatant.hp_ratio())

	pp_label.text = str(combatant.current_pp)
	pp_label.modulate = COLOR_PP

	atb_bar.value = combatant.atb_ratio() * 100.0
	atb_bar.modulate = COLOR_ATB
