extends Control

const PANEL_WIDTH: int = 76
const COLOR_HP_FULL          := Color(0.25, 0.85, 0.35)
const COLOR_HP_LOW           := Color(0.85, 0.20, 0.20)
const COLOR_PP               := Color(0.55, 0.20, 0.85)
const COLOR_ATB              := Color(1.00, 1.00, 1.00)
const COLOR_LIMIT_BUREAU     := Color(0.55, 0.55, 0.55)
const COLOR_LIMIT_JAILBROKEN := Color(1.00, 0.80, 0.10)

var _party: Array[Combatant] = []
var _panels: Array[Control] = []


func setup(party: Array[Combatant], battle: Node) -> void:
	_party = party
	battle.combatant_updated.connect(_on_combatant_updated)
	_build_panels()


func _build_panels() -> void:
	var container: HBoxContainer = $PartyPanel
	for combatant in _party:
		var panel := _make_panel(combatant)
		container.add_child(panel)
		_panels.append(panel)


func _make_panel(combatant: Combatant) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = combatant.character_name + "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name
	panel.add_child(name_label)

	for bar_name: String in ["HPBar", "PPBar", "ATBBar", "LimitBar"]:
		var bar := ProgressBar.new()
		bar.name = bar_name
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		panel.add_child(bar)

	return panel


func _on_combatant_updated(combatant: Combatant) -> void:
	var i := _party.find(combatant)
	if i < 0 or i >= _panels.size():
		return
	_update_panel(_panels[i], combatant)


func _update_panel(panel: Control, combatant: Combatant) -> void:
	var hp_bar: ProgressBar    = panel.get_node("HPBar")
	var pp_bar: ProgressBar    = panel.get_node("PPBar")
	var atb_bar: ProgressBar   = panel.get_node("ATBBar")
	var limit_bar: ProgressBar = panel.get_node("LimitBar")
	var name_label: Label      = panel.get_node("NameLabel")

	name_label.text = combatant.character_name

	hp_bar.value = combatant.hp_ratio() * 100.0
	hp_bar.modulate = COLOR_HP_FULL.lerp(COLOR_HP_LOW, 1.0 - combatant.hp_ratio())

	pp_bar.value = combatant.pp_ratio() * 100.0
	pp_bar.modulate = COLOR_PP

	atb_bar.value = combatant.atb_ratio() * 100.0
	atb_bar.modulate = COLOR_ATB

	limit_bar.max_value = combatant.limit_cap()
	limit_bar.value = combatant.limit_gauge
	match combatant.sigil_type:
		Combatant.SigilType.BUREAU:
			limit_bar.modulate = COLOR_LIMIT_BUREAU
		Combatant.SigilType.JAILBROKEN:
			limit_bar.modulate = COLOR_LIMIT_JAILBROKEN
		_:
			limit_bar.modulate = COLOR_ATB

	name_label.modulate.a = 1.0 if not combatant.atb_full() else \
		(0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
